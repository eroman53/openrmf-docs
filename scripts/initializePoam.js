db.createUser({ user: "openrmfpoam" , pwd: "openrmf1234!", roles: [{ "role": "readWrite", "db": "openrmfpoam"}]});
db.createCollection("Poams");
db.Poams.createIndex({ systemGroupId: 1, sourceType: 1, sourceKey: 1 });
db.Poams.createIndex({ systemGroupId: 1, status: 1 });
db.Poams.createIndex({ artifactId: 1 });
db.Poams.createIndex({ created: -1 });
