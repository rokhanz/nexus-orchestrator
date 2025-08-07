#!/bin/bash

# logging.sh - Centralized logging system
# Version: 4.0.0 - Professional logging for Nexus Orchestrator

# Source guard to prevent multiple inclusions
if [[ -n "${LOGGING_SH_LOADED:-}" ]]; then
    return 0
fi
readonly LOGGING_SH_LOADED=1

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

readonly LOG_LEVEL_DEBUG=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_WARNING=3
readonly LOG_LEVEL_ERROR=4
readonly LOG_LEVEL_CRITICAL=5

# Default log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log file rotation settings
readonly MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB
readonly MAX_LOG_FILES=5

# =============================================================================
# NEXUS NODE LOG MONITORING FUNCTIONS
# =============================================================================

# View logs from a specific Nexus node container
view_nexus_node_logs_interactive() {
    clear
    echo -e "${CYAN}📋 ${BOLD}Nexus Node Logs${NC}"
    echo ""

    # Get list of running containers
    local containers
    containers=$(docker ps --filter "label=nexus.network=true" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}⚠️  No running Nexus containers found.${NC}"
        echo -e "${CYAN}   Start nodes first from the Management menu.${NC}"
        echo ""
        read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
        return
    fi

    echo -e "${CYAN}Available Nexus nodes:${NC}"
    local i=1
    echo "$containers" | while read -r container; do
        local status
        status=$(docker ps --filter "name=${container}" --format "{{.Status}}" 2>/dev/null)
        echo -e "  ${GREEN}$i.${NC} ${YELLOW}$container${NC} ${CYAN}($status)${NC}"
        ((i++))
    done
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Select node number (1-$(echo "$containers" | wc -l)) or 'all' for combined:${NC} ")" selection
    echo ""

    if [[ "$selection" == "all" ]]; then
        echo -e "${BLUE}📊 ${BOLD}Monitoring all Nexus nodes (Press Ctrl+C to exit)...${NC}"
        echo ""
        # Use docker-compose logs to show all containers with service names
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f --tail=100 |
            sed -E "s/^([^|]+)\|(.*)$/$(echo -e "${PURPLE}")\1$(echo -e "${NC}${GREEN}|${NC}")\2/" |
            sed -E "s/(ERROR|error|Error|FAILED|failed|Failed)/$(echo -e "${RED}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(SUCCESS|success|Success|COMPLETED|completed|Completed)/$(echo -e "${GREEN}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(WARNING|warning|Warning|WARN|warn)/$(echo -e "${YELLOW}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(INFO|info|Info)/$(echo -e "${CYAN}")\1$(echo -e "${NC}")/g"
        else
            echo -e "${RED}❌ Docker compose file not found${NC}"
        fi
    elif [[ "$selection" =~ ^[0-9]+$ ]]; then
        local selected_container
        selected_container=$(echo "$containers" | sed -n "${selection}p")

        if [[ -n "$selected_container" ]]; then
            echo -e "${BLUE}📊 ${BOLD}Monitoring $selected_container (Press Ctrl+C to exit)...${NC}"
            echo ""
            # Show colorized logs with real-time follow
            docker logs "$selected_container" -f --tail=100 2>&1 |
            sed -E "s/(ERROR|error|Error|FAILED|failed|Failed)/$(echo -e "${RED}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(SUCCESS|success|Success|COMPLETED|completed|Completed|✅)/$(echo -e "${GREEN}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(WARNING|warning|Warning|WARN|warn|⚠️)/$(echo -e "${YELLOW}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(INFO|info|Info|ℹ️)/$(echo -e "${CYAN}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(retry|Retry|RETRY|🔄)/$(echo -e "${PURPLE}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(refresh|Refresh|REFRESH|🔄)/$(echo -e "${BLUE}")\1$(echo -e "${NC}")/g"
        else
            echo -e "${RED}❌ Invalid selection${NC}"
        fi
    else
        echo -e "${RED}❌ Invalid selection${NC}"
    fi

    echo ""
    read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
}

# Monitor all nodes with combined output
monitor_all_nodes() {
    clear
    echo -e "${CYAN}📈 ${BOLD}Monitor All Nexus Nodes${NC}"
    echo ""

    # Check if docker-compose file exists
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "${RED}❌ Docker compose file not found${NC}"
        echo -e "${YELLOW}   Generate Docker configuration first${NC}"
        echo ""
        read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
        return
    fi

    echo -e "${BLUE}📊 ${BOLD}Combined logs from all Nexus nodes (Press Ctrl+C to exit)...${NC}"
    echo -e "${CYAN}Legend: ${GREEN}SUCCESS${NC} | ${RED}ERROR${NC} | ${YELLOW}WARNING${NC} | ${CYAN}INFO${NC} | ${PURPLE}RETRY${NC}${NC}"
    echo ""

    # Combined monitoring with colors and timestamps
    docker-compose -f "$DOCKER_COMPOSE_FILE" logs -f --tail=50 --timestamps |
    sed -E "s/^([0-9T:\-\.Z]+)\s+([^|]+)\|(.*)$/$(echo -e "${GRAY}")\1$(echo -e "${NC} ${PURPLE}")\2$(echo -e "${NC}${GREEN}|${NC}")\3/" |
    sed -E "s/(ERROR|error|Error|FAILED|failed|Failed|❌)/$(echo -e "${RED}")\1$(echo -e "${NC}")/g" |
    sed -E "s/(SUCCESS|success|Success|COMPLETED|completed|Completed|✅)/$(echo -e "${GREEN}")\1$(echo -e "${NC}")/g" |
    sed -E "s/(WARNING|warning|Warning|WARN|warn|⚠️)/$(echo -e "${YELLOW}")\1$(echo -e "${NC}")/g" |
    sed -E "s/(INFO|info|Info|ℹ️)/$(echo -e "${CYAN}")\1$(echo -e "${NC}")/g" |
    sed -E "s/(retry|Retry|RETRY|refresh|Refresh|REFRESH|🔄)/$(echo -e "${PURPLE}")\1$(echo -e "${NC}")/g"

    echo ""
    read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
}

# Search in node logs
search_node_logs_interactive() {
    clear
    echo -e "${CYAN}🔍 ${BOLD}Search Nexus Node Logs${NC}"
    echo ""

    read -rp "$(echo -e "${BOLD}${PURPLE}Enter search keyword:${NC} ")" search_term
    echo ""

    if [[ -z "$search_term" ]]; then
        echo -e "${YELLOW}⏭️  No search term entered${NC}"
        read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
        return
    fi

    echo -e "${BLUE}🔍 ${BOLD}Searching for '${search_term}' in all node logs...${NC}"
    echo ""

    # Get list of running containers
    local containers
    containers=$(docker ps --filter "label=nexus.network=true" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}⚠️  No running Nexus containers found${NC}"
        read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
        return
    fi

    local found_results=false
    local temp_output=""

    while read -r container; do
        local results
        results=$(docker logs "$container" 2>&1 | grep -i "$search_term" | tail -10)

        if [[ -n "$results" ]]; then
            found_results=true
            temp_output+="${GREEN}📋 Results from ${YELLOW}$container${GREEN}:${NC}\n"
            temp_output+="$(echo "$results" |
            sed -E "s/(ERROR|error|Error|FAILED|failed|Failed)/$(echo -e "${RED}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(SUCCESS|success|Success|COMPLETED|completed|Completed)/$(echo -e "${GREEN}")\1$(echo -e "${NC}")/g" |
            sed -E "s/(WARNING|warning|Warning|WARN|warn)/$(echo -e "${YELLOW}")\1$(echo -e "${NC}")/g" |
            sed -E "s/($search_term)/$(echo -e "${CYAN}${BOLD}")\1$(echo -e "${NC}")/gi")\n\n"
        fi
    done <<< "$containers"

    if [[ "$found_results" == true ]]; then
        echo -e "$temp_output"
    else
        echo -e "${YELLOW}⚠️  No results found for '${search_term}'${NC}"
    fi

    echo ""
    read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
}

# Show node status overview
show_node_status_overview() {
    clear
    echo -e "${CYAN}📊 ${BOLD}Nexus Nodes Status Overview${NC}"
    echo ""

    # Get list of all containers (running and stopped)
    local all_containers
    all_containers=$(docker ps -a --filter "label=nexus.network=true" --format "{{.Names}}	{{.Status}}	{{.Ports}}" 2>/dev/null)

    if [[ -z "$all_containers" ]]; then
        echo -e "${YELLOW}⚠️  No Nexus containers found${NC}"
        echo -e "${CYAN}   Generate Docker configuration and start nodes first${NC}"
        echo ""
        read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
        return
    fi

    echo -e "${CYAN}Node Status:${NC}"
    echo "$all_containers" | while IFS=$'	' read -r name status ports; do
        if [[ "$status" =~ Up ]]; then
            echo -e "  ${GREEN}✅ $name${NC} - ${GREEN}$status${NC}"
            if [[ -n "$ports" ]]; then
                echo -e "     ${CYAN}Ports: $ports${NC}"
            fi

            # Get health status if available
            local health
            health=$(docker inspect "$name" --format "{{.State.Health.Status}}" 2>/dev/null)
            if [[ -n "$health" && "$health" != "<no value>" ]]; then
                case "$health" in
                    "healthy")
                        echo -e "     ${GREEN}Health: ✅ $health${NC}"
                        ;;
                    "unhealthy")
                        echo -e "     ${RED}Health: ❌ $health${NC}"
                        ;;
                    *)
                        echo -e "     ${YELLOW}Health: ⚠️ $health${NC}"
                        ;;
                esac
            fi
        else
            echo -e "  ${RED}❌ $name${NC} - ${RED}$status${NC}"
        fi
        echo ""
    done

    # Show resource usage
    echo -e "${CYAN}Resource Usage:${NC}"
    local running_containers
    running_containers=$(docker ps --filter "label=nexus.network=true" --format "{{.Names}}" | tr '\n' ' ')
    if [[ -n "$running_containers" ]]; then
        # shellcheck disable=SC2086
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $running_containers 2>/dev/null
    else
        echo -e "${YELLOW}⚠️  No running containers to show stats${NC}"
    fi

    echo ""
    read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
}

