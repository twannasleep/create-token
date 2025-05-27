#!/bin/bash

# Exit script if any command fails
set -e

# Default values
TOKEN_NAME="Binance Coin"
TOKEN_SYMBOL="BNB"
TOKEN_DESCRIPTION="BNB token test"
TOKEN_DECIMALS=9
TOKEN_AMOUNT=1000000000
TOKEN_IMAGE_URL="https://raw.githubusercontent.com/twannasleep/test-token-metadata/refs/heads/main/pancakeswap/pancakeswap-cake-logo.webp"
TOKEN_METADATA_URL="https://raw.githubusercontent.com/twannasleep/test-token-metadata/refs/heads/main/bnb/metadata.json"
RECIPIENT_WALLET="N8V3n4Tfo55hFL3VykwnjyUzjxz2wUkKqFFgPcVXpYX"
JSON_INPUT=""
READ_FROM_STDIN=false
KEYPAIR_DIR="solana-token"
MINT_AUTHORITY_KEYPAIR=""
MINT_ADDRESS_KEYPAIR=""
REUSE_KEYPAIRS=true

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
    echo "  -j, --json JSON_STRING     Set token metadata using JSON string"
    echo "  -f, --json-file FILE       Set token metadata using JSON file"
    echo "  --stdin                    Read JSON input from terminal (interactive mode)"
    echo "  --new-keypairs             Generate new keypairs instead of reusing existing ones"
    echo "  --authority FILE           Use specific file as mint authority keypair"
    echo "  --mint FILE                Use specific file as mint address keypair"
    echo ""
    echo "JSON format example:"
    echo '  {"name":"PancakeSwap","symbol":"CAKE","description":"PancakeSwap token test","image":"https://example.com/image.png"}'
    echo ""
}

