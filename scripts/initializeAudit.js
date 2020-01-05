db.createUser({ user: "openrmfaudit" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmfaudit"}]});
db.createCollection("Audits");