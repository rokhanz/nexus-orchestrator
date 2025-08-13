#!/bin/bash
# Author: Rokhanz
# Date: August 13, 2025
# License: MIT
# Description: Node Management - Integrated with unified wallet/node system

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## node_management_menu - Main node management menu with hierarchy
node_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}🖥️  NODE MANAGEMENT${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════${NC}"
        echo ""

        # Show current wallet and node status
        show_node_management_status

        echo -e "${WHITE}🌐 Choose your node management action:${NC}"
        echo ""
        PS3="$(echo -e "${YELLOW}🔢 Enter your choice: ${NC}")"
        select opt in "🚀 Start Single Node" "🔥 Start All Nodes" "⏹️  Stop Node(s)" "📊 Node Statistics" "🔍 Nexus Version Info" "🚪 Back to Main Menu"; do
            case $opt in
                "🚀 Start Single Node")
                    echo -e "${CYAN}🚀 Starting single node...${NC}"
                    start_single_node_menu
                    break
                    ;;
                "🔥 Start All Nodes")
                    echo -e "${CYAN}🔥 Starting all nodes...${NC}"
                    start_all_nodes
                    break
                    ;;
                "⏹️  Stop Node(s)")
                    echo -e "${CYAN}⏹️  Stopping nodes...${NC}"
                    stop_nodes_menu
                    break
                    ;;
                "📊 Node Statistics")
                    echo -e "${CYAN}📊 Displaying node statistics...${NC}"
                    show_node_statistics
                    break
                    ;;
                "🔍 Nexus Version Info")
                    echo -e "${CYAN}🔍 Showing Nexus version info...${NC}"
                    show_nexus_version_info
                    break
                    ;;
                "🚪 Back to Main Menu")
                    echo -e "${GREEN}↩️ Returning to main menu...${NC}"
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Invalid choice. Please select 1-6.${NC}"
                    sleep 1
                    ;;
            esac
        done
    done
}

## show_node_management_status - Show current wallet and node status
show_node_management_status() {
    local credentials_file="$WORKDIR/config/credentials.json"

    if [[ -f "$credentials_file" ]]; then
        local current_wallet
        local node_count
        current_wallet=$(jq -r '.wallet_address // "Not set"' "$credentials_file" 2>/dev/null)
        node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")

        echo -e "${GREEN}📊 Current Status:${NC}"
        echo -e "   💳 Wallet: ${YELLOW}$current_wallet${NC}"
        echo -e "   🖥️  Nodes: ${YELLOW}$node_count configured${NC}"
        echo ""

        if [[ "$node_count" -eq 0 ]]; then
            echo -e "${YELLOW}⚠️  No nodes configured. Please setup wallet & nodes first.${NC}"
            echo ""
        fi
    else
        echo -e "${RED}❌ No wallet/nodes configured${NC}"
        echo -e "${WHITE}Please go to Wallet Management to setup first${NC}"
        echo ""
    fi
}

## start_single_node_menu - Start a single node
start_single_node_menu() {
    local credentials_file="$WORKDIR/config/credentials.json"

    if [[ ! -f "$credentials_file" ]]; then
        echo -e "${RED}❌ No wallet/nodes configured!${NC}"
        echo -e "${WHITE}Please setup wallet & nodes first in Wallet Management${NC}"
        wait_for_keypress
        return
    fi

    local node_count
    node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")

    if [[ "$node_count" -eq 0 ]]; then
        echo -e "${RED}❌ No node IDs configured!${NC}"
        echo -e "${WHITE}Please add node IDs in Wallet Management first${NC}"
        wait_for_keypress
        return
    fi

    clear
    echo -e "${CYAN}🚀 START SINGLE NODE${NC}"
    echo -e "${LIGHT_BLUE}══════════════════${NC}"
    echo ""

    echo -e "${WHITE}Select node to start:${NC}"
    local nodes_array
    readarray -t nodes_array < <(jq -r '.node_ids[]' "$credentials_file")

    PS3="$(echo -e "${YELLOW}Select node: ${NC}")"
    select selected_node in "${nodes_array[@]}" "🚪 Back"; do
        if [[ "$selected_node" == "🚪 Back" ]]; then
            return
        elif [[ -n "$selected_node" ]]; then
            echo -e "${CYAN}🚀 Starting node: $selected_node${NC}"
            start_node_with_id "$selected_node"
            break
        else
            echo -e "${RED}❌ Invalid selection${NC}"
        fi
    done
}

