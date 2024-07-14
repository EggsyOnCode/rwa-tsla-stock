if (secrets.alpacaKey == "" || secrets.alpacaSecret == "") {
  throw new Error("Alpaca API key and secret are required");
}
const alpacaRequest = Functions.makeHttpRequest({
  url: "https://paper-api.alpaca.markets/v2/account",
  headers: {
    accept: "application/json",
    "APCA-API-KEY-ID": secrets.alpacaKey,
    "APCA-API-SECRET-KEY": secrets.alpacaSecret,
  },
});

const [response] = await Promise.all([alpacaRequest]);

const portfolioBalance = response.data["portfolio_value"];
console.log(`Alpaca Portfolio Balance: $${portfolioBalance}`);

// returns a bytes_buffer of the integer ; which needs to be supplied to the consumer SC
return Functions.encodeUint256(Math.round(portfolioBalance * 1e18));
