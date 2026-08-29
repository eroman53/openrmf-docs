// Consolidated MongoDB init: creates all STOOGE fork + upstream databases,
// users, collections, and indexes on a SINGLE mongod instance. Preserves the
// "one database per service, no shared writes" rule at the database + user
// (auth) level -- each service still connects only to its own logical DB with
// its own credentials. Replaces the 13 per-service initialize*.js scripts.
var d;

// ---- openrmf (checklist / systems) ----
d = db.getSiblingDB('openrmf');
d.createUser({ user: "openrmf", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmf" }] });
d.createCollection("Artifacts");
d.Artifacts.createIndex({ systemGroupId: 1 });
d.Artifacts.createIndex({ stigType: 1 });
d.Artifacts.createIndex({ stigRelease: 1 });
d.Artifacts.createIndex({ hostName: 1 });
d.Artifacts.createIndex({ version: 1 });
d.Artifacts.createIndex({ created: -1 });
d.Artifacts.createIndex({ updatedOn: -1 });
d.createCollection("SystemGroups");
d.SystemGroups.createIndex({ title: 1 });
d.SystemGroups.createIndex({ created: -1 });
d.SystemGroups.createIndex({ updatedOn: -1 });
d.SystemGroups.createIndex({ numberOfChecklists: 1 });
// full-text search (Phase 1)
d.Artifacts.createIndex({ hostName: "text", stigType: "text", systemTitle: "text" }, { name: "ft_search" });
d.SystemGroups.createIndex({ title: "text", description: "text" }, { name: "ft_search" });

// ---- openrmfscore ----
d = db.getSiblingDB('openrmfscore');
d.createUser({ user: "openrmfscore", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfscore" }] });
d.createCollection("Scores");
d.Scores.createIndex({ artifactId: 1 });
d.Scores.createIndex({ systemGroupId: 1 });
d.Scores.createIndex({ hostName: 1 });
d.Scores.createIndex({ stigType: 1 });
d.Scores.createIndex({ created: -1 });
d.Scores.createIndex({ updatedOn: -1 });
d.Scores.createIndex({ totalCat1Open: 1 });
d.Scores.createIndex({ totalCat1NotApplicable: 1 });
d.Scores.createIndex({ totalCat1NotAFinding: 1 });
d.Scores.createIndex({ totalCat1NotReviewed: 1 });
d.Scores.createIndex({ totalCat2Open: 1 });
d.Scores.createIndex({ totalCat2NotApplicable: 1 });
d.Scores.createIndex({ totalCat2NotAFinding: 1 });
d.Scores.createIndex({ totalCat2NotReviewed: 1 });
d.Scores.createIndex({ totalCat3Open: 1 });
d.Scores.createIndex({ totalCat3NotApplicable: 1 });
d.Scores.createIndex({ totalCat3NotAFinding: 1 });
d.Scores.createIndex({ totalCat3NotReviewed: 1 });

// ---- openrmftemplate ----
d = db.getSiblingDB('openrmftemplate');
d.createUser({ user: "openrmftemplate", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmftemplate" }] });
d.createCollection("Templates");
d.Templates.createIndex({ stigType: 1 });
d.Templates.createIndex({ templateType: 1 });
d.Templates.createIndex({ stigRelease: 1 });
d.Templates.createIndex({ version: 1 });
d.Templates.createIndex({ created: -1 });
d.Templates.createIndex({ updatedOn: -1 });
d.Templates.createIndex({ stigId: 1 });
d.Templates.createIndex({ title: 1 });

// ---- openrmfaudit ----
d = db.getSiblingDB('openrmfaudit');
d.createUser({ user: "openrmfaudit", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfaudit" }] });
d.createCollection("Audits");
d.Audits.createIndex({ created: -1 });
d.Audits.createIndex({ username: 1 });
d.Audits.createIndex({ program: 1 });
d.Audits.createIndex({ action: 1 });

// ---- openrmfreport ----
d = db.getSiblingDB('openrmfreport');
d.createUser({ user: "openrmfreport", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfreport" }] });
d.createCollection("ACASScanReport");
d.ACASScanReport.createIndex({ reportName: 1 });
d.ACASScanReport.createIndex({ hostname: 1 });
d.ACASScanReport.createIndex({ pluginId: 1 });
d.ACASScanReport.createIndex({ pluginName: 1 });
d.ACASScanReport.createIndex({ pluginType: 1 });
d.ACASScanReport.createIndex({ severity: -1 });
d.ACASScanReport.createIndex({ riskFactor: 1 });
d.ACASScanReport.createIndex({ created: -1 });
d.ACASScanReport.createIndex({ updatedOn: -1 });
d.ACASScanReport.createIndex({ operatingSystem: 1 });
d.ACASScanReport.createIndex({ family: 1 });
d.ACASScanReport.createIndex({ systemGroupId: 1 });
d.createCollection("VulnerabilityReport");
d.VulnerabilityReport.createIndex({ vulnid: 1 });
d.VulnerabilityReport.createIndex({ hostname: 1 });
d.VulnerabilityReport.createIndex({ severityCategory: 1 });
d.VulnerabilityReport.createIndex({ status: 1 });
d.VulnerabilityReport.createIndex({ ruleTitle: 1 });
d.VulnerabilityReport.createIndex({ checklistType: 1 });
d.VulnerabilityReport.createIndex({ created: -1 });
d.VulnerabilityReport.createIndex({ updatedOn: -1 });
d.VulnerabilityReport.createIndex({ severityOverride: 1 });
d.VulnerabilityReport.createIndex({ systemGroupId: 1 });
d.VulnerabilityReport.createIndex({ artifactId: 1 });
d.VulnerabilityReport.createIndex({ severity: 1 });
// full-text search (Phase 1)
d.VulnerabilityReport.createIndex({ ruleTitle: "text", vulnid: "text", hostname: "text", discussion: "text", cciReferences: "text", securityControlNumbers: "text" }, { name: "ft_search" });

// ---- openrmfscanhistory (fork: GridFS scan storage + delta findings) ----
d = db.getSiblingDB('openrmfscanhistory');
d.createUser({ user: "openrmfscanhistory", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfscanhistory" }] });
d.createCollection("ScanFiles");
d.ScanFiles.createIndex({ systemGroupId: 1, scanType: 1, isLatest: 1 });
d.ScanFiles.createIndex({ created: -1 });
d.createCollection("Findings");
d.Findings.createIndex({ systemGroupId: 1, scanType: 1, status: 1 });
d.Findings.createIndex({ systemGroupId: 1, scanType: 1, hostname: 1, pluginId: 1 });

// ---- openrmfpoam (fork) ----
d = db.getSiblingDB('openrmfpoam');
d.createUser({ user: "openrmfpoam", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfpoam" }] });
d.createCollection("Poams");
d.Poams.createIndex({ systemGroupId: 1, sourceType: 1, sourceKey: 1 });
d.Poams.createIndex({ systemGroupId: 1, status: 1 });
d.Poams.createIndex({ artifactId: 1 });
d.Poams.createIndex({ created: -1 });

// ---- openrmftrivyscan (fork) ----
d = db.getSiblingDB('openrmftrivyscan');
d.createUser({ user: "openrmftrivyscan", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmftrivyscan" }] });
d.createCollection("TrivyConfig");
d.createCollection("TrivyRuns");
d.TrivyRuns.createIndex({ when: -1 });

// ---- openrmftasks (fork) ----
d = db.getSiblingDB('openrmftasks');
d.createUser({ user: "openrmftasks", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmftasks" }] });
d.createCollection("Tasks");
d.Tasks.createIndex({ systemGroupId: 1, status: 1 });
d.Tasks.createIndex({ assignedTo: 1, status: 1 });
d.Tasks.createIndex({ dueDate: 1 });

// ---- openrmfinventory (fork) ----
d = db.getSiblingDB('openrmfinventory');
d.createUser({ user: "openrmfinventory", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfinventory" }] });
d.createCollection("Assets");
d.Assets.createIndex({ systemGroupId: 1, hostname: 1 });
d.Assets.createIndex({ systemGroupId: 1, osName: 1 });
d.createCollection("OsMappings");
d.OsMappings.createIndex({ priority: 1 });

// ---- openrmfconmon (fork) ----
d = db.getSiblingDB('openrmfconmon');
d.createUser({ user: "openrmfconmon", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfconmon" }] });
d.createCollection("CadencePolicies");
d.CadencePolicies.createIndex({ systemGroupId: 1 }, { unique: true });

// ---- openrmfscanwatch (fork) ----
d = db.getSiblingDB('openrmfscanwatch');
d.createUser({ user: "openrmfscanwatch", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfscanwatch" }] });
d.createCollection("ProcessedFiles");
d.ProcessedFiles.createIndex({ path: 1, sha256: 1 });
d.ProcessedFiles.createIndex({ status: 1, lastAttempt: -1 });

// ---- openrmfjournal (fork: entries + GridFS evidence) ----
d = db.getSiblingDB('openrmfjournal');
d.createUser({ user: "openrmfjournal", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfjournal" }] });
d.createCollection("JournalEntries");
d.JournalEntries.createIndex({ systemGroupId: 1, created: -1 });
d.JournalEntries.createIndex({ entityType: 1, entityId: 1, created: -1 });
d.JournalEntries.createIndex({ created: -1 });

// ---- openrmfnotify (fork: subscriptions + SMTP config + send log) ----
d = db.getSiblingDB('openrmfnotify');
d.createUser({ user: "openrmfnotify", pwd: "openrmf1234!", roles: [{ role: "readWrite", db: "openrmfnotify" }] });
d.createCollection("NotifyConfig");
d.createCollection("Subscriptions");
d.Subscriptions.createIndex({ userid: 1 });
d.Subscriptions.createIndex({ enabled: 1 });
d.createCollection("NotificationLog");
d.NotificationLog.createIndex({ subscriptionId: 1, eventKey: 1 });
d.NotificationLog.createIndex({ subscriptionId: 1, status: 1 });
d.NotificationLog.createIndex({ when: -1 });
d.NotificationLog.createIndex({ userid: 1, when: -1 });
