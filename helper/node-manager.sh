#!/bin/bash
# Author: Rokhanz
# Date: August 11, 2025
# License: MIT
# Description: Node Management with hierarchy submenu - preserves working Docker config

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## node_management_menu - Main node management menu with hierarchy
node_management_menu() {
    while true; do
        display_colorful_header "NODE MANAGEMENT" "Comprehensive Node Management System"

        # Show current credentials if available
        if detect_existing_credentials &> /dev/null; then
            display_status_badge "success" "Credentials detected"
            echo ""
        fi

        display_menu_separator
        echo -e "${BRIGHT_YELLOW}🌐 Choose your node management action:${NC}"
        echo ""
        PS3="$(echo -e "${BRIGHT_CYAN}🔢 Enter your choice: ${NC}")"
        select opt in "🚀 Start with Existing Node ID" "📝 Register New Node" "🔄 Re-register Existing Wallet" "🔄 Multi-Node Manager" "📊 Node Statistics" "🔍 Nexus Version Info" "🚪 Back to Main Menu"; do
            case $opt in
                "🚀 Start with Existing Node ID")
                    echo -e "${CYAN}🚀 Starting with existing Node ID...${NC}"
                    start_existing_node_menu
                    break
                    ;;
                "📝 Register New Node")
                    echo -e "${CYAN}📝 Registering new node...${NC}"
                    register_new_node_menu
                    break
                    ;;
                "🔄 Re-register Existing Wallet")
                    echo -e "${CYAN}🔄 Re-registering existing wallet...${NC}"
                    reregister_existing_wallet_menu
                    break
                    ;;
                "🔄 Multi-Node Manager")
                    echo -e "${CYAN}🔄 Opening multi-node manager...${NC}"
                    multi_node_manager_menu
                    break
                    ;;
                "📊 Node Statistics")
                    echo -e "${CYAN}📊 Displaying node statistics...${NC}"
                    node_statistics_menu
                    break
                    ;;
                "🔍 Nexus Version Info")
                    echo -e "${CYAN}🔍 Checking Nexus version information...${NC}"
                    nexus_version_info_menu
                    break
                    ;;
                "🚪 Back to Main Menu")
                    echo -e "${GREEN}↩️ Returning to main menu...${NC}"
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Invalid choice. Please select 1-7.${NC}"
                    sleep 1
                    ;;
            esac
        done
    done
}

## start_existing_node_menu - Start node with existing ID
start_existing_node_menu() {
    display_colorful_header "START WITH EXISTING NODE ID" "Quick Start with Saved Credentials"

    # Check for existing credentials
    # shellcheck disable=SC2153 # CREDENTIALS_FILE is defined in common.sh
    if [[ -f "$CREDENTIALS_FILE" ]] && command -v jq &> /dev/null; then
        local node_ids
        node_ids=$(jq -r '.node_ids[]? // empty' "$CREDENTIALS_FILE" 2>/dev/null || echo "")

        if [[ -n "$node_ids" ]]; then
            echo -e "${BRIGHT_GREEN}Available Node IDs:${NC}"
            local counter=1
            while IFS= read -r node_id; do
                [[ -n "$node_id" ]] || continue
                printf "   ${BRIGHT_CYAN}%d.${NC} %s\n" "$counter" "$node_id"
                ((counter++))
            done <<< "$node_ids"
            echo ""

            display_menu_separator
            echo -e "${BRIGHT_YELLOW}🚀 Choose Node ID option:${NC}"
            echo ""
            PS3="$(echo -e "${BRIGHT_CYAN}🔢 Enter your choice: ${NC}")"
            select opt in "Use saved Node ID" "Enter new Node ID" "🚪 Back"; do
                case $opt in
                    "Use saved Node ID")
                        echo -e "${CYAN}📋 Using saved Node ID...${NC}"
                        select_saved_node_id "$node_ids"
                        return
                        ;;
                    "Enter new Node ID")
                        echo -e "${CYAN}✏️ Entering manual Node ID...${NC}"
                        enter_manual_node_id
                        return
                        ;;
                    "🚪 Back")
                        echo -e "${GREEN}↩️ Returning to previous menu...${NC}"
                        return
                        ;;
                    *)
                        echo -e "${RED}❌ Invalid choice. Please select 1-3.${NC}"
                        sleep 1
                        ;;
                esac
            done
        else
            log_warn "No saved node IDs found"
            enter_manual_node_id
        fi
    else
        log_warn "No credentials file found or jq not available"
        enter_manual_node_id
    fi
}

## select_saved_node_id - Select from saved node IDs
select_saved_node_id() {
    local node_ids="$1"

    echo ""
    echo -e "${WHITE}📋 Pilih Node ID untuk dijalankan:${NC}"
    echo ""

    local node_array=()
    while IFS= read -r node_id; do
        [[ -n "$node_id" ]] && node_array+=("$node_id")
    done <<< "$node_ids"

    node_array+=("🚪 Kembali")

    PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
    select node_choice in "${node_array[@]}"; do
        if [[ "$node_choice" == "🚪 Kembali" ]]; then
            echo -e "${GREEN}↩️ Kembali ke menu sebelumnya...${NC}"
            return
        elif [[ -n "$node_choice" ]]; then
            echo ""
            echo -e "${CYAN}🚀 Memulai node dengan ID: $node_choice${NC}"
            log_info "Starting node with ID: $node_choice"

            # Ensure Docker image is available and check for updates
            auto_pull_image_if_missing || {
                log_error_display "Failed to ensure Docker image availability"
                read -r -p "Press Enter to continue..."
                return
            }

            # Use preserved working configuration
            if start_node_with_proxy "$node_choice"; then
                log_info "Node $node_choice started successfully!"
                echo ""
                echo "Monitor logs with: docker logs nexus-node-$node_choice -f"
                echo ""
                echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
                read -r -n 1
                clear
            else
                log_error_display "Failed to start node $node_choice"
                echo ""
                echo -e "${BRIGHT_RED}Press any key to return to menu...${NC}"
                read -r -n 1
                clear
            fi
            return
        else
            echo -e "${RED}❌ Invalid selection${NC}"
        fi
    done
}