## start_all_nodes - Start all configured nodes
start_all_nodes() {
    local credentials_file="$WORKDIR/config/credentials.json"

    if [[ ! -f "$credentials_file" ]]; then
        echo -e "${RED}❌ No wallet/nodes configured!${NC}"
        wait_for_keypress
        return
    fi

    local node_count
    node_count=$(jq '.node_ids | length' "$credentials_file" 2>/dev/null || echo "0")

    if [[ "$node_count" -eq 0 ]]; then
        echo -e "${RED}❌ No node IDs configured!${NC}"
        wait_for_keypress
        return
    fi

    echo -e "${CYAN}🔥 Starting all $node_count nodes...${NC}"
    echo ""

    local nodes_array
    readarray -t nodes_array < <(jq -r '.node_ids[]' "$credentials_file")

    for node_id in "${nodes_array[@]}"; do
        echo -e "${YELLOW}🚀 Starting node: $node_id${NC}"
        start_node_with_id "$node_id"
        echo ""
        sleep 2
    done

    echo -e "${GREEN}✅ All nodes started!${NC}"
    wait_for_keypress
}

## start_node_with_id - Start docker container with specific node ID
start_node_with_id() {
    local node_id="$1"
    local credentials_file="$WORKDIR/config/credentials.json"
    local wallet_address

    wallet_address=$(jq -r '.wallet_address' "$credentials_file" 2>/dev/null)

    if [[ -z "$wallet_address" || "$wallet_address" == "null" ]]; then
        echo -e "${RED}❌ No wallet address found!${NC}"
        return 1
    fi

    # Create container name from node ID (replace special chars)
    local container_name
    container_name="nexus_node_$(echo "$node_id" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')"

    echo -e "${CYAN}🐳 Starting Docker container: $container_name${NC}"

    # Check if container already exists
    if docker ps -a --format "table {{.Names}}" | grep -q "^$container_name$"; then
        echo -e "${YELLOW}⚠️  Container exists, removing old container...${NC}"
        docker rm -f "$container_name" 2>/dev/null || true
    fi

    # Start new container
    if docker run -d \
        --name "$container_name" \
        --restart unless-stopped \
        -e WALLET_ADDRESS="$wallet_address" \
        -e NODE_ID="$node_id" \
        nexusxyz/nexus-cli:latest; then
        echo -e "${GREEN}✅ Node started successfully!${NC}"
        echo -e "   Container: ${YELLOW}$container_name${NC}"
        echo -e "   Node ID: ${YELLOW}$node_id${NC}"
        echo -e "   Wallet: ${YELLOW}$wallet_address${NC}"
    else
        echo -e "${RED}❌ Failed to start node!${NC}"
        return 1
    fi
}

