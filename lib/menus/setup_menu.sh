#!/bin/bash

# setup_menu.sh - Initial Setup Menu
# Version: 4.0.0 - Enhanced setup menu for Nexus Orchestrator

# shellcheck source=../common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
# shellcheck source=../wrappers/api_wrapper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../wrappers/api_wrapper.sh" 2>/dev/null || true

# =============================================================================
# SETUP MENU MAIN FUNCTION
# =============================================================================

setup_menu() {
    while true; do
        clear
        show_banner

        show_section_header "Setup & Installation" "🚀"

        echo -e "  ${GREEN}1.${NC} 🔧 ${CYAN}Setup Nexus Docker${NC}         ${YELLOW}(Pull Docker image for containerized nodes)${NC}"
        echo -e "  ${GREEN}2.${NC} 💳 ${CYAN}Configure Wallet Address${NC}      ${YELLOW}(Set Ethereum wallet for NEX rewards)${NC}"
        echo -e "  ${GREEN}3.${NC} 🆔 ${CYAN}Setup Node ID${NC}               ${YELLOW}(Configure node identities)${NC}"
        echo -e "  ${GREEN}4.${NC} 📊 ${CYAN}Wallet Information${NC}          ${YELLOW}(View complete wallet & network status)${NC}"
        echo -e "  ${GREEN}5.${NC} ✅ ${CYAN}Verify Installation${NC}         ${YELLOW}(Test all components)${NC}"
        echo ""
        echo -e "  ${GREEN}0.${NC} ⬅️  ${CYAN}Back to Main Menu${NC}           ${YELLOW}(Return to main menu)${NC}"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        read -rp "$(echo -e "${BOLD}${PURPLE}Please select an option [0-5]:${NC} ")" choice
        echo ""

        case "$choice" in
            1)
                install_nexus_prover
                ;;
            2)
                configure_wallet_interactive
                ;;
            3)
                setup_node_ids_interactive
                ;;
            4)
                echo -e "${CYAN}📊 Loading Wallet Information...${NC}"
                echo ""
                # Complete wallet information display
                show_wallet_information
                ;;
            5)
                verify_installation
                ;;
            0)
                echo -e "${GREEN}✅ Returning to Main Menu...${NC}"
                break
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# INSTALL NEXUS PROVER
# =============================================================================

install_nexus_prover() {
    clear
    show_section_header "Install Nexus Prover" "🔧"

    echo -e "${CYAN}🔧 ${BOLD}Nexus Docker Image Setup${NC}"
    echo ""
    echo -e "${YELLOW}This will pull the Nexus CLI Docker image for containerized execution.${NC}"
    echo -e "${YELLOW}Image: ${CYAN}nexusxyz/nexus-cli:latest${NC}"
    echo ""
    echo -e "${CYAN}Benefits of Docker-based setup:${NC}"
    echo -e "  ${GREEN}•${NC} ${YELLOW}Isolated execution environment${NC}"
    echo -e "  ${GREEN}•${NC} ${YELLOW}Lower host resource usage${NC}"
    echo -e "  ${GREEN}•${NC} ${YELLOW}Easy log capturing and monitoring${NC}"
    echo -e "  ${GREEN}•${NC} ${YELLOW}Multiple node instances management${NC}"
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Continue with Docker image setup? [y/n]:${NC} ")" confirm
    echo ""

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}� ${BOLD}Setting up Docker environment...${NC}"
        echo ""

        # Check if Docker is available
        if ! command -v docker >/dev/null 2>&1; then
            echo -e "${RED}❌ Docker is not installed!${NC}"
            echo -e "${YELLOW}   Please install Docker first: ${CYAN}https://docs.docker.com/install/${NC}"
            echo ""
            echo -e "${YELLOW}Press any key to continue...${NC}"
            read -rn 1
            return
        fi

        # Check if Docker daemon is running
        if ! docker info >/dev/null 2>&1; then
            echo -e "${RED}❌ Docker daemon is not running!${NC}"
            echo -e "${YELLOW}   Please start Docker service first${NC}"
            echo ""
            echo -e "${YELLOW}Press any key to continue...${NC}"
            read -rn 1
            return
        fi

        echo -e "${BLUE}📥 Pulling Nexus CLI Docker image...${NC}"
        if docker pull nexusxyz/nexus-cli:latest; then
            echo ""
            echo -e "${GREEN}✅ Nexus Docker image pulled successfully!${NC}"
            echo -e "${CYAN}   Image: ${YELLOW}nexusxyz/nexus-cli:latest${NC}"

            # Get image info
            local image_info
            image_info=$(docker images nexusxyz/nexus-cli:latest --format "table {{.Size}}\t{{.CreatedAt}}" | tail -n 1 || echo "Unknown")
            echo -e "${CYAN}   Image info: ${YELLOW}${image_info}${NC}"

            echo ""
            echo -e "${GREEN}🎉 Docker-based setup completed!${NC}"
            echo -e "${CYAN}   You can now generate Docker configurations for your nodes.${NC}"
        else
            echo -e "${RED}❌ Failed to pull Nexus Docker image${NC}"
            echo -e "${YELLOW}   Please check your internet connection and Docker setup${NC}"
        fi
    else
        echo -e "${YELLOW}⏭️  Docker setup cancelled.${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -rn 1
}

