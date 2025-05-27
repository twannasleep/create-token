#!/bin/bash

# Exit script if any command fails
set -e

# Check if recipient wallet address is provided
if [ $# -eq 1 ]; then
    RECIPIENT_WALLET="$1"
    echo "Will transfer tokens to recipient wallet: $RECIPIENT_WALLET"
fi

echo "Creating a Solana token on devnet..."

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
spl-token create-token --program-id TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb --enable-metadata "$MINT_ADDRESS_KEYPAIR"

# Define token metadata
TOKEN_NAME="Example Token"
TOKEN_SYMBOL="EXMPL"
TOKEN_DESCRIPTION="Example token created with script"
# Using a placeholder image URL - replace with your actual image URL
TOKEN_IMAGE_URL="https://raw.githubusercontent.com/solana-developers/opos-asset/main/assets/CompressedCoil/image.png"
# Using a placeholder metadata URL - replace with your actual metadata URL
TOKEN_METADATA_URL="https://raw.githubusercontent.com/solana-developers/opos-asset/main/assets/CompressedCoil/metadata.json"

# Initialize metadata for the token
echo "Initializing token metadata..."
spl-token initialize-metadata "$MINT_PUBLIC_KEY" "$TOKEN_NAME" "$TOKEN_SYMBOL" "$TOKEN_METADATA_URL"

# Create token account
echo "Creating token account..."
spl-token create-account "$MINT_PUBLIC_KEY"

# Mint tokens
echo "Minting 100 tokens..."
spl-token mint "$MINT_PUBLIC_KEY" 100

# Transfer tokens to recipient wallet if specified
if [ -n "$RECIPIENT_WALLET" ]; then
    echo "Transferring tokens to recipient wallet: $RECIPIENT_WALLET"
    # Transfer 80 tokens (80% of minted tokens)
    echo "Transferring 80 tokens..."
    spl-token transfer --fund-recipient "$MINT_PUBLIC_KEY" 80 "$RECIPIENT_WALLET"
    echo "Tokens transferred successfully!"
fi

# Display token info
echo "Token creation complete!"
echo "Mint Address: $MINT_PUBLIC_KEY"
echo "Token Name: $TOKEN_NAME"
echo "Token Symbol: $TOKEN_SYMBOL"
echo "Token Balance:"
spl-token accounts

echo "You can view your token on Solana Explorer: https://explorer.solana.com/address/$MINT_PUBLIC_KEY?cluster=devnet"
echo ""
echo "IMPORTANT: Keep your keypair files safe. They control your token!"
echo "Mint Authority Keypair: $MINT_AUTHORITY_KEYPAIR"
echo "Mint Address Keypair: $MINT_ADDRESS_KEYPAIR" 