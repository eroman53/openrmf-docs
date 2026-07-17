db.createUser({ user: "openrmftrivyscan" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmftrivyscan"}]});
db.createCollection("TrivyConfig");
db.createCollection("TrivyRuns");
db.TrivyRuns.createIndex({ when: -1 });
