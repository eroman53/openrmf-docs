db.createUser({ user: "openrmfscore" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmfscore"}]});
db.createCollection("Scores");