module.exports = {
  "root": true,
  "env": {
    "es6": true,
    "node": true,
  },
  "extends": [
    "eslint:recommended",
    "google",
  ],
  "rules": {
    "quotes": ["error", "double"],
    "linebreak-style": "off",
    "max-len": ["error", {"code": 120}],
    "indent": ["error", 2],
    "comma-dangle": ["error", "always-multiline"],
  },
  "parserOptions": {
    "ecmaVersion": 2020,
  },
};