## enter_manual_node_id - Enter node ID manually
enter_manual_node_id() {
    echo ""
    read -r -p "$(echo -e "${YELLOW}Enter Node ID: ${NC}")" node_id

    # Validate node ID (should be numeric)
    if [[ ! "$node_id" =~ ^[0-9]+$ ]]; then
        log_error_display "Invalid Node ID format. Must be numeric."
        read -r -p "Press Enter to try again..."
        return
    fi

    echo ""
    log_info "Starting node with ID: $node_id"

    # Ensure Docker image is available
    auto_pull_image_if_missing || {
        log_error_display "Failed to ensure Docker image availability"
        read -r -p "Press Enter to continue..."
        return
    }

    # Use preserved working configuration
    if start_node_with_proxy "$node_id"; then
        log_info "Node $node_id started successfully!"
        echo ""
        echo "Monitor logs with: docker logs nexus-node-$node_id -f"

        # Optionally save this node ID
        echo ""
        read -r -p "$(echo -e "${YELLOW}Save this Node ID to credentials? (y/N): ${NC}")" -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -r -p "$(echo -e "${YELLOW}Enter wallet address: ${NC}")" wallet_address
            echo ""  # Add newline after wallet input
            if [[ -n "$wallet_address" ]]; then
                save_credentials "$wallet_address" "$node_id"
                echo -e "${GREEN}✅ Node ID saved to credentials${NC}"
            else
                echo -e "${YELLOW}⚠️ Wallet address empty, not saving${NC}"
            fi
        fi
        echo ""
        echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
        read -r -n 1
        clear
    else
        log_error_display "Failed to start node $node_id"
        echo ""
        echo -e "${BRIGHT_RED}Press any key to return to menu...${NC}"
        read -r -n 1
        clear
    fi
}

## register_new_node_menu - Enhanced registration with Opsi B
register_new_node_menu() {
    display_colorful_header "REGISTER NEW NODE (ENHANCED)" "Opsi B: Direct CLI Registration"

    echo -e "${BRIGHT_YELLOW}🎯 OPSI B: Direct CLI Registration (Recommended)${NC}"
    echo -e "${BRIGHT_GREEN}✅ Benefits:${NC}"
    echo -e "   ${CYAN}• Faster registration (no Docker overhead)${NC}"
    echo -e "   ${CYAN}• Lightweight installation${NC}"
    echo -e "   ${CYAN}• Clean separation: register once, compose anytime${NC}"
    echo -e "   ${CYAN}• Better resource efficiency${NC}"
    echo ""

    read -r -p "$(echo -e "${BRIGHT_CYAN}Enter wallet address (0x...): ${NC}")" wallet_address

    # Basic validation for Ethereum address
    if [[ ! "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        display_status_badge "error" "Invalid wallet address format"
        read -r -p "Press Enter to continue..."
        return
    fi

    echo ""
    display_menu_separator
    echo -e "${BRIGHT_YELLOW}🔧 Choose registration method:${NC}"
    echo ""
    PS3="$(echo -e "${BRIGHT_CYAN}🔢 Select method: ${NC}")"
    select method in "Direct CLI (Opsi B - Recommended)" "Docker Method (Fallback)" "Back"; do
        case $method in
            "Direct CLI (Opsi B - Recommended)")
                echo ""
                register_node_direct_cli "$wallet_address"
                break
                ;;
            "Docker Method (Fallback)")
                echo ""
                register_new_node_docker "$wallet_address"
                echo ""
                echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
                read -r -n 1
                clear
                break
                ;;
            "Back")
                clear
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice${NC}"
                ;;
        esac
    done
}

## register_new_node_docker - Original Docker registration method (fallback)
register_new_node_docker() {
    local wallet_address="$1"

    echo -e "${CYAN}📝 REGISTER NEW NODE (Docker Method)${NC}"
    echo ""

    log_info "Registering wallet: $wallet_address"

    # Ensure Docker image is available (auto-pull if missing)
    auto_pull_image_if_missing || {
        log_error_display "Failed to ensure Docker image availability"
        read -r -p "Press Enter to continue..."
        return
    }

    # Create temporary docker container for registration
    local temp_container="nexus-register-temp"

    # Clean up any existing temp container
    docker rm -f "$temp_container" &> /dev/null || true

    echo ""
    log_info "Starting registration process..."

    # Run registration in container with preserved working config
    if docker run --rm -it \
        --name "$temp_container" \
        -e "NEXUS_HOME=$NEXUS_HOME" \
        -e "RUST_LOG=$RUST_LOG_LEVEL" \
        -v "nexus_register_temp:$NEXUS_HOME" \
        "$NEXUS_IMAGE" \
        register-user --wallet-address "$wallet_address"; then

        echo ""
        log_info "Wallet registration successful. Now registering node..."

        # Register node
        if docker run --rm -it \
            --name "$temp_container" \
            -e "NEXUS_HOME=$NEXUS_HOME" \
            -e "RUST_LOG=$RUST_LOG_LEVEL" \
            -v "nexus_register_temp:$NEXUS_HOME" \
            "$NEXUS_IMAGE" \
            register-node; then

            echo ""
            log_info "Node registration successful!"

            # Extract node ID from credentials
            local node_id
            node_id=$(docker run --rm \
                -v "nexus_register_temp:$NEXUS_HOME" \
                "$NEXUS_IMAGE" \
                sh -c "cat $NEXUS_HOME/credentials.json | grep -o '\"node_id\":[^,}]*' | cut -d':' -f2 | tr -d '\"'") || true

            if [[ -n "$node_id" ]]; then
                log_info "New Node ID: $node_id"

                                # Save credentials
                save_credentials_with_node_id "$wallet_address" "$new_node_id" "direct_cli"

                echo ""
                read -r -p "$(echo -e "${YELLOW}Start this node now? (Y/n): ${NC}")" -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    start_node_with_proxy "$node_id"
                fi
            else
                log_warn "Could not extract Node ID from registration"
            fi
        else
            log_error_display "Node registration failed"
        fi
    else
        log_error_display "Wallet registration failed"
    fi

    # Cleanup temporary volume
    docker volume rm nexus_register_temp &> /dev/null || true
}

## multi_node_manager_menu - Manage multiple nodes
multi_node_manager_menu() {
    display_colorful_header "MULTI-NODE MANAGER" "Manage Multiple Nexus Nodes"

    # Show running containers
    local running_nodes
    running_nodes=$(docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "")

    if [[ -n "$running_nodes" ]]; then
        echo -e "${BRIGHT_GREEN}🚀 Running Nodes:${NC}"
        echo "$running_nodes" | sed '1s/^/   /' | sed '2,$s/^/   /'
        echo ""
    else
        display_status_badge "info" "No nodes currently running"
        echo ""
    fi

    display_menu_separator
    echo -e "${BRIGHT_YELLOW}🔄 Choose multi-node management action:${NC}"
    echo ""
    PS3="$(echo -e "${BRIGHT_CYAN}🔢 Enter your choice: ${NC}")"
    select opt in "🚀 Start All Saved Nodes" "⏹️ Stop All Nodes" "📊 Status All Nodes" "🗑️ Remove Node" "🚪 Back"; do
        case $opt in
            "🚀 Start All Saved Nodes")
                echo -e "${CYAN}🚀 Starting all saved nodes...${NC}"
                start_all_saved_nodes
                break
                ;;
            "⏹️ Stop All Nodes")
                echo -e "${CYAN}⏹️ Stopping all nodes...${NC}"
                stop_all_nodes
                break
                ;;
            "📊 Status All Nodes")
                echo -e "${CYAN}📊 Displaying status of all nodes...${NC}"
                show_all_nodes_status
                break
                ;;
            "🗑️ Remove Node")
                echo -e "${CYAN}🗑️ Removing node...${NC}"
                remove_node_menu
                break
                ;;
            "🚪 Back")
                echo -e "${GREEN}↩️ Returning to previous menu...${NC}"
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please select 1-5.${NC}"
                sleep 1
                ;;
        esac
    done
}

