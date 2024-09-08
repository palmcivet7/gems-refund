# GEMS Refund

A contract inspired by the refund policy of the [GEMS RWA project](https://everlaunch.org/gems/).

## Overview

The deployer must provide the GEMS contract address, ETH/USD pricefeed contract address, and the time refunds are available in the constructor.

The `GemsRefund` contract needs to be funded with the appropriate amount of ETH to facilitate refunds.

Once the expiry time has been reached, GEMS holders can call the `refund()` function to receive $4/ETH per token. Holders must first have approved the `GemsRefund` contract to spend their tokens on the GEMS contract.

```
address internal constant GEMS_ETHEREUM = 0x9313231236D2F3e6cadD38345DF7958536777D02;
address internal constant GEMS_POLYGON = 0x25eFae7B0b2866CaFB14E8eaD333a42eeb2A0b80;
```
