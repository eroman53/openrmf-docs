### creating the user for READ/SAVE/UPLOAD by hand
* ~/mongodb/bin/mongo 'mongodb://root:REDACTED@localhost'
* use admin
* db.createUser({ user: "openrmf" , pwd: "REDACTED", roles: ["readWriteAnyDatabase"]});
* use openrmf
* db.createCollection("Artifacts");

### creating the user for TEMPLATES by hand
* ~/mongodb/bin/mongo 'mongodb://root:REDACTED@localhost'
* use admin
* db.createUser({ user: "openrmftemplate" , pwd: "REDACTED", roles: ["readWriteAnyDatabase"]});
* use openrmftemplate
* db.createCollection("Templates");

### creating the database user SCORES by hand
* ~/mongodb/bin/mongo 'mongodb://root:REDACTED@localhost'
* use admin
* db.createUser({ user: "openrmfscore" , pwd: "REDACTED", roles: ["readWriteAnyDatabase"]});
* use openrmfscore
* db.createCollection("Scores");

## connecting to the database collection straight (example)
~/mongodb/bin/mongo 'mongodb://openrmf:REDACTED@localhost/openrmf?authSource=admin'