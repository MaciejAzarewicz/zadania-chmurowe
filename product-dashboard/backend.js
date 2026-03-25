const express = require('express');
const os = require('os');

const app = express();
app.use(express.json());

let items = [];
const instanceId = os.hostname();

app.get('/items', (req, res) => res.json(items));

app.post('/items', (req, res) => {
  const item = { id: Date.now(), name: req.body.name };
  items.push(item);
  res.status(201).json(item);
});

app.get('/stats', (req, res) => {
  res.json({
    count: items.length,
    instance: instanceId
  });
});

app.listen(3000, () => console.log('Backend running'));