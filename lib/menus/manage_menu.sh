#!/bin/bash

# manage_menu.sh - Management Menu Module for Nexus Orchestrator
# Version: 4.0.0 - Enhanced management operations with improved UX

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
# shellcheck source=lib/progress.sh
source "$(dirname "${BASH_SOURCE[0]}")/../progress.sh"
# shellcheck source=lib/wrappers/docker_wrapper.sh
source "$(dirname "${BASH_SOURCE[0]}")/../wrappers/docker_wrapper.sh"
# shellcheck source=lib/port_manager.sh
source "$(dirname "${BASH_SOURCE[0]}")/../port_manager.sh"
# shellcheck source=lib/docker_memory_optimizer.sh
source "$(dirname "${BASH_SOURCE[0]}")/../docker_memory_optimizer.sh"

# =============================================================================
# MANAGEMENT MENU FUNCTIONS
# =============================================================================

manage_menu() {
    while true; do
        clear
        show_banner
        show_section_header "Node Management" "⚙️"

        # Show current node status
        show_node_status
        echo ""

        # Menu options
        echo -e "${CYAN}${BOLD}📋 MANAGEMENT OPTIONS${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 🚀 Start All Nodes             ${CYAN}(Launch all configured provers)${NC}"
        echo -e "  ${GREEN}2.${NC} ⏹️  Stop All Nodes              ${CYAN}(Gracefully stop all provers)${NC}"
        echo -e "  ${GREEN}3.${NC} 🔄 Restart All Nodes           ${CYAN}(Restart all prover services)${NC}"
        echo -e "  ${GREEN}4.${NC} 📊 Show Node Status            ${CYAN}(Detailed status information)${NC}"
        echo -e "  ${GREEN}5.${NC} 📋 View Node Logs              ${CYAN}(Check prover logs)${NC}"
        echo -e "  ${GREEN}6.${NC} 🔧 Individual Node Control     ${CYAN}(Manage specific nodes)${NC}"
        echo -e "  ${GREEN}7.${NC} 📈 Performance Metrics         ${CYAN}(View performance stats)${NC}"
        echo -e "  ${GREEN}8.${NC} 🔄 Update Nodes                ${CYAN}(Update to latest version)${NC}"
        echo -e "  ${GREEN}9.${NC} 🔥 Port Management             ${CYAN}(UFW firewall configuration)${NC}"
        echo -e "  ${GREEN}C.${NC} 🧹 Cache Cleanup               ${CYAN}(Memory optimization & cleanup)${NC}"
        echo ""
        echo -e "  ${GREEN}0.${NC} ↩️  Back to Main Menu           ${CYAN}(Return to main menu)${NC}"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        read -rp "$(echo -e "${BOLD}Please select an option [0-9/C]:${NC} ")" choice
        echo ""

        case "$choice" in
            1)
                start_all_nodes
                ;;
            2)
                stop_all_nodes
                ;;
            3)
                restart_all_nodes
                ;;
            4)
                show_detailed_node_status
                ;;
            5)
                view_node_logs
                ;;
            6)
                individual_node_control
                ;;
            7)
                show_performance_metrics
                ;;
            8)
                update_nodes
                ;;
            9)
                port_management_menu
                ;;
            [Cc])
                cache_cleanup_menu
                ;;
            0)
                log_activity "Returning to main menu from node management"
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-9 or C.${NC}"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# NODE STATUS DISPLAY
# =============================================================================

