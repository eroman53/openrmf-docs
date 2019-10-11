db.createUser({ user: "openrmftemplate" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmftemplate"}]});
db.createCollection("Templates");