## start_all_saved_nodes - Start all nodes from credentials (ENHANCED MULTI-NODE)
start_all_saved_nodes() {
    echo ""
    log_info "Starting all saved nodes with enhanced multi-node support..."

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_warn "No credentials file found"
        read -r -p "Press Enter to continue..."
        return
    fi

    if ! command -v jq &> /dev/null; then
        log_warn "jq not available, cannot parse credentials"
        read -r -p "Press Enter to continue..."
        return
    fi

    local node_ids
    node_ids=$(jq -r '.node_ids[]? // empty' "$CREDENTIALS_FILE" 2>/dev/null || echo "")

    if [[ -z "$node_ids" ]]; then
        log_warn "No node IDs found in credentials"
        read -r -p "Press Enter to continue..."
        return
    fi

    # Convert to array for easier handling
    local node_array=()
    while IFS= read -r node_id; do
        [[ -n "$node_id" ]] && node_array+=("$node_id")
    done <<< "$node_ids"

    echo -e "${BRIGHT_GREEN}📋 Found ${#node_array[@]} nodes to start:${NC}"
    local counter=1
    for node_id in "${node_array[@]}"; do
        printf "   ${BRIGHT_CYAN}%d.${NC} Node ID: %s\n" "$counter" "$node_id"
        ((counter++))
    done
    echo ""

    # Ask user for start method
    echo -e "${BRIGHT_YELLOW}🚀 Choose starting method:${NC}"
    echo ""
    PS3="$(echo -e "${BRIGHT_CYAN}🔢 Select method: ${NC}")"
    select method in "Multi-Node Compose (Recommended)" "Sequential Individual Start" "Back"; do
        case $method in
            "Multi-Node Compose (Recommended)")
                echo -e "${CYAN}🔄 Generating multi-node compose...${NC}"
                start_all_nodes_with_multicompose "${node_array[@]}"
                echo ""
                echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
                read -r -n 1
                clear
                break
                ;;
            "Sequential Individual Start")
                echo -e "${CYAN}🔄 Starting nodes sequentially...${NC}"
                start_all_nodes_sequential "${node_array[@]}"
                echo ""
                echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
                read -r -n 1
                clear
                break
                ;;
            "Back")
                echo -e "${GREEN}↩️ Returning to previous menu...${NC}"
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice${NC}"
                ;;
        esac
    done
}

## start_all_nodes_with_multicompose - Start all nodes using single multi-service compose (Using common.sh function)
start_all_nodes_with_multicompose() {
    local node_ids=("$@")

    echo ""
    echo -e "${BRIGHT_YELLOW}🔄 Using enhanced multi-node compose from common.sh...${NC}"

    # Use the function from common.sh which has all the proper logic
    start_multiple_nodes_with_compose "${node_ids[@]}"
}

## start_all_nodes_sequential - Start nodes one by one (Using common.sh individual function)
start_all_nodes_sequential() {
    local node_ids=("$@")

    echo ""
    echo -e "${BRIGHT_YELLOW}🔄 Starting nodes sequentially using common.sh functions...${NC}"

    for node_id in "${node_ids[@]}"; do
        echo ""
        echo -e "${CYAN}🚀 Starting Node $node_id...${NC}"

        # Use common.sh function directly
        if start_node_individual "$node_id"; then
            echo -e "${GREEN}✅ Node $node_id started successfully${NC}"
        else
            echo -e "${RED}❌ Failed to start Node $node_id${NC}"
        fi

        sleep 3  # Wait between starts
    done

    echo ""
    echo -e "${GREEN}✅ Sequential start completed!${NC}"
    echo -e "${YELLOW}📊 Final status check:${NC}"
    docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}



## stop_all_nodes - Stop all running nexus nodes (Enhanced)
stop_all_nodes() {
    echo ""
    log_info "Stopping all nexus nodes with enhanced multi-node support..."

    # Check for multi-compose first
    local multi_compose="$WORKDIR/docker-compose-multi.yml"
    if [[ -f "$multi_compose" ]]; then
        echo -e "${YELLOW}🔍 Found multi-node compose file${NC}"
        echo ""
        echo -e "${BRIGHT_YELLOW}🛑 Choose stopping method:${NC}"
        echo ""
        PS3="$(echo -e "${BRIGHT_CYAN}🔢 Select method: ${NC}")"
        select method in "Stop Multi-Compose Services" "Stop Individual Containers" "Both Methods" "Back"; do
            case $method in
                "Stop Multi-Compose Services")
                    echo -e "${CYAN}🛑 Stopping multi-compose services...${NC}"
                    stop_multicompose_nodes
                    break
                    ;;
                "Stop Individual Containers")
                    echo -e "${CYAN}🛑 Stopping individual containers...${NC}"
                    stop_individual_containers
                    break
                    ;;
                "Both Methods")
                    echo -e "${CYAN}🛑 Stopping with both methods...${NC}"
                    stop_multicompose_nodes
                    stop_individual_containers
                    break
                    ;;
                "Back")
                    echo -e "${GREEN}↩️ Returning to previous menu...${NC}"
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Invalid choice${NC}"
                    ;;
            esac
        done
    else
        echo -e "${YELLOW}🔍 No multi-compose file found, using individual method${NC}"
        stop_individual_containers
    fi

    read -r -p "Press Enter to continue..."
}

## stop_multicompose_nodes - Stop nodes using multi-compose
stop_multicompose_nodes() {
    local multi_compose="$WORKDIR/docker-compose-multi.yml"

    if [[ ! -f "$multi_compose" ]]; then
        echo -e "${RED}❌ Multi-compose file not found${NC}"
        return 1
    fi

    echo -e "${CYAN}🛑 Stopping multi-node compose...${NC}"

    cd "$WORKDIR" || {
        echo -e "${RED}❌ Failed to change to workdir${NC}"
        return 1
    }

    if docker-compose -f docker-compose-multi.yml down; then
        echo -e "${GREEN}✅ Multi-compose stopped successfully${NC}"
    else
        echo -e "${RED}❌ Failed to stop multi-compose${NC}"
    fi
}

