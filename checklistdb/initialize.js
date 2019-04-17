db.createUser({ user: "openrmf" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmf"}]});
db.createCollection("Artifacts");