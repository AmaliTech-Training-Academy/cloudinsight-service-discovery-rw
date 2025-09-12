#!/bin/bash

# Team Lead Decryption Script
# Uses private key to decrypt environment variables encrypted by team members
# Private key should be stored securely (GitHub secrets, local machine, etc.)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default file names - look in repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DEFAULT_ENCRYPTED_DATA="$REPO_ROOT/encrypted-env-vars.enc"
DEFAULT_ENCRYPTED_KEY="$REPO_ROOT/encrypted-aes-key.enc"
DEFAULT_METADATA="$REPO_ROOT/encrypted-env-vars.meta"
DEFAULT_OUTPUT="decrypted-env-vars"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate private key
validate_private_key() {
    local private_key_file="$1"
    
    if [[ ! -f "$private_key_file" ]]; then
        print_error "Private key file not found: $private_key_file"
        return 1
    fi
    
    if [[ ! -r "$private_key_file" ]]; then
        print_error "Private key file is not readable: $private_key_file"
        return 1
    fi
    
    # Test if it's a valid RSA private key
    if ! openssl rsa -in "$private_key_file" -check -noout 2>/dev/null; then
        print_error "Invalid RSA private key: $private_key_file"
        return 1
    fi
    
    print_status "✅ Private key validated"
    return 0
}

# Function to validate encrypted files
validate_encrypted_files() {
    local data_file="$1"
    local key_file="$2"
    
    if [[ ! -f "$data_file" ]]; then
        print_error "Encrypted data file not found: $data_file"
        return 1
    fi
    
    if [[ ! -f "$key_file" ]]; then
        print_error "Encrypted key file not found: $key_file"
        return 1
    fi
    
    print_status "✅ Encrypted files found"
    return 0
}

# Function to show metadata if available
show_metadata() {
    local metadata_file="$1"
    
    if [[ -f "$metadata_file" ]]; then
        print_status "📋 Encryption Metadata:"
        echo "----------------------------------------"
        
        if command_exists jq; then
            jq . "$metadata_file" 2>/dev/null || cat "$metadata_file"
        else
            cat "$metadata_file"
        fi
        
        echo "----------------------------------------"
    else
        print_warning "No metadata file found ($metadata_file)"
    fi
}

# Function to decrypt using hybrid method
decrypt_file_hybrid() {
    local encrypted_data_file="$1"
    local encrypted_key_file="$2"
    local private_key_file="$3"
    local output_file="$4"
    
    print_status "🔓 Starting hybrid decryption..."
    
    # Decrypt the AES key using RSA private key
    print_status "Decrypting AES key with private key..."
    local temp_aes_key=$(mktemp)
    
    if ! openssl rsautl -decrypt -inkey "$private_key_file" -in "$encrypted_key_file" -out "$temp_aes_key"; then
        print_error "Failed to decrypt AES key with RSA private key"
        print_error "Possible issues:"
        print_error "  1. Wrong private key"
        print_error "  2. Corrupted encrypted key file"
        print_error "  3. File was encrypted with different public key"
        rm -f "$temp_aes_key"
        return 1
    fi
    
    # Read the decrypted AES key
    local aes_key=$(cat "$temp_aes_key")
    
    # Decrypt the data using AES key
    print_status "Decrypting data with AES key..."
    
    # Try GCM mode first, then fallback to CBC
    if openssl enc -aes-256-gcm -d -in "$encrypted_data_file" -out "$output_file" -pass "pass:$aes_key" 2>/dev/null; then
        print_success "Decrypted successfully using AES-GCM"
    elif openssl enc -aes-256-cbc -d -in "$encrypted_data_file" -out "$output_file" -pass "pass:$aes_key" 2>/dev/null; then
        print_success "Decrypted successfully using AES-CBC"
    else
        print_error "Failed to decrypt data with AES"
        print_error "The encrypted data file may be corrupted"
        rm -f "$temp_aes_key"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_aes_key"
    return 0
}

# Function to verify decrypted content
verify_decrypted_content() {
    local output_file="$1"
    local metadata_file="$2"
    
    if [[ ! -f "$output_file" ]]; then
        print_error "Decrypted file not found: $output_file"
        return 1
    fi
    
    local current_hash=$(sha256sum "$output_file" | cut -d' ' -f1)
    
    if [[ -f "$metadata_file" ]]; then
        local original_hash=$(grep '"original_hash"' "$metadata_file" | cut -d'"' -f4 2>/dev/null || echo "")
        
        if [[ -n "$original_hash" ]]; then
            if [[ "$current_hash" == "$original_hash" ]]; then
                print_success "✅ File integrity verified (hash matches)"
            else
                print_warning "⚠️  Hash mismatch - file may be corrupted or different"
                print_warning "Original: $original_hash"
                print_warning "Current:  $current_hash"
            fi
        fi
    fi
    
    # Show file info
    local line_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
    
    print_status "📁 Decrypted file info:"
    print_status "  Lines: $line_count"
    print_status "  Size: $file_size bytes"
    print_status "  SHA256: $current_hash"
}