## stop_individual_containers - Stop individual containers
stop_individual_containers() {
    local containers
    containers=$(docker ps --filter "name=nexus-node-" -q 2>/dev/null || echo "")

    if [[ -z "$containers" ]]; then
        log_warn "No running nexus nodes found"
    else
        echo -e "${CYAN}🛑 Stopping individual containers...${NC}"
        echo "$containers" | xargs docker stop
        log_info "All nexus node containers stopped"
    fi
}

## show_all_nodes_status - Show status of all nodes
show_all_nodes_status() {
    clear
    echo -e "${CYAN}📊 ALL NODES STATUS${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # Show saved node IDs
    if [[ -f "$CREDENTIALS_FILE" ]] && command -v jq &> /dev/null; then
        local node_ids
        node_ids=$(jq -r '.node_ids[]? // empty' "$CREDENTIALS_FILE" 2>/dev/null || echo "")

        if [[ -n "$node_ids" ]]; then
            echo -e "${GREEN}Saved Node IDs:${NC}"
            echo "$node_ids" | while IFS= read -r node_id; do
                [[ -n "$node_id" ]] || continue
                local status="❌ Stopped"
                if docker ps --filter "name=nexus-node-$node_id" | grep -q "nexus-node-$node_id"; then
                    status="✅ Running"
                fi
                echo "  Node $node_id: $status"
            done
            echo ""
        fi
    fi

    # Show all running containers
    echo -e "${GREEN}All Running Nexus Containers:${NC}"
    docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers found"

    echo ""
    echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
    read -r -n 1
    clear
}

## remove_node_menu - Remove a node
remove_node_menu() {
    echo ""
    echo -e "${RED}🗑️ REMOVE NODE${NC}"
    echo ""

    # Show current nodes
    if [[ -f "$CREDENTIALS_FILE" ]] && command -v jq &> /dev/null; then
        local node_ids
        node_ids=$(jq -r '.node_ids[]? // empty' "$CREDENTIALS_FILE" 2>/dev/null || echo "")

        if [[ -n "$node_ids" ]]; then
            echo -e "${YELLOW}Current Node IDs:${NC}"
            local counter=1
            while IFS= read -r node_id; do
                [[ -n "$node_id" ]] || continue
                printf "   %d. %s\n" "$counter" "$node_id"
                ((counter++))
            done <<< "$node_ids"
            echo ""
        fi
    fi

    read -r -p "$(echo -e "${YELLOW}Enter Node ID to remove: ${NC}")" node_id

    if [[ ! "$node_id" =~ ^[0-9]+$ ]]; then
        log_error_display "Invalid Node ID format"
        read -r -p "Press Enter to continue..."
        return
    fi

    echo ""
    echo -e "${RED}⚠️ This will:${NC}"
    echo "  - Stop the container"
    echo "  - Remove the container"
    echo "  - Remove the volume"
    echo "  - Remove from credentials"
    echo ""

    read -r -p "$(echo -e "${RED}Are you sure? (type 'yes' to confirm): ${NC}")" confirm

    if [[ "$confirm" == "yes" ]]; then
        # Stop and remove container
        docker stop "nexus-node-$node_id" &> /dev/null || true
        docker rm "nexus-node-$node_id" &> /dev/null || true
        docker volume rm "nexus_data_$node_id" &> /dev/null || true

        # Remove from credentials
        if [[ -f "$CREDENTIALS_FILE" ]] && command -v jq &> /dev/null; then
            local temp_file
            temp_file=$(mktemp)
            jq --arg node "$node_id" '.node_ids = (.node_ids // []) - [$node]' "$CREDENTIALS_FILE" > "$temp_file" && mv "$temp_file" "$CREDENTIALS_FILE"
        fi

        log_info "Node $node_id removed successfully"
    else
        log_info "Operation cancelled"
    fi

    echo ""
    echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
    read -r -n 1
    clear
}

## node_statistics_menu - Show node statistics
node_statistics_menu() {
    display_colorful_header "NODE STATISTICS" "Performance & Resource Monitoring"

    # Basic statistics
    local total_saved=0
    local total_running=0

    if [[ -f "$CREDENTIALS_FILE" ]] && command -v jq &> /dev/null; then
        total_saved=$(jq -r '.node_ids | length' "$CREDENTIALS_FILE" 2>/dev/null || echo "0")
    fi

    total_running=$(docker ps --filter "name=nexus-node-" -q 2>/dev/null | wc -l)

    echo -e "${BRIGHT_GREEN}📈 Summary:${NC}"
    echo -e "   ${GRAY}Total Saved Nodes:${NC} ${BRIGHT_CYAN}$total_saved${NC}"
    echo -e "   ${GRAY}Currently Running:${NC} ${BRIGHT_GREEN}$total_running${NC}"
    echo ""

    # Resource usage
    echo -e "${BRIGHT_GREEN}💻 Resource Usage:${NC}"
    if command -v docker &> /dev/null; then
        # Get list of Nexus containers first, then get their stats
        local nexus_containers
        nexus_containers=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null || echo "")

        if [[ -n "$nexus_containers" ]]; then
            echo -e "   ${GRAY}Container${NC}                ${GRAY}CPU%${NC}     ${GRAY}Memory${NC}"
            echo -e "   ${DARK_GRAY}${DIM}────────────────────  ──────  ─────────────${NC}"

            # Get stats for each container individually (fallback method)
            while IFS= read -r container_name; do
                [[ -n "$container_name" ]] || continue

                local stats_output
                stats_output=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" "$container_name" 2>/dev/null || printf "unavailable\tunavailable")

                local cpu_usage memory_usage
                cpu_usage=$(echo "$stats_output" | cut -f1)
                memory_usage=$(echo "$stats_output" | cut -f2)

                printf "   ${CYAN}%-20s${NC} ${YELLOW}%-8s${NC} ${GREEN}%-15s${NC}\n" "$container_name" "$cpu_usage" "$memory_usage"
            done <<< "$nexus_containers"
        else
            display_status_badge "info" "No running containers to display stats"
        fi
    else
        display_status_badge "error" "Docker not available"
    fi

    echo ""
    display_menu_separator
    echo -e "${BRIGHT_YELLOW}Available Actions:${NC}"
    echo ""
    PS3="$(echo -e "${BRIGHT_CYAN}🔢 Choose action: ${NC}")"
    select action in "🔄 Refresh Statistics" "📊 Detailed Container Info" "🏥 Health Check" "🚪 Back"; do
        case $action in
            "🔄 Refresh Statistics")
                clear
                node_statistics_menu
                return
                ;;
            "📊 Detailed Container Info")
                show_detailed_container_info
                echo ""
                echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
                read -r -n 1
                clear
                break
                ;;
            "🏥 Health Check")
                system_health_check
                echo ""
                echo -e "${BRIGHT_CYAN}Press any key to return to menu...${NC}"
                read -r -n 1
                clear
                break
                ;;
            "🚪 Back")
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice${NC}"
                sleep 1
                ;;
        esac
    done
}