# =============================================================================
# CONFIGURE WALLET ADDRESS
# =============================================================================

configure_wallet_interactive() {
    clear
    show_section_header "Configure Wallet Address" "💳"

    echo -e "${CYAN}💳 ${BOLD}Wallet Address Configuration for NEX Token Rewards${NC}"
    echo ""
    echo -e "${YELLOW}Enter your Ethereum wallet address to receive NEX token rewards.${NC}"
    echo -e "${YELLOW}The address should be a valid Ethereum address (starts with 0x).${NC}"
    echo ""

    # Show current wallet if exists
    local current_wallet
    current_wallet=$(read_config_value "wallet_address")
    if [[ -n "$current_wallet" ]]; then
        echo -e "${CYAN}Current wallet: ${YELLOW}$current_wallet${NC}"
        echo ""
    fi

    read -rp "$(echo -e "${BOLD}${PURPLE}Enter wallet address:${NC} ")" wallet_address
    echo ""

    if [[ -z "$wallet_address" ]]; then
        echo -e "${YELLOW}⏭️  No wallet address entered.${NC}"
        echo ""
        echo -e "${YELLOW}Press any key to continue...${NC}"
        read -rn 1
        return
    fi

    # Basic validation
    if [[ ! "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}❌ Invalid wallet address format!${NC}"
        echo -e "${YELLOW}   Wallet address must be 42 characters long and start with 0x${NC}"
        echo ""
        echo -e "${YELLOW}Press any key to continue...${NC}"
        read -rn 1
        return
    fi

    # Show confirmation before saving
    echo ""
    echo -e "${CYAN}📋 ${BOLD}Wallet Address Confirmation${NC}"
    echo -e "${CYAN}Address to save: ${YELLOW}$wallet_address${NC}"
    echo ""
    read -rp "$(echo -e "${PURPLE}${BOLD}Save this wallet address? [y/N]:${NC} ")" confirm

    case "${confirm,,}" in
        y|yes)
            # Save to configuration
            if write_config_value "wallet_address" "$wallet_address"; then
                echo -e "${GREEN}✅ Wallet address configured successfully!${NC}"
                echo -e "${CYAN}   Address: ${YELLOW}$wallet_address${NC}"
            else
                echo -e "${RED}❌ Failed to save wallet address!${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}⏭️  Wallet address configuration cancelled.${NC}"
            ;;
    esac

    echo ""
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -rn 1
}

# =============================================================================
# WALLET INFORMATION DISPLAY
# =============================================================================

show_wallet_information() {
    clear
    show_section_header "Wallet Information" "📊"

    echo -e "${CYAN}📊 ${BOLD}Complete Wallet & Network Information${NC}"
    echo ""

    # Show current wallet if exists
    local current_wallet
    current_wallet=$(read_config_value "wallet_address")
    if [[ -n "$current_wallet" && "$current_wallet" != "null" ]]; then
        echo -e "${CYAN}${BOLD}📍 Current Wallet:${NC} ${YELLOW}$current_wallet${NC}"
        echo ""

        # Auto-detect and display NEX rewards information
        echo -e "${YELLOW}${BOLD}💰 NEX Rewards Information:${NC}"
        if command -v check_nex_rewards >/dev/null 2>&1; then
            # Check network connectivity first
            if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
                echo -e "  ${CYAN}🔄 Auto-detecting rewards...${NC}"
                if check_nex_rewards "$current_wallet" 2>/dev/null; then
                    echo -e "  ${GREEN}✅ Rewards data auto-loaded${NC}"
                else
                    echo -e "  ${YELLOW}⚠️  No rewards data (wallet may not be active)${NC}"
                fi
            else
                echo -e "  ${RED}❌ Network offline - Cannot auto-detect rewards${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠️  NEX rewards API not available${NC}"
        fi
        echo ""

        # Auto-detect network status
        echo -e "${YELLOW}${BOLD}🌐 Network & API Auto-Detection:${NC}"
        echo -e "  ${CYAN}🔄 Auto-checking connectivity...${NC}"
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Internet: Connected${NC}"

            # Test API connectivity automatically
            if command -v test_api_connectivity >/dev/null 2>&1; then
                if test_api_connectivity >/dev/null 2>&1; then
                    echo -e "  ${GREEN}✅ Nexus API: Auto-detected & Connected${NC}"

                    # Check network status
                    if command -v check_nexus_network_status >/dev/null 2>&1; then
                        if check_nexus_network_status >/dev/null 2>&1; then
                            echo -e "  ${GREEN}✅ Nexus Network: Online & Operational${NC}"
                        else
                            echo -e "  ${YELLOW}⚠️  Nexus Network: Under Maintenance${NC}"
                        fi
                    fi

                    # Get API version
                    if command -v get_api_version >/dev/null 2>&1; then
                        local api_version
                        api_version=$(get_api_version 2>/dev/null)
                        if [[ "$api_version" != "unknown" && -n "$api_version" ]]; then
                            echo -e "  ${GREEN}✅ API Version: ${CYAN}$api_version${NC} (Auto-detected)"
                        fi
                    fi
                else
                    echo -e "  ${RED}❌ Nexus API: Auto-detection failed${NC}"
                fi
            else
                echo -e "  ${YELLOW}⚠️  API connectivity test not available${NC}"
            fi
        else
            echo -e "  ${RED}❌ Internet connection: Disconnected${NC}"
        fi
        echo ""

        # Wallet validation status
        if validate_wallet_address "$current_wallet" 2>/dev/null; then
            echo -e "  ${GREEN}✅ Wallet format: Valid${NC}"
        else
            echo -e "  ${RED}❌ Wallet format: Invalid${NC}"
        fi
        echo ""

        # Auto-detect and display Node Information
        echo -e "${YELLOW}${BOLD}🆔 Node Information:${NC}"
        local current_node_id
        current_node_id=$(read_config_value "node_id" 2>/dev/null)
        if [[ -n "$current_node_id" && "$current_node_id" != "null" ]]; then
            local node_count
            node_count=$(echo "$current_node_id" | jq -r 'length' 2>/dev/null || echo "1")
            echo -e "  ${GREEN}✅ Node IDs configured: ${CYAN}$node_count node(s)${NC}"

            # Show first few node IDs
            if command -v jq >/dev/null 2>&1; then
                echo "$current_node_id" | jq -r '.[]' 2>/dev/null | head -3 | while read -r node_id; do
                    echo -e "    ${GREEN}•${NC} ${YELLOW}$node_id${NC}"
                done
                if [[ "$node_count" -gt 3 ]]; then
                    echo -e "    ${CYAN}... and $((node_count - 3)) more${NC}"
                fi
            else
                echo -e "    ${GREEN}•${NC} ${YELLOW}$current_node_id${NC}"
            fi
        else
            echo -e "  ${RED}❌ No Node IDs configured${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No wallet configured${NC}"
        echo -e "${CYAN}   Use option 2 to configure your wallet address first.${NC}"
    fi
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -rn 1
}

# =============================================================================
# SETUP NODE IDS
# =============================================================================

setup_node_ids_interactive() {
    clear
    show_section_header "Setup Node ID Configuration" "🆔"

    echo -e "${CYAN}🆔 ${BOLD}Node ID Management${NC}"
    echo ""
    echo -e "${YELLOW}Configure one or more Node IDs for your Nexus nodes.${NC}"
    echo -e "${YELLOW}Each Node ID should be unique and alphanumeric.${NC}"
    echo ""

    # Show current node IDs
    local current_node_id
    current_node_id=$(read_config_value "node_id")
    if [[ -n "$current_node_id" && "$current_node_id" != "null" ]]; then
        echo -e "${CYAN}Current Node IDs:${NC}"
        echo "$current_node_id" | jq -r '.[]' | while read -r node_id; do
            echo -e "  ${GREEN}•${NC} ${YELLOW}$node_id${NC}"
        done
        echo ""
    fi

    echo -e "${GREEN}1.${NC} 📝 ${CYAN}Add Node ID${NC}"
    echo -e "${GREEN}2.${NC} ✏️  ${CYAN}Edit Node ID${NC}"
    echo -e "${GREEN}3.${NC} 🗑️  ${CYAN}Remove Node ID${NC}"
    echo -e "${GREEN}4.${NC} 📋 ${CYAN}List All Node IDs${NC}"
    echo -e "${GREEN}0.${NC} ⬅️  ${CYAN}Back to Setup Menu${NC}"
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Select action [0-4]:${NC} ")" action
    echo ""

    case "$action" in
        1)
            add_node_id_interactive
            ;;
        2)
            edit_node_id_interactive
            ;;
        3)
            remove_node_id_interactive
            ;;
        4)
            list_node_ids_interactive
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}❌ Invalid option.${NC}"
            sleep 2
            ;;
    esac

    echo ""
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -rn 1
}

