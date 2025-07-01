#!/bin/bash

# Exit script if any command fails
set -e

# Default values
PRIVATE_KEY=""
PRIVATE_KEY_FILE=""
NETWORK="devnet"
NETWORK_SET_BY_USER="false"
BURN_ALL=false
TOKEN_ADDRESS=""
BURN_AMOUNT=""
SKIP_CONFIRMATION=false
CLOSE_ACCOUNT=false
# New parameters
OUTPUT_LOG_FILE=""
BATCH_FILE=""
USE_TOKEN_2022=false
DRY_RUN=false
TOKEN_PROGRAM_ID=""
BURN_HOLDER_TOKENS=false
HOLDER_ADDRESS=""
EXEMPT_HOLDER_LIST=""
MAX_TOKENS_PER_BATCH=10
BURN_PERCENTAGE=100
REVOKE_AUTHORITY=false
AUTHORITY_TYPE=""
DISABLE_MINT=false
AUTO_DETECT_PROGRAM=true
VERBOSE=false

# Constants for token programs
STANDARD_TOKEN_PROGRAM_ID="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
TOKEN_2022_PROGRAM_ID="TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="[INFO] $1"
    echo -e "${BLUE}[INFO]${NC} $1"
    
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$OUTPUT_LOG_FILE"
    fi
    
    # Log to a global variable for potential reuse
    LAST_LOG_MESSAGE="$message"
}

log_success() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="[SUCCESS] $1"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$OUTPUT_LOG_FILE"
    fi
}

log_warning() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="[WARNING] $1"
    echo -e "${YELLOW}[WARNING]${NC} $1"
    
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$OUTPUT_LOG_FILE"
    fi
}

log_error() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="[ERROR] $1"
    echo -e "${RED}[ERROR]${NC} $1"
    
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$OUTPUT_LOG_FILE"
    fi
}

log_highlight() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local message="[HIGHLIGHT] $1"
    echo -e "${CYAN}[HIGHLIGHT]${NC} $1"
    
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$OUTPUT_LOG_FILE"
    fi
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        local message="[VERBOSE] $1"
        echo -e "${BLUE}[VERBOSE]${NC} $1"
        
        if [ -n "$OUTPUT_LOG_FILE" ]; then
            echo "[$timestamp] $message" >> "$OUTPUT_LOG_FILE"
        fi
    fi
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        local message="[DEBUG] $1"
        echo -e "\033[0;36m[DEBUG]${NC} $1"
        
        if [ -n "$OUTPUT_LOG_FILE" ]; then
            echo "[$timestamp] $message" >> "$OUTPUT_LOG_FILE"
        fi
    fi
}

# Help function
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Basic Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -k, --private-key KEY      Private key of the wallet (base58 encoded)"
    echo "  -f, --key-file FILE        Path to keypair JSON file"
    echo "  -w, --network NETWORK      Network to use (devnet, testnet, mainnet-beta) (default: $NETWORK)"
    echo "  -t, --token ADDRESS        Specific token mint address to burn"
    echo "  -a, --amount AMOUNT        Amount to burn (if not specified, will burn all)"
    echo "  --burn-all                 Burn all tokens in the wallet"
    echo "  --close-account            Close token account after burning (recovers SOL rent)"
    echo "  -y, --yes                  Skip confirmation prompts"
    echo "  --interactive              Force interactive mode (prompts for all inputs)"
    echo ""
    echo "Advanced Options:"
    echo "  --log-file FILE            Output log to specified file"
    echo "  --batch-file FILE          Read token addresses from a file (one per line)"
    echo "  --token-2022               Use Token 2022 program"
    echo "  --standard-token           Use Standard SPL Token program"
    echo "  --dry-run                  Simulate the operation without executing burns"
    echo "  --token-program-id ID      Specify a custom token program ID"
    echo "  --verbose                  Enable detailed logging"
    echo ""
    echo "Token Holder Operations:"
    echo "  --burn-holder-tokens       Burn tokens from all holders of the specified mint"
    echo "  --holder-address ADDR      Burn tokens from a specific holder address"
    echo "  --exempt-holders LIST      Comma-separated list of holder addresses to exempt"
    echo "  --max-batch-size NUM       Maximum number of burn operations per batch (default: 10)"
    echo "  --burn-percentage PCT      Percentage of tokens to burn (default: 100%)"
    echo ""
    echo "Authority Operations:"
    echo "  --revoke-authority         Revoke an authority from the token"
    echo "  --authority-type TYPE      Authority type to revoke (mint, freeze, close)"
    echo "  --disable-mint             Disable minting of new tokens"
    echo ""
    echo "Examples:"
    echo "  $0                                         # Full interactive mode"
    echo "  $0 --interactive                           # Force interactive mode"
    echo "  $0 -k YOUR_PRIVATE_KEY                     # Interactive with private key"
    echo "  $0 -f wallet.json -t TOKEN_ADDRESS         # Burn specific token"
    echo "  $0 -k KEY --burn-all -y                    # Burn all tokens without confirmation"
    echo "  $0 -f wallet.json -t TOKEN -a 1000         # Burn specific amount"
    echo "  $0 -f wallet.json --batch-file tokens.txt  # Burn tokens listed in file"
    echo "  $0 -f wallet.json -t TOKEN --burn-holder-tokens # Burn from all holders"
    echo ""
    echo "Networks:"
    echo "  devnet       - Development network"
    echo "  testnet      - Test network"
    echo "  mainnet-beta - Main production network"
    echo ""
    echo "Token Programs:"
    echo "  Standard Token: TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    echo "  Token 2022: TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    echo ""
    echo "SECURITY WARNING:"
    echo "  Never share your private key! This script handles sensitive data."
    echo "  Consider using a keypair file instead of command line private key."
    echo ""
}

