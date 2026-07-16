db.createUser({ user: "openrmfscanwatch" , pwd: "openrmf1234!", roles: [{ "role": "readWrite", "db": "openrmfscanwatch"}]});
db.createCollection("ProcessedFiles");
db.ProcessedFiles.createIndex({ path: 1, sha256: 1 });
db.ProcessedFiles.createIndex({ status: 1, lastAttempt: -1 });
