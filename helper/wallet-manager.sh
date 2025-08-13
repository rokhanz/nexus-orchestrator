#!/bin/bash
# Author: Rokhanz
# Date: August 13, 2025
# License: MIT
# Description: Wallet & Account Management for Nexus Orchestrator

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## wallet_management_menu - Wallet management submenu
wallet_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}🔑 WALLET & ACCOUNT MANAGEMENT${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
        echo ""
        echo -e "${WHITE}💼 Pilih aksi pengelolaan wallet yang diinginkan:${NC}"
        echo ""

        PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
        select opt in "👤 Register New User/Wallet" "🔐 Login with Existing Wallet" "📝 View Current Credentials" "🔄 Switch Account" "🚪 Logout Current Session" "🚪 Kembali ke Menu Utama"; do
            case $opt in
                "👤 Register New User/Wallet")
                    echo -e "${CYAN}👤 Memulai registrasi wallet baru...${NC}"
                    register_new_wallet
                    ;;
                "🔐 Login with Existing Wallet")
                    echo -e "${CYAN}🔐 Login dengan wallet yang sudah ada...${NC}"
                    login_existing_wallet
                    ;;
                "📝 View Current Credentials")
                    echo -e "${CYAN}📝 Menampilkan kredensial saat ini...${NC}"
                    view_current_credentials
                    ;;
                "🔄 Switch Account")
                    echo -e "${CYAN}🔄 Mengganti akun...${NC}"
                    switch_account
                    ;;
                "🚪 Logout Current Session")
                    echo -e "${CYAN}🚪 Logout dari sesi saat ini...${NC}"
                    logout_current_session
                    ;;
                "🚪 Kembali ke Menu Utama")
                    echo -e "${GREEN}↩️ Kembali ke menu utama...${NC}"
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-6.${NC}"
                    sleep 1
                    ;;
            esac
        done
    done
}

