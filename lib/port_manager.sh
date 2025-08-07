#!/bin/bash

# port_manager.sh - Automatic Port Management for Nexus Orchestrator
# Version: 4.0.0 - Auto UFW management based on docker-compose configuration

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# PORT MANAGEMENT FUNCTIONS
# =============================================================================

# Function to extract ports from docker-compose.yml
get_compose_ports() {
    local compose_file="$1"

    if [[ ! -f "$compose_file" ]]; then
        log_error "Docker compose file not found: $compose_file"
        return 1
    fi

    # Extract external ports (left side of port mapping)
    grep -E '^\s*-\s*"[0-9]+:[0-9]+"' "$compose_file" | \
    sed -E 's/.*"([0-9]+):[0-9]+".*/\1/' | \
    sort -n | uniq
}

# Function to check if UFW port is open
is_ufw_port_open() {
    local port="$1"
    # Check for both individual port and port ranges that include this port
    ufw status | grep -q "${port}/tcp.*ALLOW" 2>/dev/null || \
    ufw status | grep -q "10000:10010/tcp.*ALLOW" 2>/dev/null
}

# Function to open UFW port
open_ufw_port() {
    local port="$1"
    local description="$2"

    if is_ufw_port_open "$port"; then
        log_info "Port $port already open"
        return 0
    fi

    log_info "Opening UFW port $port ($description)"
    if ufw allow "$port/tcp" comment "$description" >/dev/null 2>&1; then
        log_success "✅ Opened port $port/tcp"
        return 0
    else
        log_error "❌ Failed to open port $port/tcp"
        return 1
    fi
}

# Function to close UFW port
close_ufw_port() {
    local port="$1"

    if ! is_ufw_port_open "$port"; then
        log_info "Port $port already closed"
        return 0
    fi

    log_info "Closing UFW port $port"
    if ufw delete allow "$port/tcp" >/dev/null 2>&1; then
        log_success "✅ Closed port $port/tcp"
        return 0
    else
        log_error "❌ Failed to close port $port/tcp"
        return 1
    fi
}

# Function to auto-open all ports from docker-compose
auto_open_ports() {
    local compose_file="${1:-$DOCKER_COMPOSE_FILE}"

    echo -e "${CYAN}${BOLD}🔥 Auto-opening UFW ports from docker-compose...${NC}"
    echo ""

    local ports
    ports=$(get_compose_ports "$compose_file")

    if [[ -z "$ports" ]]; then
        log_warning "No ports found in docker-compose file"
        return 0
    fi

    local opened_count=0
    local failed_count=0

    echo -e "${BLUE}📋 Ports to configure:${NC}"
    while IFS= read -r port; do
        [[ -n "$port" ]] || continue
        echo -e "  • Port $port/tcp"
    done <<< "$ports"
    echo ""

    while IFS= read -r port; do
        [[ -n "$port" ]] || continue

        if open_ufw_port "$port" "Nexus Orchestrator Node"; then
            ((opened_count++))
        else
            ((failed_count++))
        fi
    done <<< "$ports"

    echo ""
    echo -e "${GREEN}✅ Port configuration completed:${NC}"
    echo -e "  • Opened: $opened_count ports"
    echo -e "  • Failed: $failed_count ports"

    # Show current UFW status for Nexus ports
    echo ""
    echo -e "${CYAN}🔍 Current UFW status for Nexus ports:${NC}"
    ufw status | grep -E "(10[0-9][0-9][0-9]|Nexus)" || echo "  No Nexus-related rules found"

    return "$failed_count"
}

# Function to auto-close all Nexus ports
auto_close_ports() {
    local compose_file="${1:-$DOCKER_COMPOSE_FILE}"

    echo -e "${YELLOW}${BOLD}🔒 Auto-closing UFW ports from docker-compose...${NC}"
    echo ""

    local ports
    ports=$(get_compose_ports "$compose_file")

    if [[ -z "$ports" ]]; then
        log_warning "No ports found in docker-compose file"
        return 0
    fi

    local closed_count=0
    local failed_count=0

    while IFS= read -r port; do
        [[ -n "$port" ]] || continue

        if close_ufw_port "$port"; then
            ((closed_count++))
        else
            ((failed_count++))
        fi
    done <<< "$ports"

    echo ""
    echo -e "${GREEN}✅ Port closure completed:${NC}"
    echo -e "  • Closed: $closed_count ports"
    echo -e "  • Failed: $failed_count ports"

    return "$failed_count"
}