add_node_id_interactive() {
    echo -e "${CYAN}📝 ${BOLD}Add New Node ID${NC}"
    echo ""
    echo -e "${YELLOW}💡 Node ID must be numeric only (numbers 0-9)${NC}"
    echo -e "${YELLOW}   Length: 1-20 digits${NC}"
    echo -e "${YELLOW}   Example: 123456789${NC}"
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Enter new Node ID:${NC} ")" new_node_id
    echo ""

    if [[ -z "$new_node_id" ]]; then
        echo -e "${YELLOW}⏭️  No Node ID entered.${NC}"
        return
    fi

    if ! validate_node_id "$new_node_id"; then
        echo -e "${RED}❌ Invalid Node ID format!${NC}"
        echo -e "${YELLOW}   Node ID must contain only numbers (1-20 digits)${NC}"
        echo -e "${YELLOW}   Example: 123456789${NC}"
        return
    fi

    if add_node_id "$new_node_id"; then
        echo -e "${GREEN}✅ Node ID '$new_node_id' added successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to add Node ID or Node ID already exists!${NC}"
    fi
}

edit_node_id_interactive() {
    echo -e "${CYAN}✏️  ${BOLD}Edit Node ID${NC}"
    echo ""

    local node_ids
    node_ids=$(list_node_ids)
    if [[ -z "$node_ids" ]]; then
        echo -e "${YELLOW}⚠️  No Node IDs configured.${NC}"
        return
    fi

    echo -e "${CYAN}Current Node IDs:${NC}"
    local i=1
    echo "$node_ids" | while read -r node_entry; do
        echo -e "  ${GREEN}$i.${NC} ${YELLOW}$node_entry${NC}"
        ((i++))
    done
    echo ""

    echo -e "${GREEN}Select editing method:${NC}"
    echo -e "  ${GREEN}1.${NC} Edit by number"
    echo -e "  ${GREEN}0.${NC} Cancel"
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Select option [0-1]:${NC} ")" edit_method
    echo ""

    local old_node_id=""
    case "$edit_method" in
        1)
            read -rp "$(echo -e "${BOLD}${PURPLE}Enter number (1-$(echo "$node_ids" | wc -l)):${NC} ")" node_number
            if [[ "$node_number" =~ ^[0-9]+$ ]] && [[ "$node_number" -ge 1 ]] && [[ "$node_number" -le $(echo "$node_ids" | wc -l) ]]; then
                old_node_id=$(echo "$node_ids" | sed -n "${node_number}p")
            else
                echo -e "${RED}❌ Invalid number!${NC}"
                return
            fi
            ;;
        0)
            echo -e "${YELLOW}⏭️  Edit cancelled.${NC}"
            return
            ;;
        *)
            echo -e "${RED}❌ Invalid option.${NC}"
            return
            ;;
    esac

    if [[ -z "$old_node_id" ]]; then
        echo -e "${YELLOW}⏭️  No Node ID selected.${NC}"
        return
    fi

    echo -e "${CYAN}Selected Node ID: ${YELLOW}$old_node_id${NC}"
    echo ""
    echo -e "${YELLOW}💡 Node ID must be numeric only (numbers 0-9)${NC}"
    echo -e "${YELLOW}   Length: 1-20 digits${NC}"
    echo -e "${YELLOW}   Example: 123456789${NC}"
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Enter new Node ID:${NC} ")" new_node_id
    echo ""

    if [[ -z "$new_node_id" ]]; then
        echo -e "${YELLOW}⏭️  No new Node ID entered.${NC}"
        return
    fi

    if ! validate_node_id "$new_node_id"; then
        echo -e "${RED}❌ Invalid Node ID format!${NC}"
        echo -e "${YELLOW}   Node ID must contain only numbers (1-20 digits)${NC}"
        echo -e "${YELLOW}   Example: 123456789${NC}"
        return
    fi

    if edit_node_id "$old_node_id" "$new_node_id"; then
        echo -e "${GREEN}✅ Node ID updated from '$old_node_id' to '$new_node_id'!${NC}"
    else
        echo -e "${RED}❌ Failed to update Node ID!${NC}"
    fi
}