show_node_status() {
    echo -e "${CYAN}${BOLD}🖥️  NODE STATUS OVERVIEW${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"

    # Check if Docker Compose file exists
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "  ${RED}❌ Docker configuration not found${NC}"
        echo -e "  ${YELLOW}💡 Please generate Docker config in Setup menu first${NC}"
        echo -e "  ${CYAN}   Go to: Main Menu → Setup & Configuration → Generate Docker Config${NC}"
        return 1
    fi

    # Verify Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "  ${RED}❌ Docker not available${NC}"
        echo -e "  ${YELLOW}💡 Please install Docker first${NC}"
        return 1
    fi

    # Get running containers
    local running_containers
    running_containers=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" 2>/dev/null | wc -l)

    # Get total configured containers
    local total_containers
    total_containers=$(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null | wc -l)

    # Status summary
    local status_color="$RED"
    local status_text="Offline"
    if [[ $running_containers -gt 0 ]]; then
        if [[ $running_containers -eq $total_containers ]]; then
            status_color="$GREEN"
            status_text="All Online"
        else
            status_color="$YELLOW"
            status_text="Partial Online"
        fi
    fi

    printf "  %-20s %b%s%b\n" "Overall Status:" "$status_color" "$status_text" "$NC"
    printf "  %-20s %b%d/%d%b\n" "Running Nodes:" "$CYAN" "$running_containers" "$total_containers" "$NC"

    # Show individual container status
    if [[ $total_containers -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}Individual Node Status:${NC}"

        docker-compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null | while read -r service; do
            local container_status
            container_status=$(get_container_status "$service")

            if [[ "$container_status" =~ ^Up ]]; then
                printf "    %-15s %b✅ Running%b   %s\n" "$service" "$GREEN" "$NC" "$container_status"
            else
                printf "    %-15s %b❌ Stopped%b   %s\n" "$service" "$RED" "$NC" "$container_status"
            fi
        done
    fi
}

# =============================================================================
# NODE CONTROL FUNCTIONS
# =============================================================================

start_all_nodes() {
    show_section_header "Start All Nodes" "🚀"

    # Prerequisites check
    if ! check_prerequisites; then
        return 1
    fi

    echo -e "${CYAN}Starting all Nexus prover nodes with enhanced port management...${NC}"
    echo ""

    # Use enhanced start with auto port management
    if enhanced_start_containers; then
        echo ""
        echo -e "${GREEN}✅ Enhanced startup completed successfully!${NC}"
        show_running_containers
    else
        handle_error "Enhanced startup failed"
        return 1
    fi

    read -rp "Press Enter to continue..."
}

stop_all_nodes() {
    show_section_header "Stop All Nodes" "⏹️"

    echo -e "${CYAN}Stopping all Nexus prover nodes with enhanced port management...${NC}"
    echo ""

    # Check if any containers are running
    local running_count
    running_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    if [[ $running_count -eq 0 ]]; then
        echo -e "${YELLOW}ℹ️  No running nodes found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${YELLOW}⚠️  This will stop $running_count running node(s)${NC}"
    read -rp "Are you sure? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Operation cancelled${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    # Use enhanced stop with port management options
    if enhanced_stop_containers; then
        echo ""
        echo -e "${GREEN}✅ Enhanced shutdown completed successfully!${NC}"
    else
        log_warning "Enhanced shutdown encountered issues"
    fi

    read -rp "Press Enter to continue..."
}

restart_all_nodes() {
    show_section_header "Restart All Nodes" "🔄"

    echo -e "${CYAN}Restarting all Nexus prover nodes...${NC}"
    echo ""

    init_multi_step 3

    next_step "Stopping existing containers"
    docker-compose -f "$DOCKER_COMPOSE_FILE" down >/dev/null 2>&1

    next_step "Starting containers with fresh configuration"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans; then
        log_success "All containers restarted successfully"
    else
        handle_error "Failed to restart containers"
        return 1
    fi

    next_step "Verifying restart"
    sleep 5

    local running_count
    running_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    if [[ $running_count -gt 0 ]]; then
        complete_multi_step
        echo ""
        echo -e "${GREEN}✅ $running_count node(s) restarted successfully${NC}"
        show_running_containers
    else
        handle_error "No containers running after restart"
        return 1
    fi

    read -rp "Press Enter to continue..."
}

show_detailed_node_status() {
    show_section_header "Detailed Node Status" "📊"

    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "${RED}❌ Docker configuration not found${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${CYAN}Detailed status for all configured nodes:${NC}"
    echo ""

    # Table header
    printf "%-20s %-15s %-20s %-15s %s\n" "CONTAINER" "STATUS" "UPTIME" "PORTS" "HEALTH"
    echo "────────────────────────────────────────────────────────────────────────────────"

    docker-compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null | while read -r service; do
        local status
        status=$(get_container_status "$service")

        local uptime="N/A"
        local ports="N/A"
        local health="Unknown"

        if [[ "$status" =~ ^Up ]]; then
            # Extract uptime
            if [[ "$status" =~ Up[[:space:]]+([^[:space:]]+[[:space:]]*[^[:space:]]*) ]]; then
                uptime="${BASH_REMATCH[1]}"
            fi

            # Get port mappings
            ports=$(docker port "$service" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')

            # Check health
            local health_status
            health_status=$(docker inspect "$service" --format='{{.State.Health.Status}}' 2>/dev/null)
            case "$health_status" in
                "healthy")
                    health="✅ Healthy"
                    ;;
                "unhealthy")
                    health="❌ Unhealthy"
                    ;;
                "starting")
                    health="🔄 Starting"
                    ;;
                *)
                    health="❓ No healthcheck"
                    ;;
            esac

            printf "%-20s %b%-15s%b %-20s %-15s %s\n" "$service" "$GREEN" "Running" "$NC" "$uptime" "$ports" "$health"
        else
            printf "%-20s %b%-15s%b %-20s %-15s %s\n" "$service" "$RED" "Stopped" "$NC" "$uptime" "$ports" "$health"
        fi
    done

    echo ""
    read -rp "Press Enter to continue..."
}

