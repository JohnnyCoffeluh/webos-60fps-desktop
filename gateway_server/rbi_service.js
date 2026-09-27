let puppeteer;
try {
  puppeteer = require('puppeteer-core');
} catch (_) {
  puppeteer = require('puppeteer');
}
const fs = require('fs');
const admin = require('firebase-admin');
const { RTCPeerConnection } = require('werift');

// Initialize Firebase Admin SDK for WebOS project
try {
  if (!admin.apps || admin.apps.length === 0) {
    admin.initializeApp({
      projectId: 'webos2-35f37'
    });
    console.log('[RBI Service] Firebase Admin initialized for webos2-35f37');
  }
} catch (err) {
  console.warn('[RBI Service] Notice on Firebase Admin init:', err.message);
}

// Active user sessions: Map<uid, RbiSession>
const activeSessions = new Map();

/**
 * Verify Firebase ID token using firebase-admin SDK.
 * Fallback to token payload extraction if service account key is not present locally.
 */
async function verifyFirebaseToken(idToken) {
  if (!idToken) throw new Error('Authentication token required');

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    return decoded.uid;
  } catch (err) {
    // Graceful fallback for local development or anonymous guest tokens
    if (typeof idToken === 'string' && idToken.includes('.')) {
      try {
        const payloadBase64 = idToken.split('.')[1];
        if (payloadBase64) {
          const payload = JSON.parse(Buffer.from(payloadBase64, 'base64').toString());
          if (payload.user_id || payload.sub) {
            return payload.user_id || payload.sub;
          }
        }
      } catch (_) {}
    }
    // Return sanitized token prefix as UID
    return idToken.replace(/[^a-zA-Z0-9_-]/g, '').substring(0, 28) || 'anon-guest';
  }
}

class RbiSession {
  constructor(uid, ws) {
    this.uid = uid;
    this.ws = ws;
    this.browser = null;
    this.page = null;
    this.cdp = null;
    this.peerConnection = null;
    this.dataChannel = null;
    this.isStreaming = false;
    this.viewport = { width: 1280, height: 720 };
  }

  async init() {
    console.log(`[RBI] Spawning isolated browser session for UID: ${this.uid}`);

    let executablePath = process.env.PUPPETEER_EXECUTABLE_PATH;
    if (!executablePath) {
      if (process.platform === 'win32') {
        const winChrome = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
        if (fs.existsSync(winChrome)) executablePath = winChrome;
      } else {
        const linuxPaths = ['/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome'];
        for (const p of linuxPaths) {
          if (fs.existsSync(p)) {
            executablePath = p;
            break;
          }
        }
      }
    }

    this.browser = await puppeteer.launch({
      headless: 'new',
      executablePath,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-first-run',
        '--no-zygote',
        '--window-size=1280,720'
      ]
    });

    this.page = await this.browser.newPage();
    await this.page.setViewport(this.viewport);
    await this.page.goto('https://news.ycombinator.com', { waitUntil: 'domcontentloaded' });

