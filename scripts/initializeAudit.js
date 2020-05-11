db.createUser({ user: "openrmfaudit" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmfaudit"}]});
db.createCollection("Audits");
db.Audits.createIndex({ created: -1 })
db.Audits.createIndex({ username: 1 })
db.Audits.createIndex({ program: 1 })
db.Audits.createIndex({ action: 1 })