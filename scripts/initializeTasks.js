db.createUser({ user: "openrmftasks" , pwd: "openrmf1234!", roles: [{ "role": "readWrite", "db": "openrmftasks"}]});
db.createCollection("Tasks");
db.Tasks.createIndex({ systemGroupId: 1, status: 1 });
db.Tasks.createIndex({ assignedTo: 1, status: 1 });
db.Tasks.createIndex({ dueDate: 1 });
