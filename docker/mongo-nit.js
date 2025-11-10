db = db.getSiblingDB('ifro_logs');

db.createUser({
  user: 'ifro',
  pwd:  'ifro123',
  roles: [{ role: 'readWrite', db: 'ifro_logs' }]
});

db.createCollection('logs');