# Parse JSON input
function parse_json {
    if [ -n "$1" ]; then
        # Extract name if present
        NAME=$(echo "$1" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$NAME" ]; then
            TOKEN_NAME="$NAME"
        fi

        # Extract symbol if present
        SYMBOL=$(echo "$1" | grep -o '"symbol":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$SYMBOL" ]; then
            TOKEN_SYMBOL="$SYMBOL"
        fi

        # Extract description if present
        DESC=$(echo "$1" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$DESC" ]; then
            TOKEN_DESCRIPTION="$DESC"
        fi

        # Extract image if present
        IMAGE=$(echo "$1" | grep -o '"image":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$IMAGE" ]; then
            TOKEN_IMAGE_URL="$IMAGE"
        fi
    fi
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
        -j|--json)
            JSON_INPUT="$2"
            parse_json "$JSON_INPUT"
            shift 2
            ;;
        -f|--json-file)
            if [ -f "$2" ]; then
                JSON_INPUT=$(cat "$2")
                parse_json "$JSON_INPUT"
            else
                echo "Error: JSON file not found: $2"
                exit 1
            fi
            shift 2
            ;;
        --stdin)
            READ_FROM_STDIN=true
            shift
            ;;
        --new-keypairs)
            REUSE_KEYPAIRS=false
            shift
            ;;
        --authority)
            MINT_AUTHORITY_KEYPAIR="$2"
            shift 2
            ;;
        --mint)
            MINT_ADDRESS_KEYPAIR="$2"
            shift 2
            ;;
        *)
            # Check if input is a JSON string starting with {
            if [[ "$1" == {* ]]; then
                JSON_INPUT="$1"
                parse_json "$JSON_INPUT"
                shift
            else
                echo "Unknown option: $1"
                show_help
                exit 1
            fi
            ;;
    esac
done

# Read JSON from stdin if requested
if [ "$READ_FROM_STDIN" = true ]; then
    echo "Please enter your token metadata in JSON format:"
    echo "Example: {\"name\":\"PancakeSwap\",\"symbol\":\"CAKE\",\"description\":\"PancakeSwap token test\",\"image\":\"https://example.com/image.png\"}"
    echo "Enter JSON (press Ctrl+D when finished):"
    JSON_INPUT=$(cat)
    parse_json "$JSON_INPUT"
fi

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
mkdir -p "$KEYPAIR_DIR"
cd "$KEYPAIR_DIR"

# Set Solana to use devnet
solana config set --url devnet
echo "Solana configured to use devnet."

# Function to find existing keypair files
find_keypair() {
    local prefix=$1
    local file
    
    # Look for keypair files with the given prefix
    for file in $(find . -name "${prefix}*.json" 2>/dev/null); do
        # Return the first match
        echo "$file"
        return 0
    done
    
    # No match found
    echo ""
    return 1
}

# Handle mint authority keypair
if [ -n "$MINT_AUTHORITY_KEYPAIR" ] && [ -f "$MINT_AUTHORITY_KEYPAIR" ]; then
    echo "Using provided mint authority keypair: $MINT_AUTHORITY_KEYPAIR"
elif [ "$REUSE_KEYPAIRS" = true ]; then
    # Try to find existing keypair
    EXISTING_KEYPAIR=$(find_keypair "bos")
    
    if [ -n "$EXISTING_KEYPAIR" ]; then
        MINT_AUTHORITY_KEYPAIR="$EXISTING_KEYPAIR"
        echo "Reusing existing mint authority keypair: $MINT_AUTHORITY_KEYPAIR"
    else
        echo "Creating mint authority keypair..."
        MINT_AUTHORITY_KEYPAIR=$(solana-keygen grind --starts-with bos:1 --no-bip39-passphrase | grep 'Wrote keypair to' | awk '{print $4}')
        echo "Mint authority keypair created: $MINT_AUTHORITY_KEYPAIR"
    fi
else
    echo "Creating new mint authority keypair..."
    MINT_AUTHORITY_KEYPAIR=$(solana-keygen grind --starts-with bos:1 --no-bip39-passphrase | grep 'Wrote keypair to' | awk '{print $4}')
    echo "Mint authority keypair created: $MINT_AUTHORITY_KEYPAIR"
fi

# Set the keypair as default
solana config set --keypair "$MINT_AUTHORITY_KEYPAIR"
echo "Default keypair set to mint authority."

# Get mint authority address
MINT_AUTHORITY_ADDRESS=$(solana address -k "$MINT_AUTHORITY_KEYPAIR")
echo "Mint authority address: $MINT_AUTHORITY_ADDRESS"

# Check balance
BALANCE=$(solana balance)
echo "Current balance: $BALANCE"

# Request SOL if balance is low
if (( $(echo "$BALANCE < 0.5" | bc -l) )); then
    echo "Balance is low. Requesting devnet SOL..."
    solana airdrop 2 "$MINT_AUTHORITY_ADDRESS"
    echo "Received 2 SOL on devnet for address: $MINT_AUTHORITY_ADDRESS"
    
    # Check new balance
    BALANCE=$(solana balance)
    echo "New balance: $BALANCE"
fi

# Handle mint address keypair
if [ -n "$MINT_ADDRESS_KEYPAIR" ] && [ -f "$MINT_ADDRESS_KEYPAIR" ]; then
    echo "Using provided mint address keypair: $MINT_ADDRESS_KEYPAIR"
elif [ "$REUSE_KEYPAIRS" = true ]; then
    # Try to find existing keypair
    EXISTING_KEYPAIR=$(find_keypair "mnt")
    
    if [ -n "$EXISTING_KEYPAIR" ]; then
        MINT_ADDRESS_KEYPAIR="$EXISTING_KEYPAIR"
        echo "Reusing existing mint address keypair: $MINT_ADDRESS_KEYPAIR"
    else
        echo "Creating mint address keypair..."
        MINT_ADDRESS_KEYPAIR=$(solana-keygen grind --starts-with mnt:1 --no-bip39-passphrase | grep 'Wrote keypair to' | awk '{print $4}')
        echo "Mint address keypair created: $MINT_ADDRESS_KEYPAIR"
    fi
else
    echo "Creating new mint address keypair..."
    MINT_ADDRESS_KEYPAIR=$(solana-keygen grind --starts-with mnt:1 --no-bip39-passphrase | grep 'Wrote keypair to' | awk '{print $4}')
    echo "Mint address keypair created: $MINT_ADDRESS_KEYPAIR"
fi

# Extract just the public key from the keypair file
MINT_PUBLIC_KEY=$(solana address -k "$MINT_ADDRESS_KEYPAIR")
echo "Mint public key: $MINT_PUBLIC_KEY"

# Save keypair information to a file for future reference
echo "Saving keypair information to keypairs.txt..."
cat > "keypairs.txt" << EOF
Mint Authority Keypair: $MINT_AUTHORITY_KEYPAIR
Mint Authority Address: $MINT_AUTHORITY_ADDRESS
Mint Address Keypair: $MINT_ADDRESS_KEYPAIR
Mint Public Key: $MINT_PUBLIC_KEY
Last Used: $(date)
EOF

# Check if token already exists
echo "Checking if token already exists..."
TOKEN_EXISTS=false
if solana account "$MINT_PUBLIC_KEY" &>/dev/null; then
    echo "Token already exists. Skipping token creation."
    TOKEN_EXISTS=true
else
    echo "Token does not exist. Creating new token..."
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
fi

# Check if token account exists for mint authority
echo "Checking if token account exists for mint authority..."
if ! spl-token accounts | grep -q "$MINT_PUBLIC_KEY"; then
    echo "Creating token account..."
    spl-token create-account "$MINT_PUBLIC_KEY"
else
    echo "Token account already exists for mint authority."
fi

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
echo "Token creation/update complete!"
echo "Mint Address: $MINT_PUBLIC_KEY"
echo "Token Name: $TOKEN_NAME"
echo "Token Symbol: $TOKEN_SYMBOL"
echo "Token Decimals: $TOKEN_DECIMALS"
echo "Token Balance:"
spl-token accounts

echo "You can view your token on Solana Explorer: https://explorer.solana.com/address/$MINT_PUBLIC_KEY?cluster=devnet"
echo ""
echo "IMPORTANT: Keep your keypair files safe. They control your token!"
echo "Keypair information saved in: $KEYPAIR_DIR/keypairs.txt" 