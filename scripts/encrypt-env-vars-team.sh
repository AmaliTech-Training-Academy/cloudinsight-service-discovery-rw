#!/bin/bash

# Multi-Developer Environment Variables Encryption Script
# Uses embedded team public key for secure distribution
# Only team lead with private key can decrypt

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# TEAM PUBLIC KEY - Safe to distribute with this script
TEAM_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxR9Cqvsw1ai1f9gCcOSL
LP7fwwwBMMKHRvwTLaGEMnSymGEPLuo/MU4RkCjTNsT7v7tSOJuTBx4q/Lno5BF4
PcIPEOocqtg/YyR9lcao9FmDC1cGcdc7zskk9KBOfmjrICUYrRO/RL/8q6xl3t47
pol8xLvYySSA/4kTu3enLc34Pholp+mwIajdSwzjV3mhT4c1A5FY7evAgMZlbTdg
0BMbzw4UDqpdmRne4Uz2SHXyBSnFOnWgyz+pnzD1e61841Xcjhgu+caTjNUT6IU3
g//cGIeQH3ikDinXZq3q4gDnrNrd1z7w48MfiIEIKGprLbN1iFyolBF3EyP8ZCKs
06j8Ve8TbhcOEWPDlcRKl1rpdoOVw+/bgf+rnXL4xpnzuq4aJP3g000qUOMuuT8d
Wty6cFHsRiJXswrHNH+OEanQP5tml7tkgDBvh6YRPU2JT8JmMWfDtHr68EgxFhlL
UkdOlN1oN0F3+tTysilZnIvEiusqnNCO5JiaDAtJ+W6Xt6Nlkk5h6lP1g9iV3m6p
EIZxTrMEbuvdSRzLxn4Sen49cd6uW2UfTjJSqU6KR02gCnV+7bFaQ9giVa9J3Vq+
jCNcHifTS73KyfMy1y64jUsxWSl3Fm/68kY3S4ci+31poFVNt1EPwiVv/iRqeE+I
1ReeHbTgZR9DwRycImaM/wUCAwEAAQ==
-----END PUBLIC KEY-----"

# Configuration
ENCRYPTED_OUTPUT="encrypted-env-vars.enc"
ENCRYPTED_KEY_FILE="encrypted-aes-key.enc"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*|MINGW*|MSYS*) echo "windows";;
        *)          echo "unknown";;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies
install_dependencies() {
    local os=$(detect_os)
    print_status "Detected OS: $os"
    
    if command_exists openssl; then
        print_status "OpenSSL is available"
        return 0
    fi
    
    print_warning "Installing OpenSSL..."
    
    case "$os" in
        "linux")
            if command_exists apt-get; then
                sudo apt-get update -qq && sudo apt-get install -y openssl
            elif command_exists yum; then
                sudo yum install -y openssl
            elif command_exists dnf; then
                sudo dnf install -y openssl
            elif command_exists pacman; then
                sudo pacman -S --noconfirm openssl
            else
                print_error "Please install OpenSSL manually"
                exit 1
            fi
            ;;
        "macos")
            if command_exists brew; then
                brew install openssl
            else
                print_error "Please install Homebrew first: https://brew.sh"
                exit 1
            fi
            ;;
        "windows")
            print_error "Please install OpenSSL for Windows (Git Bash includes it)"
            exit 1
            ;;
    esac
}

# Function to validate input file
validate_input_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        print_error "File '$file' does not exist."
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        print_error "File '$file' is not readable."
        return 1
    fi
    
    if [[ ! -s "$file" ]]; then
        print_warning "File '$file' is empty."
    fi
    
    return 0
}

# Function to encrypt file using hybrid encryption (RSA + AES)
encrypt_file_hybrid() {
    local input_file="$1"
    local encrypted_data_file="$2"
    local encrypted_key_file="$3"
    
    print_status "Using hybrid encryption (RSA + AES)..."
    
    # Generate random AES-256 key
    local aes_key=$(openssl rand -hex 32)
    local aes_key_file=$(mktemp)
    echo -n "$aes_key" > "$aes_key_file"
    
    # Create temporary file for public key
    local temp_pubkey=$(mktemp)
    echo "$TEAM_PUBLIC_KEY" > "$temp_pubkey"
    
    # Encrypt the AES key with RSA public key
    print_status "Encrypting AES key with team public key..."
    if ! openssl rsautl -encrypt -pubin -inkey "$temp_pubkey" -in "$aes_key_file" -out "$encrypted_key_file"; then
        print_error "Failed to encrypt AES key with RSA"
        rm -f "$temp_pubkey" "$aes_key_file"
        return 1
    fi
    
    # Encrypt the file with AES
    print_status "Encrypting data with AES-256-GCM..."
    if openssl enc -aes-256-gcm -salt -in "$input_file" -out "$encrypted_data_file" -pass "pass:$aes_key" 2>/dev/null; then
        print_success "Hybrid encryption completed successfully!"
    elif openssl enc -aes-256-cbc -salt -in "$input_file" -out "$encrypted_data_file" -pass "pass:$aes_key" 2>/dev/null; then
        print_success "Hybrid encryption completed (using CBC mode)"
    else
        print_error "Failed to encrypt data with AES"
        rm -f "$temp_pubkey" "$aes_key_file" "$encrypted_key_file"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_pubkey" "$aes_key_file"
    return 0
}

