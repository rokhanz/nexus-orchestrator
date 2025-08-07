#!/bin/bash

# nexus_cache_cleanup.sh - Nexus Cache Cleanup Utility
# Version: 4.0.0 - Standalone cache cleanup for Nexus Orchestrator

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# CACHE CLEANUP FUNCTIONS
# =============================================================================

cleanup_system_cache() {
    log_info "Starting system cache cleanup..."
    
    # Clear package caches
    if command -v apt-get >/dev/null 2>&1; then
        apt-get clean >/dev/null 2>&1 || true
        apt-get autoclean >/dev/null 2>&1 || true
    fi
    
    if command -v yum >/dev/null 2>&1; then
        yum clean all >/dev/null 2>&1 || true
    fi
    
    # Clear temporary files
    find /tmp -type f -atime +3 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    log_success "System cache cleanup completed"
}

cleanup_docker_cache() {
    log_info "Starting Docker cache cleanup..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_warning "Docker not found, skipping Docker cleanup"
        return 0
    fi
    
    # Clean unused Docker resources
    docker system prune -f >/dev/null 2>&1 || true
    docker image prune -f >/dev/null 2>&1 || true
    docker volume prune -f >/dev/null 2>&1 || true
    
    log_success "Docker cache cleanup completed"
}

cleanup_nexus_cache() {
    log_info "Starting Nexus cache cleanup..."
    
    # Clean Nexus-specific caches
    local nexus_cache_dirs=(
        "$DEFAULT_WORKDIR/cache"
        "$DEFAULT_WORKDIR/tmp"
        "/tmp/nexus-*"
    )
    
    for cache_dir in "${nexus_cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            rm -rf "$cache_dir" 2>/dev/null || true
        fi
    done
    
    # Clean old logs (keep last 10)
    if [[ -d "$DEFAULT_LOG_DIR" ]]; then
        find "$DEFAULT_LOG_DIR" -name "*.log.*" -type f | sort -V | head -n -10 | xargs rm -f 2>/dev/null || true
    fi
    
    log_success "Nexus cache cleanup completed"
}

show_disk_usage() {
    echo -e "${CYAN}Current disk usage:${NC}"
    echo ""
    
    # System disk usage
    df -h / 2>/dev/null | tail -n 1 | awk '{printf "Root filesystem: %s used of %s (%s)\n", $3, $2, $5}'
    
    # Docker disk usage
    if command -v docker >/dev/null 2>&1; then
        docker system df 2>/dev/null || echo "Docker disk usage unavailable"
    fi
    
    # Nexus workdir usage
    if [[ -d "$DEFAULT_WORKDIR" ]]; then
        local workdir_size
        workdir_size=$(du -sh "$DEFAULT_WORKDIR" 2>/dev/null | cut -f1 || echo "Unknown")
        echo "Nexus workdir: $workdir_size"
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    show_section_header "Nexus Cache Cleanup" "🧹"
    
    echo -e "${CYAN}Cache Cleanup Options:${NC}"
    echo ""
    echo "1. Show Disk Usage"
    echo "2. Clean System Cache"
    echo "3. Clean Docker Cache"
    echo "4. Clean Nexus Cache"
    echo "5. Full Cleanup (All)"
    echo "0. Exit"
    echo ""
    
    read -rp "Choose option [0-5]: " choice
    
    case "$choice" in
        1)
            show_disk_usage
            ;;
        2)
            cleanup_system_cache
            ;;
        3)
            cleanup_docker_cache
            ;;
        4)
            cleanup_nexus_cache
            ;;
        5)
            echo -e "${CYAN}Starting full cleanup...${NC}"
            cleanup_system_cache
            cleanup_docker_cache
            cleanup_nexus_cache
            echo -e "${GREEN}✅ Full cleanup completed${NC}"
            echo ""
            show_disk_usage
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            exit 1
            ;;
    esac
}

# =============================================================================
# RUN MAIN FUNCTION
# =============================================================================

main "$@"
