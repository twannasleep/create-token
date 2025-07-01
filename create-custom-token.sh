#!/bin/bash

# Exit script if any command fails
set -e

# Default values
TOKEN_NAME="My Token"
TOKEN_SYMBOL="TKN"
TOKEN_DESCRIPTION="Custom SPL token created with create-custom-token.sh"
TOKEN_DECIMALS=9
TOKEN_AMOUNT=1000000000
TOKEN_IMAGE_URL="https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png"
TOKEN_METADATA_URL=""
RECIPIENT_WALLET="N8V3n4Tfo55hFL3VykwnjyUzjxz2wUkKqFFgPcVXpYX"
NETWORK="devnet"
JSON_INPUT=""
READ_FROM_STDIN=false
SKIP_CONFIRMATION=false
MIN_BALANCE_DEVNET="1.0"
MIN_BALANCE_TESTNET="0.5"
MIN_BALANCE_MAINNET="0.1"
USE_TOKEN_2022=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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
    echo "  -w, --network NETWORK      Network to use (devnet, testnet, mainnet-beta) (default: $NETWORK)"
    echo "  -j, --json JSON_STRING     Set token metadata using JSON string"
    echo "  -f, --json-file FILE       Set token metadata using JSON file"
    echo "  --stdin                    Read JSON input from terminal (interactive mode)"
    echo "  -y, --yes                  Skip confirmation prompt"
    echo "  --min-balance-devnet SOL   Minimum SOL balance before requesting devnet airdrop (default: $MIN_BALANCE_DEVNET)"
    echo "  --min-balance-testnet SOL  Minimum SOL balance before requesting testnet airdrop (default: $MIN_BALANCE_TESTNET)"
    echo "  --min-balance-mainnet SOL  Minimum SOL balance threshold for mainnet warning (default: $MIN_BALANCE_MAINNET)"
    echo "  --token-2022               Use Token 2022 program with metadata extensions"
    echo "  --standard-token           Use Standard SPL Token program (original token program)"
    echo ""
    echo "Token Programs:"
    echo "  If no token program option is specified, the script will interactively prompt you to choose"
    echo "  between Standard SPL Token and Token 2022 programs."
    echo ""
    echo "  Standard SPL Token: Original token program (TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA)"
    echo "  Token 2022: New token program with enhanced features including metadata extensions (TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb)"
    echo ""
    echo "JSON format example:"
    echo '  {"name":"PancakeSwap","symbol":"CAKE","description":"PancakeSwap token test","image":"https://example.com/image.png"}'
    echo ""
    echo "Networks:"
    echo "  devnet       - Development network (free SOL via airdrop)"
    echo "  testnet      - Test network"
    echo "  mainnet-beta - Main production network (requires real SOL)"
    echo ""
}