## show_detailed_container_info - Show detailed container information
show_detailed_container_info() {
    echo ""
    echo -e "${BRIGHT_YELLOW}📊 Detailed Container Information:${NC}"
    echo ""

    local containers
    containers=$(docker ps --filter "name=nexus-node-" -q 2>/dev/null || echo "")

    if [[ -z "$containers" ]]; then
        display_status_badge "info" "No Nexus containers running"
        return
    fi

    while IFS= read -r container_id; do
        [[ -n "$container_id" ]] || continue

        local container_name
        container_name=$(docker inspect "$container_id" --format '{{.Name}}' | cut -c2-)

        echo -e "${BRIGHT_CYAN}Container: $container_name${NC}"
        echo -e "${GRAY}   ID: $container_id${NC}"

        local status
        status=$(docker inspect "$container_id" --format '{{.State.Status}}')

        case "$status" in
            "running")
                display_status_badge "success" "Status: $status"
                ;;
            "exited")
                display_status_badge "error" "Status: $status"
                ;;
            *)
                display_status_badge "warning" "Status: $status"
                ;;
        esac

        # Get uptime
        local started_at
        started_at=$(docker inspect "$container_id" --format '{{.State.StartedAt}}' | cut -d'T' -f1)
        echo -e "${GRAY}   Started: $started_at${NC}"

        # Get port mapping
        local ports
        ports=$(docker port "$container_id" 2>/dev/null | head -1 || echo "none")
        echo -e "${GRAY}   Ports: $ports${NC}"

        # Get image
        local image
        image=$(docker inspect "$container_id" --format '{{.Config.Image}}')
        echo -e "${GRAY}   Image: $image${NC}"

        # Get proxy information
        local proxy_info
        proxy_info=$(docker inspect "$container_id" --format '{{range .Config.Env}}{{if or (contains . "HTTP_PROXY") (contains . "HTTPS_PROXY") (contains . "http_proxy") (contains . "https_proxy")}}{{.}} {{end}}{{end}}' 2>/dev/null || echo "")

        if [[ -n "$proxy_info" ]]; then
            echo -e "${GRAY}   Proxy: $proxy_info${NC}"
        else
            echo -e "${GRAY}   Proxy: No proxy configured${NC}"
        fi

        echo ""
    done <<< "$containers"
}

## reregister_existing_wallet_menu - Re-register web wallet to CLI
reregister_existing_wallet_menu() {
    clear
    echo -e "${CYAN}🔄 RE-REGISTER EXISTING WALLET${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}ℹ️ This option is for wallets registered via web (app.nexus.xyz)${NC}"
    echo -e "${YELLOW}   Web node IDs cannot be used directly in CLI${NC}"
    echo -e "${YELLOW}   You need to re-register to get CLI-compatible node ID${NC}"
    echo ""

    # Check for existing credentials
    local credentials_file="$WORKDIR/config/credentials.json"
    if [[ -f "$credentials_file" ]]; then
        local wallet_address
        wallet_address=$(jq -r '.wallet_address // empty' "$credentials_file" 2>/dev/null || echo "")

        if [[ -n "$wallet_address" ]]; then
            echo -e "${GREEN}✅ Found existing wallet: ${YELLOW}$wallet_address${NC}"
            echo ""

            echo -e "${WHITE}🔄 Pilih aksi re-register wallet:${NC}"
            echo ""
            PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
            select yn in "Yes, re-register" "No, enter different wallet" "Back"; do
                case $yn in
                    "Yes, re-register")
                        echo -e "${CYAN}🔄 Re-registering wallet: $wallet_address${NC}"
                        reregister_wallet "$wallet_address"
                        break
                        ;;
                    "No, enter different wallet")
                        echo -e "${CYAN}✏️ Memasukkan wallet berbeda...${NC}"
                        reregister_wallet_interactive
                        break
                        ;;
                    "Back")
                        echo -e "${GREEN}↩️ Kembali ke menu sebelumnya...${NC}"
                        return
                        ;;
                    *)
                        echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-3.${NC}"
                        sleep 1
                        ;;
                esac
            done
        else
            echo -e "${RED}❌ Invalid credentials file format${NC}"
            echo ""
            reregister_wallet_interactive
        fi
    else
        echo -e "${YELLOW}⚠️ No existing credentials found${NC}"
        echo ""
        reregister_wallet_interactive
    fi
}

## install_nexus_cli_direct - Install Nexus CLI directly to system (Opsi B)
install_nexus_cli_direct() {
    echo -e "${CYAN}🔧 INSTALLING NEXUS CLI TO SYSTEM${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}This will install Nexus CLI directly to your system${NC}"
    echo -e "${YELLOW}⚡ Benefits: Fast, lightweight, no Docker overhead${NC}"
    echo ""

    read -r -p "$(echo -e "${YELLOW}Continue with installation? (Y/n): ${NC}")" -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        return 1  # Return failure code when installation is cancelled
    fi

    # Check if already installed
    if command -v nexus-network &> /dev/null; then
        echo -e "${GREEN}✅ Nexus CLI already installed!${NC}"
        local version
        version=$(nexus-network --version 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}Version: $version${NC}"
        echo ""
        read -r -p "$(echo -e "${YELLOW}Reinstall anyway? (y/N): ${NC}")" -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0  # Return success if CLI already installed and user doesn't want to reinstall
        fi
    fi

    echo -e "${CYAN}📥 Downloading and installing Nexus CLI...${NC}"

    # Download and install using official script
    if curl -fsSL https://cli.nexus.xyz | sh; then
        echo ""
        echo -e "${GREEN}✅ Nexus CLI installed successfully!${NC}"

        # Add to PATH if needed
        if ! command -v nexus-network &> /dev/null; then
            echo -e "${YELLOW}⚠️ Adding Nexus CLI to PATH...${NC}"
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
            export PATH="$HOME/.local/bin:$PATH"
        fi

        echo -e "${GREEN}✅ Installation complete!${NC}"
        echo ""
        echo -e "${YELLOW}💡 You can now register nodes quickly without Docker overhead${NC}"
    else
        echo -e "${RED}❌ Failed to install Nexus CLI${NC}"
        echo -e "${YELLOW}💡 Falling back to Docker method...${NC}"
        return 1
    fi
}

