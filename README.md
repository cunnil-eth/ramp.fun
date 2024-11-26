# ramp.fun
Pump.fun but not so fun on Ethereum

# Solidity
The solidty part consists of 3 essential contracts:
1. Rampfun - a main contract that users interact with to deploy their tokens. This contract serves as a hub for accumulating fees from trading memes on the platform and on Uniswap DEX;

2. RampToken is an implementation of OpenZeppelin's ERC20 standard that is deployed by a user and basically a meme token. Mint and burn can only be invoked by BondingCurve contract fixed to this token for buy and sell options respectively;
  
3. BondingCurve acts as a liquidity pool but with curvature price dynamic where users can buy and sell tokens before token migration event. The event occurs after 80% of 1b tokens were bought, after the migration the token can be swapped on DEX with linear price dynamic.