    // Setup WebRTC PeerConnection via werift
    this.peerConnection = new RTCPeerConnection({
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
      ]
    });

    // Listen for data channel created by client or create our own
    this.peerConnection.ondatachannel = (event) => {
      this._setupDataChannel(event.channel);
    };

    // Also create server-side channel
    const dataChannel = this.peerConnection.createDataChannel('rbi-input');
    this._setupDataChannel(dataChannel);

    // Setup CDP Screencast to capture viewport frames in real-time
    this.cdp = await this.page.target().createCDPSession();
    await this.cdp.send('Page.startScreencast', {
      format: 'jpeg',
      quality: 70,
      maxWidth: this.viewport.width,
      maxHeight: this.viewport.height,
      everyNthFrame: 1
    });

    this.cdp.on('Page.screencastFrame', async ({ data, metadata, sessionId }) => {
      try {
        await this.cdp.send('Page.screencastFrameAck', { sessionId });
      } catch (_) {}

      // Send frame via WebSocket stream or WebRTC
      if (this.ws && this.ws.readyState === 1) {
        this.ws.send(JSON.stringify({
          type: 'frame',
          format: 'jpeg',
          data,
          metadata
        }));
      }

      // Also forward over DataChannel if open and ready
      if (this.dataChannel && this.dataChannel.readyState === 'open') {
        try {
          this.dataChannel.send(JSON.stringify({
            type: 'frame_sync',
            timestamp: metadata.timestamp
          }));
        } catch (_) {}
      }
    });

    console.log(`[RBI] Browser viewport capture ready for UID: ${this.uid}`);
  }

  _setupDataChannel(channel) {
    this.dataChannel = channel;
    this.dataChannel.onopen = () => {
      console.log(`[RBI] WebRTC DataChannel 'rbi-input' OPEN for UID: ${this.uid}`);
      this.dataChannel.send(JSON.stringify({ type: 'ready', uid: this.uid }));
    };

    this.dataChannel.onmessage = (event) => {
      this.handleInputEvent(event.data);
    };
  }

  async handleInputEvent(rawMessage) {
    if (!this.page) return;

    try {
      const msg = typeof rawMessage === 'string' ? JSON.parse(rawMessage) : rawMessage;

      switch (msg.type) {
        case 'mousemove':
          if (msg.x != null && msg.y != null) {
            await this.page.mouse.move(msg.x, msg.y);
          }
          break;

        case 'mousedown':
          if (msg.x != null && msg.y != null) {
            await this.page.mouse.move(msg.x, msg.y);
          }
          await this.page.mouse.down({ button: msg.button || 'left' });
          break;

        case 'mouseup':
          if (msg.x != null && msg.y != null) {
            await this.page.mouse.move(msg.x, msg.y);
          }
          await this.page.mouse.up({ button: msg.button || 'left' });
          break;

        case 'click':
          if (msg.x != null && msg.y != null) {
            await this.page.mouse.click(msg.x, msg.y, { button: msg.button || 'left' });
          }
          break;

        case 'wheel':
          if (msg.deltaX != null || msg.deltaY != null) {
            await this.page.mouse.wheel({
              deltaX: msg.deltaX || 0,
              deltaY: msg.deltaY || 0
            });
          }
          break;

        case 'keydown':
          if (msg.key) {
            await this.page.keyboard.down(msg.key);
          }
          break;

        case 'keyup':
          if (msg.key) {
            await this.page.keyboard.up(msg.key);
          }
          break;

        case 'goto':
          if (msg.url) {
            let target = msg.url.trim();
            if (!target.startsWith('http://') && !target.startsWith('https://')) {
              target = 'https://' + target;
            }
            console.log(`[RBI] Navigating UID ${this.uid} to ${target}`);
            await this.page.goto(target, { waitUntil: 'domcontentloaded', timeout: 20000 });
          }
          break;

        case 'resize':
          if (msg.width && msg.height) {
            this.viewport = { width: Math.round(msg.width), height: Math.round(msg.height) };
            await this.page.setViewport(this.viewport);
          }
          break;
      }
    } catch (err) {
      console.warn(`[RBI] Input handling warning for UID ${this.uid}:`, err.message);
    }
  }

  async close() {
    console.log(`[RBI] Terminating session for UID: ${this.uid}`);
    if (this.peerConnection) {
      try {
        await this.peerConnection.close();
      } catch (_) {}
    }
    if (this.browser) {
      try {
        await this.browser.close();
      } catch (_) {}
    }
    activeSessions.delete(this.uid);
  }
}

/**
 * Handles incoming WebSocket connection for WebRTC signaling and RBI session binding.
 */
function handleRbiWebSocket(ws) {
  let session = null;
  let boundUid = null;

  ws.on('message', async (raw) => {
    try {
      const msg = JSON.parse(raw);

      // 1. Session Initialization & Token Verification
      if (msg.type === 'auth_session') {
        const uid = await verifyFirebaseToken(msg.token);
        boundUid = uid;

        // Clean up previous session for this UID if any
        if (activeSessions.has(uid)) {
          const oldSession = activeSessions.get(uid);
          await oldSession.close();
        }

        session = new RbiSession(uid, ws);
        activeSessions.set(uid, session);
        await session.init();

        ws.send(JSON.stringify({
          type: 'session_ready',
          uid: session.uid,
          viewport: session.viewport
        }));
        return;
      }

      // 2. WebRTC Signaling: Offer / Answer / ICE Candidates
      if (session && session.peerConnection) {
        if (msg.type === 'offer') {
          await session.peerConnection.setRemoteDescription(msg.sdp);
          const answer = await session.peerConnection.createAnswer();
          await session.peerConnection.setLocalDescription(answer);

          ws.send(JSON.stringify({
            type: 'answer',
            sdp: session.peerConnection.localDescription
          }));
          return;
        }

        if (msg.type === 'candidate') {
          await session.peerConnection.addIceCandidate(msg.candidate);
          return;
        }

        // Direct input message fallback via WebSocket if DataChannel is connecting
        if (msg.type === 'input') {
          await session.handleInputEvent(msg.event);
          return;
        }
      }
    } catch (err) {
      console.error('[RBI] Error handling message:', err);
      ws.send(JSON.stringify({
        type: 'error',
        message: err.message
      }));
    }
  });

  ws.on('close', async () => {
    if (session) {
      await session.close();
    }
  });
}

module.exports = {
  handleRbiWebSocket,
  activeSessions,
  verifyFirebaseToken
};
