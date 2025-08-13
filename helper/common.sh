#!/bin/bash
# Author: Rokhanz
# Date: August 11, 2025
# License: MIT
# Description: Common functions for Nexus Orchestrator with preserved working Docker config

set -euo pipefail

# Color definitions - exported for external use (with guard)
# shellcheck disable=SC2034
if [[ -z "${RED:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly LIGHT_GREEN='\033[1;32m'
    readonly LIGHT_BLUE='\033[1;34m'
    readonly ORANGE='\033[0;33m'
    readonly NC='\033[0m'

    # Enhanced colors for better UI
    readonly BRIGHT_CYAN='\033[1;36m'
    readonly BRIGHT_YELLOW='\033[1;33m'
    readonly BRIGHT_GREEN='\033[1;32m'
    readonly BRIGHT_RED='\033[1;31m'
    readonly BRIGHT_BLUE='\033[1;34m'
    readonly BRIGHT_PURPLE='\033[1;35m'
    readonly GRAY='\033[0;37m'
    readonly DARK_GRAY='\033[1;30m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly UNDERLINE='\033[4m'
fi

# Project paths (with guard)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR=""
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    readonly SCRIPT_DIR
    readonly WORKDIR="$SCRIPT_DIR/workdir"
    readonly CONFIG_DIR="$WORKDIR/config"
    readonly LOGS_DIR="$WORKDIR/logs"
    readonly PROXY_FILE="$SCRIPT_DIR/proxy_list.txt"
    readonly CREDENTIALS_FILE="$CONFIG_DIR/credentials.json"
    readonly ERROR_LOG="$LOGS_DIR/error.log"
fi

# Working Docker configuration - PRESERVE THESE SETTINGS (with guards)
if [[ -z "${NEXUS_IMAGE:-}" ]]; then
    readonly NEXUS_IMAGE="nexusxyz/nexus-cli:latest"
    readonly NEXUS_HOME="/root/.nexus"
    readonly RUST_LOG_LEVEL="info"
    readonly BASE_PORT=10000
fi

## log_error - Log error with WIB timestamp
log_error() {
    local function_name="${1:-unknown}"
    local file_name="${2:-unknown}"
    local line_number="${3:-0}"
    local description="${4:-no description}"

    local timestamp
    timestamp=$(TZ="Asia/Jakarta" date '+%Y-%m-%d %H:%M:%S WIB')

    # Ensure logs directory exists
    mkdir -p "$LOGS_DIR"

    echo "[error], [$timestamp], $function_name, $file_name, $line_number, $description" >> "$ERROR_LOG"
}

## log_info - Log informational message
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message"
}

## log_warn - Log warning message
log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
}

## log_error_display - Display error message
log_error_display() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message"
}

## ensure_directories - Create required directories
ensure_directories() {
    local dirs=("$WORKDIR" "$CONFIG_DIR" "$LOGS_DIR")

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || {
                log_error "ensure_directories" "${BASH_SOURCE[0]}" "$LINENO" "Failed to create directory: $dir"
                return 1
            }
        fi
    done
}

## detect_existing_credentials - Check for existing credentials
detect_existing_credentials() {
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        log_info "Existing credentials detected: $CREDENTIALS_FILE"

        # Parse existing credentials
        if command -v jq &> /dev/null; then
            local wallet_address node_ids
            wallet_address=$(jq -r '.wallet_address // empty' "$CREDENTIALS_FILE" 2>/dev/null || echo "")
            node_ids=$(jq -r '.node_ids[]? // empty' "$CREDENTIALS_FILE" 2>/dev/null || echo "")

            if [[ -n "$wallet_address" ]]; then
                echo -e "${CYAN}Wallet Address: $wallet_address${NC}"
            fi

            if [[ -n "$node_ids" ]]; then
                echo -e "${CYAN}Node IDs:${NC}"
                echo "$node_ids" | while IFS= read -r node_id; do
                    echo -e "  - $node_id"
                done
            fi
        else
            log_warn "jq not installed, cannot parse credentials"
        fi

        return 0
    else
        log_info "No existing credentials found"
        return 1
    fi
}

## get_available_proxy - Get proxy for specific node (on-demand conversion)
get_available_proxy() {
    local proxy_file="$1"
    local node_id="$2"

    # Check if proxy file exists
    if [[ ! -f "$proxy_file" ]]; then
        log_warn "Proxy file not found: $proxy_file"
        return 1
    fi

    # Read proxy list and assign based on node_id
    local line_number
    line_number=$(( (node_id % $(wc -l < "$proxy_file")) + 1 ))

    local proxy_line
    proxy_line=$(sed -n "${line_number}p" "$proxy_file" 2>/dev/null || echo "")

    if [[ -z "$proxy_line" ]]; then
        log_warn "No proxy available for node $node_id"
        return 1
    fi

    # Convert https:// to http:// for Nexus CLI compatibility
    local converted_proxy
    converted_proxy="${proxy_line//https:/http:}"

    echo "$converted_proxy"
}

