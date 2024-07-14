const reqConfig = require("../configs/alpacaMintConfig");
const {
  simulateScript,
  decodeResult,
} = require("@chainlink/functions-toolkit");

async function main() {
  const { responseHexString, errorString, capturedTerminalOutput } =
    await simulateScript(reqConfig);
  console.log(`${capturedTerminalOutput}\n`);
  if (responseHexString) {
    const result = decodeResult(
      reqConfig.expectedReturnType,
      responseHexString
    );
    console.log(`Result: ${result}`);
  }

  if (errorString) {
    console.error(`Error: ${errorString}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