# =============================================================================
# INTERACTIVE LOG VIEWING
# =============================================================================

# Write structured log entry
write_log() {
    local level="$1"
    local message="$2"
    local component="${3:-MAIN}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Ensure log directory exists
    ensure_directories

    # Rotate log if necessary
    rotate_log_if_needed

    # Write to log file
    echo "[$timestamp] [$level] [$component] $message" >> "$NEXUS_MANAGER_LOG"

    # Also write to console based on level
    case "$level" in
        "ERROR"|"CRITICAL")
            echo -e "${RED}[$timestamp] [$level] $message${NC}" >&2
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] [$level] $message${NC}" >&2
            ;;
        "INFO")
            if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
                echo -e "${CYAN}[$timestamp] [$level] $message${NC}"
            fi
            ;;
        "DEBUG")
            if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
                echo -e "${PURPLE}[$timestamp] [$level] $message${NC}"
            fi
            ;;
    esac
}

# Convenience logging functions
log_debug() {
    write_log "DEBUG" "$1" "${2:-}"
}

log_info() {
    write_log "INFO" "$1" "${2:-}"
}

log_warning() {
    write_log "WARNING" "$1" "${2:-}"
}

log_error() {
    write_log "ERROR" "$1" "${2:-}"
}

log_critical() {
    write_log "CRITICAL" "$1" "${2:-}"
}