## register_node_direct_cli - Register using direct CLI (Opsi B)
register_node_direct_cli() {
    local wallet_address="$1"

    echo -e "${CYAN}🔄 REGISTERING WITH DIRECT CLI${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # Check if CLI is installed
    if ! command -v nexus-network &> /dev/null; then
        echo -e "${YELLOW}⚠️ Nexus CLI not found. Installing...${NC}"
        if ! install_nexus_cli_direct; then
            echo -e "${RED}❌ CLI installation failed or cancelled.${NC}"
            echo ""
            echo -e "${BRIGHT_YELLOW}� Choose fallback option:${NC}"
            echo ""
            PS3="$(echo -e "${BRIGHT_CYAN}🔢 Select option: ${NC}")"
            select fallback_option in "Try Docker Method" "Retry CLI Installation" "Back to Menu"; do
                case $fallback_option in
                    "Try Docker Method")
                        echo -e "${CYAN}🐳 Switching to Docker method...${NC}"
                        register_new_node_docker "$wallet_address"
                        return
                        ;;
                    "Retry CLI Installation")
                        echo -e "${CYAN}🔄 Retrying CLI installation...${NC}"
                        if install_nexus_cli_direct; then
                            break
                        else
                            echo -e "${RED}❌ CLI installation failed again.${NC}"
                            return 1
                        fi
                        ;;
                    "Back to Menu")
                        echo -e "${GREEN}↩️ Returning to previous menu...${NC}"
                        return 1
                        ;;
                    *)
                        echo -e "${RED}❌ Invalid choice${NC}"
                        ;;
                esac
            done
        fi

        # Double-check that CLI is now available after installation
        if ! command -v nexus-network &> /dev/null; then
            echo -e "${RED}❌ CLI installation completed but command not found.${NC}"
            echo -e "${YELLOW}⚠️ You may need to reload your shell or add CLI to PATH manually.${NC}"
            echo -e "${YELLOW}💡 Try: source ~/.bashrc or restart terminal${NC}"
            echo ""
            echo -e "${BRIGHT_YELLOW}🔧 Choose next action:${NC}"
            echo ""
            PS3="$(echo -e "${BRIGHT_CYAN}🔢 Select option: ${NC}")"
            select path_option in "Try Docker Method Instead" "Manual PATH Fix" "Back to Menu"; do
                case $path_option in
                    "Try Docker Method Instead")
                        echo -e "${CYAN}🐳 Switching to Docker method...${NC}"
                        register_new_node_docker "$wallet_address"
                        return
                        ;;
                    "Manual PATH Fix")
                        echo -e "${YELLOW}Manual PATH fix instructions:${NC}"
                        echo "1. Run: source ~/.bashrc"
                        echo "2. Or restart your terminal"
                        echo "3. Then try registration again"
                        return 1
                        ;;
                    "Back to Menu")
                        echo -e "${GREEN}↩️ Returning to previous menu...${NC}"
                        return 1
                        ;;
                    *)
                        echo -e "${RED}❌ Invalid choice${NC}"
                        ;;
                esac
            done
        fi
    fi

    echo -e "${YELLOW}Step 1: Registering wallet with direct CLI...${NC}"
    echo -e "${CYAN}Wallet: $wallet_address${NC}"
    echo ""

    # Register user
    if nexus-network register-user --wallet-address "$wallet_address"; then
        echo ""
        echo -e "${GREEN}✅ Wallet registered successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to register wallet${NC}"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Step 2: Generating new node ID...${NC}"

    # Register node and capture output
    local register_output
    if register_output=$(nexus-network register-node 2>&1); then
        echo ""
        echo -e "${GREEN}✅ Node registration successful!${NC}"

        # Extract node ID from output
        local new_node_id
        new_node_id=$(echo "$register_output" | grep -oP 'node with ID: \K\d+' || echo "")

        if [[ -z "$new_node_id" ]]; then
            echo -e "${YELLOW}⚠️ Could not extract node ID automatically${NC}"
            echo -e "${YELLOW}Registration output:${NC}"
            echo "$register_output"
            echo ""
            read -r -p "$(echo -e "${YELLOW}Please enter the node ID manually: ${NC}")" new_node_id
        fi

        if [[ -n "$new_node_id" && "$new_node_id" =~ ^[0-9]+$ ]]; then
            echo ""
            echo -e "${GREEN}✅ Node ID obtained: ${YELLOW}$new_node_id${NC}"

            # Step 3: Save credentials
            echo -e "${YELLOW}Step 3: Saving credentials...${NC}"
            mkdir -p "$WORKDIR/config"

            cat > "$WORKDIR/config/credentials.json" << EOF
{
  "wallet_address": "$wallet_address",
  "node_ids": ["$new_node_id"],
  "registration_type": "direct_cli",
  "created_at": "$(date -Iseconds)"
}
EOF

            echo -e "${GREEN}✅ Credentials saved to config/credentials.json${NC}"
            echo ""

            # Step 4: Generate docker-compose (but don't start)
            echo -e "${YELLOW}Step 4: Generating docker-compose configuration...${NC}"
            generate_docker_compose_for_node "$new_node_id" "$wallet_address"

            echo ""
            echo -e "${GREEN}🎉 REGISTRATION COMPLETE!${NC}"
            echo -e "${YELLOW}Node ID: $new_node_id${NC}"
            echo -e "${YELLOW}Status: Ready to start${NC}"
            echo ""
            echo -e "${WHITE}🚀 Start node sekarang?${NC}"
            echo ""
            PS3="$(echo -e "${YELLOW}🔢 Pilihan Anda: ${NC}")"
            select yn in "Yes, start now" "No, just save" "Generate compose only"; do
                case $yn in
                    "Yes, start now")
                        echo ""
                        echo -e "${CYAN}🚀 Starting node $new_node_id...${NC}"
                        start_node_with_compose "$new_node_id"
                        break
                        ;;
                    "No, just save")
                        echo -e "${GREEN}✅ Node saved. Start manually anytime with docker compose up${NC}"
                        break
                        ;;
                    "Generate compose only")
                        echo -e "${GREEN}✅ Docker compose generated. Node ready to start.${NC}"
                        break
                        ;;
                    *)
                        echo -e "${RED}❌ Invalid choice${NC}"
                        ;;
                esac
            done

            return 0
        else
            echo -e "${RED}❌ Invalid node ID: $new_node_id${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to register node${NC}"
        echo "$register_output"
        return 1
    fi
}

