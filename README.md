# GEMS Refund

A contract inspired by the refund policy of the [GEMS RWA project](https://everlaunch.org/gems/).

## Overview

The deployer must provide the GEMS contract address, ETH/USD pricefeed contract address, and the time at which refunds are available in the constructor.

The `GemsRefund` contract needs to be funded with the appropriate amount of ETH to facilitate refunds.

Once the expiry time has been reached, GEMS holders can call the `refund()` function to receive $4/ETH per GEMS token. Holders must first have approved the `GemsRefund` contract to spend their tokens on the GEMS contract.

A minimum of 0.01 GEMS token (`uint256 10000`) is required to call the `refund()` function.

The contract owner is able to withdraw GEMS and ETH from the contract.

## Testing and Verification

To run the Foundry tests, input:

```
forge test
```

To run the Certora formal verification spec, first export your Certora prover key and then run the following command:

```
export CERTORAKEY=your_key_here
certoraRun ./certora/conf/GemsRefund.conf
```

## GEMS Token contracts:

```
address internal constant GEMS_ETHEREUM = 0x9313231236D2F3e6cadD38345DF7958536777D02;
address internal constant GEMS_POLYGON = 0x25eFae7B0b2866CaFB14E8eaD333a42eeb2A0b80;
```