# =============================================================================
# SPECIALIZED LOGGING FUNCTIONS
# =============================================================================

# Log system operations
log_system() {
    write_log "INFO" "$1" "SYSTEM"
}

# Log Docker operations
log_docker() {
    write_log "INFO" "$1" "DOCKER"
}

# Log user interactions
log_user() {
    write_log "INFO" "$1" "USER"
}

# Log security events
log_security() {
    write_log "WARNING" "$1" "SECURITY"
}

# =============================================================================
# LOG MANAGEMENT FUNCTIONS
# =============================================================================

# Rotate log file if it exceeds size limit
rotate_log_if_needed() {
    if [[ ! -f "$NEXUS_MANAGER_LOG" ]]; then
        return 0
    fi

    local log_size
    log_size=$(stat -f%z "$NEXUS_MANAGER_LOG" 2>/dev/null || stat -c%s "$NEXUS_MANAGER_LOG" 2>/dev/null || echo 0)

    if [[ $log_size -gt $MAX_LOG_SIZE ]]; then
        rotate_logs
    fi
}

# Perform log rotation
rotate_logs() {
    local log_dir
    log_dir=$(dirname "$NEXUS_MANAGER_LOG")
    local log_name
    log_name=$(basename "$NEXUS_MANAGER_LOG")

    # Remove oldest log if we have too many
    local oldest_log="$log_dir/${log_name}.$MAX_LOG_FILES"
    if [[ -f "$oldest_log" ]]; then
        rm -f "$oldest_log"
    fi

    # Rotate existing logs
    for ((i=MAX_LOG_FILES-1; i>=1; i--)); do
        local current_log="$log_dir/${log_name}.$i"
        local next_log="$log_dir/${log_name}.$((i+1))"

        if [[ -f "$current_log" ]]; then
            mv "$current_log" "$next_log"
        fi
    done

    # Move current log to .1
    if [[ -f "$NEXUS_MANAGER_LOG" ]]; then
        mv "$NEXUS_MANAGER_LOG" "$log_dir/${log_name}.1"
    fi

    log_info "Log rotation completed" "LOGGING"
}