view_node_logs() {
    show_section_header "View Node Logs" "📋"

    # Get list of services
    local services
    services=$(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null)

    if [[ -z "$services" ]]; then
        echo -e "${RED}❌ No services configured${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${CYAN}Select a node to view logs:${NC}"
    echo ""

    local service_array=()
    local count=1

    while IFS= read -r service; do
        service_array+=("$service")
        local status
        status=$(get_container_status "$service")

        if [[ "$status" =~ ^Up ]]; then
            echo -e "  ${GREEN}$count.${NC} $service ${GREEN}(Running)${NC}"
        else
            echo -e "  ${YELLOW}$count.${NC} $service ${RED}(Stopped)${NC}"
        fi
        ((count++))
    done <<< "$services"

    echo -e "  ${GREEN}0.${NC} Back to management menu"
    echo ""

    read -rp "Select node [0-$((count-1))]: " choice

    if [[ "$choice" == "0" ]]; then
        return 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -lt $count ]]; then
        local selected_service="${service_array[$((choice-1))]}"
        echo ""
        echo -e "${CYAN}Showing logs for: ${BOLD}$selected_service${NC}"
        echo -e "${YELLOW}Press Ctrl+C to exit log view${NC}"
        echo ""

        sleep 2
        # Handle Ctrl+C gracefully
        docker logs -f --tail 50 "$selected_service" 2>/dev/null
        local exit_code=$?

        # Handle Ctrl+C (130) and normal exit codes
        if [[ $exit_code -eq 130 ]]; then
            echo ""
            echo -e "${YELLOW}📊 Log monitoring stopped${NC}"
        elif [[ $exit_code -ne 0 ]]; then
            echo -e "${RED}❌ Failed to get logs for $selected_service${NC}"
        fi
    else
        echo -e "${RED}❌ Invalid selection${NC}"
        sleep 2
    fi

    read -rp "Press Enter to continue..."
}

