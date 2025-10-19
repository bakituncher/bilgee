// functions/eslint.config.js
"use strict";

const { FlatCompat } = require("@eslint/eslintrc");
const js = require("@eslint/js");
const globals = require("globals");

const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended,
});

module.exports = [
  js.configs.recommended,
  ...compat.extends("google"),
  {
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "commonjs",
      globals: {
        ...globals.node,
        ...globals.mocha,
      },
    },
    rules: {
      "max-len": ["error", { "code": 120 }],
      "indent": ["error", 2],
      "quotes": ["error", "double"],
      "object-curly-spacing": ["error", "always"],
      "valid-jsdoc": "off", // JSDoc'u zorunlu kılma
      "require-jsdoc": "off", // JSDoc'u zorunlu kılma
      "camelcase": "off", // app_user_id gibi alanlar için
    },
  },
  {
    ignores: [
      ".git/",
      ".idea/",
      "node_modules/",
      "build/",
      "dist/",
    ],
  },
];
