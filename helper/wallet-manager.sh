#!/bin/bash
# Author: Rokhanz
# Date: August 13, 2025
# License: MIT
# Description: Wallet & Node Management - Unified wallet/node workflow

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## wallet_management_menu - Wallet management submenu
wallet_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}🔑 WALLET & NODE MANAGEMENT${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
        echo ""

        # Show current status
        show_current_wallet_status

        echo -e "${WHITE}💼 Choose wallet & node management action:${NC}"
        echo ""

        PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
        select opt in "🆕 Setup New Wallet + Node" "📝 Manage Node IDs" "👀 View Wallet & Nodes" "🔄 Switch Active Wallet" "🚪 Kembali ke Menu Utama"; do
            case $opt in
                "🆕 Setup New Wallet + Node")
                    echo -e "${CYAN}🆕 Setting up new wallet and node...${NC}"
                    setup_new_wallet_and_node
                    break
                    ;;
                "📝 Manage Node IDs")
                    echo -e "${CYAN}📝 Managing node IDs...${NC}"
                    manage_node_ids_submenu
                    break
                    ;;
                "👀 View Wallet & Nodes")
                    echo -e "${CYAN}👀 Viewing current wallet and nodes...${NC}"
                    view_wallet_and_nodes
                    break
                    ;;
                "🔄 Switch Active Wallet")
                    echo -e "${CYAN}🔄 Switching active wallet...${NC}"
                    switch_active_wallet
                    break
                    ;;
                "🚪 Kembali ke Menu Utama")
                    echo -e "${GREEN}↩️ Kembali ke menu utama...${NC}"
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-5.${NC}"
                    sleep 1
                    ;;
            esac
        done
    done
}

## show_current_wallet_status - Show current wallet and node status
show_current_wallet_status() {
    local credentials_file="$WORKDIR/config/credentials.json"

    if [[ -f "$credentials_file" ]]; then
        local current_wallet
        local node_count
        current_wallet=$(jq -r '.wallet_address // "Not set"' "$credentials_file" 2>/dev/null)
        node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")

        echo -e "${GREEN}📊 Current Status:${NC}"
        echo -e "   💳 Wallet: ${YELLOW}${current_wallet}${NC}"
        echo -e "   🖥️  Nodes: ${YELLOW}${node_count} configured${NC}"
        echo ""
    else
        echo -e "${YELLOW}⚠️  No wallet configured yet${NC}"
        echo ""
    fi
}

