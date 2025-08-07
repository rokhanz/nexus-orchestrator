#!/bin/bash

# manage_menu.sh - Management Menu Module for Nexus Orchestrator
# Version: 4.0.0 - Enhanced management operations with improved UX

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

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
        echo ""
        echo -e "  ${GREEN}0.${NC} ↩️  Back to Main Menu           ${CYAN}(Return to main menu)${NC}"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        read -rp "$(echo -e "${BOLD}Please select an option [0-8]:${NC} ")" choice
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
            0)
                log_activity "Returning to main menu from node management"
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-8.${NC}"
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

    echo -e "${CYAN}Starting all Nexus prover nodes...${NC}"
    echo ""

    init_multi_step 3

    next_step "Validating configuration"
    if ! docker-compose -f "$DOCKER_COMPOSE_FILE" config >/dev/null 2>&1; then
        handle_error "Invalid Docker Compose configuration"
        return 1
    fi

    next_step "Starting containers"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans; then
        log_success "All containers started successfully"
    else
        handle_error "Failed to start some containers"
        return 1
    fi

    next_step "Verifying startup"
    sleep 5

    # Check if containers are running
    local running_count
    running_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    if [[ $running_count -gt 0 ]]; then
        complete_multi_step
        echo ""
        echo -e "${GREEN}✅ $running_count node(s) started successfully${NC}"
        show_running_containers
    else
        handle_error "No containers are running after startup"
        return 1
    fi

    read -rp "Press Enter to continue..."
}

stop_all_nodes() {
    show_section_header "Stop All Nodes" "⏹️"

    echo -e "${CYAN}Stopping all Nexus prover nodes...${NC}"
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

    init_multi_step 2

    next_step "Gracefully stopping containers"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down; then
        log_success "All containers stopped successfully"
    else
        log_warning "Some containers may not have stopped gracefully"
    fi

    next_step "Verifying shutdown"
    sleep 2

    local remaining_count
    remaining_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    if [[ $remaining_count -eq 0 ]]; then
        complete_multi_step
        echo ""
        echo -e "${GREEN}✅ All nodes stopped successfully${NC}"
    else
        log_warning "$remaining_count containers still running"
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
        docker logs -f --tail 50 "$selected_service" 2>/dev/null || {
            echo -e "${RED}❌ Failed to get logs for $selected_service${NC}"
        }
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
            echo -e "  ${GREEN}4.${NC} 📊 Show Details               ${CYAN}(Detailed information)${NC}"
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
                    echo -e "${RED}❌ Node is not running${NC}"
                    sleep 2
                fi
                ;;
            3)
                if [[ "$status" =~ ^Up ]]; then
                    echo -e "${CYAN}Showing logs for: ${BOLD}$service${NC}"
                    echo -e "${YELLOW}Press Ctrl+C to exit log view${NC}"
                    echo ""
                    sleep 2
                    docker logs -f --tail 50 "$service" 2>/dev/null
                else
                    echo -e "${RED}❌ Node is not running${NC}"
                    sleep 2
                fi
                ;;
            4)
                show_single_node_details "$service"
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

    if docker-compose -f "$DOCKER_COMPOSE_FILE" stop "$service"; then
        log_success "Node $service stopped successfully"
    else
        handle_error "Failed to stop node $service"
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

check_prerequisites() {
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "${RED}❌ Docker Compose configuration not found${NC}"
        echo -e "${YELLOW}💡 Please run setup first${NC}"
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
# EXPORT FUNCTIONS
# =============================================================================

export -f manage_menu show_node_status start_all_nodes stop_all_nodes restart_all_nodes
export -f show_detailed_node_status view_node_logs individual_node_control
export -f control_single_node start_single_node stop_single_node restart_single_node
export -f show_single_node_details show_performance_metrics update_nodes
export -f check_prerequisites show_running_containers

log_success "Node management menu module loaded successfully"
