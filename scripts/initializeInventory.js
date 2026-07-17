db.createUser({ user: "openrmfinventory" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmfinventory"}]});
db.createCollection("Assets");
db.Assets.createIndex({ systemGroupId: 1, hostname: 1 });
db.Assets.createIndex({ systemGroupId: 1, osName: 1 });
db.createCollection("OsMappings");
db.OsMappings.createIndex({ priority: 1 });
