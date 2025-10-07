// App Check global zorunluluğu
const { setGlobalOptions } = require('firebase-functions/v2');
setGlobalOptions({ enforceAppCheck: true });

// Import and re-export all the functions from the new modules
const admin = require("./src/admin");
const ai = require("./src/ai");
const leaderboard = require("./src/leaderboard");
const notifications = require("./src/notifications");
const posts = require("./src/posts");
const profile = require("./src/profile");
const quests = require("./src/quests");
const reports = require("./src/reports");
const tests = require("./src/tests");
const users = require("./src/users");
const premium = require("./src/premium");

exports.admin = admin;
exports.ai = ai;
exports.users = users;
exports.premium = premium;
exports.leaderboard = leaderboard;
exports.notifications = notifications;
exports.posts = posts;
exports.profile = profile;
exports.quests = quests;
exports.reports = reports;
exports.tests = tests;