# Validate inputs
validate_inputs() {
    # Check if either private key or key file is provided
    if [ -z "$PRIVATE_KEY" ] && [ -z "$PRIVATE_KEY_FILE" ]; then
        log_error "Either private key (-k) or key file (-f) must be provided"
        exit 1
    fi

    # Validate network
    if [[ ! "$NETWORK" =~ ^(devnet|testnet|mainnet-beta)$ ]]; then
        log_error "Network must be one of: devnet, testnet, mainnet-beta"
        exit 1
    fi

    # Validate burn amount if provided
    if [ -n "$BURN_AMOUNT" ]; then
        if ! [[ "$BURN_AMOUNT" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$BURN_AMOUNT <= 0" | bc -l) )); then
            log_error "Burn amount must be a positive number"
            exit 1
        fi
    fi

    # Validate token address if provided
    if [ -n "$TOKEN_ADDRESS" ]; then
        if [ ${#TOKEN_ADDRESS} -lt 32 ] || [ ${#TOKEN_ADDRESS} -gt 44 ]; then
            log_error "Token address appears to be invalid (wrong length)"
            log_info "Expected: 32-44 character base58 encoded address"
            log_info "Received: ${#TOKEN_ADDRESS} characters"
            exit 1
        fi
        
        # Additional validation - check if it's a valid base58 string
        if ! [[ "$TOKEN_ADDRESS" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]; then
            log_error "Token address contains invalid characters"
            log_info "Token addresses should only contain base58 characters (1-9, A-H, J-N, P-Z, a-k, m-z)"
            exit 1
        fi
    fi
    
    # Validate token program ID if provided
    if [ -n "$TOKEN_PROGRAM_ID" ]; then
        if [ ${#TOKEN_PROGRAM_ID} -lt 32 ] || [ ${#TOKEN_PROGRAM_ID} -gt 44 ]; then
            log_error "Token program ID appears to be invalid (wrong length)"
            log_info "Expected: 32-44 character base58 encoded address"
            exit 1
        fi
        
        if ! [[ "$TOKEN_PROGRAM_ID" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]; then
            log_error "Token program ID contains invalid characters"
            exit 1
        fi
    fi
    
    # Validate burn percentage
    if [ -n "$BURN_PERCENTAGE" ]; then
        if ! [[ "$BURN_PERCENTAGE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || 
           (( $(echo "$BURN_PERCENTAGE <= 0" | bc -l) )) || 
           (( $(echo "$BURN_PERCENTAGE > 100" | bc -l) )); then
            log_error "Burn percentage must be a number between 0.1 and 100"
            exit 1
        fi
    fi
    
    # Validate holder address if provided
    if [ -n "$HOLDER_ADDRESS" ]; then
        if [ ${#HOLDER_ADDRESS} -lt 32 ] || [ ${#HOLDER_ADDRESS} -gt 44 ]; then
            log_error "Holder address appears to be invalid (wrong length)"
            exit 1
        fi
    fi
    
    # Validate max tokens per batch
    if [ -n "$MAX_TOKENS_PER_BATCH" ]; then
        if ! [[ "$MAX_TOKENS_PER_BATCH" =~ ^[0-9]+$ ]] || [ "$MAX_TOKENS_PER_BATCH" -lt 1 ]; then
            log_error "Max tokens per batch must be a positive integer"
            exit 1
        fi
    fi
    
    # Validate authority type if provided
    if [ -n "$AUTHORITY_TYPE" ]; then
        if [[ ! "$AUTHORITY_TYPE" =~ ^(mint|freeze|close)$ ]]; then
            log_error "Authority type must be one of: mint, freeze, close"
            exit 1
        fi
    fi
    
    # Validate batch file if provided
    if [ -n "$BATCH_FILE" ]; then
        if [ ! -f "$BATCH_FILE" ]; then
            log_error "Batch file not found: $BATCH_FILE"
            exit 1
        fi
    fi
    
    # Validate log file if provided
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        # Check if directory exists
        LOG_DIR=$(dirname "$OUTPUT_LOG_FILE")
        if [ ! -d "$LOG_DIR" ] && [ "$LOG_DIR" != "." ]; then
            log_warning "Log directory does not exist: $LOG_DIR"
            log_info "Attempting to create log directory..."
            mkdir -p "$LOG_DIR" || {
                log_error "Failed to create log directory"
                exit 1
            }
        fi
        
        # Check if file is writable
        touch "$OUTPUT_LOG_FILE" 2>/dev/null || {
            log_error "Cannot write to log file: $OUTPUT_LOG_FILE"
            exit 1
        }
    fi
    
    # Validate conflicting options
    if [ "$BURN_ALL" = true ] && [ -n "$TOKEN_ADDRESS" ]; then
        log_warning "Both --burn-all and --token options provided. --burn-all will take precedence."
    fi
    
    if [ "$BURN_HOLDER_TOKENS" = true ] && [ -z "$TOKEN_ADDRESS" ]; then
        log_error "Token address (-t) must be provided when using --burn-holder-tokens"
        exit 1
    fi
    
    if [ "$REVOKE_AUTHORITY" = true ] && [ -z "$AUTHORITY_TYPE" ]; then
        log_error "Authority type must be specified when using --revoke-authority"
        exit 1
    fi
}

# Setup wallet from private key or file
setup_wallet() {
    if [ -n "$PRIVATE_KEY_FILE" ]; then
        if [ ! -f "$PRIVATE_KEY_FILE" ]; then
            log_error "Keypair file not found: $PRIVATE_KEY_FILE"
            exit 1
        fi
        log_info "Using keypair file: $PRIVATE_KEY_FILE"
        solana config set --keypair "$PRIVATE_KEY_FILE"
    else
        log_info "Setting up wallet with private key..."
        
        # Create a temporary keypair file from the private key
        local temp_keypair_file="temp_wallet_$(date +%s).json"
        
        # Try different approaches to handle the private key
        if [[ ${#PRIVATE_KEY} -eq 88 ]] && [[ "$PRIVATE_KEY" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]; then
            # This looks like a base58 private key
            log_info "Processing base58 private key..."
            
            # Method 1: Try using solana-keygen recover with stdin
            if echo "$PRIVATE_KEY" | solana-keygen recover --outfile "$temp_keypair_file" --no-bip39-passphrase prompt:// >/dev/null 2>&1; then
                log_success "Successfully created keypair from private key"
            else
                # Method 2: Try to create keypair file manually using a Python script if available
                if command -v python3 &> /dev/null; then
                    log_info "Attempting to create keypair file using Python..."
                    python3 -c "
import base58
import json
import sys

try:
    # Decode base58 private key
    private_key = base58.b58decode('$PRIVATE_KEY')
    
    # Convert to list format expected by Solana
    keypair_data = list(private_key)
    
    # Write to file
    with open('$temp_keypair_file', 'w') as f:
        json.dump(keypair_data, f)
    
    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        log_success "Created keypair file using Python"
                    else
                        log_error "Failed to process private key with Python"
                        log_error "Please ensure your private key is in the correct format"
                        log_info "Alternative: Use a keypair JSON file with -f option"
                        exit 1
                    fi
                else
                    log_error "Unable to process private key format"
                    log_error "This script requires either:"
                    log_error "1. A valid seed phrase (12+ words), or"
                    log_error "2. Python3 with base58 library for base58 private keys, or"
                    log_error "3. A keypair JSON file (use -f option)"
                    log_info "To install required Python library: pip3 install base58"
                    exit 1
                fi
            fi
        elif [[ "$PRIVATE_KEY" =~ ^[a-zA-Z\ ]+$ ]] && [ $(echo "$PRIVATE_KEY" | wc -w) -ge 12 ]; then
            # This looks like a seed phrase
            log_info "Processing seed phrase..."
            if echo "$PRIVATE_KEY" | solana-keygen recover --outfile "$temp_keypair_file" prompt:// >/dev/null 2>&1; then
                log_success "Successfully created keypair from seed phrase"
            else
                log_error "Failed to create keypair from seed phrase"
                log_error "Please check your seed phrase format"
                exit 1
            fi
        else
            log_error "Unrecognized private key format"
            log_error "Supported formats:"
            log_error "- Base58 encoded private key (88 characters)"
            log_error "- Seed phrase (12+ words separated by spaces)"
            log_info "Alternative: Use a keypair JSON file with -f option"
            exit 1
        fi
        
        # Set the keypair file for solana config
        solana config set --keypair "$temp_keypair_file"
        
        # Schedule cleanup
        trap "rm -f $temp_keypair_file" EXIT
        
        log_success "Private key configured successfully"
    fi
    
    # Get wallet address
    WALLET_ADDRESS=$(solana address)
    log_success "Wallet configured: $WALLET_ADDRESS"
}

# List all token accounts
list_token_accounts() {
    log_info "Fetching token accounts..."
    
    # Get token accounts with balances
    TOKEN_ACCOUNTS=$(spl-token accounts --output json 2>/dev/null || echo "[]")
    
    if [ "$TOKEN_ACCOUNTS" = "[]" ] || [ -z "$TOKEN_ACCOUNTS" ]; then
        log_warning "No token accounts found in this wallet"
        return 1
    fi
    
    echo ""
    log_highlight "=== TOKEN ACCOUNTS ==="
    
    # Parse and display token accounts
    if command -v jq &> /dev/null; then
        echo "$TOKEN_ACCOUNTS" | jq -r '.accounts[] | select(.tokenAmount.uiAmount > 0) | "\(.mint) | \(.tokenAmount.uiAmount) \(.symbol // "Unknown")"' | nl -w2 -s'. '
    else
        # Fallback parsing without jq
        spl-token accounts | grep -E "Token|Balance" | paste - - | nl -w2 -s'. '
    fi
    
    echo ""
    return 0
}

# Interactive token selection
select_token_interactive() {
    if ! list_token_accounts; then
        return 1
    fi
    
    echo "Enter the number of the token you want to burn (or 'q' to quit):"
    read -r selection
    
    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
    
    # Validate selection is a number
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        log_error "Invalid selection. Please enter a number."
        return 1
    fi
    
    # Create a filtered array of only tokens with positive balance (matching what's displayed)
    if command -v jq &> /dev/null; then
        # Get the filtered array of tokens with positive balance
        POSITIVE_BALANCE_TOKENS=$(echo "$TOKEN_ACCOUNTS" | jq -c '[.accounts[] | select(.tokenAmount.uiAmount > 0)]')
        
        # Get the selected token from the filtered array
        TOKEN_ADDRESS=$(echo "$POSITIVE_BALANCE_TOKENS" | jq -r ".[$((selection-1))].mint" 2>/dev/null)
        TOKEN_BALANCE=$(echo "$POSITIVE_BALANCE_TOKENS" | jq -r ".[$((selection-1))].tokenAmount.uiAmount" 2>/dev/null)
        TOKEN_SYMBOL=$(echo "$POSITIVE_BALANCE_TOKENS" | jq -r ".[$((selection-1))].symbol // \"Unknown\"" 2>/dev/null)
    else
        # Fallback method - get only positive balance tokens
        TOKEN_INFO=$(spl-token accounts | grep -E "Token|Balance" | paste - - | awk '$4 > 0' | sed -n "${selection}p")
        TOKEN_ADDRESS=$(echo "$TOKEN_INFO" | awk '{print $2}')
        TOKEN_BALANCE=$(echo "$TOKEN_INFO" | awk '{print $4}')
        TOKEN_SYMBOL="Unknown"
    fi
    
    if [ -z "$TOKEN_ADDRESS" ] || [ "$TOKEN_ADDRESS" = "null" ]; then
        log_error "Invalid selection or token not found"
        return 1
    fi
    
    log_success "Selected token: $TOKEN_SYMBOL ($TOKEN_ADDRESS)"
    log_info "Current balance: $TOKEN_BALANCE"
    
    return 0
}

# Get token info
get_token_info() {
    log_info "Getting token information for: $TOKEN_ADDRESS"
    
    # First, check if we have any token accounts at all
    ALL_TOKEN_ACCOUNTS=$(spl-token accounts --output json 2>/dev/null || echo "[]")
    
    if [ "$ALL_TOKEN_ACCOUNTS" = "[]" ] || [ -z "$ALL_TOKEN_ACCOUNTS" ]; then
        log_error "No token accounts found in this wallet"
        log_info "This wallet doesn't hold any tokens"
        return 1
    fi
    
    # Get token account info for the specific token
    TOKEN_ACCOUNT=$(spl-token accounts "$TOKEN_ADDRESS" --output json 2>/dev/null | jq -r '.accounts[0].address' 2>/dev/null || echo "")
    
    if [ -z "$TOKEN_ACCOUNT" ] || [ "$TOKEN_ACCOUNT" = "null" ]; then
        log_error "No token account found for mint address: $TOKEN_ADDRESS"
        log_info "This wallet doesn't hold any tokens of this type"
        
        # Show available tokens
        log_info "Available tokens in this wallet:"
        if command -v jq &> /dev/null; then
            POSITIVE_BALANCE_TOKENS=$(echo "$ALL_TOKEN_ACCOUNTS" | jq -r '.accounts[] | select(.tokenAmount.uiAmount > 0) | "  • \(.mint) (Balance: \(.tokenAmount.uiAmount) \(.symbol // "Unknown"))"' 2>/dev/null)
            if [ -n "$POSITIVE_BALANCE_TOKENS" ]; then
                echo "$POSITIVE_BALANCE_TOKENS"
            else
                echo "  No tokens with positive balance found"
                log_info "All token accounts (including zero balance):"
                echo "$ALL_TOKEN_ACCOUNTS" | jq -r '.accounts[] | "  • \(.mint) (Balance: \(.tokenAmount.uiAmount) \(.symbol // "Unknown"))"' 2>/dev/null || echo "  No token accounts found"
            fi
        else
            ACCOUNT_LIST=$(spl-token accounts | grep -E "Token|Balance" | paste - - | head -5)
            if [ -n "$ACCOUNT_LIST" ]; then
                echo "$ACCOUNT_LIST" | while read line; do
                    echo "  • $line"
                done
            else
                echo "  No token accounts found"
            fi
        fi
        
        return 1
    fi
    
    # Get current balance
    CURRENT_BALANCE=$(spl-token balance "$TOKEN_ADDRESS" 2>/dev/null || echo "0")
    
    if [ "$CURRENT_BALANCE" = "0" ] || [ "$CURRENT_BALANCE" = "0.0" ]; then
        log_warning "Token balance is 0. Nothing to burn."
        log_info "This token account exists but has no balance"
        return 1
    fi
    
    log_success "Token account found: $TOKEN_ACCOUNT"
    log_info "Current balance: $CURRENT_BALANCE"
    
    return 0
}

# Determine burn amount
determine_burn_amount() {
    if [ -n "$BURN_AMOUNT" ]; then
        # Validate that burn amount doesn't exceed balance
        if command -v bc &> /dev/null; then
            if (( $(echo "$BURN_AMOUNT > $CURRENT_BALANCE" | bc -l) )); then
                log_error "Burn amount ($BURN_AMOUNT) exceeds current balance ($CURRENT_BALANCE)"
                return 1
            fi
        fi
        log_info "Will burn: $BURN_AMOUNT tokens"
    else
        # Burn all tokens
        BURN_AMOUNT="$CURRENT_BALANCE"
        log_info "Will burn all tokens: $BURN_AMOUNT"
    fi
    
    return 0
}

# Confirm burn operation
confirm_burn() {
    if [ "$SKIP_CONFIRMATION" = true ]; then
        return 0
    fi
    
    echo ""
    log_warning "=== BURN CONFIRMATION ==="
    echo "Wallet: $WALLET_ADDRESS"
    echo "Network: $NETWORK"
    echo "Token: $TOKEN_ADDRESS"
    echo "Amount to burn: $BURN_AMOUNT"
    if [ "$CLOSE_ACCOUNT" = true ]; then
        echo "Close account: YES (will recover SOL rent)"
    else
        echo "Close account: NO"
    fi
    echo ""
    log_error "WARNING: This action is IRREVERSIBLE! Tokens will be permanently destroyed."
    echo ""
    echo "Type 'BURN' to confirm or anything else to cancel:"
    read -r confirmation
    
    if [ "$confirmation" != "BURN" ]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
    
    return 0
}

# Burn tokens
burn_tokens() {
    log_info "Starting token burn process..."
    
    # Burn the tokens using the token account address, not the mint address
    log_info "Burning $BURN_AMOUNT tokens..."
    if spl-token burn "$TOKEN_ACCOUNT" "$BURN_AMOUNT"; then
        log_success "Successfully burned $BURN_AMOUNT tokens!"
    else
        log_error "Failed to burn tokens"
        return 1
    fi
    
    # Close account if requested
    if [ "$CLOSE_ACCOUNT" = true ]; then
        log_info "Closing token account to recover SOL rent..."
        if spl-token close "$TOKEN_ACCOUNT"; then
            log_success "Token account closed successfully! SOL rent recovered."
        else
            log_warning "Failed to close token account, but tokens were burned successfully"
        fi
    fi
    
    return 0
}

# Burn all tokens in wallet
burn_all_tokens() {
    log_info "Burning all tokens in wallet..."
    
    if ! list_token_accounts; then
        log_info "No tokens to burn"
        return 0
    fi
    
    # Confirm burn all
    if [ "$SKIP_CONFIRMATION" = false ]; then
        echo ""
        log_warning "=== BURN ALL CONFIRMATION ==="
        echo "Wallet: $WALLET_ADDRESS"
        echo "Network: $NETWORK"
        echo ""
        log_error "WARNING: This will burn ALL tokens in your wallet! This is IRREVERSIBLE!"
        echo ""
        echo "Type 'BURN ALL' to confirm or anything else to cancel:"
        read -r confirmation
        
        if [ "$confirmation" != "BURN ALL" ]; then
            log_info "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Get all token mints with balances > 0
    if command -v jq &> /dev/null; then
        TOKEN_MINTS=$(echo "$TOKEN_ACCOUNTS" | jq -r '.accounts[] | select(.tokenAmount.uiAmount > 0) | .mint')
    else
        log_error "jq is required for burn-all functionality. Please install jq or burn tokens individually."
        return 1
    fi
    
    if [ -z "$TOKEN_MINTS" ]; then
        log_info "No tokens with positive balance found"
        return 0
    fi
    
    # Burn each token
    echo "$TOKEN_MINTS" | while read -r mint; do
        if [ -n "$mint" ]; then
            log_info "Processing token: $mint"
            TOKEN_ADDRESS="$mint"
            
            if get_token_info && determine_burn_amount; then
                log_info "Burning $BURN_AMOUNT tokens of $TOKEN_ADDRESS..."
                if spl-token burn "$TOKEN_ACCOUNT" "$BURN_AMOUNT"; then
                    log_success "Burned $BURN_AMOUNT tokens of $TOKEN_ADDRESS"
                    
                    if [ "$CLOSE_ACCOUNT" = true ]; then
                        if spl-token close "$TOKEN_ACCOUNT"; then
                            log_success "Closed account for $TOKEN_ADDRESS"
                        fi
                    fi
                else
                    log_error "Failed to burn tokens of $TOKEN_ADDRESS"
                fi
            fi
        fi
    done
    
    log_success "Burn all operation completed!"
    return 0
}

# Interactive input functions
get_private_key_interactive() {
    if [ -z "$PRIVATE_KEY" ] && [ -z "$PRIVATE_KEY_FILE" ]; then
        echo ""
        log_info "=== WALLET SETUP ==="
        echo "Choose wallet input method:"
        echo "1. Enter private key directly"
        echo "2. Use keypair file"
        echo ""
        echo -n "Select option (1 or 2): "
        read -r wallet_option
        
        case $wallet_option in
            1)
                echo ""
                log_info "Choose private key input method:"
                echo "a. Hidden input (recommended - private key won't be visible)"
                echo "b. Visible input (less secure)"
                echo ""
                echo -n "Select method (a or b): "
                read -r input_method
                
                case $input_method in
                    a|A)
                        echo ""
                        log_info "Enter your private key (input will be hidden):"
                        echo -n "Private key: "
                        read -s PRIVATE_KEY
                        echo ""  # New line after hidden input
                        ;;
                    b|B)
                        echo ""
                        log_warning "SECURITY WARNING: Private key will be visible on screen!"
                        echo -n "Enter your private key (base58 encoded): "
                        read -r PRIVATE_KEY
                        ;;
                    *)
                        log_error "Invalid method. Using hidden input as default."
                        echo -n "Private key (hidden): "
                        read -s PRIVATE_KEY
                        echo ""
                        ;;
                esac
                
                if [ -z "$PRIVATE_KEY" ]; then
                    log_error "Private key cannot be empty"
                    exit 1
                fi
                ;;
            2)
                echo -n "Enter path to keypair file: "
                read -r PRIVATE_KEY_FILE
                if [ -z "$PRIVATE_KEY_FILE" ]; then
                    log_error "Keypair file path cannot be empty"
                    exit 1
                fi
                ;;
            *)
                log_error "Invalid option. Please select 1 or 2."
                exit 1
                ;;
        esac
    fi
}

get_network_interactive() {
    # Only show interactive network selection if network wasn't set via command line
    # We'll track this with a flag
    if [ "$NETWORK_SET_BY_USER" != "true" ]; then
        echo ""
        log_info "=== NETWORK SELECTION ==="
        echo "Select network:"
        echo "1. devnet (default)"
        echo "2. testnet"
        echo "3. mainnet-beta"
        echo ""
        echo -n "Select network (1-3, or press Enter for devnet): "
        read -r network_option
        
        case $network_option in
            ""|1)
                NETWORK="devnet"
                ;;
            2)
                NETWORK="testnet"
                ;;
            3)
                NETWORK="mainnet-beta"
                log_warning "WARNING: You selected mainnet-beta! Real tokens will be burned!"
                ;;
            *)
                log_error "Invalid option. Using devnet as default."
                NETWORK="devnet"
                ;;
        esac
    fi
}

get_token_interactive() {
    if [ -z "$TOKEN_ADDRESS" ] && [ "$BURN_ALL" = false ]; then
        echo ""
        log_info "=== TOKEN SELECTION ==="
        echo "Choose token selection method:"
        echo "1. Select from wallet tokens (recommended)"
        echo "2. Enter token mint address manually"
        echo "3. Burn all tokens in wallet"
        echo ""
        echo -n "Select option (1-3): "
        read -r token_option
        
        case $token_option in
            1)
                # This will be handled by select_token_interactive function
                return 0
                ;;
            2)
                echo -n "Enter token mint address: "
                read -r TOKEN_ADDRESS
                if [ -z "$TOKEN_ADDRESS" ]; then
                    log_error "Token address cannot be empty"
                    exit 1
                fi
                ;;
            3)
                BURN_ALL=true
                ;;
            *)
                log_error "Invalid option. Please select 1, 2, or 3."
                exit 1
                ;;
        esac
    fi
}

get_burn_amount_interactive() {
    if [ -z "$BURN_AMOUNT" ] && [ "$BURN_ALL" = false ] && [ -n "$TOKEN_ADDRESS" ]; then
        echo ""
        log_info "=== BURN AMOUNT ==="
        echo "Current token balance: $CURRENT_BALANCE"
        echo ""
        echo "Choose burn amount:"
        echo "1. Burn all tokens ($CURRENT_BALANCE)"
        echo "2. Burn specific amount"
        echo ""
        echo -n "Select option (1 or 2): "
        read -r amount_option
        
        case $amount_option in
            1)
                BURN_AMOUNT="$CURRENT_BALANCE"
                ;;
            2)
                echo -n "Enter amount to burn (max: $CURRENT_BALANCE): "
                read -r BURN_AMOUNT
                if [ -z "$BURN_AMOUNT" ]; then
                    log_error "Burn amount cannot be empty"
                    exit 1
                fi
                ;;
            *)
                log_error "Invalid option. Please select 1 or 2."
                exit 1
                ;;
        esac
    fi
}

