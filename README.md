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
5. **MEV (Miner Extractable Value) attacks** - Sandwich attack
6. **Denial of Service** - Revert-based DoS and Unbounded Loop DoS

## Prerequisites

- **Foundry**: Download from https://getfoundry.sh/
- **Solidity**: 0.8.20 (automatically installed by Foundry on first build)
- **Infura API Key**: Required for mainnet fork tests (set in `.env` file)
  
## Quick Start
### Environment Setup
Create your INFURA RPC api key here:
https://developer.metamask.io

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Create a .env file in the project root
echo 'INFURA_URL=https://mainnet.infura.io/v3/YOUR_API_KEY' > .env
```

Foundry automatically loads `.env` files when running tests.

### Running Tests

**Reentrancy Attack:**
```bash
forge test --match-contract Reentrancy -vvv
```

**Access Control Failures:**
```bash
forge test --match-contract AccessControl -vvv
```

**Weak Randomness:**
```bash
forge test --match-contract WeakRandomness -vvv
```

**Oracle Manipulation (requires mainnet fork):**
```bash
forge test --fork-url $INFURA_URL --match-contract OracleManipulation -vvv
```

**MEV/Front-Running (requires mainnet fork):**
```bash
forge test --fork-url $INFURA_URL --match-contract FrontRunning -vvv
```

**Denial of Service (requires mainnet fork):**
```bash
forge test --fork-url $INFURA_URL --match-contract DenialOfService -vvv
```

### Run All Tests
```bash
forge test -vvv
```

## License
MIT
