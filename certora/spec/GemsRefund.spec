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
                             RULES
//////////////////////////////////////////////////////////////*/
/// @notice refund reverts if caller is not holding the `amount` of GEMS
rule refundRevertsIfGemsBalanceInsufficient(uint amount) {
    env e;
    require e.msg.sender != currentContract;
    require e.block.timestamp >= getExpiryTime();
    require amount > 0;
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

rule refundIntegrity(uint amount) {
    env e;
    require e.block.timestamp >= getExpiryTime();
    require amount > 0;
    require gems.balanceOf(e.msg.sender) >= amount;

    mathint gemsBalanceBefore = gems.balanceOf(e.msg.sender);

    refund(e, amount);

    mathint gemsBalanceAfter = gems.balanceOf(e.msg.sender);

    // mathint expectedEthBalance = ;
    mathint actualEthBalance = nativeBalances[e.msg.sender];

    assert gemsBalanceAfter == gemsBalanceBefore - amount;
}