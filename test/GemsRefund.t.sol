// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {GemsRefund} from "../src/GemsRefund.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract GemsRefundTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public constant GEMS_SUPPLY = 20_000_000 * 1e6;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ETH_PRICE = 3000 * 1e8;
    uint256 public constant EXPIRY_TIME = 3 * (365 days);
    uint256 public constant CONTRACT_ETH_BALANCE = 40_000 ether;
    uint256 internal constant WAD_PRECISION = 10 ** 18;
    uint256 internal constant REFUND_VALUE = 4 * 1e18;
    uint256 internal constant GEMS_PRECISION = 10 ** 6;

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
        _amount = bound(_amount, 1, GEMS_SUPPLY);
        vm.warp(EXPIRY_TIME + 1);
        vm.expectRevert(GemsRefund.GemsRefund__InsufficientEthBalance.selector);
        gemsRefund.refund(_amount);
    }

    function test_refund_works(uint256 _amount) public {
        _amount = bound(_amount, 1, GEMS_SUPPLY);
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
            (((((REFUND_VALUE * WAD_PRECISION)) / gemsRefund.getLatestPrice()) * _amount) / GEMS_PRECISION);
        uint256 actualEthBalance = holder.balance;
        assertEq(actualEthBalance, expectedEthBalance);
        assertEq(gemsBalanceAfter, gemsBalanceBefore - _amount);
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
}