individual_node_control() {
    show_section_header "Individual Node Control" "🔧"

    # Similar to view_node_logs but for control actions
    local services
    services=$(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null)

    if [[ -z "$services" ]]; then
        echo -e "${RED}❌ No services configured${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${CYAN}Select a node to control:${NC}"
    echo ""

    local service_array=()
    local count=1

    while IFS= read -r service; do
        service_array+=("$service")
        local status
        status=$(get_container_status "$service")

        if [[ "$status" =~ ^Up ]]; then
            echo -e "  ${GREEN}$count.${NC} $service ${GREEN}(Running)${NC}"
        else
            echo -e "  ${YELLOW}$count.${NC} $service ${RED}(Stopped)${NC}"
        fi
        ((count++))
    done <<< "$services"

    echo -e "  ${GREEN}0.${NC} Back to management menu"
    echo ""

    read -rp "Select node [0-$((count-1))]: " choice

    if [[ "$choice" == "0" ]]; then
        return 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -lt $count ]]; then
        local selected_service="${service_array[$((choice-1))]}"
        control_single_node "$selected_service"
    else
        echo -e "${RED}❌ Invalid selection${NC}"
        sleep 2
    fi
}

control_single_node() {
    local service="$1"

    while true; do
        clear
        show_banner
        show_section_header "Control Node: $service" "🔧"

        # Show node status
        local status
        status=$(get_container_status "$service")

        echo -e "${CYAN}Current Status: ${BOLD}$status${NC}"
        echo ""

        # Control options
        echo -e "${CYAN}${BOLD}📋 CONTROL OPTIONS${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        if [[ "$status" =~ ^Up ]]; then
            echo -e "  ${GREEN}1.${NC} ⏹️  Stop Node                   ${CYAN}(Gracefully stop this node)${NC}"
            echo -e "  ${GREEN}2.${NC} 🔄 Restart Node               ${CYAN}(Restart this node)${NC}"
            echo -e "  ${GREEN}3.${NC} 📋 View Logs                  ${CYAN}(Show recent logs)${NC}"
            echo -e "  ${GREEN}4.${NC} 📊 Show Details               ${CYAN}(Detailed information)${NC}"
        else
            echo -e "  ${GREEN}1.${NC} 🚀 Start Node                 ${CYAN}(Start this node)${NC}"
            echo -e "  ${GREEN}2.${NC} 📋 View Logs                  ${CYAN}(Show recent logs)${NC}"
            echo -e "  ${GREEN}3.${NC} 📊 Show Details               ${CYAN}(Detailed information)${NC}"
        fi

        echo ""
        echo -e "  ${GREEN}0.${NC} ↩️  Back to Node Selection      ${CYAN}(Return to node list)${NC}"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        read -rp "$(echo -e "${BOLD}Please select an option:${NC} ")" action_choice
        echo ""

        case "$action_choice" in
            1)
                if [[ "$status" =~ ^Up ]]; then
                    stop_single_node "$service"
                else
                    start_single_node "$service"
                fi
                ;;
            2)
                if [[ "$status" =~ ^Up ]]; then
                    restart_single_node "$service"
                else
                    # For stopped nodes: option 2 is View Logs
                    echo -e "${CYAN}Showing logs for: ${BOLD}$service${NC}"
                    echo -e "${YELLOW}Press Ctrl+C to exit log view${NC}"
                    echo ""
                    sleep 2
                    # Handle Ctrl+C gracefully
                    docker logs -f --tail 50 "$service" 2>/dev/null
                    local exit_code=$?

                    # Handle Ctrl+C (130) and normal exit codes
                    if [[ $exit_code -eq 130 ]]; then
                        echo ""
                        echo -e "${YELLOW}📊 Log monitoring stopped${NC}"
                    elif [[ $exit_code -ne 0 ]]; then
                        echo -e "${RED}❌ Failed to get logs for $service${NC}"
                    fi
                fi
                ;;
            3)
                if [[ "$status" =~ ^Up ]]; then
                    echo -e "${CYAN}Showing logs for: ${BOLD}$service${NC}"
                    echo -e "${YELLOW}Press Ctrl+C to exit log view${NC}"
                    echo ""
                    sleep 2
                    # Handle Ctrl+C gracefully
                    docker logs -f --tail 50 "$service" 2>/dev/null
                    local exit_code=$?

                    # Handle Ctrl+C (130) and normal exit codes
                    if [[ $exit_code -eq 130 ]]; then
                        echo ""
                        echo -e "${YELLOW}📊 Log monitoring stopped${NC}"
                    elif [[ $exit_code -ne 0 ]]; then
                        echo -e "${RED}❌ Failed to get logs for $service${NC}"
                    fi
                else
                    # For stopped nodes: option 3 is Show Details
                    show_single_node_details "$service"
                fi
                ;;
            4)
                # For running nodes: option 4 is Show Details
                if [[ "$status" =~ ^Up ]]; then
                    show_single_node_details "$service"
                else
                    echo -e "${RED}❌ Invalid option for stopped node${NC}"
                    sleep 2
                fi
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                sleep 2
                ;;
        esac
    done
}

