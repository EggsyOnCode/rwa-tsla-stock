// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract dTSLA is ConfirmedOwner, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    // Errors
    error dTSLA__NotEnoughCollateral();

    // Events

    enum MintOrRedeem {
        mint,
        redeem
    }

    struct dTSLARequest {
        address requester;
        MintOrRedeem mintOrRedeem;
        // amount of tokens to be minted
        uint256 tokens;
    }

    string i_mintSourceCode;
    address private immutable i_priceFeed;

    uint256 private s_portfolioBalance;
    uint64 private immutable i_subId;
    bytes32 private immutable i_donId;
    mapping(bytes32 requestId => dTSLARequest request) private s_reqIdtoReq;

    //CONSTANTS
    // address public SEPOLIA_FUNCTIONS_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    // bytes32 constant DON_ID = hex"66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
    // address public LINK_USDT_PRICE_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    uint32 constant GAS_LIMIT = 300_000;
    uint256 constant PRECISION = 1e18;
    uint256 constant COLLATERAL_RATIO = 200;
    // our protocol is 200% overcollateralized; that means that only if we have 200 USD in collateral (TSLA stocks) can we  mint 100 USD worth of dTSLA
    uint256 constant COLLATERAL_PRECISION = 100;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;

    constructor(address _router, string memory _mintSourceCode, uint64 _subId, bytes32 _donId, address _priceFeed)
        ConfirmedOwner(msg.sender)
        FunctionsClient(_router)
    {
        i_mintSourceCode = _mintSourceCode;
        i_subId = _subId;
        i_donId = _donId;
        i_priceFeed = _priceFeed;
    }

    /// @notice send HTTP req to chianlink along with func that we wish to call to
    /// 1. calcualte how much TSLA stock we have in USD evaluation in our brokerage
    /// 2. calculate how much dTSLA tokens we can mint
    /// 3. mint the tokens
    /// @param _amt amount of dTSLA tokens the user wishes to mint
    function sendMintRequest(uint256 _amt, string calldata _req) public onlyOwner returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(_req);
        bytes32 reqID = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, i_donId);
        s_reqIdtoReq[reqID] = dTSLARequest(msg.sender, MintOrRedeem.mint, _amt);
        return reqID;
    }

    /// @notice will recieve the response from chainlink (the USD evaluation of TSLA stock) and mint the tokens;
    /// ensuring that the protocol stays overcollateralized
    function _mintFullfillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 toBeMinted = s_reqIdtoReq[requestId].tokens;

        s_portfolioBalance = uint256(bytes32(response));
        if (_getCollateralAdjustedTotalBalance(toBeMinted) > s_portfolioBalance) {
            revert dTSLA__NotEnoughCollateral();
        }
        if (toBeMinted != 0) {
            _mint(s_reqIdtoReq[requestId].requester, toBeMinted);
        }
    }

    /// @notice User sends the request to redeem their dTSLA tokens for USDC (redemption Token)
    /// this will have chianlink function call to brokerage to
    /// 1. sell current TSLA stocks in account
    /// 2. buy equivalent USDC in brokerage
    /// 3. send USDC to contract
    function sendRedeemRequest() public {}

    function _redeemFullFillRequest() internal {}

    /// @dev Internal because Chainlink's gonan call handleOracleFullfillment externally and handleOracle will call fullReq intenrally
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (s_reqIdtoReq[requestId].mintOrRedeem == MintOrRedeem.mint) {
            _mintFullfillRequest(requestId, response);
        } else {
            _redeemFullFillRequest(requestId, response);
        }
    }

    function _getCollateralAdjustedTotalBalance(uint256 _tokens) internal view returns (uint256) {
        uint256 totalCollateralUSD = _getTotalCollateralValue(_tokens);
        return (totalCollateralUSD * COLLATERAL_RATIO) / PRECISION;
    }

    /// @dev returns the total value of collateral in USD
    function _getTotalCollateralValue(uint256 _addedTokens) internal view returns (uint256) {
        return ((totalSupply() + _addedTokens) * getTSLAPrice()) / PRECISION;
    }

    /// @dev returns the price of TSLA stock in USD
    function getTSLAPrice() internal view returns (uint256) {
        AggregatorV3Interface memory priceFeed = AggregatorV3Interface(i_priceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION; // so that we have 18 decimals in the price
    }
}
