#!/bin/bash
# Common functions for Nexus Orchestrator
# This module provides shared utilities for all other components

# Source guard to prevent multiple inclusions
if [[ -n "${COMMON_SH_LOADED:-}" ]]; then
    return 0
fi
readonly COMMON_SH_LOADED=1

# Color constants for output formatting (exported for external use)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'
readonly ORANGE='\033[0;33m'  # Orange is same as yellow in basic ANSI

# Export all colors for external use
export RED GREEN YELLOW BLUE PURPLE CYAN WHITE GRAY NC BOLD ORANGE

# Configuration defaults
DEFAULT_WORKDIR_BASE=""
DEFAULT_WORKDIR_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEFAULT_WORKDIR_BASE
readonly DEFAULT_WORKDIR="${DEFAULT_WORKDIR_BASE}/workdir"
readonly DEFAULT_CONFIG_DIR="${DEFAULT_WORKDIR}/config"
readonly DEFAULT_LOG_DIR="${DEFAULT_WORKDIR}/logs"
readonly DEFAULT_BACKUP_DIR="${DEFAULT_WORKDIR}/backup"
readonly CREDENTIALS_FILE="${DEFAULT_WORKDIR}/credentials.json"
readonly DOCKER_COMPOSE_FILE="${DEFAULT_WORKDIR}/docker-compose.yml"
readonly PROVER_ID_FILE="${DEFAULT_WORKDIR}/prover-id"
readonly NEXUS_MANAGER_LOG="${DEFAULT_WORKDIR}/nexus-orchestrator.log"

# Global flags
VERBOSE=false
DEBUG=false
DEV_MODE="${DEV_MODE:-false}"  # Set to true for development, false for production

# Export variables for external use
export DEFAULT_WORKDIR DEFAULT_CONFIG_DIR DEFAULT_LOG_DIR DEFAULT_BACKUP_DIR
export CREDENTIALS_FILE DOCKER_COMPOSE_FILE PROVER_ID_FILE NEXUS_MANAGER_LOG
export VERBOSE DEBUG DEV_MODE

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" >&2
            echo "[ERROR] ${timestamp} - $message" >> "$NEXUS_MANAGER_LOG"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} ${timestamp} - $message"
            echo "[WARNING] ${timestamp} - $message" >> "$NEXUS_MANAGER_LOG"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${timestamp} - $message"
            echo "[INFO] ${timestamp} - $message" >> "$NEXUS_MANAGER_LOG"
            ;;
        "DEBUG")
            if [[ "$DEBUG" == true ]]; then
                echo -e "${PURPLE}[DEBUG]${NC} ${timestamp} - $message"
                echo "[DEBUG] ${timestamp} - $message" >> "$NEXUS_MANAGER_LOG"
            fi
            ;;
    esac
}