# Function to preview decrypted content
preview_content() {
    local output_file="$1"
    
    local line_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    
    if [[ $line_count -eq 0 ]]; then
        print_warning "Decrypted file is empty"
        return
    fi
    
    echo
    print_status "📋 Content Preview:"
    echo "========================================"
    
    if [[ $line_count -le 20 ]]; then
        cat "$output_file"
    else
        print_status "(Showing first 20 lines of $line_count total)"
        head -n 20 "$output_file"
        echo "... ($((line_count - 20)) more lines)"
    fi
    
    echo "========================================"
}

# Main function
main() {
    # Setup cleanup trap for any exit (success or failure)
    cleanup() {
        echo
        print_status "🧹 Performing security cleanup..."
        # Remove any temporary files that might have been created
        rm -f ./temp-aes-key ./decrypted-*.env 2>/dev/null
        # Note: We don't remove the output .env file as it's the intended result
        print_status "✅ Security cleanup completed"
    }
    trap cleanup EXIT
    
    echo
    print_status "🔓 Team Lead Environment Variables Decryption"
    print_status "============================================="
    print_status "This script decrypts environment variables using your private key"
    echo
    
    # Check dependencies
    if ! command_exists openssl; then
        print_error "OpenSSL is required but not installed"
        exit 1
    fi
    
    # Prompt for private key location
    echo
    print_status "🗝️  Private Key Location"
    read -p "Enter path to your private key file: " private_key_file
    
    if [[ -z "$private_key_file" ]]; then
        print_error "No private key file specified"
        exit 1
    fi
    
    # Handle relative paths
    if [[ ! "$private_key_file" = /* ]]; then
        private_key_file="$(pwd)/$private_key_file"
    fi
    
    # Validate private key
    if ! validate_private_key "$private_key_file"; then
        exit 1
    fi
    
    # Prompt for encrypted files
    echo
    print_status "📦 Encrypted Files"
    
    read -p "Enter encrypted data file (default: $DEFAULT_ENCRYPTED_DATA): " encrypted_data_file
    if [[ -z "$encrypted_data_file" ]]; then
        encrypted_data_file="$DEFAULT_ENCRYPTED_DATA"
    fi
    
    read -p "Enter encrypted key file (default: $DEFAULT_ENCRYPTED_KEY): " encrypted_key_file
    if [[ -z "$encrypted_key_file" ]]; then
        encrypted_key_file="$DEFAULT_ENCRYPTED_KEY"
    fi
    
    # Handle relative paths
    if [[ ! "$encrypted_data_file" = /* ]]; then
        encrypted_data_file="$(pwd)/$encrypted_data_file"
    fi
    
    if [[ ! "$encrypted_key_file" = /* ]]; then
        encrypted_key_file="$(pwd)/$encrypted_key_file"
    fi
    
    # Validate encrypted files
    if ! validate_encrypted_files "$encrypted_data_file" "$encrypted_key_file"; then
        exit 1
    fi
    
    # Prompt for output file
    echo
    read -p "Enter output file name (default: $DEFAULT_OUTPUT): " output_file
    if [[ -z "$output_file" ]]; then
        output_file="$DEFAULT_OUTPUT"
    fi
    
    # Show metadata if available
    echo
    local metadata_file="$DEFAULT_METADATA"
    if [[ ! "$metadata_file" = /* ]]; then
        metadata_file="$(pwd)/$metadata_file"
    fi
    show_metadata "$metadata_file"
    
    # Perform decryption
    echo
    print_status "🔓 Starting decryption process..."
    
    if decrypt_file_hybrid "$encrypted_data_file" "$encrypted_key_file" "$private_key_file" "$output_file"; then
        echo
        print_success "✅ Decryption completed successfully!"
        
        # Verify content
        verify_decrypted_content "$output_file" "$metadata_file"
        
        # Preview content
        preview_content "$output_file"
        
        echo
        print_warning "🔒 Security Reminders:"
        print_warning "  • Keep '$output_file' secure and local"
        print_warning "  • Do NOT commit decrypted files to Git"
        print_warning "  • Delete '$output_file' when no longer needed"
        print_warning "  • Keep your private key secure"
        
        echo
        print_success "🎉 Environment variables successfully decrypted!"
        
    else
        print_error "❌ Decryption failed!"
        exit 1
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