## generate_docker_compose_for_node - Generate compose for specific node (Using common.sh function)
generate_docker_compose_for_node() {
    local node_id="$1"
    local wallet_address="$2"

    echo -e "${CYAN}📝 Using enhanced compose generation from common.sh...${NC}"

    # Use generate_docker_compose function from common.sh
    generate_docker_compose "$node_id" "$wallet_address"
}

## start_node_with_compose - Start node using generated compose
start_node_with_compose() {
    local node_id="$1"

    echo -e "${CYAN}🚀 Starting node $node_id with docker-compose...${NC}"

    cd "$WORKDIR" || {
        echo -e "${RED}❌ Failed to change to workdir${NC}"
        return 1
    }

    if [[ ! -f "docker-compose.yml" ]]; then
        echo -e "${RED}❌ docker-compose.yml not found${NC}"
        return 1
    fi

    # Start the service
    if docker-compose up -d; then
        echo ""
        echo -e "${GREEN}✅ Node $node_id started successfully!${NC}"

        # Wait and check status
        sleep 3
        if docker ps | grep -q "nexus-node-$node_id"; then
            echo -e "${GREEN}✅ Container is running${NC}"
            echo ""
            echo -e "${YELLOW}📊 Monitor logs with:${NC}"
            echo "  docker logs nexus-node-$node_id -f"
            echo ""
            echo -e "${YELLOW}📊 Quick status check:${NC}"
            docker ps --filter "name=nexus-node-$node_id" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            echo -e "${RED}❌ Container failed to start properly${NC}"
            echo -e "${YELLOW}Check logs: docker logs nexus-node-$node_id${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to start with docker-compose${NC}"
        return 1
    fi
}

## reregister_wallet - Enhanced registration with Opsi B
reregister_wallet() {
    local wallet_address="$1"

    echo -e "${CYAN}🔄 ENHANCED REGISTRATION (OPSI B)${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}Choose registration method:${NC}"
    echo ""
    PS3="$(echo -e "${YELLOW}🔢 Select method: ${NC}")"
    select method in "Direct CLI (Recommended)" "Docker Method (Fallback)" "Back"; do
        case $method in
            "Direct CLI (Recommended)")
                echo ""
                register_node_direct_cli "$wallet_address"
                break
                ;;
            "Docker Method (Fallback)")
                echo ""
                reregister_wallet_docker "$wallet_address"
                break
                ;;
            "Back")
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice${NC}"
                ;;
        esac
    done
}

## reregister_wallet_docker - Original Docker method (fallback)
reregister_wallet_docker() {
    local wallet_address="$1"

    echo -e "${CYAN}🔄 Re-registering wallet with Docker method: $wallet_address${NC}"
    echo ""

    # Auto-pull image if missing
    auto_pull_image_if_missing "$NEXUS_IMAGE"

    # Step 1: Register user (wallet)
    echo -e "${YELLOW}Step 1: Registering wallet...${NC}"
    if ! docker run --rm \
        "$NEXUS_IMAGE" \
        register-user \
        --wallet-address "$wallet_address"; then
        echo -e "${RED}❌ Failed to register wallet${NC}"
        read -r -p "Press Enter to continue..."
        return 1
    fi

    echo ""

    # Step 2: Register node (get new node ID)
    echo -e "${YELLOW}Step 2: Generating new node ID...${NC}"
    local register_output
    if ! register_output=$(docker run --rm "$NEXUS_IMAGE" register-node 2>&1); then
        echo -e "${RED}❌ Failed to register node${NC}"
        echo "$register_output"
        read -r -p "Press Enter to continue..."
        return 1
    fi

    # Extract node ID from output
    local new_node_id
    new_node_id=$(echo "$register_output" | grep -oP 'node with ID: \K\d+' || echo "")

    if [[ -z "$new_node_id" ]]; then
        echo -e "${RED}❌ Could not extract node ID from registration${NC}"
        echo "Registration output: $register_output"
        read -r -p "Press Enter to continue..."
        return 1
    fi

    echo -e "${GREEN}✅ New CLI node ID generated: ${YELLOW}$new_node_id${NC}"
    echo ""

    # Step 3: Save new credentials
    echo -e "${YELLOW}Step 3: Saving new credentials...${NC}"
    mkdir -p "$WORKDIR/config"

    # Create new credentials with the CLI node ID
    cat > "$WORKDIR/config/credentials.json" << EOF
{
  "wallet_address": "$wallet_address",
  "node_ids": ["$new_node_id"],
  "registration_type": "docker_method",
  "created_at": "$(date -Iseconds)"
}
EOF

    echo -e "${GREEN}✅ Credentials saved to config/credentials.json${NC}"
    echo ""

    # Step 4: Ask to start immediately
    echo -e "${WHITE}🚀 Mulai proving dengan node ID baru sekarang?${NC}"
    echo ""
    PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
    select yn in "Yes, start now" "No, just save" "Back"; do
        case $yn in
            "Yes, start now")
                echo ""
                echo -e "${CYAN}🚀 Starting node $new_node_id...${NC}"
                start_node_with_proxy "$new_node_id"
                echo ""
                echo -e "${GREEN}✅ Re-registration and start complete!${NC}"
                read -r -p "Press Enter to continue..."
                break
                ;;
            "No, just save")
                echo -e "${GREEN}✅ Re-registration complete! Node ID saved.${NC}"
                read -r -p "Press Enter to continue..."
                break
                ;;
            "Back")
                echo -e "${GREEN}↩️ Kembali ke menu sebelumnya...${NC}"
                break
                ;;
            *)
                echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-3.${NC}"
                sleep 1
                ;;
        esac
    done
}