get_close_account_interactive() {
    if [ "$CLOSE_ACCOUNT" = false ] && [ "$BURN_ALL" = false ]; then
        echo ""
        log_info "=== ACCOUNT CLOSURE ==="
        echo "Do you want to close the token account after burning?"
        echo "(This will recover the SOL rent ~0.00203 SOL)"
        echo ""
        echo -n "Close account? (y/N): "
        read -r close_option
        
        case $close_option in
            y|Y|yes|YES)
                CLOSE_ACCOUNT=true
                log_info "Token account will be closed after burning"
                ;;
            *)
                CLOSE_ACCOUNT=false
                log_info "Token account will remain open"
                ;;
        esac
    fi
}

# Process a batch file of token addresses
process_batch_file() {
    log_info "Processing batch file: $BATCH_FILE"
    
    # Check if the file exists
    if [ ! -f "$BATCH_FILE" ]; then
        log_error "Batch file not found: $BATCH_FILE"
        return 1
    fi
    
    # Count lines in the file (excluding comments and empty lines)
    local total_lines=$(grep -v "^#" "$BATCH_FILE" | grep -v "^$" | wc -l)
    log_info "Found $total_lines token addresses in batch file"
    
    if [ "$total_lines" -eq 0 ]; then
        log_warning "Batch file contains no valid token addresses"
        return 1
    fi
    
    # Confirm batch operation
    if [ "$SKIP_CONFIRMATION" = false ]; then
        echo ""
        log_warning "=== BATCH BURN CONFIRMATION ==="
        echo "Wallet: $WALLET_ADDRESS"
        echo "Network: $NETWORK"
        echo "Total tokens to process: $total_lines"
        if [ "$DRY_RUN" = true ]; then
            echo "Mode: DRY RUN (no actual burns)"
        fi
        echo ""
        log_error "WARNING: This will process multiple token operations! Review the batch file carefully."
        echo ""
        echo "Type 'BATCH' to confirm or anything else to cancel:"
        read -r confirmation
        
        if [ "$confirmation" != "BATCH" ]; then
            log_info "Batch operation cancelled by user"
            return 1
        fi
    fi
    
    # Initialize counters
    local success_count=0
    local error_count=0
    local current=0
    
    # Process each line in the batch file
    while IFS=',' read -r token_addr burn_amt close_flag extra_data; do
        # Skip comments and empty lines
        if [[ "$token_addr" =~ ^#.*$ ]] || [ -z "$token_addr" ]; then
            continue
        fi
        
        # Increment counter
        ((current++))
        
        # Trim whitespace
        token_addr=$(echo "$token_addr" | tr -d '[:space:]')
        
        log_info "[$current/$total_lines] Processing token: $token_addr"
        
        # Set the current token address
        TOKEN_ADDRESS="$token_addr"
        
        # Set burn amount if provided in the file
        if [ -n "$burn_amt" ] && [ "$burn_amt" != "-" ]; then
            BURN_AMOUNT="$burn_amt"
            log_verbose "Using amount from batch file: $BURN_AMOUNT"
        else
            BURN_AMOUNT=""
        fi
        
        # Set close flag if provided in the file
        if [ "$close_flag" = "close" ] || [ "$close_flag" = "true" ] || [ "$close_flag" = "yes" ]; then
            CLOSE_ACCOUNT=true
            log_verbose "Will close account after burning"
        else
            CLOSE_ACCOUNT=false
        fi
        
        # Process this token
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY RUN: Would burn token $TOKEN_ADDRESS"
            ((success_count++))
        else
            if get_token_info && determine_burn_amount; then
                log_info "Burning $BURN_AMOUNT tokens of $TOKEN_ADDRESS..."
                
                if spl-token burn "$TOKEN_ACCOUNT" "$BURN_AMOUNT"; then
                    log_success "Burned $BURN_AMOUNT tokens of $TOKEN_ADDRESS"
                    ((success_count++))
                    
                    if [ "$CLOSE_ACCOUNT" = true ]; then
                        if spl-token close "$TOKEN_ACCOUNT"; then
                            log_success "Closed account for $TOKEN_ADDRESS"
                        else
                            log_warning "Failed to close account for $TOKEN_ADDRESS"
                        fi
                    fi
                else
                    log_error "Failed to burn tokens of $TOKEN_ADDRESS"
                    ((error_count++))
                fi
            else
                log_warning "Skipping $TOKEN_ADDRESS (not found or zero balance)"
                ((error_count++))
            fi
        fi
        
        # Add a short delay between operations
        if [ $current -lt $total_lines ]; then
            sleep 0.5
        fi
        
    done < "$BATCH_FILE"
    
    # Summary
    echo ""
    log_highlight "=== BATCH PROCESSING SUMMARY ==="
    echo "Total tokens processed: $total_lines"
    echo "Successful operations: $success_count"
    echo "Failed operations: $error_count"
    
    if [ "$success_count" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Detect which token program a token is using
detect_token_program() {
    local mint_address="$1"
    log_verbose "Detecting token program for mint: $mint_address"
    
    if [ -z "$mint_address" ]; then
        log_error "No token address provided for program detection"
        return 1
    fi
    
    # Attempt to get token info
    local token_info=$(solana account "$mint_address" --output json 2>/dev/null)
    if [ -z "$token_info" ]; then
        log_error "Failed to retrieve token info for $mint_address"
        return 1
    fi
    
    # Extract program ID
    local program_id=""
    if command -v jq &> /dev/null; then
        program_id=$(echo "$token_info" | jq -r '.owner' 2>/dev/null)
    else
        # Fallback method if jq is not available
        program_id=$(echo "$token_info" | grep -o '"owner": "[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -z "$program_id" ]; then
        log_error "Could not determine token program ID"
        return 1
    fi
    
    log_verbose "Detected token program: $program_id"
    
    # Set the token program ID based on detection
    TOKEN_PROGRAM_ID="$program_id"
    
    # Set the USE_TOKEN_2022 flag based on detection
    if [ "$program_id" = "$TOKEN_2022_PROGRAM_ID" ]; then
        USE_TOKEN_2022=true
        log_info "Token $mint_address uses Token 2022 program"
    else
        USE_TOKEN_2022=false
        log_info "Token $mint_address uses Standard SPL Token program"
    fi
    
    return 0
}

# Revoke or disable an authority
manage_token_authority() {
    if [ "$REVOKE_AUTHORITY" = true ] || [ "$DISABLE_MINT" = true ]; then
        local action="revoke"
        local authority_type=""
        
        if [ "$DISABLE_MINT" = true ]; then
            authority_type="mint"
            log_info "Disabling mint authority for token: $TOKEN_ADDRESS"
        else
            authority_type="$AUTHORITY_TYPE"
            log_info "Revoking $authority_type authority for token: $TOKEN_ADDRESS"
        fi
        
        # Confirm operation
        if [ "$SKIP_CONFIRMATION" = false ]; then
            echo ""
            log_warning "=== AUTHORITY MANAGEMENT CONFIRMATION ==="
            echo "Token: $TOKEN_ADDRESS"
            echo "Action: ${action^} $authority_type authority"
            echo ""
            log_error "WARNING: This action is IRREVERSIBLE!"
            echo ""
            echo "Type 'CONFIRM' to proceed or anything else to cancel:"
            read -r confirmation
            
            if [ "$confirmation" != "CONFIRM" ]; then
                log_info "Operation cancelled by user"
                return 1
            fi
        fi
        
        # Execute the authority change
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY RUN: Would $action $authority_type authority for $TOKEN_ADDRESS"
            return 0
        else
            if spl-token authorize "$TOKEN_ADDRESS" "$authority_type" --disable; then
                log_success "Successfully ${action}d $authority_type authority for $TOKEN_ADDRESS"
                return 0
            else
                log_error "Failed to $action $authority_type authority"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Burn tokens from specified holders
burn_holder_tokens() {
    if [ "$BURN_HOLDER_TOKENS" = true ]; then
        log_info "Finding holders of token: $TOKEN_ADDRESS"
        
        # Get all token accounts for this mint
        log_verbose "Querying token accounts for mint $TOKEN_ADDRESS"
        local token_accounts_json=$(spl-token accounts "$TOKEN_ADDRESS" --output json --all 2>/dev/null)
        
        if [ -z "$token_accounts_json" ] || [ "$token_accounts_json" = "[]" ]; then
            log_error "No token accounts found for mint: $TOKEN_ADDRESS"
            return 1
        fi
        
        # Parse token accounts
        local holder_count=0
        local holders=""
        
        if command -v jq &> /dev/null; then
            holders=$(echo "$token_accounts_json" | jq -r '.accounts[] | select(.tokenAmount.uiAmount > 0) | "\(.address),\(.owner),\(.tokenAmount.uiAmount)"')
            holder_count=$(echo "$holders" | wc -l)
        else
            log_error "jq is required for holder token operations"
            return 1
        fi
        
        if [ -z "$holders" ] || [ "$holder_count" -eq 0 ]; then
            log_warning "No holders with positive balance found for token: $TOKEN_ADDRESS"
            return 1
        fi
        
        log_info "Found $holder_count holders with positive balance"
        
        # Confirm holder burn operation
        if [ "$SKIP_CONFIRMATION" = false ]; then
            echo ""
            log_warning "=== HOLDER TOKEN BURN CONFIRMATION ==="
            echo "Token: $TOKEN_ADDRESS"
            echo "Total holders: $holder_count"
            echo "Burn percentage: $BURN_PERCENTAGE%"
            if [ -n "$EXEMPT_HOLDER_LIST" ]; then
                echo "Exempt holders: $EXEMPT_HOLDER_LIST"
            fi
            echo ""
            log_error "WARNING: This will burn tokens from multiple holders!"
            echo ""
            echo "Type 'BURN HOLDERS' to confirm or anything else to cancel:"
            read -r confirmation
            
            if [ "$confirmation" != "BURN HOLDERS" ]; then
                log_info "Operation cancelled by user"
                return 1
            fi
        fi
        
        # Process holder tokens
        local processed=0
        local success=0
        local failed=0
        local exempt=0
        local exempt_holders=()
        
        # Parse exempt holders list if provided
        if [ -n "$EXEMPT_HOLDER_LIST" ]; then
            IFS=',' read -ra exempt_holders <<< "$EXEMPT_HOLDER_LIST"
        fi
        
        # Process each holder
        echo "$holders" | while IFS=',' read -r account_address owner_address balance; do
            ((processed++))
            
            # Check if holder is exempt
            local is_exempt=false
            for exempt_addr in "${exempt_holders[@]}"; do
                if [ "$owner_address" = "$exempt_addr" ]; then
                    is_exempt=true
                    ((exempt++))
                    log_verbose "Skipping exempt holder: $owner_address"
                    break
                fi
            done
            
            # Skip exempt holders
            if [ "$is_exempt" = true ]; then
                continue
            fi
            
            # Calculate amount to burn based on percentage
            local burn_amount=0
            if [ "$BURN_PERCENTAGE" = "100" ]; then
                burn_amount="$balance"
            else
                burn_amount=$(echo "scale=9; $balance * $BURN_PERCENTAGE / 100" | bc)
            fi
            
            log_info "[$processed/$holder_count] Processing holder $owner_address with balance $balance, burning $burn_amount"
            
            # Burn tokens
            if [ "$DRY_RUN" = true ]; then
                log_info "DRY RUN: Would burn $burn_amount tokens from account $account_address (owner: $owner_address)"
                ((success++))
            else
                if spl-token burn "$account_address" "$burn_amount" --owner "$MINT_AUTHORITY_ADDRESS"; then
                    log_success "Burned $burn_amount tokens from account $account_address"
                    ((success++))
                else
                    log_error "Failed to burn tokens from account $account_address"
                    ((failed++))
                fi
            fi
        done
        
        # Summary
        echo ""
        log_highlight "=== HOLDER BURN SUMMARY ==="
        echo "Total holders processed: $processed"
        echo "Successful burns: $success"
        echo "Failed burns: $failed"
        echo "Exempt holders: $exempt"
        
        if [ "$success" -gt 0 ]; then
            return 0
        else
            return 1
        fi
    fi
    
    return 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -k|--private-key)
            PRIVATE_KEY="$2"
            shift 2
            ;;
        -f|--key-file)
            PRIVATE_KEY_FILE="$2"
            shift 2
            ;;
        -w|--network)
            NETWORK="$2"
            NETWORK_SET_BY_USER="true"
            shift 2
            ;;
        -t|--token)
            TOKEN_ADDRESS="$2"
            shift 2
            ;;
        -a|--amount)
            BURN_AMOUNT="$2"
            shift 2
            ;;
        --burn-all)
            BURN_ALL=true
            shift
            ;;
        --close-account)
            CLOSE_ACCOUNT=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --interactive)
            # Force interactive mode even if some parameters are provided
            PRIVATE_KEY=""
            PRIVATE_KEY_FILE=""
            TOKEN_ADDRESS=""
            BURN_AMOUNT=""
            BURN_ALL=false
            shift
            ;;
        # New options
        --log-file)
            OUTPUT_LOG_FILE="$2"
            shift 2
            ;;
        --batch-file)
            BATCH_FILE="$2"
            shift 2
            ;;
        --token-2022)
            USE_TOKEN_2022=true
            AUTO_DETECT_PROGRAM=false
            shift
            ;;
        --standard-token)
            USE_TOKEN_2022=false
            AUTO_DETECT_PROGRAM=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --token-program-id)
            TOKEN_PROGRAM_ID="$2"
            AUTO_DETECT_PROGRAM=false
            shift 2
            ;;
        --burn-holder-tokens)
            BURN_HOLDER_TOKENS=true
            shift
            ;;
        --holder-address)
            HOLDER_ADDRESS="$2"
            shift 2
            ;;
        --exempt-holders)
            EXEMPT_HOLDER_LIST="$2"
            shift 2
            ;;
        --max-batch-size)
            MAX_TOKENS_PER_BATCH="$2"
            shift 2
            ;;
        --burn-percentage)
            BURN_PERCENTAGE="$2"
            shift 2
            ;;
        --revoke-authority)
            REVOKE_AUTHORITY=true
            shift
            ;;
        --authority-type)
            AUTHORITY_TYPE="$2"
            shift 2
            ;;
        --disable-mint)
            DISABLE_MINT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting Solana Token Burn Script"
    
    # Start logging if specified
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        log_info "Logging enabled to file: $OUTPUT_LOG_FILE"
        # Add header to log file
        echo "========================================" > "$OUTPUT_LOG_FILE"
        echo "Solana Token Burn Script - $(date)" >> "$OUTPUT_LOG_FILE"
        echo "========================================" >> "$OUTPUT_LOG_FILE"
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_verbose "Verbose logging enabled"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No actual operations will be performed"
    fi
    
    # Interactive input collection
    get_private_key_interactive
    get_network_interactive
    
    # Validate inputs
    validate_inputs
    
    # Check if required tools are installed
    if ! command -v solana &> /dev/null; then
        log_error "Solana CLI not found. Please install Solana CLI first."
        exit 1
    fi
    
    if ! command -v spl-token &> /dev/null; then
        log_error "spl-token command not found. Please install SPL Token CLI."
        exit 1
    fi
    
    # Set network
    log_info "Configuring Solana to use $NETWORK..."
    solana config set --url "$NETWORK"
    
    # Setup wallet
    setup_wallet
    
    # Check SOL balance
    SOL_BALANCE=$(solana balance)
    log_info "SOL balance: $SOL_BALANCE"
    
    # Process batch file if provided
    if [ -n "$BATCH_FILE" ]; then
        log_info "Batch file mode: Processing tokens from $BATCH_FILE"
        process_batch_file
        log_success "Batch processing completed"
        exit 0
    fi
    
    # Interactive token selection
    get_token_interactive
    
    # Auto-detect token program if needed
    if [ -n "$TOKEN_ADDRESS" ] && [ "$AUTO_DETECT_PROGRAM" = true ]; then
        log_info "Auto-detecting token program..."
        detect_token_program "$TOKEN_ADDRESS"
    fi
    
    # Handle authority management
    if [ "$REVOKE_AUTHORITY" = true ] || [ "$DISABLE_MINT" = true ]; then
        manage_token_authority
        exit $?
    fi
    
    # Handle holder token burning
    if [ "$BURN_HOLDER_TOKENS" = true ]; then
        burn_holder_tokens
        exit $?
    fi
    
    if [ "$BURN_ALL" = true ]; then
        # Burn all tokens
        burn_all_tokens
    elif [ -n "$TOKEN_ADDRESS" ]; then
        # Burn specific token
        if get_token_info; then
            get_burn_amount_interactive
            get_close_account_interactive
            if determine_burn_amount && confirm_burn; then
                burn_tokens
            fi
        else
            log_warning "The specified token was not found in this wallet"
            echo ""
            echo "Would you like to:"
            echo "1. Select a different token from your wallet"
            echo "2. Exit"
            echo ""
            echo -n "Choose option (1 or 2): "
            read -r choice
            
            case $choice in
                1)
                    log_info "Switching to interactive token selection..."
                    if select_token_interactive && get_token_info; then
                        get_burn_amount_interactive
                        get_close_account_interactive
                        if determine_burn_amount && confirm_burn; then
                            burn_tokens
                        fi
                    fi
                    ;;
                *)
                    log_info "Exiting..."
                    exit 0
                    ;;
            esac
        fi
    else
        # Interactive mode - select from wallet
        log_info "Interactive mode: Select token to burn"
        if select_token_interactive && get_token_info; then
            get_burn_amount_interactive
            get_close_account_interactive
            if determine_burn_amount && confirm_burn; then
                burn_tokens
            fi
        else
            log_warning "No tokens available to burn or operation cancelled"
        fi
    fi
    
    log_success "Script completed!"
    
    if [ -n "$OUTPUT_LOG_FILE" ]; then
        log_info "Log file saved to: $OUTPUT_LOG_FILE"
    fi
}

# Run main function
main 