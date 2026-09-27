const http = require('http');
const express = require('express');
const cors = require('cors');
const { createBareServer } = require('@tomphttp/bare-server-node');
const wisp = require('@mercuryworkshop/wisp-js/server');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

// Initialize Bare Server
const bareServer = createBareServer('/bare/');

// CORS middleware allowing Firebase Hosting domains and local development
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD'],
  allowedHeaders: ['*'],
  exposedHeaders: ['*']
}));

app.use(express.json());

// Serve compiled Flutter WebOS frontend & Ultraviolet assets
const path = require('path');
const fs = require('fs');
const staticPath = fs.existsSync(path.join(__dirname, 'public'))
  ? path.join(__dirname, 'public')
  : path.join(__dirname, '../build/web');
app.use(express.static(staticPath, {
  setHeaders: (res, filepath) => {
    if (filepath.endsWith('sw.js')) {
      res.set('Service-Worker-Allowed', '/');
    }
  }
}));

// Health & Status routes
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/api/status', (req, res) => {
  res.status(200).json({
    status: 'ONLINE',
    proxyType: 'Wisp & Bare Multiplexing Engine',
    port: PORT,
    endpoints: {
      wisp: '/wisp/',
      bare: '/bare/',
      health: '/health'
    },
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

// Bare server HTTP routing middleware
app.use((req, res, next) => {
  if (bareServer.shouldRoute(req)) {
    bareServer.routeRequest(req, res);
  } else {
    next();
  }
});

// Create underlying HTTP Server to handle both Express and WebSocket upgrades
const server = http.createServer();

server.on('request', (req, res) => {
  if (bareServer.shouldRoute(req)) {
    bareServer.routeRequest(req, res);
  } else {
    app(req, res);
  }
});

// Handle WebSocket upgrades for Wisp and Bare
server.on('upgrade', (req, socket, head) => {
  const url = req.url || '';

  if (url.startsWith('/wisp')) {
    // Route to Wisp multiplexing server
    wisp.server.routeRequest(req, socket, head);
  } else if (bareServer.shouldRoute(req)) {
    // Route to Bare server
    bareServer.routeUpgrade(req, socket, head);
  } else {
    socket.destroy();
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[Wisp/Bare Gateway] Server listening on http://${HOST}:${PORT}`);
  console.log(`[Wisp/Bare Gateway] Wisp endpoint: ws://${HOST}:${PORT}/wisp/`);
  console.log(`[Wisp/Bare Gateway] Bare endpoint: http://${HOST}:${PORT}/bare/`);
  console.log(`[Wisp/Bare Gateway] Health check: http://${HOST}:${PORT}/health`);
});
