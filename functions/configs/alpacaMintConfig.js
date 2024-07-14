const fs = require("fs");
const {
  Location,
  ReturnType,
  CodeLanguage,
} = require("@chainlink/functions-toolkit");

const reqConfig = {
  source: fs.readFileSync("./functions/sources/alpacaBalance.js").toString(),
  codeLocation: Location.Inline,
  secrets: {
    alpacaKey: process.env.ALPACA_KEY,
    alpacaSecret: process.env.ALPACA_SECRET,
  },
  secretsLocation: Location.DONHosted,
  args: [],
  codeLanguage: CodeLanguage.JavaScript,
  expectedReturnType: ReturnType.uint256,
};

module.exports = reqConfig;