# Function to show port status
show_port_status() {
    local compose_file="${1:-$DOCKER_COMPOSE_FILE}"

    echo -e "${CYAN}${BOLD}📊 Port Status Report${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local ports
    ports=$(get_compose_ports "$compose_file")

    if [[ -z "$ports" ]]; then
        echo -e "${YELLOW}⚠️  No ports configured in docker-compose${NC}"
        return 0
    fi

    echo -e "${GREEN}📋 Docker Compose Ports:${NC}"
    while IFS= read -r port; do
        [[ -n "$port" ]] || continue

        local status="❌ CLOSED"
        local color="$RED"

        if is_ufw_port_open "$port"; then
            status="✅ OPEN"
            color="$GREEN"
        fi

        echo -e "  • Port ${CYAN}$port/tcp${NC} → ${color}$status${NC}"
    done <<< "$ports"

    echo ""
    echo -e "${BLUE}🔍 UFW Status (Nexus-related):${NC}"
    ufw status | grep -E "(10[0-9][0-9][0-9]|Nexus)" | while IFS= read -r line; do
        echo -e "  $line"
    done || echo -e "  ${GRAY}No Nexus-related UFW rules found${NC}"

    echo ""
    echo -e "${BLUE}🐳 Container Port Mappings:${NC}"
    if docker ps --filter "name=nexus-node" --format "table {{.Names}}\t{{.Ports}}" | grep -v NAMES | while IFS= read -r line; do
        [[ -n "$line" ]] && echo -e "  $line"
    done; then
        :
    else
        echo -e "  ${GRAY}No running Nexus containers found${NC}"
    fi
}

# Function to validate port availability
validate_ports() {
    # Temporarily disable error trapping for this function
    set +e

    local compose_file="${1:-$DOCKER_COMPOSE_FILE}"

    echo -e "${CYAN}${BOLD}🔍 Validating port availability...${NC}"
    echo ""

    local ports
    ports=$(get_compose_ports "$compose_file")

    if [[ -z "$ports" ]]; then
        log_warning "No ports found in docker-compose file"
        set -e  # Re-enable error trapping
        return 0
    fi

    local conflicts=0

    while IFS= read -r port; do
        [[ -n "$port" ]] || continue

        # Check if port is in use by other processes
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            local process_info
            process_info=$(netstat -tulnp 2>/dev/null | grep ":$port " | head -1)
            echo -e "${YELLOW}⚠️  Port $port is in use (normal if containers running):${NC}"
            echo -e "   ${GRAY}$process_info${NC}"
            conflicts=$((conflicts + 1))
        else
            echo -e "${GREEN}✅ Port $port is available${NC}"
        fi
    done <<< "$ports"

    echo ""
    if [[ $conflicts -eq 0 ]]; then
        echo -e "${GREEN}✅ All ports are available for new containers${NC}"
    else
        echo -e "${CYAN}ℹ️  $conflicts port(s) currently in use${NC}"
        echo -e "${BLUE}💡 This is normal if Nexus containers are already running${NC}"
    fi

    # Re-enable error trapping before returning
    set -e
    return 0
}

# Function to backup current UFW rules
backup_ufw_rules() {
    local backup_dir="${DEFAULT_WORKDIR}/backup"
    local backup_file
    backup_file="$backup_dir/ufw_rules_$(date +%Y%m%d_%H%M%S).backup"

    ensure_directory "$backup_dir"

    echo -e "${CYAN}💾 Backing up UFW rules...${NC}"

    if ufw status numbered > "$backup_file"; then
        log_success "✅ UFW rules backed up to: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_error "❌ Failed to backup UFW rules"
        return 1
    fi
}

# Main port management wrapper
manage_ports() {
    local action="$1"
    local compose_file="${2:-$DOCKER_COMPOSE_FILE}"

    case "$action" in
        "open"|"start")
            auto_open_ports "$compose_file"
            ;;
        "close"|"stop")
            auto_close_ports "$compose_file"
            ;;
        "status"|"show")
            show_port_status "$compose_file"
            ;;
        "validate"|"check")
            validate_ports "$compose_file"
            ;;
        "backup")
            backup_ufw_rules
            ;;
        *)
            echo -e "${RED}❌ Invalid action: $action${NC}"
            echo -e "${CYAN}Usage: manage_ports {open|close|status|validate|backup} [compose_file]${NC}"
            return 1
            ;;
    esac
}

# =============================================================================
# ENHANCED DOCKER WRAPPER WITH AUTO PORT MANAGEMENT
# =============================================================================

# Enhanced start with auto port opening
enhanced_start_containers() {
    echo -e "${CYAN}${BOLD}🚀 Enhanced Container Startup${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Step 1: Validate ports
    echo -e "${CYAN}Step 1/4: Validating port availability...${NC}"
    if ! validate_ports; then
        read -rp "Continue anyway? (y/N): " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && return 1
    fi
    echo ""

    # Step 2: Auto-open UFW ports
    echo -e "${CYAN}Step 2/4: Configuring firewall...${NC}"
    auto_open_ports
    echo ""

    # Step 3: Start containers
    echo -e "${CYAN}Step 3/4: Starting containers...${NC}"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans; then
        log_success "✅ Containers started successfully"
    else
        log_error "❌ Failed to start containers"
        return 1
    fi
    echo ""

    # Step 4: Verify startup
    echo -e "${CYAN}Step 4/4: Verifying startup...${NC}"
    sleep 3
    show_port_status
    echo ""

    echo -e "${GREEN}${BOLD}🎉 Enhanced startup completed successfully!${NC}"
}