## setup_new_wallet_and_node - Setup new wallet with node ID in one flow
setup_new_wallet_and_node() {
    echo -e "${CYAN}🆕 Setting up new wallet and node...${NC}"
    echo ""

    # Create credentials directory
    mkdir -p "$WORKDIR/config"
    local credentials_file="$WORKDIR/config/credentials.json"

    # Get wallet address with cancel option
    echo -e "${WHITE}Step 1: Wallet Configuration${NC}"
    while true; do
        echo -e "${YELLOW}💳 Enter your wallet address (or 'cancel' to return):${NC}"
        read -r wallet_address

        if [[ "$wallet_address" == "cancel" || "$wallet_address" == "CANCEL" ]]; then
            echo -e "${CYAN}❌ Setup cancelled${NC}"
            wait_for_keypress
            return
        fi

        if [[ -z "$wallet_address" ]]; then
            echo -e "${RED}❌ Wallet address cannot be empty!${NC}"
            continue
        fi

        # Basic validation (starts with 0x and has reasonable length)
        if [[ ! "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            echo -e "${YELLOW}⚠️  Warning: This doesn't look like a standard Ethereum address${NC}"
            echo -e "${WHITE}Continue anyway? (y/n):${NC}"
            read -r confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                continue
            fi
        fi
        break
    done

    # Get first node ID with cancel option
    echo ""
    echo -e "${WHITE}Step 2: Node Configuration${NC}"
    while true; do
        echo -e "${YELLOW}🖥️  Enter your first node ID (or 'cancel' to return):${NC}"
        read -r node_id

        if [[ "$node_id" == "cancel" || "$node_id" == "CANCEL" ]]; then
            echo -e "${CYAN}❌ Setup cancelled${NC}"
            wait_for_keypress
            return
        fi

        if [[ -z "$node_id" ]]; then
            echo -e "${RED}❌ Node ID cannot be empty!${NC}"
            continue
        fi
        break
    done

    # Save to credentials.json
    cat > "$credentials_file" << EOF
{
  "wallet_address": "$wallet_address",
  "node_ids": ["$node_id"],
  "active_wallet": "$wallet_address",
  "created_at": "$(date -Iseconds)",
  "last_updated": "$(date -Iseconds)"
}
EOF

    # Set proper permissions
    chmod 600 "$credentials_file"

    echo ""
    echo -e "${GREEN}✅ Wallet and node setup completed!${NC}"
    echo -e "   💳 Wallet: ${YELLOW}$wallet_address${NC}"
    echo -e "   🖥️  Node:  ${YELLOW}$node_id${NC}"
    echo -e "   📁 Saved to: ${CYAN}$credentials_file${NC}"

    wait_for_keypress
}

## manage_node_ids_submenu - Node ID management submenu with add/edit/remove
manage_node_ids_submenu() {
    local credentials_file="$WORKDIR/config/credentials.json"

    if [[ ! -f "$credentials_file" ]]; then
        echo -e "${RED}❌ No wallet configured. Please setup wallet first.${NC}"
        wait_for_keypress
        return
    fi

    while true; do
        clear
        echo -e "${CYAN}📝 MANAGE NODE IDs${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════${NC}"
        echo ""

        # Show current nodes
        echo -e "${WHITE}Current Node IDs:${NC}"
        local node_count
        node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")

        if [[ "$node_count" -gt 0 ]]; then
            jq -r '.node_ids[] | "   🖥️  " + .' "$credentials_file" 2>/dev/null
        else
            echo -e "   ${YELLOW}No nodes configured${NC}"
        fi
        echo ""

        PS3="$(echo -e "${YELLOW}Choose action: ${NC}")"
        select action in "➕ Add New Node ID" "✏️  Edit Node ID" "🗑️ Remove Node ID" "🚪 Back"; do
            case $action in
                "➕ Add New Node ID")
                    add_new_node_id
                    break
                    ;;
                "✏️  Edit Node ID")
                    edit_node_id
                    break
                    ;;
                "🗑️ Remove Node ID")
                    remove_node_id
                    break
                    ;;
                "🚪 Back")
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Invalid selection${NC}"
                    sleep 1
                    ;;
            esac
        done
    done
}

## add_new_node_id - Add new node ID
add_new_node_id() {
    local credentials_file="$WORKDIR/config/credentials.json"

    echo -e "${CYAN}➕ Adding new node ID...${NC}"
    echo -e "${YELLOW}Enter new node ID (or 'cancel' to return):${NC}"
    read -r new_node_id

    if [[ "$new_node_id" == "cancel" || "$new_node_id" == "CANCEL" ]]; then
        echo -e "${CYAN}❌ Addition cancelled${NC}"
        sleep 2
        return
    fi

    if [[ -z "$new_node_id" ]]; then
        echo -e "${RED}❌ Node ID cannot be empty!${NC}"
        sleep 2
        return
    fi

    # Check if node ID already exists
    if jq -e --arg node "$new_node_id" '.node_ids | index($node)' "$credentials_file" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Node ID already exists!${NC}"
        sleep 2
        return
    fi

    # Add node ID
    jq --arg node "$new_node_id" '.node_ids += [$node] | .last_updated = now | strftime("%Y-%m-%dT%H:%M:%S%z")' "$credentials_file" > "${credentials_file}.tmp" && mv "${credentials_file}.tmp" "$credentials_file"

    echo -e "${GREEN}✅ Node ID added successfully!${NC}"
    sleep 2
}

