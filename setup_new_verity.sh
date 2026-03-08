#!/bin/bash
source .env
export VERITY_ADDRESS=0x0d6beF1F6B53E215e1c9e3F56e596b0945A81362
export GRANTEE=0x71b0C7a96EdAA59caeB614A329d256Ce9F12cC51
forge script script/GrantCRERole.s.sol --rpc-url https://sepolia.base.org --broadcast
forge script script/ProposeMarket.s.sol --rpc-url https://sepolia.base.org --broadcast