start_single_node() {
    local service="$1"
    echo -e "${CYAN}Starting node: ${BOLD}$service${NC}"

    if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d "$service"; then
        log_success "Node $service started successfully"
    else
        handle_error "Failed to start node $service"
    fi

    read -rp "Press Enter to continue..."
}

stop_single_node() {
    local service="$1"
    echo -e "${CYAN}Stopping node: ${BOLD}$service${NC}"
    echo ""

    # Check if service exists
    if ! docker ps -a --filter "name=$service" --format "{{.Names}}" | grep -q "^$service$"; then
        echo -e "${YELLOW}⚠️  Container $service not found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    if docker-compose -f "$DOCKER_COMPOSE_FILE" stop "$service" 2>/dev/null; then
        log_success "Node $service stopped successfully"
    else
        echo -e "${YELLOW}⚠️  Docker compose stop failed, trying direct stop...${NC}"
        if docker stop "$service" 2>/dev/null; then
            log_success "Node $service stopped directly"
        else
            handle_error "Failed to stop node $service"
        fi
    fi

    read -rp "Press Enter to continue..."
}

restart_single_node() {
    local service="$1"
    echo -e "${CYAN}Restarting node: ${BOLD}$service${NC}"

    if docker-compose -f "$DOCKER_COMPOSE_FILE" restart "$service"; then
        log_success "Node $service restarted successfully"
    else
        handle_error "Failed to restart node $service"
    fi

    read -rp "Press Enter to continue..."
}

show_single_node_details() {
    local service="$1"
    echo -e "${CYAN}${BOLD}Detailed Information for: $service${NC}"
    echo ""

    # Container details
    echo -e "${BOLD}Container Information:${NC}"
    docker inspect "$service" --format='
  Image: {{.Config.Image}}
  Created: {{.Created}}
  Status: {{.State.Status}}
  Started: {{.State.StartedAt}}
  Restart Count: {{.RestartCount}}
' 2>/dev/null || echo "  Container not found"

    echo ""

    # Resource usage
    echo -e "${BOLD}Resource Usage:${NC}"
    docker stats "$service" --no-stream --format '
  CPU: {{.CPUPerc}}
  Memory: {{.MemUsage}}
  Network I/O: {{.NetIO}}
  Block I/O: {{.BlockIO}}
' 2>/dev/null || echo "  Resource information not available"

    read -rp "Press Enter to continue..."
}

show_performance_metrics() {
    show_section_header "Performance Metrics" "📈"

    echo -e "${CYAN}Real-time performance metrics for all nodes:${NC}"
    echo ""

    # Check if any containers are running
    local running_containers
    running_containers=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$running_containers" ]]; then
        echo -e "${YELLOW}ℹ️  No running nodes found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${YELLOW}Press Ctrl+C to exit metrics view${NC}"
    echo ""
    sleep 2

    # Show live stats
    docker stats "$running_containers" 2>/dev/null || {
        echo -e "${RED}❌ Failed to get performance metrics${NC}"
    }

    read -rp "Press Enter to continue..."
}