remove_node_id_interactive() {
    echo -e "${CYAN}🗑️  ${BOLD}Remove Node ID${NC}"
    echo ""

    local node_ids
    node_ids=$(list_node_ids)
    if [[ -z "$node_ids" ]]; then
        echo -e "${YELLOW}⚠️  No Node IDs configured.${NC}"
        return
    fi

    echo -e "${CYAN}Current Node IDs:${NC}"
    local i=1
    echo "$node_ids" | while read -r node_entry; do
        echo -e "  ${GREEN}$i.${NC} ${YELLOW}$node_entry${NC}"
        ((i++))
    done
    echo ""

    echo -e "${GREEN}Select removal method:${NC}"
    echo -e "  ${GREEN}1.${NC} Remove by number"
    echo -e "  ${GREEN}2.${NC} ${RED}Remove ALL Node IDs${NC}"
    echo -e "  ${GREEN}0.${NC} Cancel"
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Select option [0-2]:${NC} ")" remove_method
    echo ""

    case "$remove_method" in
        1)
            read -rp "$(echo -e "${BOLD}${PURPLE}Enter number (1-$(echo "$node_ids" | wc -l)):${NC} ")" node_number
            if [[ "$node_number" =~ ^[0-9]+$ ]] && [[ "$node_number" -ge 1 ]] && [[ "$node_number" -le $(echo "$node_ids" | wc -l) ]]; then
                local node_id_to_remove
                node_id_to_remove=$(echo "$node_ids" | sed -n "${node_number}p")
                echo ""
                echo -e "${RED}⚠️  Are you sure you want to remove Node ID '${YELLOW}$node_id_to_remove${RED}'?${NC}"
                read -rp "$(echo -e "${BOLD}${PURPLE}Confirm removal [y/n]:${NC} ")" confirm
                echo ""
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if remove_node_id "$node_id_to_remove"; then
                        echo -e "${GREEN}✅ Node ID '$node_id_to_remove' removed successfully!${NC}"
                    else
                        echo -e "${RED}❌ Failed to remove Node ID!${NC}"
                    fi
                else
                    echo -e "${YELLOW}⏭️  Removal cancelled.${NC}"
                fi
            else
                echo -e "${RED}❌ Invalid number!${NC}"
            fi
            ;;
        2)
            echo -e "${RED}🚨 ${BOLD}WARNING: This will remove ALL Node IDs!${NC}"
            echo -e "${RED}This action cannot be undone.${NC}"
            echo ""
            read -rp "$(echo -e "${BOLD}${RED}Type 'DELETE ALL' to confirm:${NC} ")" confirm_all
            echo ""
            if [[ "$confirm_all" == "DELETE ALL" ]]; then
                # Remove all node IDs by setting empty array
                if write_config_value "node_id" "[]"; then
                    echo -e "${GREEN}✅ All Node IDs removed successfully!${NC}"
                else
                    echo -e "${RED}❌ Failed to remove all Node IDs!${NC}"
                fi
            else
                echo -e "${YELLOW}⏭️  Mass removal cancelled.${NC}"
            fi
            ;;
        0)
            echo -e "${YELLOW}⏭️  Removal cancelled.${NC}"
            ;;
        *)
            echo -e "${RED}❌ Invalid option.${NC}"
            ;;
    esac
}

