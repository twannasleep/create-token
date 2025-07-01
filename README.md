# Solana Token Management Tools

A collection of professional-grade bash scripts for creating and managing Solana tokens.

## Overview

This repository contains two powerful command-line tools for Solana token operations:

- **`create-custom-token.sh`**: Create custom SPL tokens with extensive configuration options
- **`burn-token.sh`**: Burn tokens and manage token authorities

Both scripts support Standard SPL Token and Token 2022 programs, providing comprehensive management capabilities for token creators and administrators.

## Prerequisites

- Bash shell environment (Linux, macOS, WSL)
- [Solana CLI tools](https://docs.solana.com/cli/install-solana-cli-tools)
- [SPL Token CLI](https://spl.solana.com/token)

## Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/solana-token-tools.git
   cd solana-token-tools
   ```

2. Make the scripts executable:
   ```bash
   chmod +x create-custom-token.sh burn-token.sh
   ```

## Create Custom Token

### Basic Usage

```bash
./create-custom-token.sh --name "My Token" --symbol TKN --decimals 9 --amount 1000000000
```

### Key Features

- Full support for both Standard SPL Token and Token 2022 programs
- Interactive or command-line modes
- Advanced token features for Token 2022:
  - Non-transferable tokens
  - Interest-bearing tokens
  - Permanent delegate
  - Confidential transfers
- Authority management:
  - Freeze authority
  - Disable/transfer mint authority
  - Multisig authority support
- JSON metadata customization
- Cross-network support (devnet, testnet, mainnet-beta)

### Options

| Category | Option | Description |
|----------|--------|-------------|
| **Basic** | `-n, --name NAME` | Set token name |
| | `-s, --symbol SYMBOL` | Set token symbol |
| | `-d, --description DESC` | Set token description |
| | `-c, --decimals NUM` | Set token decimals (0-9) |
| | `-a, --amount NUM` | Token amount to mint |
| | `-r, --recipient ADDRESS` | Recipient wallet to receive tokens |
| | `-w, --network NETWORK` | Network to use (devnet, testnet, mainnet-beta) |
| **Metadata** | `-i, --image URL` | Token image URL |
| | `-m, --metadata URL` | Token metadata URL |
| | `-j, --json JSON_STRING` | Set token metadata using JSON |
| | `-f, --json-file FILE` | Set token metadata from JSON file |
| **Token Program** | `--token-2022` | Use Token 2022 program (default) |
| | `--standard-token` | Use Standard SPL Token program |
| **Advanced** | `--enable-freeze-authority` | Enable freeze authority |
| | `--disable-mint-authority` | Disable mint authority after initial minting |
| | `--transfer-mint-authority ADDR` | Transfer mint authority |
| | `--enable-permanent-delegate ADDR` | Enable permanent delegate (Token 2022) |
| | `--enable-interest-bearing RATE` | Make token interest-bearing (Token 2022) |
| | `--enable-non-transferable` | Make token non-transferable (Token 2022) |
| | `--multisig-authority ADDRS` | Create multisig authority |

## Burn Token

### Basic Usage

```bash
./burn-token.sh -f keypair.json -t TOKEN_ADDRESS
```

### Key Features

- Burn specific tokens or all tokens in a wallet
- Close token accounts to recover SOL rent
- Batch operations from file
- Burn tokens from multiple holders
- Authority management operations
- Token program auto-detection
- Interactive and command-line modes
- Dry run capability for testing

### Options

| Category | Option | Description |
|----------|--------|-------------|
| **Basic** | `-k, --private-key KEY` | Private key of wallet |
| | `-f, --key-file FILE` | Path to keypair JSON file |
| | `-t, --token ADDRESS` | Token mint address to burn |
| | `-a, --amount AMOUNT` | Amount to burn (if not specified, burns all) |
| | `-w, --network NETWORK` | Network to use (devnet, testnet, mainnet-beta) |
| | `--burn-all` | Burn all tokens in the wallet |
| | `--close-account` | Close token account after burning |
| **Batch Operations** | `--batch-file FILE` | Read token addresses from a file |
| | `--max-batch-size NUM` | Maximum operations per batch |
| **Holder Operations** | `--burn-holder-tokens` | Burn from all token holders |
| | `--holder-address ADDR` | Burn from specific holder |
| | `--exempt-holders LIST` | Comma-separated addresses to exempt |
| | `--burn-percentage PCT` | Percentage of tokens to burn (1-100) |
| **Authority** | `--revoke-authority` | Revoke token authority |
| | `--authority-type TYPE` | Authority type (mint, freeze, close) |
| | `--disable-mint` | Disable minting of new tokens |
| **Token Program** | `--token-2022` | Use Token 2022 program |
| | `--standard-token` | Use Standard SPL Token program |
| **Other** | `--dry-run` | Simulate operations without executing |
| | `--log-file FILE` | Output log to specified file |
| | `--verbose` | Enable detailed logging |

## Examples

### Creating a Token

1. **Basic token on devnet**:
   ```bash
   ./create-custom-token.sh --name "Example Token" --symbol EX --amount 1000000
   ```

2. **Token with custom image and description**:
   ```bash
   ./create-custom-token.sh -n "Example Token" -s EX -d "My example token" -i "https://example.com/image.png" -a 1000000
   ```

3. **Token with freeze authority**:
   ```bash
   ./create-custom-token.sh -n "Example Token" -s EX --enable-freeze-authority
   ```

4. **Non-transferable token (Token 2022)**:
   ```bash
   ./create-custom-token.sh -n "Example NFT" -s NFT --token-2022 --enable-non-transferable -a 1
   ```

### Burning Tokens

1. **Burn specific amount**:
   ```bash
   ./burn-token.sh -f wallet.json -t TOKEN_ADDRESS -a 100
   ```

2. **Burn all tokens and close account**:
   ```bash
   ./burn-token.sh -f wallet.json -t TOKEN_ADDRESS --close-account
   ```

3. **Batch burn from file**:
   ```bash
   ./burn-token.sh -f wallet.json --batch-file tokens.txt
   ```

4. **Burn from all holders**:
   ```bash
   ./burn-token.sh -f wallet.json -t TOKEN_ADDRESS --burn-holder-tokens
   ```

## Network Support

Both scripts support all Solana networks:

- `devnet` - Development network (with airdrop capability)
- `testnet` - Test network
- `mainnet-beta` - Production network (requires real SOL)

## Future Tools Roadmap

We're planning to expand this toolkit with the following tools:

### 1. Token Airdrop Tool
- Distribute tokens to multiple recipients in batch operations
- Support for CSV/JSON input with addresses and amounts
- Configurable transaction rate limiting
- Transaction fee estimation and optimization
- Progress tracking with resumable operations

### 2. Token Vesting Tool
- Create time-locked tokens with customizable vesting schedules
- Support for cliff periods, linear vesting, and custom schedules
- Management interface for team allocations
- Revocable and non-revocable vesting options
- Integration with Token 2022 extensions

### 3. Token Metadata Manager
- Update metadata for existing tokens
- Batch update capabilities for collections
- Support for image hosting and integration with decentralized storage
- Rich attribute management for NFT collections

### 4. Token Analytics Tool
- Track holder statistics and token distribution metrics
- Generate reports on wallet concentration
- Monitor trading activity across different marketplaces
- Export data in various formats for analysis

### 5. Token Authority Manager
- Transfer token authorities between accounts
- Setup multisig governance controls
- Delegate temporary authorities with expiration
- Configure threshold-based approval systems

## Security Notes

- Keep your keypair files and private keys secure
- Consider using keypair files rather than passing private keys directly
- Test operations on devnet before using on mainnet-beta
- Use `--dry-run` with burn operations to verify behavior

## License

MIT License - See LICENSE file for details. 