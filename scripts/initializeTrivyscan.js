db.createUser({ user: "openrmftrivyscan" , pwd: "openrmf1234!", roles: [{ "role": "readWrite", "db": "openrmftrivyscan"}]});
db.createCollection("TrivyConfig");
db.createCollection("TrivyRuns");
db.TrivyRuns.createIndex({ when: -1 });
