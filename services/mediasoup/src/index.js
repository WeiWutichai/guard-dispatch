/**
 * MediaSoup Server — Video/Audio Call Service
 * Port: 3005
 */

'use strict';

const http = require('http');

const PORT = process.env.MEDIASOUP_PORT || 3005;

// Health check server
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK');
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log(`mediasoup-server listening on port ${PORT}`);
});