## register_new_wallet - Register new wallet
register_new_wallet() {
    echo -e "${CYAN}👤 REGISTER NEW USER/WALLET${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    read -r -p "$(echo -e "${YELLOW}Enter wallet address (0x...): ${NC}")" wallet_address

    if [[ -z "$wallet_address" ]]; then
        echo -e "${RED}❌ Wallet address cannot be empty${NC}"
        wait_for_keypress
        return
    fi

    # Validate wallet format
    if [[ ! "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}❌ Invalid wallet address format${NC}"
        echo -e "${YELLOW}Expected format: 0x followed by 40 hex characters${NC}"
        wait_for_keypress
        return
    fi

    echo -e "${YELLOW}Registering wallet: $wallet_address${NC}"
    echo ""

    # Create credentials directory if not exists
    local config_dir
    config_dir="$(dirname "${BASH_SOURCE[0]}")/../workdir/config"
    mkdir -p "$config_dir"

    # Save credentials
    local credentials_file="$config_dir/credentials.json"
    cat > "$credentials_file" << EOF
{
    "wallet_address": "$wallet_address",
    "registration_type": "new_wallet",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%S%z")",
    "node_ids": []
}
EOF
        echo -e "${GREEN}✅ Credentials saved to workdir/config/credentials.json${NC}"

    wait_for_keypress
}

## login_existing_wallet - Login with existing wallet
login_existing_wallet() {
    echo -e "${CYAN}🔐 LOGIN WITH EXISTING WALLET${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    read -r -p "$(echo -e "${YELLOW}Enter wallet address (0x...): ${NC}")" wallet_address

    if [[ -z "$wallet_address" ]]; then
        echo -e "${RED}❌ Wallet address cannot be empty${NC}"
        wait_for_keypress
        return
    fi

    # Validate wallet format
    if [[ ! "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}❌ Invalid wallet address format${NC}"
        wait_for_keypress
        return
    fi

    # Create credentials directory if not exists
    local config_dir
    config_dir="$(dirname "${BASH_SOURCE[0]}")/../workdir/config"
    mkdir -p "$config_dir"

    # Save session
    local credentials_file="$config_dir/credentials.json"
    cat > "$credentials_file" << EOF
{
    "wallet_address": "$wallet_address",
    "registration_type": "existing_wallet",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%S%z")",
    "node_ids": []
}
EOF

    echo -e "${GREEN}✅ Session established for wallet: $wallet_address${NC}"
    echo -e "${YELLOW}💡 You can now use Node Management to register nodes${NC}"

    wait_for_keypress
}

## view_current_credentials - View current credentials
view_current_credentials() {
    echo -e "${CYAN}📝 VIEW CURRENT CREDENTIALS${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local credentials_file
    credentials_file="$(dirname "${BASH_SOURCE[0]}")/../workdir/config/credentials.json"

    if [[ ! -f "$credentials_file" ]]; then
        echo -e "${RED}❌ No credentials found${NC}"
        echo -e "${YELLOW}💡 Use 'Register New User/Wallet' or 'Login with Existing Wallet' first${NC}"
        wait_for_keypress
        return
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️ jq not found, showing raw file:${NC}"
        cat "$credentials_file"
    else
        echo -e "${GREEN}📋 Current Credentials:${NC}"
        echo ""

        local wallet_address
        wallet_address=$(jq -r '.wallet_address // "N/A"' "$credentials_file")
        echo -e "${YELLOW}Wallet Address:${NC} $wallet_address"

        local registration_type
        registration_type=$(jq -r '.registration_type // "N/A"' "$credentials_file")
        echo -e "${YELLOW}Registration Type:${NC} $registration_type"

        local created_at
        created_at=$(jq -r '.created_at // "N/A"' "$credentials_file")
        echo -e "${YELLOW}Created At:${NC} $created_at"

        local node_ids
        node_ids=$(jq -r '.node_ids[]? // empty' "$credentials_file")
        if [[ -n "$node_ids" ]]; then
            echo -e "${YELLOW}Node IDs:${NC}"
            while IFS= read -r node_id; do
                echo "  - $node_id"
            done <<< "$node_ids"
        else
            echo -e "${YELLOW}Node IDs:${NC} None registered"
        fi
    fi

    wait_for_keypress
}

## switch_account - Switch account
switch_account() {
    echo -e "${CYAN}🔄 SWITCH ACCOUNT${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}This will clear current session and allow you to login with different wallet${NC}"
    read -r -p "$(echo -e "${RED}Are you sure? (y/N): ${NC}")" confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        local credentials_file
        credentials_file="$(dirname "${BASH_SOURCE[0]}")/../workdir/config/credentials.json"
        if [[ -f "$credentials_file" ]]; then
            mv "$credentials_file" "${credentials_file}.backup.$(date +%s)"
            echo -e "${GREEN}✅ Current session backed up and cleared${NC}"
        fi

        echo -e "${GREEN}✅ You can now login with a different wallet${NC}"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi

    wait_for_keypress
}

## logout_current_session - Logout current session
logout_current_session() {
    echo -e "${CYAN}🚪 LOGOUT CURRENT SESSION${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local credentials_file
    credentials_file="$(dirname "${BASH_SOURCE[0]}")/../workdir/config/credentials.json"

    if [[ ! -f "$credentials_file" ]]; then
        echo -e "${YELLOW}⚠️ No active session found${NC}"
        wait_for_keypress
        return
    fi

    read -r -p "$(echo -e "${RED}Are you sure you want to logout? (y/N): ${NC}")" confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        mv "$credentials_file" "${credentials_file}.backup.$(date +%s)"
        echo -e "${GREEN}✅ Session ended successfully${NC}"
        echo -e "${YELLOW}💡 Backup saved with timestamp${NC}"
    else
        echo -e "${YELLOW}Logout cancelled${NC}"
    fi

    wait_for_keypress
}