# Function to get developer info
get_developer_info() {
    local developer_name=""
    local developer_email=""
    
    # Try to get from git config
    if command_exists git; then
        developer_name=$(git config user.name 2>/dev/null || echo "")
        developer_email=$(git config user.email 2>/dev/null || echo "")
    fi
    
    # Prompt if not found
    if [[ -z "$developer_name" ]]; then
        read -p "Enter your name: " developer_name
    fi
    
    if [[ -z "$developer_email" ]]; then
        read -p "Enter your email: " developer_email
    fi
    
    echo "Developer: $developer_name <$developer_email>"
}

# Function to create metadata file
create_metadata() {
    local input_file="$1"
    local metadata_file="encrypted-env-vars.meta"
    
    local developer_info=$(get_developer_info)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local file_hash=$(sha256sum "$input_file" | cut -d' ' -f1)
    
    cat > "$metadata_file" << EOF
{
  "encrypted_at": "$timestamp",
  "developer": "$developer_info",
  "original_file": "$(basename "$input_file")",
  "original_hash": "$file_hash",
  "encryption_method": "RSA-4096 + AES-256",
  "files": {
    "data": "$ENCRYPTED_OUTPUT",
    "key": "$ENCRYPTED_KEY_FILE"
  }
}
EOF
    
    print_status "Metadata saved to: $metadata_file"
}

# Main function
main() {
    echo
    print_status "🔐 Multi-Developer Environment Variables Encryption"
    print_status "=================================================="
    print_status "This script encrypts your .env files using the team's public key"
    print_status "Only the team lead can decrypt them using the private key"
    echo
    
    # Install dependencies
    install_dependencies
    
    # Prompt for input file
    echo
    read -p "Enter the path to your environment variables file: " env_file
    
    if [[ -z "$env_file" ]]; then
        print_error "No file specified."
        exit 1
    fi
    
    # Handle relative paths
    if [[ ! "$env_file" = /* ]]; then
        env_file="$(pwd)/$env_file"
    fi
    
    if ! validate_input_file "$env_file"; then
        exit 1
    fi
    
    # Show file info
    echo
    local file_size=$(stat -c%s "$env_file" 2>/dev/null || stat -f%z "$env_file" 2>/dev/null)
    print_status "File: $(basename "$env_file")"
    print_status "Size: $file_size bytes"
    print_status "Full path: $env_file"
    
    # Perform hybrid encryption
    echo
    print_status "🔒 Starting encryption process..."
    
    if encrypt_file_hybrid "$env_file" "$ENCRYPTED_OUTPUT" "$ENCRYPTED_KEY_FILE"; then
        echo
        print_success "✅ Encryption completed successfully!"
        
        # Create metadata
        create_metadata "$env_file"
        
        echo
        print_status "📦 Files created:"
        print_status "  🔐 $ENCRYPTED_OUTPUT (encrypted environment variables)"
        print_status "  🗝️  $ENCRYPTED_KEY_FILE (encrypted AES key)"
        print_status "  📋 encrypted-env-vars.meta (metadata)"
        
        echo
        print_warning "📋 Next steps:"
        echo "  1. Add encrypted files to Git:"
        echo "     git add $ENCRYPTED_OUTPUT $ENCRYPTED_KEY_FILE encrypted-env-vars.meta"
        echo "  2. Commit and push:"
        echo "     git commit -m 'Add encrypted environment variables'"
        echo "     git push"
        
        echo
        print_warning "🔒 Security Notes:"
        print_warning "  ✅ These encrypted files are safe to commit to GitHub"
        print_warning "  ✅ Only the team lead can decrypt them"
        print_warning "  ❌ NEVER commit your original .env file"
        print_warning "  ❌ Do not share the team private key"
        
        echo
        print_status "🎉 Your environment variables are now securely encrypted!"
        
    else
        print_error "❌ Encryption failed!"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