## get_proxy_display_name - Get sanitized proxy display name (hide credentials)
get_proxy_display_name() {
    local proxy_url="$1"

    # Extract IP and port from proxy URL (hide username/password)
    # Format: http://user:pass@ip:port -> ip:port
    if [[ "$proxy_url" =~ http://[^@]+@([0-9.]+):([0-9]+) ]]; then
        local ip="${BASH_REMATCH[1]}"
        local port="${BASH_REMATCH[2]}"

        # Mask IP for security: 192.168.1.100 -> 192.xx.xx.100
        local masked_ip
        if [[ "$ip" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
            masked_ip="${BASH_REMATCH[1]}.xx.xx.${BASH_REMATCH[4]}"
        else
            masked_ip="xxx.xx.xx.xxx"
        fi

        echo "$masked_ip:$port"
    else
        echo "proxy-hidden"
    fi
}

## open_ufw_port - Open UFW port for node
open_ufw_port() {
    local port="$1"

    if ! command -v ufw &> /dev/null; then
        log_warn "UFW not installed, skipping port management"
        return 0
    fi

    # Check if port is already open
    if ufw status | grep -q "$port/tcp"; then
        log_info "Port $port/tcp already open"
        return 0
    fi

    # Open port
    if ufw allow "$port/tcp" &> /dev/null; then
        log_info "Opened UFW port $port/tcp"
    else
        log_error "open_ufw_port" "${BASH_SOURCE[0]}" "$LINENO" "Failed to open port $port/tcp"
        return 1
    fi
}

## generate_docker_compose - Generate docker-compose with enhanced error handling
generate_docker_compose() {
    local node_id="$1"
    local port="$2"
    local proxy_url="${3:-}"

    ensure_directories || return 1

    local compose_file="$WORKDIR/docker-compose.yml"
    local container_name="nexus-node-$node_id"
    local volume_name="nexus_data_$node_id"

    # Clean up any existing volume that might cause conflicts
    docker volume rm "$volume_name" &>/dev/null || true

    # Use preserved working configuration with enhanced safety
    cat > "$compose_file" << EOF
# Generated with preserved working configuration
# Node ID: $node_id (Enhanced with cleanup)
# Image: $NEXUS_IMAGE (WORKING ✅)
# Command format: start --headless --node-id (WORKING ✅)
# Generated: $(date -Iseconds)

services:
  $container_name:
    image: $NEXUS_IMAGE
    container_name: $container_name
    restart: unless-stopped
    environment:
      - NEXUS_HOME=$NEXUS_HOME
      - RUST_LOG=$RUST_LOG_LEVEL
      - TZ=Asia/Jakarta
      - NODE_ID=$node_id
EOF

    # Add proxy environment if available
    if [[ -n "$proxy_url" ]]; then
        cat >> "$compose_file" << EOF
      - HTTP_PROXY=$proxy_url
      - HTTPS_PROXY=$proxy_url
      - http_proxy=$proxy_url
      - https_proxy=$proxy_url
EOF
    fi

    # Add volumes and command (preserve working format)
    cat >> "$compose_file" << EOF
    volumes:
      - $volume_name:$NEXUS_HOME
    ports:
      - "$port:$port"
    command: ["start", "--headless", "--node-id", "$node_id"]
    labels:
      - "nexus.orchestrator=true"
      - "nexus.node_id=$node_id"
      - "nexus.port=$port"

volumes:
  $volume_name:
    driver: local
    labels:
      - "nexus.node_id=$node_id"

EOF

    log_info "Generated docker-compose for node $node_id at port $port"

    # Open UFW port with comment
    open_ufw_port_with_comment "$port" "$container_name"
}

## start_node_with_proxy - Start node with automatic proxy assignment (Enhanced)
start_node_with_proxy() {
    local node_id="$1"

    # Step 1: Cleanup any existing containers/volumes first
    echo -e "${YELLOW}🧹 Cleaning up existing containers for node $node_id...${NC}"
    cleanup_node_containers "$node_id"

    # Ensure Docker image is available (auto-pull if missing)
    auto_pull_image_if_missing || {
        log_error "start_node_with_proxy" "${BASH_SOURCE[0]}" "$LINENO" "Failed to ensure Docker image availability"
        return 1
    }

    # Calculate port - use modulo to keep port in valid range (max 65535)
    # Take last 3 digits of node_id and add to BASE_PORT (consistent with management-node.sh)
    local port=$(( (node_id % 1000) + BASE_PORT ))

    # Get proxy (on-demand conversion)
    local proxy_url=""
    local proxy_display=""
    if [[ -f "$PROXY_FILE" ]]; then
        proxy_url=$(get_available_proxy "$PROXY_FILE" "$node_id" 2>/dev/null || echo "")

        if [[ -n "$proxy_url" ]]; then
            proxy_display=$(get_proxy_display_name "$proxy_url")
            log_info "Assigned proxy for node $node_id: $proxy_display"
        else
            log_warn "No proxy available for node $node_id, using direct connection"
        fi
    else
        log_warn "Proxy file not found, using direct connection"
    fi

    # Generate docker-compose with preserved config
    generate_docker_compose "$node_id" "$port" "$proxy_url" || {
        log_error "start_node_with_proxy" "${BASH_SOURCE[0]}" "$LINENO" "Failed to generate docker-compose for node $node_id"
        return 1
    }

    # Start container
    log_info "Starting node $node_id on port $port..."

    cd "$WORKDIR" || {
        log_error "start_node_with_proxy" "${BASH_SOURCE[0]}" "$LINENO" "Failed to change to workdir"
        return 1
    }

    # Use --remove-orphans flag to handle orphan containers
    if docker-compose up -d --remove-orphans; then
        log_info "Node $node_id started successfully"

        # Wait a moment and check status
        sleep 3
        if docker ps | grep -q "nexus-node-$node_id"; then
            log_info "Node $node_id is running"

            # Show container info
            echo -e "${GREEN}✅ Container Status:${NC}"
            docker ps --filter "name=nexus-node-$node_id" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            log_error_display "Node $node_id failed to start properly"
            echo -e "${YELLOW}📋 Checking logs for troubleshooting:${NC}"
            docker logs "nexus-node-$node_id" --tail 10 2>/dev/null || echo "No logs available"
        fi
    else
        log_error "start_node_with_proxy" "${BASH_SOURCE[0]}" "$LINENO" "Docker compose failed for node $node_id"
        return 1
    fi
}

## cleanup_node_containers - Clean up existing containers and volumes for node
cleanup_node_containers() {
    local node_id="$1"
    local container_name="nexus-node-$node_id"

    # Stop container if running
    if docker ps -q --filter "name=$container_name" | grep -q .; then
        echo -e "${YELLOW}  Stopping existing container: $container_name${NC}"
        docker stop "$container_name" &>/dev/null || true
    fi

    # Remove container if exists
    if docker ps -aq --filter "name=$container_name" | grep -q .; then
        echo -e "${YELLOW}  Removing existing container: $container_name${NC}"
        docker rm "$container_name" &>/dev/null || true
    fi

    # Clean up orphaned containers with similar names
    local orphaned_containers
    orphaned_containers=$(docker ps -aq --filter "name=nexus-node-" | head -5)
    if [[ -n "$orphaned_containers" ]]; then
        echo -e "${YELLOW}  Cleaning up orphaned containers...${NC}"
        echo "$orphaned_containers" | xargs docker rm -f &>/dev/null || true
    fi
}

## open_ufw_port_with_comment - Open UFW port with container name comment
open_ufw_port_with_comment() {
    local port="$1"
    local comment="${2:-Manual Nexus Port}"

    if command -v ufw &> /dev/null; then
        if sudo ufw allow "$port/tcp" comment "$comment"; then
            log_info "UFW port $port opened with comment: $comment"
        else
            log_error "open_ufw_port_with_comment" "${BASH_SOURCE[0]}" "$LINENO" "Failed to open port $port/tcp"
        fi
    else
        log_warn "UFW not available, skipping port opening"
    fi
}

## get_next_available_port - Get next available port for node
get_next_available_port() {
    local base_port=${1:-11000}
    local max_attempts=100

    for ((i=0; i<max_attempts; i++)); do
        local test_port=$((base_port + i))
        if ! ss -tuln | grep -q ":$test_port "; then
            echo "$test_port"
            return 0
        fi
    done

    log_error "get_next_available_port" "${BASH_SOURCE[0]}" "$LINENO" "No available ports found"
    return 1
}

## save_credentials_with_node_id - Save credentials with node ID
save_credentials_with_node_id() {
    local wallet_address="$1"
    local node_id="$2"
    local method="${3:-direct_cli}"

    ensure_directories || return 1

    local credentials_file="$WORKDIR/config/credentials.json"

    # Check if credentials exist and merge node IDs
    local existing_node_ids=""
    if [[ -f "$credentials_file" ]] && command -v jq &> /dev/null; then
        existing_node_ids=$(jq -r '.node_ids[]? // empty' "$credentials_file" 2>/dev/null | tr '\n' ' ')
    fi

    # Add new node ID to existing ones (avoid duplicates)
    local all_node_ids="$existing_node_ids $node_id"
    local unique_node_ids
    unique_node_ids=$(echo "$all_node_ids" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')

    # Create JSON array
    local node_ids_json="["
    for nid in $unique_node_ids; do
        [[ -n "$nid" ]] || continue
        if [[ "$node_ids_json" != "[" ]]; then
            node_ids_json="$node_ids_json,"
        fi
        node_ids_json="$node_ids_json\"$nid\""
    done
    node_ids_json="$node_ids_json]"

    cat > "$credentials_file" << EOF
{
  "wallet_address": "$wallet_address",
  "node_ids": $node_ids_json,
  "registration_type": "$method",
  "created_at": "$(date -Iseconds)",
  "last_updated": "$(date -Iseconds)"
}
EOF

    log_info "Credentials saved with node ID: $node_id"
}

## check_and_install_dependencies - Auto install required dependencies
check_and_install_dependencies() {
    echo -e "${CYAN}🔍 Checking system dependencies...${NC}"

    local required_deps=("docker" "docker-compose" "curl" "jq" "tar" "gzip")
    local optional_deps=("git" "wget" "ufw")
    local missing_required=()
    local missing_optional=()
    local install_commands=()

    # Check required dependencies
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_required+=("$dep")
            case "$dep" in
                "docker")
                    install_commands+=("Installing Docker...")
                    ;;
                "docker-compose")
                    install_commands+=("Installing Docker Compose...")
                    ;;
                "curl"|"jq"|"tar"|"gzip")
                    install_commands+=("sudo apt update && sudo apt install -y $dep")
                    ;;
            esac
        fi
    done

    # Check optional dependencies
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_optional+=("$dep")
        fi
    done

    # Report status
    if [[ ${#missing_required[@]} -eq 0 && ${#missing_optional[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ All dependencies are installed${NC}"
    else
        if [[ ${#missing_required[@]} -gt 0 ]]; then
            echo -e "${RED}❌ Missing required dependencies: ${missing_required[*]}${NC}"
            echo -e "${YELLOW}🔧 Auto-installing missing dependencies...${NC}"

            # Auto-install missing dependencies
            for dep in "${missing_required[@]}"; do
                case "$dep" in
                    "docker")
                        install_docker
                        ;;
                    "docker-compose")
                        install_docker_compose
                        ;;
                    "curl"|"jq"|"tar"|"gzip")
                        echo -e "${YELLOW}Installing $dep...${NC}"
                        if sudo apt update && sudo apt install -y "$dep"; then
                            echo -e "${GREEN}✅ $dep installed successfully${NC}"
                        else
                            echo -e "${RED}❌ Failed to install $dep${NC}"
                            return 1
                        fi
                        ;;
                esac
            done
        fi

        if [[ ${#missing_optional[@]} -gt 0 ]]; then
            echo -e "${YELLOW}⚠️ Missing optional dependencies: ${missing_optional[*]}${NC}"
            echo -e "${BLUE}💡 Install with: sudo apt install -y ${missing_optional[*]}${NC}"
        fi
    fi

    # Check Docker daemon after installation
    if command -v docker &> /dev/null; then
        if ! docker info &> /dev/null; then
            echo -e "${YELLOW}🔄 Starting Docker daemon...${NC}"
            if sudo systemctl start docker && sudo systemctl enable docker; then
                echo -e "${GREEN}✅ Docker daemon started${NC}"

                # Add current user to docker group if not already
                if ! groups | grep -q docker; then
                    echo -e "${YELLOW}👤 Adding user to docker group...${NC}"
                    sudo usermod -aG docker "$USER"
                    echo -e "${YELLOW}⚠️ Please logout and login again for docker group changes to take effect${NC}"
                fi
            else
                echo -e "${RED}❌ Failed to start Docker daemon${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✅ Docker daemon is running${NC}"
        fi
    fi

    echo -e "${GREEN}✅ Dependency check completed${NC}"
    echo ""
}

## check_and_create_swap - Auto create 10GB swap if not exists
check_and_create_swap() {
    echo -e "${CYAN}💾 Checking swap memory configuration...${NC}"
    sleep 2

    # Check current swap status
    local swap_total
    swap_total=$(free -m | awk '/^Swap:/ {print $2}')

    if [[ "$swap_total" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ No swap memory detected${NC}"
        echo -e "${CYAN}🔧 Creating 10GB swap file for better performance...${NC}"
        sleep 2

        # Check available disk space (need at least 12GB for 10GB swap + buffer)
        local available_space
        available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')

        if [[ "$available_space" -lt 12 ]]; then
            echo -e "${RED}❌ Insufficient disk space. Need at least 12GB available${NC}"
            echo -e "${YELLOW}💡 Available space: ${available_space}GB${NC}"
            return 1
        fi

        echo -e "${YELLOW}📁 Creating swap file (this may take a few minutes)...${NC}"
        sleep 1

        # Create 10GB swap file
        if sudo fallocate -l 10G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1024 count=10485760 status=progress; then
            echo -e "${GREEN}✅ Swap file created${NC}"
            sleep 1
        else
            echo -e "${RED}❌ Failed to create swap file${NC}"
            return 1
        fi

        echo -e "${YELLOW}🔐 Setting swap file permissions...${NC}"
        sudo chmod 600 /swapfile
        sleep 1

        echo -e "${YELLOW}🔧 Setting up swap area...${NC}"
        if sudo mkswap /swapfile; then
            echo -e "${GREEN}✅ Swap area configured${NC}"
            sleep 1
        else
            echo -e "${RED}❌ Failed to setup swap area${NC}"
            return 1
        fi

        echo -e "${YELLOW}🚀 Enabling swap...${NC}"
        if sudo swapon /swapfile; then
            echo -e "${GREEN}✅ Swap enabled successfully${NC}"
            sleep 1
        else
            echo -e "${RED}❌ Failed to enable swap${NC}"
            return 1
        fi

        echo -e "${YELLOW}💾 Making swap permanent...${NC}"
        if ! grep -q '/swapfile' /etc/fstab; then
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
            echo -e "${GREEN}✅ Swap made permanent${NC}"
        fi
        sleep 1

        # Configure swappiness for better performance
        echo -e "${YELLOW}⚙️ Optimizing swap settings...${NC}"
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
        sudo sysctl vm.swappiness=10 > /dev/null
        echo -e "${GREEN}✅ Swap optimized (swappiness=10)${NC}"
        sleep 1

        # Display final status
        echo -e "${CYAN}📊 Final swap status:${NC}"
        free -h | grep -E "Mem:|Swap:"

    elif [[ "$swap_total" -lt 8192 ]]; then
        echo -e "${YELLOW}⚠️ Swap memory detected but less than 8GB (${swap_total}MB)${NC}"
        echo -e "${BLUE}💡 Current swap: $(($swap_total / 1024))GB${NC}"
        echo -e "${BLUE}💡 For optimal performance, consider 10GB+ swap for Nexus mining${NC}"

    else
        echo -e "${GREEN}✅ Sufficient swap memory detected: $(($swap_total / 1024))GB${NC}"
    fi

    echo -e "${GREEN}✅ Swap memory check completed${NC}"
    echo ""
    sleep 1
}

## install_docker - Install Docker
install_docker() {
    echo -e "${YELLOW}🐳 Installing Docker...${NC}"

    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Update package index
    sudo apt update

    # Install packages to allow apt to use repository over HTTPS
    sudo apt install -y \
        ca-certificates \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    sudo apt update
    if sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin; then
        echo -e "${GREEN}✅ Docker installed successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to install Docker${NC}"
        return 1
    fi
}

## install_docker_compose - Install Docker Compose
install_docker_compose() {
    echo -e "${YELLOW}🔧 Installing Docker Compose...${NC}"

    # Get latest version
    local compose_version
    compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')

    if [[ -z "$compose_version" ]]; then
        compose_version="v2.21.0"  # Fallback version
        echo -e "${YELLOW}⚠️ Using fallback version: $compose_version${NC}"
    fi

    # Download and install
    if curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /tmp/docker-compose; then
        sudo mv /tmp/docker-compose /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        # Create symlink for compatibility
        sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true

        echo -e "${GREEN}✅ Docker Compose $compose_version installed successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to install Docker Compose${NC}"
        return 1
    fi
}

## check_dependencies - Check required dependencies (legacy function maintained for compatibility)
check_dependencies() {
    # This function is maintained for backward compatibility
    # Redirect to the new comprehensive function
    check_and_install_dependencies
}

## save_credentials - Save credentials to JSON file
save_credentials() {
    local wallet_address="$1"
    local node_id="$2"

    ensure_directories || return 1

    # Check if credentials file exists
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        # Update existing file
        if command -v jq &> /dev/null; then
            local temp_file
            temp_file=$(mktemp)

            # Add node_id to existing array if not already present
            jq --arg wallet "$wallet_address" --arg node "$node_id" '
                .wallet_address = $wallet |
                .node_ids = (.node_ids // []) |
                if .node_ids | index($node) then . else .node_ids += [$node] end
            ' "$CREDENTIALS_FILE" > "$temp_file" && mv "$temp_file" "$CREDENTIALS_FILE"
        else
            log_warn "jq not available, creating simple JSON format"
            cat > "$CREDENTIALS_FILE" << EOF
{
  "wallet_address": "$wallet_address",
  "node_ids": ["$node_id"]
}
EOF
        fi
    else
        # Create new credentials file
        cat > "$CREDENTIALS_FILE" << EOF
{
  "wallet_address": "$wallet_address",
  "node_ids": ["$node_id"]
}
EOF
    fi

    log_info "Credentials saved for wallet: $wallet_address, node: $node_id"
}

## auto_pull_image_if_missing - Auto pull image if not present
auto_pull_image_if_missing() {
    if ! docker images | grep -q "nexusxyz/nexus-cli"; then
        log_info "Nexus CLI image not found, auto-pulling..."
        pull_nexus_image_with_retry
        return $?
    fi
    return 0
}

## pull_nexus_image_with_retry - Pull Nexus image with retry mechanism
pull_nexus_image_with_retry() {
    local max_retries=3
    local retry_delay=5
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        log_info "Attempt $attempt/$max_retries: Pulling nexusxyz/nexus-cli:latest..."

        if docker pull nexusxyz/nexus-cli:latest; then
            log_info "Successfully pulled nexusxyz/nexus-cli:latest"
            return 0
        else
            log_warn "Failed to pull image (attempt $attempt/$max_retries)"

            if [[ $attempt -lt $max_retries ]]; then
                log_info "Retrying in $retry_delay seconds..."
                sleep $retry_delay
                # Exponential backoff
                retry_delay=$((retry_delay * 2))
            fi
        fi

        ((attempt++))
    done

    log_error_display "Failed to pull image after $max_retries attempts"
    log_error "pull_nexus_image_with_retry" "${BASH_SOURCE[0]}" "$LINENO" "Failed to pull image after $max_retries attempts"
    return 1
}

# Initialize directories on source
ensure_directories

## get_nexus_cli_version - Get installed Nexus CLI version with fallback
get_nexus_cli_version() {
    if command -v nexus-network &> /dev/null; then
        local version
        # Try multiple methods to get version
        version=$(nexus-network --version 2>/dev/null | grep -oP 'nexus-network \K[\d\.]+' 2>/dev/null || echo "")

        if [[ -z "$version" ]]; then
            # Fallback: try different version format
            version=$(nexus-network --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' 2>/dev/null || echo "")
        fi

        if [[ -z "$version" ]]; then
            # Final fallback: just confirm it's installed
            echo "installed"
        else
            echo "$version"
        fi
    else
        echo "not_installed"
    fi
}

## get_nexus_docker_version - Get Docker image version info with fallback
get_nexus_docker_version() {
    if ! command -v docker &> /dev/null; then
        echo "docker_not_available"
        return
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null 2>&1; then
        echo "docker_not_running"
        return
    fi

    # Try to get image info with multiple fallbacks
    local image_info created_date

    # Method 1: Try with table format
    image_info=$(docker images nexusxyz/nexus-cli:latest --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" 2>/dev/null | tail -n +2 || echo "")

    if [[ -n "$image_info" ]]; then
        created_date=$(echo "$image_info" | awk '{print $2, $3, $4}' 2>/dev/null || echo "unknown")
        echo "$created_date"
        return
    fi

    # Method 2: Try with simple format
    image_info=$(docker images nexusxyz/nexus-cli:latest --format "{{.CreatedAt}}" 2>/dev/null || echo "")

    if [[ -n "$image_info" ]]; then
        echo "$image_info"
        return
    fi

    # Method 3: Check if image exists at all
    if docker images nexusxyz/nexus-cli:latest -q 2>/dev/null | grep -q .; then
        echo "available"
    else
        echo "not_available"
    fi
}

## display_nexus_version_info - Display comprehensive version information
display_nexus_version_info() {
    echo -e "${BRIGHT_CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_CYAN}║                    🚀 NEXUS VERSION INFO                 ║${NC}"
    echo -e "${BRIGHT_CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # CLI Version
    echo -e "${BRIGHT_YELLOW}📋 CLI Information:${NC}"
    local cli_version
    cli_version=$(get_nexus_cli_version)

    if [[ "$cli_version" == "not_installed" ]]; then
        echo -e "   ${GRAY}CLI Status:${NC} ${RED}❌ Not Installed${NC}"
        echo -e "   ${GRAY}Install with:${NC} ${CYAN}curl -fsSL https://cli.nexus.xyz | sh${NC}"
    elif [[ "$cli_version" == "installed" ]]; then
        echo -e "   ${GRAY}CLI Status:${NC} ${GREEN}✅ Installed${NC}"
        echo -e "   ${GRAY}CLI Version:${NC} ${YELLOW}Available (version detection failed)${NC}"
        echo -e "   ${GRAY}Binary Path:${NC} ${CYAN}$(command -v nexus-network)${NC}"
    else
        echo -e "   ${GRAY}CLI Status:${NC} ${GREEN}✅ Installed${NC}"
        echo -e "   ${GRAY}CLI Version:${NC} ${BRIGHT_GREEN}v$cli_version${NC}"
        echo -e "   ${GRAY}Binary Path:${NC} ${CYAN}$(command -v nexus-network)${NC}"
    fi

    echo ""

    # Docker Image Info
    echo -e "${BRIGHT_YELLOW}🐳 Docker Image Information:${NC}"
    local docker_version
    docker_version=$(get_nexus_docker_version)

    if [[ "$docker_version" == "docker_not_available" ]]; then
        echo -e "   ${GRAY}Docker Status:${NC} ${RED}❌ Docker Not Available${NC}"
    elif [[ "$docker_version" == "docker_not_running" ]]; then
        echo -e "   ${GRAY}Docker Status:${NC} ${RED}❌ Docker Not Running${NC}"
    elif [[ "$docker_version" == "not_available" ]]; then
        echo -e "   ${GRAY}Image Status:${NC} ${YELLOW}⚠️ Image Not Downloaded${NC}"
        echo -e "   ${GRAY}Download with:${NC} ${CYAN}docker pull nexusxyz/nexus-cli:latest${NC}"
    elif [[ "$docker_version" == "available" ]]; then
        echo -e "   ${GRAY}Image Status:${NC} ${GREEN}✅ Available${NC}"
        echo -e "   ${GRAY}Image:${NC} ${BRIGHT_GREEN}nexusxyz/nexus-cli:latest${NC}"
        echo -e "   ${GRAY}Created:${NC} ${CYAN}Date info unavailable${NC}"

        # Try to get image size with fallback
        local image_size
        image_size=$(docker images nexusxyz/nexus-cli:latest --format "{{.Size}}" 2>/dev/null || echo "unknown")
        echo -e "   ${GRAY}Size:${NC} ${YELLOW}$image_size${NC}"
    else
        echo -e "   ${GRAY}Image Status:${NC} ${GREEN}✅ Available${NC}"
        echo -e "   ${GRAY}Image:${NC} ${BRIGHT_GREEN}nexusxyz/nexus-cli:latest${NC}"
        echo -e "   ${GRAY}Created:${NC} ${CYAN}$docker_version${NC}"

        # Get image size with fallback
        local image_size
        image_size=$(docker images nexusxyz/nexus-cli:latest --format "{{.Size}}" 2>/dev/null || echo "unknown")
        echo -e "   ${GRAY}Size:${NC} ${YELLOW}$image_size${NC}"
    fi

    echo ""

    # System Info
    echo -e "${BRIGHT_YELLOW}💻 System Information:${NC}"
    echo -e "   ${GRAY}OS:${NC} ${CYAN}$(uname -s) $(uname -r)${NC}"
    echo -e "   ${GRAY}Architecture:${NC} ${CYAN}$(uname -m)${NC}"

    # Check Docker status
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            echo -e "   ${GRAY}Docker:${NC} ${GREEN}✅ Running${NC}"
            local docker_ver
            docker_ver=$(docker --version | grep -oP 'Docker version \K[\d\.]+' || echo "unknown")
            echo -e "   ${GRAY}Docker Version:${NC} ${CYAN}v$docker_ver${NC}"
        else
            echo -e "   ${GRAY}Docker:${NC} ${RED}❌ Not Running${NC}"
        fi
    else
        echo -e "   ${GRAY}Docker:${NC} ${RED}❌ Not Installed${NC}"
    fi

    # Check Compose
    if command -v docker-compose &> /dev/null; then
        local compose_ver
        compose_ver=$(docker-compose --version | grep -oP 'docker-compose version \K[\d\.]+' || echo "unknown")
        echo -e "   ${GRAY}Docker Compose:${NC} ${GREEN}✅ v$compose_ver${NC}"
    else
        echo -e "   ${GRAY}Docker Compose:${NC} ${RED}❌ Not Available${NC}"
    fi

    echo ""

    # Network connectivity check
    echo -e "${BRIGHT_YELLOW}🌐 Network Connectivity:${NC}"

    # Quick internet check with timeout
    if timeout 3 ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "   ${GRAY}Internet:${NC} ${GREEN}✅ Connected${NC}"

        # Check Nexus endpoints with timeout and fallback
        echo -e "   ${GRAY}Checking endpoints...${NC}"

        if timeout 5 curl -s --max-time 3 https://cli.nexus.xyz &> /dev/null; then
            echo -e "   ${GRAY}Nexus CLI Endpoint:${NC} ${GREEN}✅ Reachable${NC}"
        else
            echo -e "   ${GRAY}Nexus CLI Endpoint:${NC} ${YELLOW}⚠️ Slow/Unreachable${NC}"
        fi

        if timeout 5 curl -s --max-time 3 https://hub.docker.com &> /dev/null; then
            echo -e "   ${GRAY}Docker Hub:${NC} ${GREEN}✅ Reachable${NC}"
        else
            echo -e "   ${GRAY}Docker Hub:${NC} ${YELLOW}⚠️ Slow/Unreachable${NC}"
        fi
    else
        echo -e "   ${GRAY}Internet:${NC} ${RED}❌ No Connection${NC}"
        echo -e "   ${GRAY}Nexus CLI Endpoint:${NC} ${GRAY}❓ Skipped (no internet)${NC}"
        echo -e "   ${GRAY}Docker Hub:${NC} ${GRAY}❓ Skipped (no internet)${NC}"
    fi

    echo ""
}

## display_colorful_header - Enhanced colorful header for submenus
display_colorful_header() {
    local title="$1"
    local subtitle="${2:-}"

    clear

    # Main title with gradient effect
    echo -e "${BRIGHT_CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_CYAN}║${NC}${BOLD}                    🚀 $title${NC}${BRIGHT_CYAN}║${NC}"

    if [[ -n "$subtitle" ]]; then
        echo -e "${BRIGHT_CYAN}║${NC}${DIM}                    $subtitle${NC}${BRIGHT_CYAN}║${NC}"
    fi

    echo -e "${BRIGHT_CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

## display_menu_separator - Colorful menu separator
display_menu_separator() {
    echo -e "${DARK_GRAY}${DIM}────────────────────────────────────────────────────────────${NC}"
}

## display_status_badge - Display colored status badge
display_status_badge() {
    local status="$1"
    local text="$2"

    case "$status" in
        "success"|"running"|"active")
            echo -e "${GREEN}✅${NC} ${BRIGHT_GREEN}$text${NC}"
            ;;
        "warning"|"pending"|"partial")
            echo -e "${YELLOW}⚠️${NC} ${BRIGHT_YELLOW}$text${NC}"
            ;;
        "error"|"failed"|"stopped")
            echo -e "${RED}❌${NC} ${BRIGHT_RED}$text${NC}"
            ;;
        "info"|"neutral")
            echo -e "${BLUE}ℹ️${NC} ${BRIGHT_BLUE}$text${NC}"
            ;;
        *)
            echo -e "${GRAY}•${NC} ${WHITE}$text${NC}"
            ;;
    esac
}

## start_multiple_nodes_with_compose - Start multiple nodes using single compose file
start_multiple_nodes_with_compose() {
    local node_ids=("$@")

    [[ ${#node_ids[@]} -eq 0 ]] && {
        log_error "start_multiple_nodes_with_compose" "${BASH_SOURCE[0]}" "$LINENO" "No node IDs provided"
        return 1
    }

    echo -e "${BRIGHT_YELLOW}🔄 Creating multi-node docker-compose configuration...${NC}"

    # Ensure directories
    ensure_directories || return 1

    local compose_file="$WORKDIR/docker-compose-multi.yml"
    local wallet_address

    # Get wallet address from credentials
    wallet_address=$(jq -r '.wallet_address // "unknown"' "$CREDENTIALS_FILE" 2>/dev/null || echo "unknown")

    # Create multi-node compose header
    cat > "$compose_file" << EOF
# Multi-Node Docker Compose Configuration
# Generated for ${#node_ids[@]} nodes: ${node_ids[*]}
# Wallet: $wallet_address
# Generated: $(date -Iseconds)

services:
EOF

    # Add each node as a service
    for node_id in "${node_ids[@]}"; do
        # Use modulo to keep port in valid range (max 65535)
        # Take last 3 digits of node_id and add to BASE_PORT
        local port=$(( (node_id % 1000) + BASE_PORT ))
        local container_name="nexus-node-$node_id"

        # Get proxy if available
        local proxy_url=""
        if [[ -f "$PROXY_FILE" ]]; then
            proxy_url=$(get_available_proxy "$PROXY_FILE" "$node_id" 2>/dev/null || echo "")
        fi

        echo -e "${CYAN}📝 Adding Node $node_id (Port: $port, Last 3 digits: $((node_id % 1000)))${NC}"

        # Add service definition
        cat >> "$compose_file" << EOF
  $container_name:
    image: $NEXUS_IMAGE
    container_name: $container_name
    restart: unless-stopped
    environment:
      - NEXUS_HOME=$NEXUS_HOME
      - RUST_LOG=$RUST_LOG_LEVEL
      - TZ=Asia/Jakarta
      - NODE_ID=$node_id
      - WALLET_ADDRESS=$wallet_address
EOF

        # Add proxy if available
        if [[ -n "$proxy_url" ]]; then
            cat >> "$compose_file" << EOF
      - HTTP_PROXY=$proxy_url
      - HTTPS_PROXY=$proxy_url
      - http_proxy=$proxy_url
      - https_proxy=$proxy_url
EOF
        fi

        # Add volumes, ports, and command
        cat >> "$compose_file" << EOF
    volumes:
      - nexus_data_$node_id:$NEXUS_HOME
    ports:
      - "$port:$port"
    command: ["start", "--headless", "--node-id", "$node_id"]
    labels:
      - "nexus.orchestrator=true"
      - "nexus.node_id=$node_id"
      - "nexus.wallet=$wallet_address"
      - "nexus.port=$port"

EOF

        # Open UFW port
        open_ufw_port_with_comment "$port" "$container_name"
    done

    # Add volumes section
    echo "volumes:" >> "$compose_file"
    for node_id in "${node_ids[@]}"; do
        echo "  nexus_data_$node_id:" >> "$compose_file"
        echo "    external: false" >> "$compose_file"
    done
    echo "" >> "$compose_file"

    echo -e "${GREEN}✅ Multi-node compose created: $compose_file${NC}"

    # Check for potential port conflicts
    check_port_conflicts "${node_ids[@]}"

    # Start all nodes
    echo -e "${CYAN}🚀 Starting all ${#node_ids[@]} nodes simultaneously...${NC}"

    cd "$WORKDIR" || {
        log_error "start_multiple_nodes_with_compose" "${BASH_SOURCE[0]}" "$LINENO" "Failed to change to workdir"
        return 1
    }

    # Use the multi-compose file
    if docker-compose -f docker-compose-multi.yml up -d; then
        echo ""
        echo -e "${GREEN}✅ All nodes started successfully!${NC}"

        # Wait and check status
        sleep 5
        echo -e "${BRIGHT_GREEN}📊 Node Status Summary:${NC}"

        for node_id in "${node_ids[@]}"; do
            local container_name="nexus-node-$node_id"
            if docker ps | grep -q "$container_name"; then
                echo -e "   ${GREEN}✅ Node $node_id: Running${NC}"
            else
                echo -e "   ${RED}❌ Node $node_id: Failed${NC}"
            fi
        done

        echo ""
        echo -e "${YELLOW}📊 Full container status:${NC}"
        docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

        echo ""
        echo -e "${YELLOW}💡 Monitoring tips:${NC}"
        echo "   • View all logs: docker-compose -f docker-compose-multi.yml logs -f"
        echo "   • View specific node: docker logs nexus-node-[NODE_ID] -f"
        echo "   • Stop all: docker-compose -f docker-compose-multi.yml down"

    else
        log_error "start_multiple_nodes_with_compose" "${BASH_SOURCE[0]}" "$LINENO" "Docker compose failed for multi-node"
        return 1
    fi
}

## check_port_conflicts - Check for port conflicts between nodes
check_port_conflicts() {
    local node_ids=("$@")

    echo ""
    echo -e "${YELLOW}🔍 Port Assignment Summary:${NC}"
    local used_ports=()
    local conflicts=()

    for node_id in "${node_ids[@]}"; do
        local port=$(( (node_id % 1000) + BASE_PORT ))
        printf "   Node %-8s → Port %d (last 3 digits: %03d)\n" "$node_id" "$port" "$((node_id % 1000))"

        # Check for conflicts
        local found_conflict=false
        for used_port in "${used_ports[@]}"; do
            if [[ "$used_port" == "$port" ]]; then
                found_conflict=true
                break
            fi
        done

        if [[ "$found_conflict" == "true" ]]; then
            conflicts+=("$port")
        else
            used_ports+=("$port")
        fi
    done

    # Warn about conflicts
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}⚠️ WARNING: Port conflicts detected!${NC}"
        echo -e "${YELLOW}   Conflicting ports: ${conflicts[*]}${NC}"
        echo -e "${YELLOW}   Some nodes may fail to start due to port conflicts.${NC}"
        echo ""
        read -r -p "$(echo -e "${YELLOW}Continue anyway? (y/N): ${NC}")" -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled. Consider using different node IDs.${NC}"
            return 1
        fi
    fi
}

## start_node_individual - Start single node using docker run (no compose conflicts)
start_node_individual() {
    local node_id="$1"

    [[ -z "$node_id" ]] && {
        log_error "start_node_individual" "${BASH_SOURCE[0]}" "$LINENO" "Node ID is required"
        return 1
    }

    # Cleanup existing container first
    docker stop "nexus-node-$node_id" &>/dev/null || true
    docker rm "nexus-node-$node_id" &>/dev/null || true

    # Calculate port - use modulo to keep port in valid range (max 65535)
    # Take last 3 digits of node_id and add to BASE_PORT
    local port=$(( (node_id % 1000) + BASE_PORT ))
    local container_name="nexus-node-$node_id"
    local volume_name="nexus_data_$node_id"

    # Get proxy if available
    local proxy_url=""
    local proxy_args=""
    if [[ -f "$PROXY_FILE" ]]; then
        proxy_url=$(get_available_proxy "$PROXY_FILE" "$node_id" 2>/dev/null || echo "")
        if [[ -n "$proxy_url" ]]; then
            proxy_args="-e HTTP_PROXY=$proxy_url -e HTTPS_PROXY=$proxy_url -e http_proxy=$proxy_url -e https_proxy=$proxy_url"
        fi
    fi

    # Get wallet address
    local wallet_address
    wallet_address=$(jq -r '.wallet_address // "unknown"' "$CREDENTIALS_FILE" 2>/dev/null || echo "unknown")

    echo -e "${CYAN}📝 Starting Node $node_id on port $port...${NC}"

    # Start with docker run
    # shellcheck disable=SC2086
    if docker run -d \
        --name "$container_name" \
        --restart unless-stopped \
        -e "NEXUS_HOME=$NEXUS_HOME" \
        -e "RUST_LOG=$RUST_LOG_LEVEL" \
        -e "TZ=Asia/Jakarta" \
        -e "NODE_ID=$node_id" \
        -e "WALLET_ADDRESS=$wallet_address" \
        $proxy_args \
        -v "$volume_name:$NEXUS_HOME" \
        -p "$port:$port" \
        --label "nexus.orchestrator=true" \
        --label "nexus.node_id=$node_id" \
        --label "nexus.wallet=$wallet_address" \
        --label "nexus.port=$port" \
        "$NEXUS_IMAGE" \
        start --headless --node-id "$node_id"; then

        echo -e "${GREEN}✅ Node $node_id started successfully${NC}"

        # Open UFW port
        open_ufw_port_with_comment "$port" "$container_name"

        log_info "Node $node_id started individually on port $port"
        return 0
    else
        log_error "start_node_individual" "${BASH_SOURCE[0]}" "$LINENO" "Failed to start Node $node_id"
        return 1
    fi
}

## wait_for_keypress - Standardized wait for user input with clear screen
wait_for_keypress() {
    local message="${1:-Tekan tombol apapun untuk kembali...}"
    echo ""
    echo -e "${LIGHT_BLUE}$message${NC}"
    read -r -n 1
    clear
}
