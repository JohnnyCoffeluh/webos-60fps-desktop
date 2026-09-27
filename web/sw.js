// WebOS Virtual Desktop Network Gateway Service Worker
// Version: 2.4.0-speedboost

const CACHE_NAME = 'webos-network-gateway-v2';
const STATIC_ASSETS_CACHE = 'webos-static-assets-v1';

let GATEWAY_ENDPOINT = 'http://localhost:3000';
let FIREBASE_AUTH_TOKEN = '';

// Install lifecycle
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

// Activate lifecycle
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME && key !== STATIC_ASSETS_CACHE) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Listen for messages from Flutter Web app (e.g. dynamic gateway endpoint or Firebase Auth token)
self.addEventListener('message', (event) => {
  if (!event.data) return;
  
  if (event.data.type === 'CONFIGURE_GATEWAY') {
    if (event.data.gatewayUrl) {
      GATEWAY_ENDPOINT = event.data.gatewayUrl.replace(/\/+$/, '');
    }
    if (event.data.authToken) {
      FIREBASE_AUTH_TOKEN = event.data.authToken;
    }
    if (event.source) {
      event.source.postMessage({
        type: 'GATEWAY_CONFIGURED',
        gatewayUrl: GATEWAY_ENDPOINT,
        hasAuthToken: !!FIREBASE_AUTH_TOKEN
      });
    }
  }

  if (event.data.type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.delete(CACHE_NAME).then(() => {
        if (event.source) {
          event.source.postMessage({ type: 'CACHE_CLEARED' });
        }
      })
    );
  }
});

// Intercept network requests
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Check if this request is routed to the virtual gateway:
  // 1. Explicit path prefix '/v-gateway/'
  // 2. Custom header 'X-WebOS-Virtual-Net'
  const isVirtualRoute = url.pathname.startsWith('/v-gateway/');
  const hasVirtualHeader = event.request.headers.get('X-WebOS-Virtual-Net') === 'true';

  if (!isVirtualRoute && !hasVirtualHeader) {
    // Normal Flutter app asset request, let default network handle it
    return;
  }

  // Extract target URL
  let targetUrl = '';
  if (isVirtualRoute) {
    targetUrl = decodeURIComponent(url.pathname.replace('/v-gateway/', '')) + url.search;
  } else {
    targetUrl = event.request.url;
  }

  event.respondWith(handleVirtualGatewayRequest(event.request, targetUrl));
});

async function handleVirtualGatewayRequest(originalRequest, targetUrl) {
  // Strategy: Cache-First for media/fonts/images; Stale-While-Revalidate for web pages
  const cacheKey = new Request(targetUrl);
  const cache = await caches.open(CACHE_NAME);
  const cachedResponse = await cache.match(cacheKey);

  // If cached and it's a GET request, return cached immediately while updating in background
  if (cachedResponse && originalRequest.method === 'GET') {
    // Background revalidate (non-blocking)
    fetchViaGateway(originalRequest, targetUrl)
      .then((freshResponse) => {
        if (freshResponse && freshResponse.ok) {
          cache.put(cacheKey, freshResponse.clone());
        }
      })
      .catch(() => {/* Ignore background revalidation failure */});

    return cachedResponse;
  }

  // Not in cache, fetch via backend Gateway
  try {
    const freshResponse = await fetchViaGateway(originalRequest, targetUrl);
    if (freshResponse.ok && originalRequest.method === 'GET') {
      cache.put(cacheKey, freshResponse.clone());
    }
    return freshResponse;
  } catch (err) {
    // If network fails but we had an older cache, fallback to it
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Return friendly JSON error
    return new Response(
      JSON.stringify({
        error: 'Virtual Gateway routing error',
        details: err.message,
        targetUrl
      }),
      {
        status: 504,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
}

async function fetchViaGateway(request, targetUrl) {
  const gatewayUrl = `${GATEWAY_ENDPOINT}/proxy?url=${encodeURIComponent(targetUrl)}`;
  
  const headers = new Headers(request.headers);
  headers.set('X-Forwarded-For-WebOS', 'true');
  if (FIREBASE_AUTH_TOKEN) {
    headers.set('Authorization', `Bearer ${FIREBASE_AUTH_TOKEN}`);
    headers.set('X-Firebase-Auth-Token', FIREBASE_AUTH_TOKEN);
  }

  const fetchOptions = {
    method: request.method,
    headers,
    mode: 'cors'
  };

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    fetchOptions.body = await request.clone().blob();
  }

  return fetch(gatewayUrl, fetchOptions);
}
