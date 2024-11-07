## Proveably Random Raffle Contracts

## About

This code is to create a proveably random smart contract lottery

## What we want it to do?

1. Users can enter by paying for a ticket 
    1. The ticket fees are going to go to the winner during the draw 
2. After X period of time, the lottery will automatically draw a winner
    1. And this will be done programatically 
3. Using Chainlink VRF & Chainlink Automation
    1. Chainlink VRF -> Randomness
    2. Chainlink Automation - Time based trigger

## About Test
1. deploy contract
    1. use cheatcode to deploy
2. forked testnet
    1. on local chain
    2. on sepolia chain
3. test function

## Attention!
1. if you use the local chain to deploy your raffle.sol, please inspect the function in mock contract, called createSubcription. The blockhash at the beginning, is 0. If you meet the problem " Error: script failed: panic: arithmetic underflow or overflow (0x11)" that means you should add the blockhash because "0 - 1" will exceed the limitation of the value.