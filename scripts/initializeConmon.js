db.createUser({ user: "openrmfconmon" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmfconmon"}]});
db.createCollection("CadencePolicies");
db.CadencePolicies.createIndex({ systemGroupId: 1 }, { unique: true });
