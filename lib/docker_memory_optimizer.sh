#!/bin/bash

# docker_memory_optimizer.sh - Docker Memory Optimization Module
# Version: 4.0.0 - Memory management for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# DOCKER MEMORY OPTIMIZATION CONFIGURATION
# =============================================================================

# Prevent redefinition of readonly variables
if [[ -z "${DEFAULT_MEMORY_LIMIT:-}" ]]; then
    readonly DEFAULT_MEMORY_LIMIT="2g"
    readonly DEFAULT_MEMORY_SWAP_LIMIT="4g"
    readonly MEMORY_CHECK_THRESHOLD=85
    readonly SWAP_CHECK_THRESHOLD=90
fi

# =============================================================================
# MEMORY OPTIMIZATION FUNCTIONS
# =============================================================================

# Function to check system memory usage
check_system_memory() {
    local memory_usage
    memory_usage=$(free | grep Mem: | awk '{printf("%.0f", ($3/$2) * 100)}')
    echo "$memory_usage"
}

# Function to check swap usage
check_swap_usage() {
    local swap_usage
    swap_usage=$(free | grep Swap: | awk '{if($2>0) printf("%.0f", ($3/$2) * 100); else print "0"}')
    echo "$swap_usage"
}

# Function to optimize docker memory
optimize_docker_memory() {
    local memory_usage
    memory_usage=$(check_system_memory)
    local swap_usage
    swap_usage=$(check_swap_usage)

    echo -e "${CYAN}${BOLD}🧠 Docker Memory Optimization${NC}"
    echo -e "${CYAN}$(printf '%.0s─' {1..50})${NC}"
    echo ""

    echo -e "${BLUE}📊 Current Memory Status:${NC}"
    echo -e "  Memory Usage: ${memory_usage}%"
    echo -e "  Swap Usage: ${swap_usage}%"
    echo ""

    # Check if optimization is needed
    if [[ $memory_usage -gt $MEMORY_CHECK_THRESHOLD ]] || [[ $swap_usage -gt $SWAP_CHECK_THRESHOLD ]]; then
        echo -e "${YELLOW}⚠️  High memory usage detected - performing optimization${NC}"

        # Docker cleanup
        echo -e "${CYAN}Step 1: Docker system cleanup...${NC}"
        docker system prune -f --volumes 2>/dev/null || true

        # Remove unused images
        echo -e "${CYAN}Step 2: Removing unused images...${NC}"
        docker image prune -a -f 2>/dev/null || true

        echo -e "${GREEN}✅ Memory optimization completed${NC}"
    else
        echo -e "${GREEN}✅ Memory usage is within acceptable limits${NC}"
    fi
}

# Function to set container memory limits
set_container_memory_limits() {
    local container_name="$1"
    local memory_limit="${2:-$DEFAULT_MEMORY_LIMIT}"
    local swap_limit="${3:-$DEFAULT_MEMORY_SWAP_LIMIT}"

    if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "^$container_name$"; then
        echo -e "${CYAN}Setting memory limits for: ${BOLD}$container_name${NC}"
        echo -e "  Memory: $memory_limit"
        echo -e "  Swap: $swap_limit"

        # Note: Memory limits are set during container creation
        # This function is for monitoring and reporting
        local current_memory
        current_memory=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" "$container_name" 2>/dev/null | tail -n +2 | awk '{print $2}')

        if [[ -n "$current_memory" ]]; then
            echo -e "  Current Usage: $current_memory"
        fi
    else
        echo -e "${YELLOW}⚠️  Container $container_name not found or not running${NC}"
    fi
}

# Function to monitor all containers memory usage
monitor_containers_memory() {
    echo -e "${CYAN}${BOLD}📊 Container Memory Monitoring${NC}"
    echo -e "${CYAN}$(printf '%.0s─' {1..60})${NC}"

    local containers
    containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}⚠️  No Nexus containers running${NC}"
        return 0
    fi

    printf "%-20s %-15s %-15s %-10s\n" "CONTAINER" "MEMORY" "CPU" "STATUS"
    echo "────────────────────────────────────────────────────────────────"

    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            local stats
            stats=$(docker stats --no-stream --format "{{.MemUsage}}\t{{.CPUPerc}}" "$container" 2>/dev/null)
            local status
            status=$(docker inspect "$container" --format "{{.State.Status}}" 2>/dev/null)

            if [[ -n "$stats" ]]; then
                local mem_usage cpu_usage
                mem_usage=$(echo "$stats" | cut -f1)
                cpu_usage=$(echo "$stats" | cut -f2)
                printf "%-20s %-15s %-15s %-10s\n" "$container" "$mem_usage" "$cpu_usage" "$status"
            fi
        fi
    done <<< "$containers"

    echo ""
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f check_system_memory check_swap_usage optimize_docker_memory
export -f set_container_memory_limits monitor_containers_memory

log_success "✅ Docker memory optimizer loaded successfully"