# Clean old logs
clean_old_logs() {
    local log_dir
    log_dir=$(dirname "$NEXUS_MANAGER_LOG")
    local log_name
    log_name=$(basename "$NEXUS_MANAGER_LOG")

    # Remove logs older than specified number
    for ((i=MAX_LOG_FILES+1; i<=20; i++)); do
        local old_log="$log_dir/${log_name}.$i"
        if [[ -f "$old_log" ]]; then
            rm -f "$old_log"
        fi
    done
}

# =============================================================================
# LOG ANALYSIS FUNCTIONS
# =============================================================================

# Show recent log entries
show_recent_logs() {
    local lines="${1:-50}"

    if [[ ! -f "$NEXUS_MANAGER_LOG" ]]; then
        echo "No log file found"
        return 1
    fi

    echo -e "${CYAN}${BOLD}📋 Recent Log Entries (last $lines lines):${NC}"
    echo ""

    tail -n "$lines" "$NEXUS_MANAGER_LOG" | while IFS= read -r line; do
        # Color code based on log level
        if [[ "$line" =~ \[ERROR\]|\[CRITICAL\] ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" =~ \[WARNING\] ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" =~ \[DEBUG\] ]]; then
            echo -e "${PURPLE}$line${NC}"
        else
            echo "$line"
        fi
    done
}

# Show log statistics
show_log_stats() {
    if [[ ! -f "$NEXUS_MANAGER_LOG" ]]; then
        echo "No log file found"
        return 1
    fi

    echo -e "${CYAN}${BOLD}📊 Log Statistics:${NC}"
    echo ""

    local total_entries
    total_entries=$(wc -l < "$NEXUS_MANAGER_LOG")

    local error_count
    error_count=$(grep -c "\[ERROR\]" "$NEXUS_MANAGER_LOG" || echo 0)

    local warning_count
    warning_count=$(grep -c "\[WARNING\]" "$NEXUS_MANAGER_LOG" || echo 0)

    local info_count
    info_count=$(grep -c "\[INFO\]" "$NEXUS_MANAGER_LOG" || echo 0)

    printf "  %-15s %d\n" "Total entries:" "$total_entries"
    printf "  %-15s %d\n" "Errors:" "$error_count"
    printf "  %-15s %d\n" "Warnings:" "$warning_count"
    printf "  %-15s %d\n" "Info messages:" "$info_count"

    echo ""
}

