# Create Solana Token

This repository contains scripts to help you create a Solana token on the devnet.

## Prerequisites

- A Unix-like operating system (Linux, macOS)
- Internet connection
- Basic knowledge of terminal/command line

## Getting Started

1. Make the scripts executable:
   ```bash
   chmod +x create-solana-token.sh create-custom-token.sh
   ```

2. Run one of the scripts:
   
   Basic script (with default values):
   ```bash
   ./create-solana-token.sh [recipient_wallet_address]
   ```
   
   Advanced script (with customization options):
   ```bash
   ./create-custom-token.sh [options]
   ```

## Script Options

### Basic Script (`create-solana-token.sh`)

The basic script uses hardcoded default values for token creation.

You can optionally provide a recipient wallet address as an argument to transfer tokens to:
```bash
./create-solana-token.sh YOUR_WALLET_ADDRESS
```

### Advanced Script (`create-custom-token.sh`)

The advanced script allows you to customize your token through command-line arguments:

```bash
./create-custom-token.sh [options]
```

Available options:
- `-h, --help`: Show help message
- `-n, --name NAME`: Set token name (default: "Example Token")
- `-s, --symbol SYMBOL`: Set token symbol (default: "EXMPL")
- `-d, --description DESC`: Set token description
- `-c, --decimals DECIMALS`: Set token decimals (default: 9)
- `-a, --amount AMOUNT`: Set token amount to mint (default: 100)
- `-i, --image URL`: Set token image URL
- `-m, --metadata URL`: Set token metadata URL
- `-r, --recipient ADDRESS`: Set recipient wallet address to transfer tokens to

Example:
```bash
./create-custom-token.sh --name "My Token" --symbol "MTK" --decimals 6 --amount 1000 --recipient YOUR_WALLET_ADDRESS
```

## What the Scripts Do

Both scripts automate the following steps:

1. Install Solana CLI tools if not already installed
2. Create a keypair for the mint authority (with public key starting with "bos")
3. Get some devnet SOL via airdrop
4. Create a mint address (with public key starting with "mnt")
5. Create the token mint account with metadata extension
6. Initialize the metadata for the token
7. Create a token account and mint tokens
8. Transfer tokens to your wallet (if recipient address is provided)

## Customizing Your Token Metadata

The advanced script generates a local metadata.json file with your specified parameters. For production tokens, you should:

1. Upload the generated metadata.json file to a permanent storage location
2. Upload your token image to a permanent storage location
3. Update the metadata URL in the script or use the `-m` option

## Viewing Your Token

After running the script, you can view your token on the Solana Explorer:
https://explorer.solana.com/address/YOUR_MINT_ADDRESS?cluster=devnet

Replace `YOUR_MINT_ADDRESS` with the mint address output by the script.

If you transferred tokens to your wallet, you can view them in any Solana wallet app that supports devnet (like Phantom or Solflare).

## Important Notes

- These scripts create tokens on the Solana devnet, not the mainnet
- The keypairs generated are stored in the `solana-token` directory
- Keep your keypair files safe as they control your token
- For production tokens, you should use decentralized storage for metadata and images
- The `--fund-recipient` flag is used when transferring tokens to automatically create the token account for the recipient 