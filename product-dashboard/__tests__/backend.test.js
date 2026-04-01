const request = require('supertest');
const { createApp } = require('../backend');

describe('backend endpoints', () => {
  test('GET /health returns ok and uptime', async () => {
    const app = createApp();
    const res = await request(app).get('/health');

    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(typeof res.body.uptime).toBe('number');
    expect(res.body.uptime).toBeGreaterThanOrEqual(0);
  });

  test('GET /stats returns serverTime and requestCount', async () => {
    const app = createApp();

    await request(app).get('/items');
    const res = await request(app).get('/stats');

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('serverTime');
    expect(res.body).toHaveProperty('requestCount');
    expect(typeof res.body.serverTime).toBe('string');
    expect(typeof res.body.requestCount).toBe('number');
    expect(res.body.requestCount).toBeGreaterThanOrEqual(2);
  });
});
