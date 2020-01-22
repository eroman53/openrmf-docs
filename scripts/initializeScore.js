db.createUser({ user: "openrmfscore" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmfscore"}]});
db.createCollection("Scores");
db.Scores.createIndex({ artifactId: 1 })
db.Scores.createIndex({ systemGroupId: 1 })
db.Scores.createIndex({ hostName: 1 })