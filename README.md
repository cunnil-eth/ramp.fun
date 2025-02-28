# ramp.fun
Pump.fun, but on Base

## Solidity
The Solidty component consists of three essential contracts:
1. **Rampfun** - The main contract that users interact with to deploy their tokens. This contract acts as a hub for accumulating fees from trading memes on the platform and on the [Aerodrome DEX](https://aerodrome.finance/).

2. **RampToken** - An implementation of [OpenZeppelin's ERC20 standard](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/token/ERC20) deployed by a user. It is essentialy a meme token contract. The mint and burn functions can only be invoked by the BondingCurve contract attached to this token, which handles the buy and sell options, respectively.
  
3. **BondingCurve** - Functions as a liquidity pool but with dynamic price curve. Users can buy and sell tokens before the token migration event. This event occurs after 80% of 1b tokens have been purchased. After the migration the token can be swapped on the DEX.
***

### Test coverage
![Test coverage](https://github.com/user-attachments/assets/5f4a90ca-39e3-4b3f-a7a6-948b1f968f5e)


