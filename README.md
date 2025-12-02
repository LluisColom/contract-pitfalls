# Smart Contract Security Analysis - MSc Project

**Author:** Add names  
**Institution:** UPC Barcelona  
**Program:** MSc in Cybersecurity  
**Date:** 11/2025

## Overview
Educational demonstrations of common Solidity vulnerabilities using Foundry.

## Vulnerabilities Covered

1. **Reentrancy** - The DAO-style attack with CEI pattern fix
2. **Access Control** - Missing authorization checks
3. **Weak Randomness** - Predictable on-chain entropy
4. **Oracle Manipulation** - Flash loan + spot price exploitation
5. **MEV (Miner Extractable Value) attacks** - 

## Quick Start
Download Foundry: https://getfoundry.sh/introduction/installation/

### Running Reentrancy Tests

Use Solidity **0.7.6** (legacy profile) and **0.8.20**:

```bash
# Solidity 0.7.6
FOUNDRY_PROFILE=legacy forge test --match-contract ReentrancyV7 -vvv

# Solidity 0.8.20
forge test --match-contract ReentrancyV8 -vvv
```

### Running AccessControl Test
```bash
# Solidity 0.8.20
forge test --match-contract AccessControl -vvv
```

### Running WeakRandomness Test
```bash
# Solidity 0.8.20
forge test --match-contract WeakRandomness -vvv
```

### Running OracleManipulation Test
```bash
# Solidity 0.8.20
forge test --fork-url $INFURA_URL --match-contract OracleManipulation -vvv
```

### Running MEV Test
```bash
# Solidity 0.8.20
forge test --fork-url $INFURA_URL --match-contract FrontRunning -vvv
```

### Running DenialOfService Test
```bash
# Solidity 0.8.20
forge test --fork-url $INFURA_URL --match-contract DenialOfService -vvv
```

## License
MIT
