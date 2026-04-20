const os = require('os');
const instance = process.env.WORKER || os.hostname();
console.log(`${instance} worker starting`);
setInterval(() => {
  console.log(`${instance} heartbeat ${new Date().toISOString()}`);
}, 5000);
