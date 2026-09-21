# Creating MongoDB Users by Hand

If you wish, you can have a separate MongoDB setup locally, on your network, or in the cloud and connect to it.
The commands below would create it locally in a MongoDB on your local machine. Adjust the server name and user/pwd
accordingly. Make sure your connection strings in the docker-compose or YAML are correct when you do this. 

If using Kubernetes the best way to match up servers, users, and passwords is to use the Helm chart.

## creating the user for READ/SAVE/UPLOAD by hand
* ~/mongodb/bin/mongo 'mongodb://root:${MONGO_ROOT_PASSWORD}@localhost'
* use admin
* db.createUser({ user: "openrmf" , pwd: "${MONGO_PASSWORD}", roles: ["readWriteAnyDatabase"]});
* use openrmf
* db.createCollection("Artifacts");

## creating the user for TEMPLATES by hand
* ~/mongodb/bin/mongo 'mongodb://root:${MONGO_ROOT_PASSWORD}@localhost'
* use admin
* db.createUser({ user: "openrmftemplate" , pwd: "${MONGO_PASSWORD}", roles: ["readWriteAnyDatabase"]});
* use openrmftemplate
* db.createCollection("Templates");

## creating the database user SCORES by hand
* ~/mongodb/bin/mongo 'mongodb://root:${MONGO_ROOT_PASSWORD}@localhost'
* use admin
* db.createUser({ user: "openrmfscore" , pwd: "${MONGO_PASSWORD}", roles: ["readWriteAnyDatabase"]});
* use openrmfscore
* db.createCollection("Scores");

## connecting to the database collection straight (example)
~/mongodb/bin/mongo 'mongodb://openrmf:${MONGO_PASSWORD}@localhost/openrmf?authSource=admin'