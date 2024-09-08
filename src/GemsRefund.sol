// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// import {console} from "forge-std/console.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @notice This contract needs to be funded with the appropriate amount of ETH to facilitate refunds
contract GemsRefund is Ownable {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error GemsRefund__NoZeroValue();
    error GemsRefund__RefundPolicyNotActiveYet();
    error GemsRefund__InsufficientEthBalance();
    error GemsRefund__EthTransferFailed();
    error GemsRefund__InsufficientGemsBalance();
    error GemsRefund__GemsTransferFailed();
    error GemsRefund__InvalidAmount();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant GEMS_PRECISION = 10 ** 6;
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8;
    uint256 internal constant WAD_PRECISION = 10 ** 18;
    uint256 internal constant SCALING_FACTOR = WAD_PRECISION / PRICE_FEED_PRECISION;
    uint256 internal constant REFUND_VALUE = 4 * 1e18;
    uint256 internal constant GEMS_SUPPLY = 20_000_000 * 1e6;

    IERC20 internal immutable i_gems;
    AggregatorV3Interface internal immutable i_priceFeed;
    uint256 internal immutable i_expiryTime;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @param gemsAmount The amount of GEMS being refunded
    /// @param ethAmountPerGem The amount of ETH a GEMS token is worth
    /// @param totalEthRefund The amount of ETH received as a refund
    event GemsRefunded(uint256 indexed gemsAmount, uint256 indexed ethAmountPerGem, uint256 indexed totalEthRefund);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _gems, address _priceFeed, uint256 _expiryTime) payable Ownable(msg.sender) {
        i_gems = IERC20(_gems);
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_expiryTime = _expiryTime;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice msg.sender must approve address(this) on gems contract first
    function refund(uint256 _gemsAmount) external {
        if (block.timestamp < i_expiryTime) revert GemsRefund__RefundPolicyNotActiveYet();
        if (_gemsAmount > GEMS_SUPPLY) revert GemsRefund__InvalidAmount();

        uint256 ethUsdPrice = getLatestPrice();
        uint256 ethAmountPerGem = (REFUND_VALUE * WAD_PRECISION) / ethUsdPrice;
        uint256 totalEthRefund = ((ethAmountPerGem * _gemsAmount) / GEMS_PRECISION);
        if (totalEthRefund > address(this).balance) revert GemsRefund__InsufficientEthBalance();

        emit GemsRefunded(_gemsAmount, ethAmountPerGem, totalEthRefund);

        if (!i_gems.transferFrom(msg.sender, address(this), _gemsAmount)) revert GemsRefund__GemsTransferFailed();
        (bool success,) = payable(msg.sender).call{value: totalEthRefund}("");
        if (!success) revert GemsRefund__EthTransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function withdrawEth(uint256 _amount) external onlyOwner {
        if (_amount > address(this).balance) revert GemsRefund__InsufficientEthBalance();
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) revert GemsRefund__EthTransferFailed();
    }

    function withdrawGems(uint256 _amount) external onlyOwner {
        if (_amount > i_gems.balanceOf(address(this))) revert GemsRefund__InsufficientGemsBalance();
        if (!i_gems.transfer(msg.sender, _amount)) revert GemsRefund__GemsTransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price) * SCALING_FACTOR;
    }

    function getGems() external view returns (address) {
        return address(i_gems);
    }

    function getPriceFeed() external view returns (address) {
        return address(i_priceFeed);
    }

    function getExpiryTime() external view returns (uint256) {
        return i_expiryTime;
    }

    receive() external payable {}
}
