// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

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
    error GemsRefund__NoZeroAddress();
    error GemsRefund__InvalidExpiryTime();
    error GemsRefund__RefundPolicyNotActiveYet();
    error GemsRefund__EthTransferFailed();
    error GemsRefund__InsufficientGemsBalance();
    error GemsRefund__GemsTransferFailed();
    error GemsRefund__InvalidAmount();
    error GemsRefund__RefundAmountTooSmall();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant GEMS_PRECISION = 10 ** 6;
    uint256 internal constant MINIMUM_GEMS_FOR_REFUND = 10 ** 4;
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8;
    uint256 internal constant REFUND_VALUE = 4 * 1e18;
    uint256 internal constant GEMS_SUPPLY = 21_000_000 * GEMS_PRECISION;
    uint256 internal constant REFUND_VALUE_BY_PRICE_FEED = REFUND_VALUE * PRICE_FEED_PRECISION;

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
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier noZeroAddress(address _address) {
        if (_address == address(0)) revert GemsRefund__NoZeroAddress();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @param _gems GEMS contract address
    /// @param _priceFeed ETH/USD PriceFeed contract address
    /// @param _expiryTime Unix timestamp when refund will be available
    constructor(address _gems, address _priceFeed, uint256 _expiryTime)
        payable
        Ownable(msg.sender)
        noZeroAddress(_gems)
        noZeroAddress(_priceFeed)
    {
        if (_expiryTime < block.timestamp) revert GemsRefund__InvalidExpiryTime();
        i_gems = IERC20(_gems);
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        i_expiryTime = _expiryTime;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice msg.sender must approve address(this) on GEMS contract first
    function refund(uint256 _gemsAmount) external {
        //slither-disable-next-line timestamp
        if (block.timestamp < i_expiryTime) revert GemsRefund__RefundPolicyNotActiveYet();
        if (_gemsAmount < MINIMUM_GEMS_FOR_REFUND) revert GemsRefund__RefundAmountTooSmall();
        if (_gemsAmount > GEMS_SUPPLY) revert GemsRefund__InvalidAmount();

        uint256 ethUsdPrice = getLatestPrice();
        //slither-disable-next-line divide-before-multiply
        uint256 ethAmountPerGem = REFUND_VALUE_BY_PRICE_FEED / ethUsdPrice;
        uint256 totalEthRefund = (ethAmountPerGem * _gemsAmount) / GEMS_PRECISION;

        emit GemsRefunded(_gemsAmount, ethAmountPerGem, totalEthRefund);

        if (!i_gems.transferFrom(msg.sender, address(this), _gemsAmount)) revert GemsRefund__GemsTransferFailed();
        (bool success,) = payable(msg.sender).call{value: totalEthRefund}("");
        if (!success) revert GemsRefund__EthTransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function withdrawEth(uint256 _amount) external onlyOwner {
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
        //slither-disable-next-line unused-return
        (, int256 price,,,) = i_priceFeed.latestRoundData();
        return uint256(price);
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
