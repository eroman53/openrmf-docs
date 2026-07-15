db.createUser({ user: "openrmfjournal" , pwd: "REDACTED", roles: [{ "role": "readWrite", "db": "openrmfjournal"}]});
db.createCollection("JournalEntries");
db.JournalEntries.createIndex({ systemGroupId: 1, created: -1 });
db.JournalEntries.createIndex({ entityType: 1, entityId: 1, created: -1 });
db.JournalEntries.createIndex({ created: -1 });