## stop_nodes_menu - Stop running nodes
stop_nodes_menu() {
    clear
    echo -e "${CYAN}⏹️  STOP NODES${NC}"
    echo -e "${LIGHT_BLUE}═════════════${NC}"
    echo ""

    # Get all nexus containers (include all patterns)
    local containers
    containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" 2>/dev/null | grep -E "(nexus_node|nexus-node)" || echo "")

    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}⚠️  No running Nexus nodes found${NC}"
        wait_for_keypress
        return
    fi

    echo -e "${WHITE}Running Nexus nodes:${NC}"
    local container_array
    readarray -t container_array <<< "$containers"

    for container in "${container_array[@]}"; do
        [[ -n "$container" ]] && echo -e "   🐳 $container"
    done
    echo ""

    PS3="$(echo -e "${YELLOW}Choose action: ${NC}")"
    select action in "⏹️  Stop All Nodes" "🎯 Stop Specific Node" "🚪 Back"; do
        case $action in
            "⏹️  Stop All Nodes")
                echo -e "${CYAN}⏹️  Stopping all nodes...${NC}"
                for container in "${container_array[@]}"; do
                    [[ -n "$container" ]] && {
                        echo -e "   Stopping $container..."
                        docker stop "$container" >/dev/null 2>&1 || true
                    }
                done
                echo -e "${GREEN}✅ All nodes stopped!${NC}"
                wait_for_keypress
                return
                ;;
            "🎯 Stop Specific Node")
                echo -e "${WHITE}Select node to stop:${NC}"
                PS3="$(echo -e "${YELLOW}Select container: ${NC}")"
                select container_to_stop in "${container_array[@]}" "🚪 Cancel"; do
                    if [[ "$container_to_stop" == "🚪 Cancel" ]]; then
                        break
                    elif [[ -n "$container_to_stop" ]]; then
                        echo -e "${CYAN}⏹️  Stopping $container_to_stop...${NC}"
                        docker stop "$container_to_stop" >/dev/null 2>&1 || true
                        echo -e "${GREEN}✅ Node stopped!${NC}"
                        wait_for_keypress
                        return
                    fi
                done
                ;;
            "🚪 Back")
                return
                ;;
        esac
    done
}

## show_node_statistics - Show statistics of running nodes
show_node_statistics() {
    clear
    echo -e "${CYAN}📊 NODE STATISTICS${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════${NC}"
    echo ""

    # Get all nexus containers (include all patterns: nexus_node_, nexus-node-, etc.)
    local containers
    containers=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null | grep -E "(nexus_node|nexus-node)" || echo "")

    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}⚠️  No running Nexus nodes found${NC}"
        wait_for_keypress
        return
    fi

    echo -e "${WHITE}Running Nexus Nodes:${NC}"
    echo ""

    local container_array
    readarray -t container_array <<< "$containers"

    for container in "${container_array[@]}"; do
        [[ -n "$container" ]] || continue

        echo -e "${CYAN}🐳 Container: $container${NC}"

        # Get container status
        local status
        status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        echo -e "   Status: ${GREEN}$status${NC}"

        # Get uptime
        local started
        started=$(docker inspect --format='{{.State.StartedAt}}' "$container" 2>/dev/null || echo "unknown")
        echo -e "   Started: ${YELLOW}$started${NC}"

        # Get resource usage
        local stats
        if stats=$(docker stats --no-stream --format "{{.CPUPerc}} {{.MemUsage}}" "$container" 2>/dev/null); then
            local cpu_usage memory_usage
            cpu_usage=$(echo "$stats" | awk '{print $1}')
            memory_usage=$(echo "$stats" | awk '{print $2}')
            echo -e "   CPU: ${YELLOW}$cpu_usage${NC}"
            echo -e "   Memory: ${YELLOW}$memory_usage${NC}"
        fi

        echo ""
    done

    wait_for_keypress
}

## show_nexus_version_info - Show Nexus CLI version information
show_nexus_version_info() {
    clear
    echo -e "${CYAN}🔍 NEXUS VERSION INFO${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════${NC}"
    echo ""

    echo -e "${WHITE}Docker Image Information:${NC}"
    echo -e "   Image: ${YELLOW}nexusxyz/nexus-cli:latest${NC}"
    echo ""

    # Try to get version from a temporary container
    echo -e "${CYAN}Getting version information...${NC}"
    if docker run --rm nexusxyz/nexus-cli:latest --version 2>/dev/null; then
        echo ""
    else
        echo -e "${YELLOW}⚠️  Unable to get version directly${NC}"
        echo -e "${WHITE}This is normal - Nexus CLI runs interactively${NC}"
    fi

    # Show image details
    echo -e "${WHITE}Image Details:${NC}"
    if docker images nexusxyz/nexus-cli:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null; then
        echo ""
    else
        echo -e "${YELLOW}⚠️  Image not found locally${NC}"
        echo -e "${WHITE}Run docker pull nexusxyz/nexus-cli:latest to download${NC}"
    fi

    wait_for_keypress
}
