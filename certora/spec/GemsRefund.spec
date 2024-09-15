// Verification of GemsRefund

using MockGems as gems;

/*//////////////////////////////////////////////////////////////
                            METHODS
//////////////////////////////////////////////////////////////*/
methods {
    function refund(uint256 amount) external;
    function getExpiryTime() external returns (uint256) envfree;
    function getLatestPrice() external returns (uint256) envfree;

    function MockGems.balanceOf(address) external returns (uint256) envfree;
}

/*//////////////////////////////////////////////////////////////
                          DEFINITIONS
//////////////////////////////////////////////////////////////*/
definition PRICE_FEED_PRECISION() returns uint = 100000000;
definition REFUND_VALUE() returns uint = 4000000000000000000;
definition GEMS_PRECISION() returns uint = 1000000;
definition MINIMUM_GEMS_REFUND() returns uint = 10000;
definition MAXIMUM_GEMS_REFUND() returns uint = 21000000000000;

/*//////////////////////////////////////////////////////////////
                             RULES
//////////////////////////////////////////////////////////////*/
/// @notice refund reverts if caller is not holding the `amount` of GEMS
rule refundRevertsIfGemsBalanceInsufficient(uint amount) {
    env e;
    require e.msg.sender != currentContract;
    require e.block.timestamp >= getExpiryTime();
    require amount > MINIMUM_GEMS_REFUND();
    require gems.balanceOf(e.msg.sender) < amount;

    refund@withrevert(e, amount);
    assert lastReverted;
}

/// @notice refund reverts if it is not time yet
rule refundRevertsIfNotTime(uint amount) {
    env e;
    require e.block.timestamp < getExpiryTime();

    refund@withrevert(e, amount);
    assert lastReverted;
}

/// @notice refund reverts if invalid `amount` of GEMS
rule refundRevertsIfInvalidAmount(uint amount) {
    env e;
    require e.block.timestamp >= getExpiryTime();
    require amount < MINIMUM_GEMS_REFUND() || amount > MAXIMUM_GEMS_REFUND();

    refund@withrevert(e, amount);
    assert lastReverted;
}

/// @notice asserts the correct balance changes of GEMS and ETH for a successful refund
rule refundIntegrity(uint amount) {
    env e;
    require e.msg.sender != currentContract;
    require e.block.timestamp >= getExpiryTime();
    require amount > MINIMUM_GEMS_REFUND();
    require gems.balanceOf(e.msg.sender) >= amount;

    mathint gemsBalanceBefore = gems.balanceOf(e.msg.sender);
    mathint ethBalanceBefore = nativeBalances[e.msg.sender];

    refund(e, amount);

    mathint gemsBalanceAfter = gems.balanceOf(e.msg.sender);
    mathint ethBalanceAfter = nativeBalances[e.msg.sender];

    mathint expectedEthRefunded = (((REFUND_VALUE() * PRICE_FEED_PRECISION()) / getLatestPrice()) * amount) / GEMS_PRECISION();
    mathint actualEthRefunded = ethBalanceAfter - ethBalanceBefore;

    assert expectedEthRefunded == actualEthRefunded;
    assert gemsBalanceAfter == gemsBalanceBefore - amount;
}