# Validate inputs
validate_inputs() {
    # Validate decimals
    if ! [[ "$TOKEN_DECIMALS" =~ ^[0-9]+$ ]] || [ "$TOKEN_DECIMALS" -lt 0 ] || [ "$TOKEN_DECIMALS" -gt 9 ]; then
        log_error "Token decimals must be a number between 0 and 9"
        exit 1
    fi

    # Validate amount
    if ! [[ "$TOKEN_AMOUNT" =~ ^[0-9]+$ ]] || [ "$TOKEN_AMOUNT" -le 0 ]; then
        log_error "Token amount must be a positive integer"
        exit 1
    fi

    # Validate network
    if [[ ! "$NETWORK" =~ ^(devnet|testnet|mainnet-beta)$ ]]; then
        log_error "Network must be one of: devnet, testnet, mainnet-beta"
        exit 1
    fi

    # Validate recipient wallet if provided
    if [ -n "$RECIPIENT_WALLET" ]; then
        if [ ${#RECIPIENT_WALLET} -lt 32 ] || [ ${#RECIPIENT_WALLET} -gt 44 ]; then
            log_error "Recipient wallet address appears to be invalid (wrong length)"
            exit 1
        fi
    fi

    # Validate URLs if provided
    if [ -n "$TOKEN_IMAGE_URL" ] && ! [[ "$TOKEN_IMAGE_URL" =~ ^https?:// ]]; then
        log_warning "Token image URL should start with http:// or https://"
    fi

    if [ -n "$TOKEN_METADATA_URL" ] && ! [[ "$TOKEN_METADATA_URL" =~ ^https?:// ]]; then
        log_warning "Token metadata URL should start with http:// or https://"
    fi

    # Validate minimum balance values
    if ! [[ "$MIN_BALANCE_DEVNET" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "Minimum balance for devnet must be a positive number"
        exit 1
    fi

    if ! [[ "$MIN_BALANCE_TESTNET" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "Minimum balance for testnet must be a positive number"
        exit 1
    fi

    if ! [[ "$MIN_BALANCE_MAINNET" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "Minimum balance for mainnet must be a positive number"
        exit 1
    fi
}

# Parse JSON input with improved parsing
function parse_json {
    if [ -n "$1" ]; then
        # Try to use jq if available for better JSON parsing
        if command -v jq &> /dev/null; then
            log_info "Using jq for JSON parsing"
            
            # Validate JSON format first
            if ! echo "$1" | jq . > /dev/null 2>&1; then
                log_error "Invalid JSON format"
                exit 1
            fi
            
            # Extract fields using jq
            NAME=$(echo "$1" | jq -r '.name // empty')
            SYMBOL=$(echo "$1" | jq -r '.symbol // empty')
            DESC=$(echo "$1" | jq -r '.description // empty')
            IMAGE=$(echo "$1" | jq -r '.image // empty')
        else
            log_warning "jq not found, using basic grep parsing (consider installing jq for better JSON support)"
            
            # Fallback to grep-based parsing
            NAME=$(echo "$1" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
            SYMBOL=$(echo "$1" | grep -o '"symbol":"[^"]*"' | cut -d'"' -f4)
            DESC=$(echo "$1" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
            IMAGE=$(echo "$1" | grep -o '"image":"[^"]*"' | cut -d'"' -f4)
        fi

        # Update variables if values were found
        [ -n "$NAME" ] && TOKEN_NAME="$NAME"
        [ -n "$SYMBOL" ] && TOKEN_SYMBOL="$SYMBOL"
        [ -n "$DESC" ] && TOKEN_DESCRIPTION="$DESC"
        [ -n "$IMAGE" ] && TOKEN_IMAGE_URL="$IMAGE"
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
        -w|--network)
            NETWORK="$2"
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
                log_error "JSON file not found: $2"
                exit 1
            fi
            shift 2
            ;;
        --stdin)
            READ_FROM_STDIN=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --min-balance-devnet)
            MIN_BALANCE_DEVNET="$2"
            shift 2
            ;;
        --min-balance-testnet)
            MIN_BALANCE_TESTNET="$2"
            shift 2
            ;;
        --min-balance-mainnet)
            MIN_BALANCE_MAINNET="$2"
            shift 2
            ;;
        --token-2022)
            USE_TOKEN_2022=true
            shift
            ;;
        --standard-token)
            USE_TOKEN_2022=false
            shift
            ;;
        *)
            # Check if input is a JSON string starting with {
            if [[ "$1" == {* ]]; then
                JSON_INPUT="$1"
                parse_json "$JSON_INPUT"
                shift
            else
                log_error "Unknown option: $1"
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

# Always ask for custom metadata JSON unless already provided via a command-line option
JSON_PROVIDED=false
for arg in "$@"; do
    if [ "$arg" == "-j" ] || [ "$arg" == "--json" ] || [ "$arg" == "-f" ] || [ "$arg" == "--json-file" ] || [ "$arg" == "--stdin" ] || [[ "$arg" == {* ]]; then
        JSON_PROVIDED=true
        break
    fi
done

if [ "$SKIP_CONFIRMATION" = false ] && [ "$JSON_PROVIDED" = false ]; then
    echo ""
    echo "=== CUSTOM TOKEN METADATA ==="
    read -p "Would you like to enter custom token metadata? (y/n) [default: y]: " ENTER_METADATA
    
    if [[ -z "$ENTER_METADATA" || "$ENTER_METADATA" =~ ^[Yy](es)?$ ]]; then
        echo ""
        echo "Please enter your token metadata in JSON format."
        echo "Required fields: name, symbol"
        echo "Recommended fields: description, image (URL)"
        echo ""
        echo "Current values:"
        echo "  Name: $TOKEN_NAME"
        echo "  Symbol: $TOKEN_SYMBOL"
        echo "  Description: $TOKEN_DESCRIPTION"
        echo "  Image URL: $TOKEN_IMAGE_URL"
        echo ""
        echo "Example JSON:"
        echo "{\"name\":\"$TOKEN_NAME\",\"symbol\":\"$TOKEN_SYMBOL\",\"description\":\"$TOKEN_DESCRIPTION\",\"image\":\"$TOKEN_IMAGE_URL\"}"
        echo ""
        echo "Enter your JSON below (press Ctrl+D when finished):"
        JSON_INPUT=$(cat)
        parse_json "$JSON_INPUT"
    fi
    echo ""
fi

# Interactive token program selection if not specified via command line
TOKEN_PROGRAM_SELECTED_BY_USER=false
for arg in "$@"; do
    if [ "$arg" == "--token-2022" ] || [ "$arg" == "--standard-token" ]; then
        TOKEN_PROGRAM_SELECTED_BY_USER=true
        break
    fi
done

if [ "$SKIP_CONFIRMATION" = false ] && [ "$TOKEN_PROGRAM_SELECTED_BY_USER" = false ]; then
    echo ""
    echo "=== SELECT TOKEN PROGRAM ==="
    echo "1) Standard SPL Token (original token program)"
    echo "2) Token 2022 (with metadata extensions)"
    echo ""
    read -p "Select token program [1-2] (default: 1): " TOKEN_PROGRAM_CHOICE
    
    case $TOKEN_PROGRAM_CHOICE in
        2)
            USE_TOKEN_2022=true
            log_info "Selected Token 2022 program"
            ;;
        *)
            USE_TOKEN_2022=false
            log_info "Selected Standard SPL Token program"
            ;;
    esac
    echo ""
fi

# Validate all inputs
validate_inputs

log_info "Creating a Solana token on $NETWORK with the following parameters:"
echo "  Token Name: $TOKEN_NAME"
echo "  Token Symbol: $TOKEN_SYMBOL"
echo "  Token Description: $TOKEN_DESCRIPTION"
echo "  Token Decimals: $TOKEN_DECIMALS"
echo "  Token Amount to Mint: $TOKEN_AMOUNT"
echo "  Token Image URL: $TOKEN_IMAGE_URL"
echo "  Token Metadata URL: $TOKEN_METADATA_URL"
echo "  Network: $NETWORK"
if [ "$USE_TOKEN_2022" = true ]; then
    echo "  Token Program: Token 2022 (with metadata extensions)"
else
    echo "  Token Program: Original SPL Token (no metadata extensions)"
fi
if [ -n "$RECIPIENT_WALLET" ]; then
    echo "  Recipient Wallet: $RECIPIENT_WALLET"
fi
echo ""

if [ "$SKIP_CONFIRMATION" = false ]; then
    echo "Press Enter to continue or Ctrl+C to cancel..."
    read
fi

# Check if Solana CLI is installed
if ! command -v solana &> /dev/null; then
    log_info "Solana CLI not found. Installing Solana tools..."
    sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
    
    # Set PATH for different OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    else
        # Linux
        export PATH="/home/$USER/.local/share/solana/install/active_release/bin:$PATH"
    fi
    
    log_success "Solana tools installed!"
else
    log_success "Solana CLI already installed."
fi

# Check if spl-token is available
if ! command -v spl-token &> /dev/null; then
    log_error "spl-token command not found. Please ensure SPL Token CLI is installed."
    log_info "You can install it with: cargo install spl-token-cli"
    exit 1
fi

# Create directory for token files
mkdir -p solana-token
cd solana-token

# Set Solana to use specified network
log_info "Configuring Solana to use $NETWORK..."
solana config set --url "$NETWORK"
log_success "Solana configured to use $NETWORK."

# Create a keypair for the mint authority (removed prefix requirement)
log_info "Creating mint authority keypair..."
MINT_AUTHORITY_KEYPAIR="mint-authority-$(date +%s).json"
solana-keygen new --no-bip39-passphrase --outfile "$MINT_AUTHORITY_KEYPAIR" --silent
log_success "Mint authority keypair created: $MINT_AUTHORITY_KEYPAIR"

# Set the keypair as default
solana config set --keypair "$MINT_AUTHORITY_KEYPAIR"
log_success "Default keypair set to mint authority."

# Get the mint authority address
MINT_AUTHORITY_ADDRESS=$(solana address)
log_info "Mint authority address: $MINT_AUTHORITY_ADDRESS"

# Function to check if balance is sufficient
check_balance_and_airdrop() {
    local required_sol=$1
    local network=$2
    
    # Get current balance and extract numeric value
    local current_balance=$(solana balance --lamports)
    local current_sol=$(echo "scale=9; $current_balance / 1000000000" | bc 2>/dev/null || echo "0")
    
    # Compare using bc if available, otherwise use basic comparison
    if command -v bc &> /dev/null; then
        local needs_airdrop=$(echo "$current_sol < $required_sol" | bc)
    else
        # Fallback for systems without bc - convert to integer comparison
        local current_int=$(echo "$current_sol * 1000000000" | cut -d'.' -f1)
        local required_int=$(echo "$required_sol * 1000000000" | cut -d'.' -f1)
        if [ "$current_int" -lt "$required_int" ]; then
            needs_airdrop=1
        else
            needs_airdrop=0
        fi
    fi
    
    log_info "Current balance: $(echo "scale=4; $current_sol" | bc 2>/dev/null || echo "$current_sol") SOL"
    log_info "Required balance: $required_sol SOL"
    
    if [ "$needs_airdrop" = "1" ]; then
        log_info "Balance insufficient, requesting airdrop..."
        return 0  # Need airdrop
    else
        log_success "Balance sufficient, skipping airdrop"
        return 1  # Don't need airdrop
    fi
}

# Get SOL for the specified network with balance checking
if [ "$NETWORK" = "devnet" ]; then
    if check_balance_and_airdrop "$MIN_BALANCE_DEVNET" "devnet"; then
        log_info "Requesting devnet SOL..."
        if solana airdrop 2 "$MINT_AUTHORITY_ADDRESS"; then
            log_success "Received 2 SOL on devnet"
        else
            log_warning "Airdrop failed, but continuing anyway..."
        fi
    fi
elif [ "$NETWORK" = "testnet" ]; then
    if check_balance_and_airdrop "$MIN_BALANCE_TESTNET" "testnet"; then
        log_info "Requesting testnet SOL..."
        if solana airdrop 1 "$MINT_AUTHORITY_ADDRESS"; then
            log_success "Received 1 SOL on testnet"
        else
            log_warning "Airdrop failed, but continuing anyway..."
        fi
    fi
else
    log_warning "Using mainnet-beta - make sure you have sufficient SOL in your wallet!"
    # Check balance for mainnet but don't request airdrop
    local current_balance=$(solana balance --lamports)
    local current_sol=$(echo "scale=9; $current_balance / 1000000000" | bc 2>/dev/null || echo "0")
    log_info "Current balance: $(echo "scale=4; $current_sol" | bc 2>/dev/null || echo "$current_sol") SOL"
    
    # Warn if balance is very low for mainnet operations
    if command -v bc &> /dev/null; then
        local low_balance=$(echo "$current_sol < $MIN_BALANCE_MAINNET" | bc)
        if [ "$low_balance" = "1" ]; then
            log_warning "Balance is very low for mainnet operations. Consider adding more SOL."
        fi
    fi
fi

# Check final balance
BALANCE=$(solana balance)
log_info "Final balance: $BALANCE"

# Create mint address (removed prefix requirement)
log_info "Creating mint address..."
MINT_ADDRESS_KEYPAIR="mint-address-$(date +%s).json"
solana-keygen new --no-bip39-passphrase --outfile "$MINT_ADDRESS_KEYPAIR" --silent
log_success "Mint address keypair created: $MINT_ADDRESS_KEYPAIR"

# Extract just the public key from the keypair file
MINT_PUBLIC_KEY=$(solana address -k "$MINT_ADDRESS_KEYPAIR")
log_info "Mint public key: $MINT_PUBLIC_KEY"

# Create token mint
if [ "$USE_TOKEN_2022" = true ]; then
    log_info "Creating token mint with Token 2022 program and metadata extension..."
    if spl-token create-token --program-id TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb --enable-metadata --decimals "$TOKEN_DECIMALS" "$MINT_ADDRESS_KEYPAIR"; then
        log_success "Token mint created successfully with Token 2022 program"
    else
        log_error "Failed to create token mint with Token 2022 program"
        exit 1
    fi
else
    log_info "Creating token mint with original Token program..."
    if spl-token create-token --program-id TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA --decimals "$TOKEN_DECIMALS" "$MINT_ADDRESS_KEYPAIR"; then
        log_success "Token mint created successfully with original Token program"
    else
        log_error "Failed to create token mint with original Token program"
        exit 1
    fi
fi

# Generate metadata file with timestamp
METADATA_FILE="metadata-$(date +%s).json"
log_info "Generating metadata file: $METADATA_FILE"
cat > "$METADATA_FILE" << EOF
{
  "name": "$TOKEN_NAME",
  "symbol": "$TOKEN_SYMBOL",
  "description": "$TOKEN_DESCRIPTION",
  "image": "$TOKEN_IMAGE_URL",
  "external_url": "",
  "attributes": [],
  "properties": {
    "files": [
      {
        "uri": "$TOKEN_IMAGE_URL",
        "type": "image/png"
      }
    ],
    "category": "image"
  }
}
EOF
log_success "Metadata file generated: $METADATA_FILE"
log_warning "NOTE: You should upload this file to a permanent storage location and update the metadata URL."

# Initialize metadata for the token (only for Token 2022)
if [ "$USE_TOKEN_2022" = true ]; then
    log_info "Initializing token metadata..."
    if spl-token initialize-metadata "$MINT_PUBLIC_KEY" "$TOKEN_NAME" "$TOKEN_SYMBOL" "$TOKEN_METADATA_URL"; then
        log_success "Token metadata initialized"
    else
        log_error "Failed to initialize token metadata"
        exit 1
    fi
else
    log_info "Skipping metadata initialization (not supported by original Token program)"
fi

# Create token account
log_info "Creating token account..."
if spl-token create-account "$MINT_PUBLIC_KEY"; then
    log_success "Token account created"
else
    log_error "Failed to create token account"
    exit 1
fi

# Mint tokens
log_info "Minting $TOKEN_AMOUNT tokens..."
if spl-token mint "$MINT_PUBLIC_KEY" "$TOKEN_AMOUNT"; then
    log_success "Tokens minted successfully"
else
    log_error "Failed to mint tokens"
    exit 1
fi

# Transfer tokens to recipient wallet if specified
if [ -n "$RECIPIENT_WALLET" ]; then
    log_info "Transferring tokens to recipient wallet: $RECIPIENT_WALLET"
    # Calculate amount to transfer (we'll transfer 80% of minted tokens)
    if command -v bc &> /dev/null; then
        TRANSFER_AMOUNT=$(echo "$TOKEN_AMOUNT * 0.8" | bc | cut -d'.' -f1)
    else
        TRANSFER_AMOUNT=$((TOKEN_AMOUNT * 8 / 10))
    fi
    
    log_info "Transferring $TRANSFER_AMOUNT tokens..."
    if spl-token transfer --fund-recipient "$MINT_PUBLIC_KEY" "$TRANSFER_AMOUNT" "$RECIPIENT_WALLET"; then
        log_success "Tokens transferred successfully!"
    else
        log_error "Failed to transfer tokens"
        exit 1
    fi
fi

# Display token info
log_success "Token creation complete!"
echo ""
echo "=== TOKEN INFORMATION ==="
echo "Mint Address: $MINT_PUBLIC_KEY"
echo "Token Name: $TOKEN_NAME"
echo "Token Symbol: $TOKEN_SYMBOL"
echo "Token Decimals: $TOKEN_DECIMALS"
echo "Network: $NETWORK"
echo ""
echo "=== TOKEN BALANCE ==="
spl-token accounts

# Generate explorer URL based on network
if [ "$NETWORK" = "mainnet-beta" ]; then
    EXPLORER_URL="https://explorer.solana.com/address/$MINT_PUBLIC_KEY"
else
    EXPLORER_URL="https://explorer.solana.com/address/$MINT_PUBLIC_KEY?cluster=$NETWORK"
fi

echo ""
echo "=== EXPLORER LINK ==="
echo "You can view your token on Solana Explorer: $EXPLORER_URL"
echo ""
echo "=== IMPORTANT FILES ==="
echo "Keep these keypair files safe - they control your token!"
echo "Mint Authority Keypair: $PWD/$MINT_AUTHORITY_KEYPAIR"
echo "Mint Address Keypair: $PWD/$MINT_ADDRESS_KEYPAIR"
echo "Metadata File: $PWD/$METADATA_FILE"
echo ""
log_success "Script completed successfully!" 