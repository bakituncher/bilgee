const { logger } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");

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

exports.admin = admin;
exports.ai = ai;
exports.leaderboard = leaderboard;
exports.notifications = notifications;
exports.posts = posts;
exports.profile = profile;
exports.quests = quests;
exports.reports = reports;
exports.tests = tests;

// Basit test fonksiyonu
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", { structuredData: true });
  response.send("Hello from BilgeAI!");
});