## reregister_wallet_interactive - Interactive wallet re-registration
reregister_wallet_interactive() {
    echo -e "${YELLOW}Enter your wallet address:${NC}"
    read -r wallet_address

    if [[ -z "$wallet_address" ]]; then
        echo -e "${RED}❌ Wallet address cannot be empty${NC}"
        read -r -p "Press Enter to continue..."
        return 1
    fi

    # Validate wallet format (basic check)
    if [[ ! "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}❌ Invalid wallet address format${NC}"
        echo -e "${YELLOW}Expected format: 0x followed by 40 hex characters${NC}"
        read -r -p "Press Enter to continue..."
        return 1
    fi

    reregister_wallet "$wallet_address"

    read -r -p "Press Enter to continue..."
}

## nexus_version_info_menu - Display comprehensive Nexus version information
nexus_version_info_menu() {
    display_colorful_header "NEXUS VERSION INFORMATION" "System & Version Diagnostics"

    display_nexus_version_info

    display_menu_separator
    echo -e "${BRIGHT_YELLOW}🔧 Available Actions:${NC}"
    echo ""
    PS3="$(echo -e "${BRIGHT_CYAN}🔢 Choose action: ${NC}")"
    select action in "🔄 Refresh Information" "⬇️ Install/Update CLI" "🐳 Pull Latest Docker Image" "🏥 System Health Check" "🚪 Back to Menu"; do
        case $action in
            "🔄 Refresh Information")
                echo -e "${CYAN}🔄 Refreshing version information...${NC}"
                nexus_version_info_menu
                return
                ;;
            "⬇️ Install/Update CLI")
                echo -e "${CYAN}⬇️ Installing/Updating Nexus CLI...${NC}"
                install_or_update_nexus_cli
                read -r -p "Press Enter to continue..."
                break
                ;;
            "🐳 Pull Latest Docker Image")
                echo -e "${CYAN}🐳 Pulling latest Docker image...${NC}"
                pull_latest_docker_image
                read -r -p "Press Enter to continue..."
                break
                ;;
            "🏥 System Health Check")
                echo -e "${CYAN}🏥 Running system health check...${NC}"
                system_health_check
                read -r -p "Press Enter to continue..."
                break
                ;;
            "🚪 Back to Menu")
                echo -e "${GREEN}↩️ Returning to previous menu...${NC}"
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please select 1-5.${NC}"
                sleep 1
                ;;
        esac
    done
}

## install_or_update_nexus_cli - Install or update Nexus CLI
install_or_update_nexus_cli() {
    echo ""
    echo -e "${BRIGHT_YELLOW}🔧 Installing/Updating Nexus CLI...${NC}"
    echo ""

    local current_version
    current_version=$(get_nexus_cli_version)

    if [[ "$current_version" != "not_installed" ]]; then
        echo -e "${YELLOW}Current CLI version: v$current_version${NC}"
        echo -e "${YELLOW}This will update to the latest version.${NC}"
        echo ""
    fi

    read -r -p "$(echo -e "${BRIGHT_CYAN}Continue with installation/update? (Y/n): ${NC}")" -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        return
    fi

    if install_nexus_cli_direct; then
        echo ""
        echo -e "${GREEN}✅ Nexus CLI installation/update completed!${NC}"

        local new_version
        new_version=$(get_nexus_cli_version)
        if [[ "$new_version" != "not_installed" ]]; then
            echo -e "${BRIGHT_GREEN}New version: v$new_version${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to install/update Nexus CLI${NC}"
    fi
}

## pull_latest_docker_image - Pull latest Docker image
pull_latest_docker_image() {
    echo ""
    echo -e "${BRIGHT_YELLOW}🐳 Pulling latest Docker image...${NC}"
    echo ""

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        return 1
    fi

    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker is not running${NC}"
        return 1
    fi

    echo -e "${CYAN}Pulling nexusxyz/nexus-cli:latest...${NC}"

    if docker pull nexusxyz/nexus-cli:latest; then
        echo ""
        echo -e "${GREEN}✅ Docker image updated successfully!${NC}"

        local image_size
        image_size=$(docker images nexusxyz/nexus-cli:latest --format "{{.Size}}" 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}Image size: $image_size${NC}"
    else
        echo -e "${RED}❌ Failed to pull Docker image${NC}"
    fi
}

## system_health_check - Comprehensive system health check
system_health_check() {
    echo ""
    echo -e "${BRIGHT_YELLOW}🏥 Running System Health Check...${NC}"
    echo ""

    local issues_found=0

    # Check disk space
    echo -e "${CYAN}💾 Checking disk space...${NC}"
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [[ $disk_usage -gt 90 ]]; then
        display_status_badge "error" "Disk usage critical: ${disk_usage}%"
        ((issues_found++))
    elif [[ $disk_usage -gt 80 ]]; then
        display_status_badge "warning" "Disk usage high: ${disk_usage}%"
    else
        display_status_badge "success" "Disk usage healthy: ${disk_usage}%"
    fi

    # Check memory
    echo -e "${CYAN}🧠 Checking memory usage...${NC}"
    if command -v free &> /dev/null; then
        local mem_usage
        mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

        if [[ $mem_usage -gt 90 ]]; then
            display_status_badge "error" "Memory usage critical: ${mem_usage}%"
            ((issues_found++))
        elif [[ $mem_usage -gt 80 ]]; then
            display_status_badge "warning" "Memory usage high: ${mem_usage}%"
        else
            display_status_badge "success" "Memory usage healthy: ${mem_usage}%"
        fi
    else
        display_status_badge "warning" "Memory check unavailable"
    fi

    # Check Docker containers
    echo -e "${CYAN}🐳 Checking Docker containers...${NC}"
    local running_containers
    running_containers=$(docker ps --filter "name=nexus-node-" -q 2>/dev/null | wc -l)

    if [[ $running_containers -gt 0 ]]; then
        display_status_badge "success" "$running_containers Nexus containers running"

        # Check for any failed containers
        local failed_containers
        failed_containers=$(docker ps -a --filter "name=nexus-node-" --filter "status=exited" -q 2>/dev/null | wc -l)

        if [[ $failed_containers -gt 0 ]]; then
            display_status_badge "warning" "$failed_containers containers stopped/failed"
        fi
    else
        display_status_badge "info" "No Nexus containers running"
    fi

    # Check network connectivity
    echo -e "${CYAN}🌐 Checking network connectivity...${NC}"
    if ping -c 1 8.8.8.8 &> /dev/null; then
        display_status_badge "success" "Internet connectivity working"
    else
        display_status_badge "error" "No internet connectivity"
        ((issues_found++))
    fi

    # Check for zombie processes
    echo -e "${CYAN}🧟 Checking for zombie processes...${NC}"
    local zombies
    zombies=$(ps aux | awk '$8 ~ /^Z/ { count++ } END { print count+0 }')

    if [[ $zombies -gt 0 ]]; then
        display_status_badge "warning" "$zombies zombie processes found"
    else
        display_status_badge "success" "No zombie processes"
    fi

    echo ""
    echo -e "${BRIGHT_YELLOW}📊 Health Check Summary:${NC}"

    if [[ $issues_found -eq 0 ]]; then
        display_status_badge "success" "System health is excellent!"
    elif [[ $issues_found -eq 1 ]]; then
        display_status_badge "warning" "1 issue found - review recommendations"
    else
        display_status_badge "error" "$issues_found issues found - attention required"
    fi
}
