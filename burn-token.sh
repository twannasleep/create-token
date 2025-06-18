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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_highlight() {
    echo -e "${CYAN}[HIGHLIGHT]${NC} $1"
}

# Help function
function show_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
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
    echo "Examples:"
    echo "  $0                                         # Full interactive mode"
    echo "  $0 --interactive                           # Force interactive mode"
    echo "  $0 -k YOUR_PRIVATE_KEY                     # Interactive with private key"
    echo "  $0 -f wallet.json -t TOKEN_ADDRESS         # Burn specific token"
    echo "  $0 -k KEY --burn-all -y                    # Burn all tokens without confirmation"
    echo "  $0 -f wallet.json -t TOKEN -a 1000         # Burn specific amount"
    echo ""
    echo "Networks:"
    echo "  devnet       - Development network"
    echo "  testnet      - Test network"
    echo "  mainnet-beta - Main production network"
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
    
    # Interactive token selection
    get_token_interactive
    
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
}

# Run main function
main 