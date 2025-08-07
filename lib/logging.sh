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
# CORE LOGGING FUNCTIONS
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
        echo -e "${CYAN}${BOLD}📋 LOG VIEWER MENU${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo ""
        echo "1. Show recent logs (50 lines)"
        echo "2. Show log statistics"
        echo "3. Search logs"
        echo "4. View full log file"
        echo "5. Clean old logs"
        echo "0. Return to main menu"
        echo ""

        read -rp "Select option [0-5]: " choice

        case "$choice" in
            1)
                clear
                show_recent_logs 50
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            2)
                clear
                show_log_stats
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            3)
                echo ""
                read -rp "Enter search term: " search_term
                clear
                search_logs "$search_term"
                echo ""
                read -rp "Press Enter to continue..."
                ;;
            4)
                if command -v less >/dev/null 2>&1; then
                    less "$NEXUS_MANAGER_LOG"
                else
                    cat "$NEXUS_MANAGER_LOG"
                fi
                ;;
            5)
                clean_old_logs
                echo "Old logs cleaned"
                read -rp "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid option"
                sleep 1
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

# Export log level constants
export LOG_LEVEL_DEBUG LOG_LEVEL_INFO LOG_LEVEL_WARNING LOG_LEVEL_ERROR LOG_LEVEL_CRITICAL

log_info "Centralized logging system loaded successfully" "LOGGING"