list_node_ids_interactive() {
    echo -e "${CYAN}📋 ${BOLD}All Configured Node IDs${NC}"
    echo ""

    local node_id
    node_id=$(list_node_ids)
    if [[ -z "$node_id" ]]; then
        echo -e "${YELLOW}⚠️  No Node IDs configured.${NC}"
        echo -e "${CYAN}   Use option 1 to add your first Node ID.${NC}"
    else
        echo -e "${CYAN}Current Node IDs:${NC}"
        local i=1
        echo "$node_id" | while read -r node_entry; do
            echo -e "  ${GREEN}$i.${NC} ${YELLOW}$node_entry${NC}"
            ((i++))
        done
        echo ""
        echo -e "${CYAN}Total: ${YELLOW}$(echo "$node_id" | wc -l)${NC} Node ID(s)"
    fi
}

# =============================================================================
# VERIFY INSTALLATION
# =============================================================================

verify_installation() {
    clear
    show_section_header "Verify Installation" "✅"

    echo -e "${CYAN}✅ ${BOLD}Installation Verification${NC}"
    echo ""
    echo -e "${YELLOW}Checking all components and configuration...${NC}"
    echo ""

    local all_good=true

    # Check Nexus Docker image
    echo -e "${BLUE}🔧 Checking Nexus Docker image...${NC}"

    # Check if Docker is available first
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "   ${RED}❌ Docker not installed${NC}"
        echo -e "   ${YELLOW}   Install Docker first before proceeding${NC}"
        all_good=false
    elif ! docker info >/dev/null 2>&1; then
        echo -e "   ${RED}❌ Docker daemon not running${NC}"
        echo -e "   ${YELLOW}   Start Docker service first${NC}"
        all_good=false
    else
        # Check if Nexus image exists
        if docker images nexusxyz/nexus-cli:latest --format "{{.Repository}}:{{.Tag}}" | grep -q "nexusxyz/nexus-cli:latest"; then
            local image_size
            image_size=$(docker images nexusxyz/nexus-cli:latest --format "{{.Size}}" | head -1)
            echo -e "   ${GREEN}✅ Nexus Docker image found${NC} ${CYAN}(nexusxyz/nexus-cli:latest)${NC}"
            echo -e "   ${CYAN}   Size: ${image_size}${NC}"
        else
            echo -e "   ${RED}❌ Nexus Docker image not found${NC}"
            echo -e "   ${YELLOW}   Use option 1 to pull the Docker image${NC}"
            all_good=false
        fi
    fi

    # Check wallet configuration
    echo -e "${BLUE}💳 Checking wallet configuration...${NC}"
    local wallet_address
    wallet_address=$(read_config_value "wallet_address")
    if [[ -n "$wallet_address" && "$wallet_address" != "null" ]]; then
        echo -e "   ${GREEN}✅ Wallet address configured${NC} ${CYAN}($wallet_address)${NC}"
    else
        echo -e "   ${RED}❌ Wallet address not configured${NC}"
        all_good=false
    fi

    # Check node IDs
    echo -e "${BLUE}🆔 Checking Node ID configuration...${NC}"
    local node_ids
    if node_ids=$(list_node_ids 2>/dev/null) && [[ -n "$node_ids" ]]; then
        local count
        count=$(echo "$node_ids" | wc -l)
        echo -e "   ${GREEN}✅ Node IDs configured${NC} ${CYAN}($count node(s))${NC}"
        echo "$node_ids" | while read -r node_id; do
            echo -e "     ${GREEN}•${NC} ${YELLOW}$node_id${NC}"
        done
    else
        echo -e "   ${RED}❌ No Node IDs configured${NC}"
        all_good=false
    fi

    # Check Docker configuration
    echo -e "${BLUE}🐳 Checking Docker configuration...${NC}"
    if [[ -f "docker-compose.yml" ]]; then
        echo -e "   ${GREEN}✅ Docker compose file exists${NC}"
    else
        echo -e "   ${CYAN}ℹ️  Docker compose will auto-generate when starting containers${NC}"
        echo -e "   ${GRAY}   No manual generation needed${NC}"
    fi

    # Check Docker availability
    echo -e "${BLUE}🐋 Checking Docker availability...${NC}"
    if command -v docker >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Docker is available${NC}"
        if docker compose version >/dev/null 2>&1; then
            echo -e "   ${GREEN}✅ Docker Compose is available${NC}"
        else
            echo -e "   ${YELLOW}⚠️  Docker Compose not available${NC}"
        fi
    else
        echo -e "   ${YELLOW}⚠️  Docker not installed${NC}"
    fi

    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if $all_good; then
        echo -e "${GREEN}🎉 ${BOLD}All core components are properly configured!${NC}"
        echo -e "${CYAN}   Your Nexus Orchestrator is ready to use.${NC}"
        echo ""
        echo -e "${BLUE}💡 ${BOLD}Next Steps:${NC}"
        echo -e "   ${CYAN}• Use 'Nexus Management' to start your nodes${NC}"
        echo -e "   ${CYAN}• Docker config will auto-generate when needed${NC}"
    else
        echo -e "${YELLOW}⚠️  ${BOLD}Some components need attention.${NC}"
        echo -e "${CYAN}   Please complete the missing configurations above.${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -rn 1
}

