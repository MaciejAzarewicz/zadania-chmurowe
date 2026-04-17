const express = require('express');
const os = require('os');
const { Pool } = require('pg');
const { createClient } = require('redis');

const app = express();
app.use(express.json());

const instanceId = process.env.INSTANCE_ID || os.hostname();
const startedAt = Date.now();
let requestCount = 0;

app.use((req, res, next) => {
  requestCount += 1;
  next();
});

const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'postgres',
  port: process.env.POSTGRES_PORT ? parseInt(process.env.POSTGRES_PORT, 10) : 5432,
  database: process.env.POSTGRES_DB || 'products',
  user: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'postgres',
});

const redisUrl = process.env.REDIS_URL || `redis://${process.env.REDIS_HOST || 'redis'}:${process.env.REDIS_PORT || 6379}`;
const redisClient = createClient({ url: redisUrl });
redisClient.on('error', (err) => console.error('Redis Client Error', err));

async function init() {
  // try to connect to redis (best effort)
  try {
    await redisClient.connect();
  } catch (err) {
    console.error('Redis connect failed (will retry on demand):', err.message);
  }

  // ensure table exists
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS items (
        id BIGINT PRIMARY KEY,
        name TEXT NOT NULL
      );
    `);
  } catch (err) {
    console.error('Failed to create table:', err.message);
  }
}

app.get('/items', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT id, name FROM items ORDER BY id');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'db_error' });
  }
});

app.post('/items', async (req, res) => {
  const name = req.body.name;
  if (!name) return res.status(400).json({ error: 'name_required' });
  const id = Date.now();
  try {
    await pool.query('INSERT INTO items (id, name) VALUES ($1, $2)', [id, name]);
    res.status(201).json({ id, name });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'db_error' });
  }
});

app.get('/stats', async (req, res) => {
  try {
    let cached = null;
    try {
      cached = await redisClient.get('stats');
    } catch (err) {
      console.error('Redis GET error:', err.message);
    }

    if (cached) {
      res.set('X-Cache', 'HIT');
      return res.json(JSON.parse(cached));
    }

    const { rows } = await pool.query('SELECT COUNT(*) AS count FROM items');
    const count = parseInt(rows[0].count, 10) || 0;
    const stats = {
      count,
      instance: instanceId,
      serverTime: new Date().toISOString(),
      uptime: Math.floor((Date.now() - startedAt) / 1000),
      requestCount,
    };

    try {
      await redisClient.setEx('stats', 10, JSON.stringify(stats));
    } catch (err) {
      console.error('Redis SETEX error:', err.message);
    }

    res.set('X-Cache', 'MISS');
    res.json(stats);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'db_error' });
  }
});

app.get('/health', async (req, res) => {
  const health = { postgres: { ok: false }, redis: { ok: false } };
  try {
    await pool.query('SELECT 1');
    health.postgres.ok = true;
  } catch (err) {
    health.postgres.ok = false;
    health.postgres.error = err.message;
  }
  try {
    const pong = await redisClient.ping();
    health.redis.ok = pong === 'PONG';
  } catch (err) {
    health.redis.ok = false;
    health.redis.error = err.message;
  }
  res.json(health);
});

const port = process.env.PORT || 3000;
const server = app.listen(port, async () => {
  console.log('Server listening on', port);
  await init();
});

process.on('SIGINT', async () => {
  console.log('Shutting down...');
  server.close();
  try { await redisClient.disconnect(); } catch (e) {}
  try { await pool.end(); } catch (e) {}
  process.exit(0);
});
