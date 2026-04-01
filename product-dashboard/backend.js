const express = require('express');
const os = require('os');

const app = express();
app.use(express.json());

let items = [];
const instanceId = process.env.INSTANCE_ID || os.hostname(); // <- zmiana
const startedAt = Date.now();
let requestCount = 0;

app.use((req, res, next) => {
  requestCount += 1;
  next();
});

app.get('/items', (req, res) => res.json(items));

app.post('/items', (req, res) => {
  const item = { id: Date.now(), name: req.body.name };
  items.push(item);
  res.status(201).json(item);
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: Math.floor((Date.now() - startedAt) / 1000)
  });
});

app.get('/stats', (req, res) => {
  res.json({
    count: items.length,
    instance: instanceId,
    serverTime: new Date().toISOString(),
    uptime: Math.floor((Date.now() - startedAt) / 1000),
    requestCount
  });
});

app.listen(3000);