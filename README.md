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
Download Foundry: https://getfoundry.sh/introduction/installation/

### Running Reentrancy Tests

Use Solidity **0.7.6** (legacy profile) and **0.8.20**:

```bash
# Solidity 0.7.6
FOUNDRY_PROFILE=legacy forge test --match-contract ReentrancyTestv7 -vvv

# Solidity 0.8.20
forge test --match-contract ReentrancyTestv8 -vvv
```

### Running AccessControl Test
```bash
# Solidity 0.8.20
forge test --match-contract AccessControlTestv8 -vvv
```

## License
MIT
