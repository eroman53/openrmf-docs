db.createUser({ user: "openrmfconmon" , pwd: "openrmf1234!", roles: [{ "role": "readWrite", "db": "openrmfconmon"}]});
db.createCollection("CadencePolicies");
db.CadencePolicies.createIndex({ systemGroupId: 1 }, { unique: true });
