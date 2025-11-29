# Smart Contract Security Analysis - MSc Project

**Author:** Add names  
**Institution:** UPC Barcelona  
**Program:** MSc in Cybersecurity  
**Date:** 11/2025

## Overview

Comprehensive analysis of smart contract vulnerabilities in Solidity 0.8.x, including:
- Reentrancy attacks
- Access control vulnerabilities
- Oracle manipulation
- Delegatecall exploits
- MEV (Miner Extractable Value) attacks

All exploits demonstrated with proof-of-concept implementations using Foundry and mainnet forking.

## Quick Start
To run the Reentrancy tests using Solidity 0.7.6 and 0.8.20:
FOUNDRY_PROFILE=legacy forge test --match-contract ReentrancyTestv7 -vvv
forge test --match-contract ReentrancyTestv8 -vvv

To run the AccessControl tests using Solidity 0.8.20
forge test --match-contract AccessControlTestv8 -vvv

## License
MIT