update_nodes() {
    show_section_header "Update Nodes" "🔄"

    echo -e "${CYAN}Updating Nexus nodes to latest version...${NC}"
    echo ""

    init_multi_step 4

    next_step "Pulling latest Docker images"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" pull; then
        log_success "Latest images pulled successfully"
    else
        handle_error "Failed to pull latest images"
        return 1
    fi

    next_step "Stopping current containers"
    docker-compose -f "$DOCKER_COMPOSE_FILE" down >/dev/null 2>&1

    next_step "Starting with updated images"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans; then
        log_success "Containers started with updated images"
    else
        handle_error "Failed to start updated containers"
        return 1
    fi

    next_step "Verifying update"
    sleep 5

    local running_count
    running_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    if [[ $running_count -gt 0 ]]; then
        complete_multi_step
        echo ""
        echo -e "${GREEN}✅ $running_count node(s) updated successfully${NC}"
    else
        handle_error "No containers running after update"
        return 1
    fi

    read -rp "Press Enter to continue..."
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

check_credentials() {
    # Check if wallet address is configured
    local wallet_address
    wallet_address=$(read_config_value "wallet_address" 2>/dev/null)

    if [[ -z "$wallet_address" || "$wallet_address" == "null" ]]; then
        return 1
    fi

    # Check if node IDs are configured
    local node_ids
    node_ids=$(read_config_value "node_id" 2>/dev/null)
    local node_count
    node_count=$(echo "$node_ids" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$node_count" -eq 0 ]]; then
        return 1
    fi

    return 0
}

check_prerequisites() {
    # Force regenerate docker-compose to sync with current Node IDs
    if ! ensure_docker_compose_exists "true"; then
        echo -e "${RED}❌ Failed to sync Docker configuration with current Node IDs${NC}"
        echo -e "${YELLOW}💡 Please check your Node ID configuration${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    if ! check_credentials; then
        echo -e "${RED}❌ Node configuration incomplete${NC}"
        echo -e "${YELLOW}💡 Please configure wallet and node IDs first${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    return 0
}

show_running_containers() {
    echo ""
    echo -e "${CYAN}${BOLD}Running Containers:${NC}"
    docker ps --filter "name=nexus-node" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || {
        echo -e "${RED}❌ Failed to get container information${NC}"
    }
}

# =============================================================================
# PORT MANAGEMENT MENU
# =============================================================================

port_management_menu() {
    while true; do
        clear
        show_section_header "Port Management" "🔥"

        echo -e "${CYAN}Current UFW Firewall Status:${NC}"
        show_port_status
        echo ""

        echo -e "${CYAN}${BOLD}📋 PORT MANAGEMENT OPTIONS${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 🔥 Open All Ports              ${CYAN}(Auto-open ports from docker-compose)${NC}"
        echo -e "  ${GREEN}2.${NC} 🔒 Close All Ports             ${CYAN}(Close Nexus-related ports)${NC}"
        echo -e "  ${GREEN}3.${NC} 📊 Show Port Status            ${CYAN}(Detailed port information)${NC}"
        echo -e "  ${GREEN}4.${NC} 🔍 Validate Ports              ${CYAN}(Check port availability)${NC}"
        echo -e "  ${GREEN}5.${NC} 💾 Backup UFW Rules            ${CYAN}(Save current firewall config)${NC}"
        echo ""
        echo -e "  ${GREEN}0.${NC} ↩️  Back to Management Menu     ${CYAN}(Return to previous menu)${NC}"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        read -rp "$(echo -e "${BOLD}Please select an option [0-5]:${NC} ")" choice
        echo ""

        case "$choice" in
            1)
                auto_open_ports
                read -rp "Press Enter to continue..."
                ;;
            2)
                auto_close_ports
                read -rp "Press Enter to continue..."
                ;;
            3)
                show_port_status
                read -rp "Press Enter to continue..."
                ;;
            4)
                validate_ports
                read -rp "Press Enter to continue..."
                ;;
            5)
                backup_ufw_rules
                read -rp "Press Enter to continue..."
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-5.${NC}"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f manage_menu show_node_status start_all_nodes stop_all_nodes restart_all_nodes
export -f show_detailed_node_status view_node_logs individual_node_control
export -f control_single_node start_single_node stop_single_node restart_single_node
export -f show_single_node_details show_performance_metrics update_nodes
export -f port_management_menu show_running_containers
export -f check_prerequisites show_running_containers

log_success "Node management menu module loaded successfully"
