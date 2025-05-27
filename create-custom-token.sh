#!/bin/bash

# Exit script if any command fails
set -e

# Default values
TOKEN_NAME="Hyperliquid"
TOKEN_SYMBOL="HYPE"
TOKEN_DESCRIPTION="Hyperliqid"
TOKEN_DECIMALS=9
TOKEN_AMOUNT=1000000000
TOKEN_IMAGE_URL="https://raw.githubusercontent.com/twannasleep/test-token-metadata/refs/heads/main/hype/hyperliquid.jpg"
TOKEN_METADATA_URL="https://raw.githubusercontent.com/twannasleep/test-token-metadata/refs/heads/main/hype/metadata.json"
RECIPIENT_WALLET="N8V3n4Tfo55hFL3VykwnjyUzjxz2wUkKqFFgPcVXpYX"

# Help function
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -n, --name NAME            Set token name (default: $TOKEN_NAME)"
    echo "  -s, --symbol SYMBOL        Set token symbol (default: $TOKEN_SYMBOL)"
    echo "  -d, --description DESC     Set token description (default: $TOKEN_DESCRIPTION)"
    echo "  -c, --decimals DECIMALS    Set token decimals (default: $TOKEN_DECIMALS)"
    echo "  -a, --amount AMOUNT        Set token amount to mint (default: $TOKEN_AMOUNT)"
    echo "  -i, --image URL            Set token image URL"
    echo "  -m, --metadata URL         Set token metadata URL"
    echo "  -r, --recipient ADDRESS    Recipient wallet address to transfer tokens to"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--name)
            TOKEN_NAME="$2"
            shift 2
            ;;
        -s|--symbol)
            TOKEN_SYMBOL="$2"
            shift 2
            ;;
        -d|--description)
            TOKEN_DESCRIPTION="$2"
            shift 2
            ;;
        -c|--decimals)
            TOKEN_DECIMALS="$2"
            shift 2
            ;;
        -a|--amount)
            TOKEN_AMOUNT="$2"
            shift 2
            ;;
        -i|--image)
            TOKEN_IMAGE_URL="$2"
            shift 2
            ;;
        -m|--metadata)
            TOKEN_METADATA_URL="$2"
            shift 2
            ;;
        -r|--recipient)
            RECIPIENT_WALLET="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "Creating a Solana token on devnet with the following parameters:"
echo "  Token Name: $TOKEN_NAME"
echo "  Token Symbol: $TOKEN_SYMBOL"
echo "  Token Description: $TOKEN_DESCRIPTION"
echo "  Token Decimals: $TOKEN_DECIMALS"
echo "  Token Amount to Mint: $TOKEN_AMOUNT"
echo "  Token Image URL: $TOKEN_IMAGE_URL"
echo "  Token Metadata URL: $TOKEN_METADATA_URL"
if [ -n "$RECIPIENT_WALLET" ]; then
    echo "  Recipient Wallet: $RECIPIENT_WALLET"
fi
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Check if Solana CLI is installed
if ! command -v solana &> /dev/null; then
    echo "Solana CLI not found. Installing Solana tools..."
    sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
    export PATH="/home/$USER/.local/share/solana/install/active_release/bin:$PATH"
    echo "Solana tools installed!"
else
    echo "Solana CLI already installed."
fi

# Create directory for token files
mkdir -p solana-token
cd solana-token

# Set Solana to use devnet
solana config set --url devnet
echo "Solana configured to use devnet."

# Create a keypair for the mint authority (boss)
echo "Creating mint authority keypair..."
MINT_AUTHORITY_KEYPAIR=$(solana-keygen grind --starts-with bos:1 --no-bip39-passphrase | grep 'Wrote keypair to' | awk '{print $4}')
echo "Mint authority keypair created: $MINT_AUTHORITY_KEYPAIR"

# Set the keypair as default
solana config set --keypair "$MINT_AUTHORITY_KEYPAIR"
echo "Default keypair set to mint authority."

# Get devnet SOL
echo "Requesting devnet SOL..."
MINT_AUTHORITY_ADDRESS=$(solana address)
solana airdrop 2 "$MINT_AUTHORITY_ADDRESS"
echo "Received 2 SOL on devnet for address: $MINT_AUTHORITY_ADDRESS"

# Check balance
BALANCE=$(solana balance)
echo "Current balance: $BALANCE"

# Create mint address
echo "Creating mint address..."
MINT_ADDRESS_KEYPAIR=$(solana-keygen grind --starts-with mnt:1 --no-bip39-passphrase | grep 'Wrote keypair to' | awk '{print $4}')
echo "Mint address keypair created: $MINT_ADDRESS_KEYPAIR"

# Extract just the public key from the keypair file
MINT_PUBLIC_KEY=$(solana address -k "$MINT_ADDRESS_KEYPAIR")
echo "Mint public key: $MINT_PUBLIC_KEY"

# Create token mint with metadata extension
echo "Creating token mint with metadata extension..."
spl-token create-token --program-id TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb --enable-metadata --decimals "$TOKEN_DECIMALS" "$MINT_ADDRESS_KEYPAIR"

# Generate metadata file
echo "Generating metadata file..."
cat > "metadata.json" << EOF
{
  "name": "$TOKEN_NAME",
  "symbol": "$TOKEN_SYMBOL",
  "description": "$TOKEN_DESCRIPTION",
  "image": "$TOKEN_IMAGE_URL"
}
EOF
echo "Metadata file generated: metadata.json"
echo "NOTE: You should upload this file to a permanent storage location and update the metadata URL."

# Initialize metadata for the token
echo "Initializing token metadata..."
spl-token initialize-metadata "$MINT_PUBLIC_KEY" "$TOKEN_NAME" "$TOKEN_SYMBOL" "$TOKEN_METADATA_URL"

# Create token account
echo "Creating token account..."
spl-token create-account "$MINT_PUBLIC_KEY"

# Mint tokens
echo "Minting $TOKEN_AMOUNT tokens..."
spl-token mint "$MINT_PUBLIC_KEY" "$TOKEN_AMOUNT"

# Transfer tokens to recipient wallet if specified
if [ -n "$RECIPIENT_WALLET" ]; then
    echo "Transferring tokens to recipient wallet: $RECIPIENT_WALLET"
    # Calculate amount to transfer (we'll transfer 80% of minted tokens)
    TRANSFER_AMOUNT=$(echo "$TOKEN_AMOUNT * 0.8" | bc)
    # If bc is not available, use integer division
    if [ -z "$TRANSFER_AMOUNT" ]; then
        TRANSFER_AMOUNT=$((TOKEN_AMOUNT * 8 / 10))
    fi
    echo "Transferring $TRANSFER_AMOUNT tokens..."
    spl-token transfer --fund-recipient "$MINT_PUBLIC_KEY" "$TRANSFER_AMOUNT" "$RECIPIENT_WALLET"
    echo "Tokens transferred successfully!"
fi

# Display token info
echo "Token creation complete!"
echo "Mint Address: $MINT_PUBLIC_KEY"
echo "Token Name: $TOKEN_NAME"
echo "Token Symbol: $TOKEN_SYMBOL"
echo "Token Decimals: $TOKEN_DECIMALS"
echo "Token Balance:"
spl-token accounts

echo "You can view your token on Solana Explorer: https://explorer.solana.com/address/$MINT_PUBLIC_KEY?cluster=devnet"
echo ""
echo "IMPORTANT: Keep your keypair files safe. They control your token!"
echo "Mint Authority Keypair: $MINT_AUTHORITY_KEYPAIR"
echo "Mint Address Keypair: $MINT_ADDRESS_KEYPAIR" 