# Enhanced stop with auto port closing
enhanced_stop_containers() {
    echo -e "${YELLOW}${BOLD}⏹️  Enhanced Container Shutdown${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Step 1: Stop containers
    echo -e "${CYAN}Step 1/2: Stopping containers...${NC}"
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down; then
        log_success "✅ Containers stopped successfully"
    else
        log_error "❌ Failed to stop containers"
        return 1
    fi
    echo ""

    # Step 2: Close UFW ports (optional)
    read -rp "Close UFW ports as well? (y/N): " close_ports
    if [[ "$close_ports" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Step 2/2: Closing firewall ports...${NC}"
        auto_close_ports
    else
        echo -e "${CYAN}Step 2/2: Keeping firewall ports open${NC}"
        echo -e "${BLUE}💡 Ports remain open for quick restart${NC}"
    fi
    echo ""

    echo -e "${GREEN}${BOLD}✅ Enhanced shutdown completed!${NC}"
}

# Function to clean system cache and optimize memory
cleanup_system_cache() {
    echo -e "${CYAN}${BOLD}🧹 System Cache Cleanup${NC}"
    echo -e "${CYAN}$(printf '%.0s─' {1..50})${NC}"
    echo ""

    # Check system memory before cleanup
    echo -e "${BLUE}📊 Memory status before cleanup:${NC}"
    free -h | head -2
    echo ""

    # Step 1: Docker system cleanup
    echo -e "${CYAN}Step 1/5: Docker system cleanup...${NC}"
    if command -v docker >/dev/null 2>&1; then
        docker system prune -f --volumes 2>/dev/null || true
        docker image prune -f 2>/dev/null || true
        echo -e "${GREEN}✅ Docker cleanup completed${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker not found, skipping Docker cleanup${NC}"
    fi
    echo ""

    # Step 2: Clear page cache
    echo -e "${CYAN}Step 2/5: Clearing page cache...${NC}"
    if [[ $EUID -eq 0 ]]; then
        sync
        echo 1 > /proc/sys/vm/drop_caches
        echo -e "${GREEN}✅ Page cache cleared${NC}"
    else
        echo -e "${YELLOW}⚠️  Root required for page cache cleanup${NC}"
    fi
    echo ""

    # Step 3: Clear buffer cache
    echo -e "${CYAN}Step 3/5: Clearing buffer cache...${NC}"
    if [[ $EUID -eq 0 ]]; then
        sync
        echo 2 > /proc/sys/vm/drop_caches
        echo -e "${GREEN}✅ Buffer cache cleared${NC}"
    else
        echo -e "${YELLOW}⚠️  Root required for buffer cache cleanup${NC}"
    fi
    echo ""

    # Step 4: Clear directory entry cache
    echo -e "${CYAN}Step 4/5: Clearing directory entry cache...${NC}"
    if [[ $EUID -eq 0 ]]; then
        sync
        echo 3 > /proc/sys/vm/drop_caches
        echo -e "${GREEN}✅ Directory entry cache cleared${NC}"
    else
        echo -e "${YELLOW}⚠️  Root required for directory cache cleanup${NC}"
    fi
    echo ""

    # Step 5: Clean temporary files
    echo -e "${CYAN}Step 5/5: Cleaning temporary files...${NC}"
    if [[ $EUID -eq 0 ]]; then
        # Clean /tmp older than 7 days
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        # Clean Nexus specific temp files
        find "${DEFAULT_WORKDIR}" -name "*.tmp" -delete 2>/dev/null || true
        find "${DEFAULT_WORKDIR}" -name "*.temp" -delete 2>/dev/null || true
        echo -e "${GREEN}✅ Temporary files cleaned${NC}"
    else
        echo -e "${YELLOW}⚠️  Root required for temp file cleanup${NC}"
    fi
    echo ""

    # Show memory status after cleanup
    echo -e "${BLUE}📊 Memory status after cleanup:${NC}"
    free -h | head -2
    echo ""

    echo -e "${GREEN}${BOLD}✅ System cache cleanup completed!${NC}"
    echo -e "${BLUE}💡 Consider restarting containers for optimal performance${NC}"
}

# Function to clean nexus specific cache
cleanup_nexus_cache() {
    echo -e "${CYAN}${BOLD}🧹 Nexus Cache Cleanup${NC}"
    echo -e "${CYAN}$(printf '%.0s─' {1..50})${NC}"
    echo ""

    local container_count=0
    local containers_cleaned=0

    # Get running nexus containers
    local containers
    mapfile -t containers < <(docker ps --filter "name=nexus-node" --format "{{.Names}}" 2>/dev/null || true)
    container_count=${#containers[@]}

    if [[ $container_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No running Nexus containers found${NC}"
        echo -e "${BLUE}💡 Starting general cache cleanup instead...${NC}"
        echo ""
        cleanup_system_cache
        return 0
    fi

    echo -e "${BLUE}📋 Found $container_count running Nexus container(s)${NC}"
    echo ""

    # Clean each container's cache
    for container in "${containers[@]}"; do
        echo -e "${CYAN}🧹 Cleaning cache for: ${WHITE}$container${NC}"

        # Stop container temporarily
        if docker stop "$container" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Container stopped${NC}"

            # Remove container (data is preserved in volumes)
            if docker rm "$container" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✅ Container cache cleared${NC}"
                ((containers_cleaned++))
            else
                echo -e "  ${RED}❌ Failed to clear container cache${NC}"
            fi
        else
            echo -e "  ${RED}❌ Failed to stop container${NC}"
        fi
        echo ""
    done

    # Restart containers
    if [[ $containers_cleaned -gt 0 ]]; then
        echo -e "${CYAN}🔄 Restarting cleaned containers...${NC}"
        if enhanced_start_containers; then
            echo -e "${GREEN}✅ Containers restarted successfully${NC}"
        else
            echo -e "${RED}❌ Some containers failed to restart${NC}"
            echo -e "${BLUE}💡 Run: cd /root/nexus-orchestrator && ./main.sh${NC}"
        fi
    fi

    echo ""
    echo -e "${GREEN}${BOLD}✅ Nexus cache cleanup completed!${NC}"
    echo -e "${BLUE}📊 Cleaned $containers_cleaned/$container_count containers${NC}"
}

# Function to show cache cleanup menu
cache_cleanup_menu() {
    echo -e "${CYAN}${BOLD}🧹 CACHE CLEANUP MENU${NC}"
    echo -e "${CYAN}$(printf '%.0s─' {1..50})${NC}"
    echo ""

    # Show current memory usage
    echo -e "${BLUE}📊 Current System Status:${NC}"
    free -h | head -2
    echo ""

    echo -e "${GREEN}Cache Cleanup Options:${NC}"
    echo -e "  ${GREEN}1.${NC} ${CYAN}Nexus Cache Cleanup${NC} ${GRAY}(Restart containers)${NC}"
    echo -e "  ${GREEN}2.${NC} ${CYAN}System Cache Cleanup${NC} ${GRAY}(Memory optimization)${NC}"
    echo -e "  ${GREEN}3.${NC} ${CYAN}Full Cleanup${NC} ${GRAY}(Both Nexus + System)${NC}"
    echo -e "  ${GREEN}4.${NC} ${YELLOW}Show Memory Usage${NC}"
    echo -e "  ${GREEN}5.${NC} ${PURPLE}Docker Memory Monitor${NC} ${GRAY}(Container memory stats)${NC}"
    echo -e "  ${GREEN}6.${NC} ${BLUE}Memory Optimization${NC} ${GRAY}(Auto optimize if needed)${NC}"
    echo -e "  ${GREEN}0.${NC} ${WHITE}Back to Main Menu${NC}"
    echo ""

    read -rp "Select cleanup option [1-6/0]: " choice
    echo ""

    case "$choice" in
        1)
            cleanup_nexus_cache
            ;;
        2)
            cleanup_system_cache
            ;;
        3)
            echo -e "${CYAN}${BOLD}🧹 Full System Cleanup${NC}"
            echo -e "${BLUE}This will clean both Nexus and system cache${NC}"
            echo ""
            cleanup_nexus_cache
            echo ""
            cleanup_system_cache
            ;;
        4)
            echo -e "${BLUE}📊 Detailed Memory Usage:${NC}"
            free -h
            echo ""
            df -h | head -5
            echo ""
            docker system df 2>/dev/null || echo "Docker not available"
            ;;
        5)
            monitor_containers_memory
            ;;
        6)
            optimize_docker_memory
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            sleep 2
            cache_cleanup_menu
            ;;
    esac

    echo ""
    read -rp "Press Enter to continue..."
    cache_cleanup_menu
}

# =============================================================================

export -f get_compose_ports is_ufw_port_open open_ufw_port close_ufw_port
export -f auto_open_ports auto_close_ports show_port_status validate_ports
export -f backup_ufw_rules manage_ports
export -f enhanced_start_containers enhanced_stop_containers
export -f cleanup_system_cache cleanup_nexus_cache cache_cleanup_menu

log_info "🔥 Port management system loaded successfully"