log_error() {
    log_message "ERROR" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

log_info() {
    log_message "INFO" "$1"
}

log_debug() {
    log_message "DEBUG" "$1"
}

log_success() {
    log_message "INFO" "✅ $1"
}

log_activity() {
    log_message "INFO" "🔄 $1"
}

# Error handling with development/production modes
handle_error() {
    local error_message="$1"
    local line_number="${2:-unknown}"
    local exit_code="${3:-1}"

    if [[ "$DEV_MODE" == "true" ]]; then
        # Development mode: Show detailed error information
        echo -e "${RED}[DEV ERROR]${NC} Line $line_number: $error_message"
        echo -e "${YELLOW}Exit code: $exit_code${NC}"
        echo -e "${CYAN}Check logs: $NEXUS_MANAGER_LOG${NC}"
        log_error "Development error on line $line_number: $error_message (Exit code: $exit_code)"
    else
        # Production mode: Show user-friendly error message
        echo -e "${RED}An error occurred. Check the log file for details: $NEXUS_MANAGER_LOG${NC}"
        log_error "Error on line $line_number: $error_message (Exit code: $exit_code)"
    fi
}

# Directory management
ensure_directories() {
    local dirs=("$DEFAULT_WORKDIR" "$DEFAULT_CONFIG_DIR" "$DEFAULT_LOG_DIR")

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if ! mkdir -p "$dir"; then
                log_error "Failed to create directory: $dir"
                return 1
            fi
            log_debug "Created directory: $dir"
        fi
    done
    return 0
}

backup_file() {
    local file="$1"
    local backup_dir="$DEFAULT_BACKUP_DIR"

    # Ensure backup directory exists
    ensure_directories || return 1
    mkdir -p "$backup_dir" 2>/dev/null

    if [[ -f "$file" ]]; then
        # Create simple backup name based on original filename
        local filename
        filename=$(basename "$file")
        local backup_file="${backup_dir}/${filename}.backup"

        if cp "$file" "$backup_file"; then
            log_info "Backed up $file to $backup_file"
            return 0
        else
            log_error "Failed to backup $file"
            return 1
        fi
    fi
    return 0
}

# Validation functions
validate_json() {
    local json_file="$1"

    if [[ ! -f "$json_file" ]]; then
        log_error "JSON file not found: $json_file"
        return 1
    fi

    if ! python3 -m json.tool < "$json_file" > /dev/null 2>&1; then
        log_error "Invalid JSON format in: $json_file"
        return 1
    fi

    return 0
}

validate_wallet_address() {
    local address="$1"

    # Basic validation for Ethereum-style addresses
    if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        log_error "Invalid wallet address format: $address"
        return 1
    fi

    return 0
}

validate_node_id() {
    local node_id="$1"

    # Validation for node ID - must be numeric only
    if [[ ! "$node_id" =~ ^[0-9]+$ ]]; then
        log_error "Invalid node ID format: $node_id. Node ID must contain only numbers."
        return 1
    fi

    # Additional validation - node ID should not be empty or too long
    if [[ ${#node_id} -eq 0 || ${#node_id} -gt 20 ]]; then
        log_error "Node ID length must be between 1-20 digits"
        return 1
    fi

    return 0
}

# Alias for backward compatibility
validate_prover_id() {
    validate_node_id "$@"
}

# Get list of configured node IDs
list_node_ids() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        return 1
    fi

    local node_id
    node_id=$(read_config_value "node_id" 2>/dev/null || echo "[]")

    # Check if we have valid JSON array with elements
    local node_count
    node_count=$(echo "$node_id" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$node_count" -gt 0 ]]; then
        echo "$node_id" | jq -r '.[]' 2>/dev/null
        return 0
    else
        return 1
    fi
}

# Edit node ID in the array
edit_node_id() {
    local old_node_id="$1"
    local new_node_id="$2"

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Configuration file not found: $CREDENTIALS_FILE"
        return 1
    fi

    # Validate new node ID
    if ! validate_node_id "$new_node_id"; then
        return 1
    fi

    # Get current node_id array
    local current_nodes
    current_nodes=$(read_config_value "node_id" 2>/dev/null || echo "[]")

    # Check if old node exists
    if ! echo "$current_nodes" | jq -e --arg old "$old_node_id" 'index($old)' >/dev/null 2>&1; then
        log_error "Node ID not found: $old_node_id"
        return 1
    fi

    # Check if new node already exists (and is different from old)
    if [[ "$old_node_id" != "$new_node_id" ]] && echo "$current_nodes" | jq -e --arg new "$new_node_id" 'index($new)' >/dev/null 2>&1; then
        log_error "Node ID already exists: $new_node_id"
        return 1
    fi

    # Replace old node with new node
    local updated_nodes
    updated_nodes=$(echo "$current_nodes" | jq --arg old "$old_node_id" --arg new "$new_node_id" 'map(if . == $old then $new else . end)' 2>/dev/null)

    if write_config_value "node_id" "$updated_nodes"; then
        log_info "Node ID updated: $old_node_id -> $new_node_id"
        return 0
    else
        log_error "Failed to update node ID"
        return 1
    fi
}

# Add node ID to the array
add_node_id() {
    local new_node_id="$1"

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Configuration file not found: $CREDENTIALS_FILE"
        return 1
    fi

    # Validate new node ID
    if ! validate_node_id "$new_node_id"; then
        return 1
    fi

    # Get current node_id array
    local current_nodes
    current_nodes=$(read_config_value "node_id" 2>/dev/null || echo "[]")

    # Check if node already exists
    if echo "$current_nodes" | jq -e --arg new "$new_node_id" 'index($new)' >/dev/null 2>&1; then
        log_error "Node ID already exists: $new_node_id"
        return 1
    fi

    # Add new node to array
    local updated_nodes
    updated_nodes=$(echo "$current_nodes" | jq --arg new "$new_node_id" '. + [$new]' 2>/dev/null)

    if write_config_value "node_id" "$updated_nodes"; then
        log_info "Node ID added: $new_node_id"
        return 0
    else
        log_error "Failed to add node ID"
        return 1
    fi
}

# Remove node ID from the array
remove_node_id() {
    local node_id_to_remove="$1"

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Configuration file not found: $CREDENTIALS_FILE"
        return 1
    fi

    # Get current node_id array
    local current_nodes
    current_nodes=$(read_config_value "node_id" 2>/dev/null || echo "[]")

    # Check if node exists
    if ! echo "$current_nodes" | jq -e --arg remove "$node_id_to_remove" 'index($remove)' >/dev/null 2>&1; then
        log_error "Node ID not found: $node_id_to_remove"
        return 1
    fi

    # Remove node from array
    local updated_nodes
    updated_nodes=$(echo "$current_nodes" | jq --arg remove "$node_id_to_remove" 'map(select(. != $remove))' 2>/dev/null)

    if write_config_value "node_id" "$updated_nodes"; then
        log_info "Node ID removed: $node_id_to_remove"
        return 0
    else
        log_error "Failed to remove node ID"
        return 1
    fi
}

# File operations
read_config_value() {
    local key="$1"
    local config_file="${2:-$CREDENTIALS_FILE}"

    # Initialize config file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        log_debug "Configuration file not found, initializing: $config_file"
        ensure_directories || return 1
        echo '{}' > "$config_file" || {
            log_error "Failed to create configuration file: $config_file"
            return 1
        }
    fi

    if ! validate_json "$config_file"; then
        log_warning "Invalid JSON in config file, reinitializing: $config_file"
        backup_file "$config_file" 2>/dev/null || true
        echo '{}' > "$config_file"
    fi

    python3 -c "
import json, sys
try:
    with open('$config_file', 'r') as f:
        data = json.load(f)
    value = data.get('$key', '')
    if isinstance(value, (list, dict)):
        print(json.dumps(value))
    else:
        print(value)
except Exception as e:
    sys.exit(1)
"
}

write_config_value() {
    local key="$1"
    local value="$2"
    local config_file="${3:-$CREDENTIALS_FILE}"

    ensure_directories || return 1

    # Create empty JSON file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        echo '{}' > "$config_file"
    fi

    # Backup existing file
    backup_file "$config_file" || return 1

    # Check if value is already JSON (starts with [ or {)
    if [[ "$value" =~ ^[\[\{] ]]; then
        # Value is JSON, use jq to update
        local temp_file
        temp_file=$(mktemp) || return 1

        if jq --arg key "$key" --argjson value "$value" '.[$key] = $value' "$config_file" > "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$config_file" || return 1
        else
            rm -f "$temp_file"
            return 1
        fi
    else
        # Value is string, use original Python method
        python3 -c "
import json, sys
try:
    with open('$config_file', 'r') as f:
        data = json.load(f)
    data['$key'] = '$value'
    with open('$config_file', 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    print(f'Error updating config: {e}', file=sys.stderr)
    sys.exit(1)
" || {
        log_error "Failed to update configuration"
        return 1
    }
    fi

    log_info "Updated configuration: $key"

    # Auto-update docker-compose.yml when critical config changes
    if [[ "$key" == "wallet_address" || "$key" == "node_id" ]]; then
        log_debug "Critical configuration changed, will trigger docker-compose regeneration"
        # Set a flag that docker operations should regenerate compose file
        export NEXUS_CONFIG_CHANGED="true"
    fi

    return 0
}

# System utilities
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

get_system_info() {
    echo "System Information:"
    echo "  OS: $(uname -s)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  CPU Cores: $(nproc)"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  Disk Space: $(df -h / | awk 'NR==2 {print $4}')"
}

# Docker utilities
is_docker_running() {
    docker info > /dev/null 2>&1
}

get_container_status() {
    local container_name="$1"
    docker ps -a --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# User interaction
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    while true; do
        if [[ "$default" == "y" ]]; then
            read -rp "$prompt [Y/n]: " response
            response=${response:-y}
        else
            read -rp "$prompt [y/N]: " response
            response=${response:-n}
        fi

        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

show_banner() {
    echo -e "${CYAN}"
    echo ""
    echo "  ██████╗  ██████╗ ██╗  ██╗██╗  ██╗ █████╗ ███╗   ██╗███████╗ "
    echo "  ██╔══██╗██╔═══██╗██║ ██╔╝██║  ██║██╔══██╗████╗  ██║╚══███╔╝ "
    echo "  ██████╔╝██║   ██║█████╔╝ ███████║███████║██╔██╗ ██║  ███╔╝  "
    echo "  ██╔══██╗██║   ██║██╔═██╗ ██╔══██║██╔══██║██║╚██╗██║ ███╔╝   "
    echo "  ██║  ██║╚██████╔╝██║  ██╗██║  ██║██║  ██║██║ ╚████║███████╗ "
    echo "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ "
    echo ""
    echo -e "${WHITE}           NEXUS ORCHESTRATOR v4.0${NC}"
    echo -e "${PURPLE}     Intelligent zkML Infrastructure Management${NC}"
    echo -e "${YELLOW}           Enterprise Edition${NC}"
    echo ""
}

show_section_header() {
    local title="$1"
    local icon="${2:-📋}"

    echo ""
    echo -e "${CYAN}${BOLD}$icon $title${NC}"
    echo -e "${CYAN}$(printf '%.0s─' {1..50})${NC}"
    echo ""
}

# Set up error trapping
set -eE
trap 'handle_error $? "Command failed" $LINENO' ERR

# Export functions for use in other modules
export -f log_message log_error log_warning log_info log_debug log_success log_activity handle_error
export -f ensure_directories backup_file
export -f validate_json validate_wallet_address validate_node_id validate_prover_id list_node_ids edit_node_id add_node_id remove_node_id
export -f read_config_value write_config_value
export -f check_root get_system_info
export -f is_docker_running get_container_status
export -f ask_yes_no show_banner show_section_header handle_error