## edit_node_id - Edit existing node ID
edit_node_id() {
    local credentials_file="$WORKDIR/config/credentials.json"
    local node_count
    node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")

    if [[ "$node_count" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No nodes to edit${NC}"
        sleep 2
        return
    fi

    echo -e "${CYAN}✏️  Select node ID to edit:${NC}"
    local nodes_array
    readarray -t nodes_array < <(jq -r '.node_ids[]' "$credentials_file")

    PS3="$(echo -e "${YELLOW}Select node to edit: ${NC}")"
    select node_to_edit in "${nodes_array[@]}" "Cancel"; do
        if [[ "$node_to_edit" == "Cancel" ]]; then
            return
        elif [[ -n "$node_to_edit" ]]; then
            echo -e "${WHITE}Current node ID: ${YELLOW}$node_to_edit${NC}"
            echo -e "${YELLOW}Enter new node ID (or 'cancel' to return):${NC}"
            read -r new_node_id

            if [[ "$new_node_id" == "cancel" || "$new_node_id" == "CANCEL" ]]; then
                echo -e "${CYAN}❌ Edit cancelled${NC}"
                sleep 2
                return
            fi

            if [[ -z "$new_node_id" ]]; then
                echo -e "${RED}❌ Node ID cannot be empty!${NC}"
                sleep 2
                return
            fi

            # Replace the node ID
            jq --arg old_node "$node_to_edit" --arg new_node "$new_node_id" '
                .node_ids = (.node_ids | map(if . == $old_node then $new_node else . end)) |
                .last_updated = now | strftime("%Y-%m-%dT%H:%M:%S%z")
            ' "$credentials_file" > "${credentials_file}.tmp" && mv "${credentials_file}.tmp" "$credentials_file"

            echo -e "${GREEN}✅ Node ID updated successfully!${NC}"
            echo -e "   Old: ${YELLOW}$node_to_edit${NC}"
            echo -e "   New: ${YELLOW}$new_node_id${NC}"
            sleep 2
            return
        else
            echo -e "${RED}❌ Invalid selection${NC}"
        fi
    done
}

## remove_node_id - Remove specific node ID
remove_node_id() {
    local credentials_file="$WORKDIR/config/credentials.json"
    local node_count
    node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")

    if [[ "$node_count" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No nodes to remove${NC}"
        sleep 2
        return
    fi

    echo -e "${CYAN}🗑️ Select node ID to remove:${NC}"
    local nodes_array
    readarray -t nodes_array < <(jq -r '.node_ids[]' "$credentials_file")

    PS3="$(echo -e "${YELLOW}Select node to remove: ${NC}")"
    select node_to_remove in "${nodes_array[@]}" "Cancel"; do
        if [[ "$node_to_remove" == "Cancel" ]]; then
            return
        elif [[ -n "$node_to_remove" ]]; then
            echo -e "${YELLOW}⚠️  Are you sure you want to remove: ${RED}$node_to_remove${NC}?"
            echo -e "${WHITE}Type 'yes' to confirm or anything else to cancel:${NC}"
            read -r confirm

            if [[ "$confirm" == "yes" ]]; then
                # Remove the selected node
                jq --arg node "$node_to_remove" '.node_ids = (.node_ids - [$node]) | .last_updated = now | strftime("%Y-%m-%dT%H:%M:%S%z")' "$credentials_file" > "${credentials_file}.tmp" && mv "${credentials_file}.tmp" "$credentials_file"

                echo -e "${GREEN}✅ Node ID removed successfully!${NC}"
                sleep 2
            else
                echo -e "${CYAN}❌ Removal cancelled${NC}"
                sleep 2
            fi
            return
        else
            echo -e "${RED}❌ Invalid selection${NC}"
        fi
    done
}

## view_wallet_and_nodes - Display current wallet and all node IDs
view_wallet_and_nodes() {
    local credentials_file="$WORKDIR/config/credentials.json"

    clear
    echo -e "${CYAN}👀 WALLET & NODES OVERVIEW${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════${NC}"
    echo ""

    if [[ ! -f "$credentials_file" ]]; then
        echo -e "${RED}❌ No wallet configured${NC}"
        wait_for_keypress
        return
    fi

    local wallet_address
    local node_count
    local created_at
    local last_updated

    wallet_address=$(jq -r '.wallet_address // "Not set"' "$credentials_file" 2>/dev/null)
    node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")
    created_at=$(jq -r '.created_at // "Unknown"' "$credentials_file" 2>/dev/null)
    last_updated=$(jq -r '.last_updated // "Unknown"' "$credentials_file" 2>/dev/null)

    echo -e "${WHITE}💳 Wallet Address:${NC}"
    echo -e "   ${YELLOW}$wallet_address${NC}"
    echo ""

    echo -e "${WHITE}🖥️  Node IDs (${node_count} total):${NC}"
    if [[ "$node_count" -gt 0 ]]; then
        jq -r '.node_ids[] | "   🔸 " + .' "$credentials_file" 2>/dev/null
    else
        echo -e "   ${YELLOW}No nodes configured${NC}"
    fi
    echo ""

    echo -e "${WHITE}📅 Created: ${CYAN}$created_at${NC}"
    echo -e "${WHITE}🔄 Last Updated: ${CYAN}$last_updated${NC}"

    wait_for_keypress
}

## switch_active_wallet - Switch to different wallet (if multiple exist)
switch_active_wallet() {
    echo -e "${CYAN}🔄 Switch Active Wallet${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Currently only single wallet is supported${NC}"
    echo -e "${WHITE}To use different wallet, please setup new wallet${NC}"

    wait_for_keypress
}
