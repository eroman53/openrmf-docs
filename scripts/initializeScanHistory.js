db.createUser({ user: "openrmfscanhistory" , pwd: "openrmf1234!", roles: [{ "role": "readWrite", "db": "openrmfscanhistory"}]});
db.createCollection("ScanFiles");
db.ScanFiles.createIndex({ systemGroupId: 1, scanType: 1, isLatest: 1 });
db.ScanFiles.createIndex({ created: -1 });
db.createCollection("Findings");
db.Findings.createIndex({ systemGroupId: 1, scanType: 1, status: 1 });
db.Findings.createIndex({ systemGroupId: 1, scanType: 1, hostname: 1, pluginId: 1 });
