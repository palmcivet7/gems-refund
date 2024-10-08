// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {GemsRefund, Ownable} from "../src/GemsRefund.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract GemsRefundTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public constant GEMS_SUPPLY = 21_000_000 * 1e6;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ETH_PRICE = 3000 * 1e8;
    uint256 public constant EXPIRY_TIME = 3 * (365 days);
    uint256 public constant CONTRACT_ETH_BALANCE = 40_000 ether;
    uint256 internal constant WAD_PRECISION = 10 ** 18;
    uint256 internal constant REFUND_VALUE = 4 * 1e18;
    uint256 internal constant GEMS_PRECISION = 10 ** 6;
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8;
    uint256 internal constant MINIMUM_GEMS_FOR_REFUND = 10 ** 4;

    GemsRefund public gemsRefund;
    MockV3Aggregator public priceFeed;
    ERC20Mock public gems;

    address owner = makeAddr("owner");
    address holder = makeAddr("holder");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        priceFeed = new MockV3Aggregator(DECIMALS, INITIAL_ETH_PRICE);
        gems = new ERC20Mock();

        vm.prank(owner);
        gemsRefund = new GemsRefund(address(gems), address(priceFeed), EXPIRY_TIME);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    function test_constructor() public view {
        assertEq(gemsRefund.getGems(), address(gems));
        assertEq(gemsRefund.getPriceFeed(), address(priceFeed));
        assertEq(gemsRefund.getExpiryTime(), EXPIRY_TIME);
    }

    function test_constructor_reverts() public {
        vm.expectRevert(GemsRefund.GemsRefund__NoZeroAddress.selector);
        new GemsRefund(address(0), address(priceFeed), EXPIRY_TIME);

        vm.expectRevert(GemsRefund.GemsRefund__NoZeroAddress.selector);
        new GemsRefund(address(gems), address(0), EXPIRY_TIME);

        vm.expectRevert(GemsRefund.GemsRefund__InvalidExpiryTime.selector);
        new GemsRefund(address(gems), address(priceFeed), block.timestamp - 1);
    }

    /*//////////////////////////////////////////////////////////////
                                 REFUND
    //////////////////////////////////////////////////////////////*/
    function test_refund_reverts_if_not_time(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.expectRevert(GemsRefund.GemsRefund__RefundPolicyNotActiveYet.selector);
        gemsRefund.refund(_amount);
    }

    function test_refund_reverts_if_zero_value() public {
        vm.warp(EXPIRY_TIME + 1);
        vm.expectRevert();
        gemsRefund.refund(0);
    }

    function test_refund_reverts_if_no_eth(uint256 _amount) public {
        _amount = bound(_amount, MINIMUM_GEMS_FOR_REFUND, GEMS_SUPPLY);
        gems.mint(holder, _amount);
        vm.prank(holder);
        gems.approve(address(gemsRefund), _amount);
        vm.warp(EXPIRY_TIME + 1);
        vm.prank(holder);
        vm.expectRevert(GemsRefund.GemsRefund__EthTransferFailed.selector);
        gemsRefund.refund(_amount);
    }

    function test_refund_works(uint256 _amount) public {
        _amount = bound(_amount, MINIMUM_GEMS_FOR_REFUND, GEMS_SUPPLY);
        gems.mint(holder, _amount);

        vm.deal(address(gemsRefund), CONTRACT_ETH_BALANCE);
        assertEq(address(gemsRefund).balance, CONTRACT_ETH_BALANCE);

        vm.warp(EXPIRY_TIME + 1);

        uint256 gemsBalanceBefore = gems.balanceOf(holder);

        vm.prank(holder);
        gems.approve(address(gemsRefund), _amount);
        vm.prank(holder);
        gemsRefund.refund(_amount);
        uint256 gemsBalanceAfter = gems.balanceOf(holder);

        uint256 expectedEthBalance =
            (((((REFUND_VALUE * PRICE_FEED_PRECISION)) / gemsRefund.getLatestPrice()) * _amount) / GEMS_PRECISION);
        uint256 actualEthBalance = holder.balance;
        assertEq(actualEthBalance, expectedEthBalance);
        assertEq(gemsBalanceAfter, gemsBalanceBefore - _amount);
    }

    function test_refund_reverts_if_gemsAmount_less_than_minimum(uint256 _amount) public {
        vm.assume(_amount < MINIMUM_GEMS_FOR_REFUND);
        vm.warp(EXPIRY_TIME + 1);
        vm.expectRevert(GemsRefund.GemsRefund__RefundAmountTooSmall.selector);
        gemsRefund.refund(_amount);
    }

    function test_refund_reverts_if_gemsAmount_more_than_maximum(uint256 _amount) public {
        vm.assume(_amount > GEMS_SUPPLY);
        vm.warp(EXPIRY_TIME + 1);
        vm.expectRevert(GemsRefund.GemsRefund__InvalidAmount.selector);
        gemsRefund.refund(_amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    function test_withdrawEth_works() public {
        vm.deal(address(gemsRefund), CONTRACT_ETH_BALANCE);
        vm.prank(gemsRefund.owner());
        gemsRefund.withdrawEth(CONTRACT_ETH_BALANCE);
        assertEq(address(gemsRefund).balance, 0);
        assertEq(owner.balance, CONTRACT_ETH_BALANCE);
    }

    function test_withdrawEth_reverts_if_not_owner(address _caller) public {
        vm.assume(_caller != gemsRefund.owner());
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _caller));
        vm.prank(_caller);
        gemsRefund.withdrawEth(CONTRACT_ETH_BALANCE);
    }

    function test_withdrawEth_reverts_if_insufficient_balance() public {
        vm.prank(gemsRefund.owner());
        vm.expectRevert(GemsRefund.GemsRefund__EthTransferFailed.selector);
        gemsRefund.withdrawEth(1);
    }

    function test_withdrawGems_reverts_if_not_owner(address _caller) public {
        vm.assume(_caller != gemsRefund.owner());
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", _caller));
        vm.prank(_caller);
        gemsRefund.withdrawGems(CONTRACT_ETH_BALANCE);
    }
}