# Search logs
search_logs() {
    local search_term="$1"
    local lines="${2:-10}"

    if [[ ! -f "$NEXUS_MANAGER_LOG" ]]; then
        echo "No log file found"
        return 1
    fi

    if [[ -z "$search_term" ]]; then
        echo "Please provide a search term"
        return 1
    fi

    echo -e "${CYAN}${BOLD}🔍 Search results for '$search_term':${NC}"
    echo ""

    grep -n -i "$search_term" "$NEXUS_MANAGER_LOG" | tail -n "$lines" | while IFS= read -r line; do
        # Color code based on log level
        if [[ "$line" =~ \[ERROR\]|\[CRITICAL\] ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" =~ \[WARNING\] ]]; then
            echo -e "${YELLOW}$line${NC}"
        else
            echo "$line"
        fi
    done
}

# =============================================================================
# LOG VIEWER FUNCTIONS
# =============================================================================

# Interactive log viewer
view_logs_interactive() {
    while true; do
        clear
        show_banner
        show_section_header "System Logs & Monitoring" "📊"

        echo -e "${GREEN}1.${NC} 📋 ${CYAN}View Nexus Node Logs (TUI Output)${NC}    ${YELLOW}(Real-time colorized output)${NC}"
        echo -e "${GREEN}2.${NC} 📈 ${CYAN}Monitor All Nodes${NC}                  ${YELLOW}(Combined logs from all containers)${NC}"
        echo -e "${GREEN}3.${NC} 🔍 ${CYAN}Search Node Logs${NC}                   ${YELLOW}(Filter logs by keyword)${NC}"
        echo -e "${GREEN}4.${NC} 📊 ${CYAN}Node Status Overview${NC}               ${YELLOW}(Health check & statistics)${NC}"
        echo ""
        echo -e "${GREEN}5.${NC} 📝 ${CYAN}System Logs (Recent)${NC}               ${YELLOW}(Orchestrator internal logs)${NC}"
        echo -e "${GREEN}6.${NC} 📈 ${CYAN}Log Statistics${NC}                     ${YELLOW}(System log analysis)${NC}"
        echo -e "${GREEN}7.${NC} 🧹 ${CYAN}Clean Old Logs${NC}                     ${YELLOW}(Remove old log files)${NC}"
        echo ""
        echo -e "${GREEN}0.${NC} ⬅️  ${CYAN}Return to Main Menu${NC}               ${YELLOW}(Back to main menu)${NC}"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        read -rp "$(echo -e "${BOLD}${PURPLE}Select option [0-7]:${NC} ")" choice
        echo ""

        case "$choice" in
            1)
                view_nexus_node_logs_interactive
                ;;
            2)
                monitor_all_nodes
                ;;
            3)
                search_node_logs_interactive
                ;;
            4)
                show_node_status_overview
                ;;
            5)
                clear
                show_recent_logs 50
                echo ""
                read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
                ;;
            6)
                clear
                show_log_stats
                echo ""
                read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
                ;;
            7)
                clean_old_logs
                echo -e "${GREEN}✅ Old logs cleaned${NC}"
                read -rp "$(echo -e "${YELLOW}Press any key to continue...${NC}")"
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
# EXPORT FUNCTIONS
# =============================================================================

export -f write_log log_debug log_info log_warning log_error log_critical
export -f log_system log_docker log_user log_security
export -f rotate_log_if_needed rotate_logs clean_old_logs
export -f show_recent_logs show_log_stats search_logs view_logs_interactive
export -f view_nexus_node_logs_interactive monitor_all_nodes search_node_logs_interactive show_node_status_overview

# Export log level constants
export LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_WARNING LOG_LEVEL_ERROR LOG_LEVEL_CRITICAL

log_info "Centralized logging system loaded successfully" "LOGGING"
