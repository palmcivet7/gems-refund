// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract MockAggregator is MockV3Aggregator {
    uint8 internal constant DECIMALS = 8;
    int256 internal constant INITIAL_ANSWER = 3000 * 1e8;

    constructor() MockV3Aggregator(DECIMALS, INITIAL_ANSWER) {}
}
