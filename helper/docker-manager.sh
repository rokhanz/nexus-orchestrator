#!/bin/bash
# Author: Rokhanz
# Date: August 11, 2025
# License: MIT
# Description: Docker Management - preserves working Docker configurations

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## docker_management_menu - Docker & System management menu
docker_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}🔧 MANAGE DOCKER & SYSTEM${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
        echo ""

        # Show Docker status
        if docker info &> /dev/null; then
            echo -e "${GREEN}✅ Docker daemon is running${NC}"
        else
            echo -e "${RED}❌ Docker daemon is not running${NC}"
        fi

        # Show running containers count
        local container_count
        container_count=$(docker ps --filter "name=nexus-node-" -q 2>/dev/null | wc -l)
        echo -e "${CYAN}📦 Running Nexus containers: $container_count${NC}"
        echo ""

        echo -e "${WHITE}🐳 Pilih aksi Docker & System management:${NC}"
        echo ""
        PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
        select opt in "🐳 Docker Status & Health Check" "🔄 Restart All Containers" "🧹 Clean Unused Images/Volumes" "📦 Update Docker Compose" "🔧 System Resources Monitor" "🚪 Kembali ke Menu Utama"; do
            case $opt in
                "🐳 Docker Status & Health Check")
                    echo -e "${CYAN}🐳 Menjalankan Docker health check...${NC}"
                    docker_health_check
                    break
                    ;;
                "🔄 Restart All Containers")
                    echo -e "${CYAN}🔄 Restart semua container...${NC}"
                    restart_all_containers
                    break
                    ;;
                "🧹 Clean Unused Images/Volumes")
                    echo -e "${CYAN}🧹 Membersihkan resources Docker...${NC}"
                    clean_docker_resources
                    break
                    ;;
                "📦 Update Docker Compose")
                    echo -e "${CYAN}📦 Update Docker Compose...${NC}"
                    update_docker_compose
                    break
                    ;;
                "🔧 System Resources Monitor")
                    echo -e "${CYAN}🔧 Menampilkan monitor system resources...${NC}"
                    system_resources_monitor
                    break
                    ;;
                "🚪 Kembali ke Menu Utama")
                    echo -e "${GREEN}↩️ Kembali ke menu utama...${NC}"
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-6.${NC}"
                    sleep 1
                    ;;
            esac
        done
    done
}

## docker_health_check - Comprehensive Docker health check
docker_health_check() {
    clear
    echo -e "${CYAN}🐳 DOCKER HEALTH CHECK${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # Check Docker daemon
    echo -e "${YELLOW}Checking Docker daemon...${NC}"
    if docker info &> /dev/null; then
        log_info "Docker daemon is running"
    else
        log_error_display "Docker daemon is not running"
        echo ""
        echo "To start Docker:"
        echo "  sudo systemctl start docker"
        read -r -p "Press Enter to continue..."
        return
    fi

    # Check Docker Compose
    echo ""
    echo -e "${YELLOW}Checking Docker Compose...${NC}"
    if command -v docker-compose &> /dev/null; then
        local compose_version
        compose_version=$(docker-compose --version 2>/dev/null || echo "unknown")
        log_info "Docker Compose: $compose_version"
    else
        log_warn "Docker Compose not found"
    fi

    # Check Nexus image
    echo ""
    echo -e "${YELLOW}Checking Nexus CLI image...${NC}"
    if docker images | grep -q "nexusxyz/nexus-cli"; then
        local image_info
        image_info=$(docker images nexusxyz/nexus-cli --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}")
        log_info "Nexus CLI image found:"
        echo "$image_info"

        # Check for updates automatically
        check_and_update_nexus_image
    else
        log_warn "Nexus CLI image not found"
        log_info "Auto-pulling nexusxyz/nexus-cli:latest..."
        pull_nexus_image_with_retry
    fi

    # Check running containers
    echo ""
    echo -e "${YELLOW}Checking running containers...${NC}"
    local nexus_containers
    nexus_containers=$(docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "")

    if [[ -n "$nexus_containers" ]]; then
        log_info "Running Nexus containers:"
        echo "$nexus_containers"
    else
        log_info "No Nexus containers running"
    fi

    # Check volumes
    echo ""
    echo -e "${YELLOW}Checking volumes...${NC}"
    local nexus_volumes
    nexus_volumes=$(docker volume ls --filter "name=nexus" --format "table {{.Name}}\t{{.Driver}}" 2>/dev/null || echo "")

    if [[ -n "$nexus_volumes" ]]; then
        log_info "Nexus volumes:"
        echo "$nexus_volumes"
        echo ""

        # Volume management options
        echo -e "${CYAN}📦 Volume Management Options:${NC}"
        echo "  v) View detailed volume information"
        echo "  c) Cleanup unused volumes"
        echo "  s) Skip volume management"
        echo ""
        read -r -p "$(echo -e "${YELLOW}Choose volume action (v/c/s): ${NC}")" volume_action

        case "$volume_action" in
            "v"|"V")
                show_detailed_volumes
                ;;
            "c"|"C")
                cleanup_unused_volumes
                ;;
            "s"|"S")
                echo -e "${CYAN}Continuing with system resources...${NC}"
                ;;
            *)
                echo -e "${YELLOW}⚠️ Invalid choice, continuing...${NC}"
                ;;
        esac
    else
        log_info "No Nexus volumes found"
    fi

    # Check system resources
    echo ""
    echo -e "${YELLOW}System resources:${NC}"
    echo "  CPU cores: $(nproc)"
    echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $2}' || echo "unknown")"
    echo "  Disk space: $(df -h / | tail -1 | awk '{print $4}' || echo "unknown") available"

    read -r -p "Press Enter to continue..."
}

## restart_all_containers - Restart all Nexus containers
restart_all_containers() {
    echo ""
    log_info "Restarting all Nexus containers..."

    local containers
    containers=$(docker ps --filter "name=nexus-node-" -q 2>/dev/null || echo "")

    if [[ -z "$containers" ]]; then
        log_warn "No running Nexus containers found"
    else
        echo ""
        echo -e "${YELLOW}Found containers to restart:${NC}"
        docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}"
        echo ""

        read -p "$(echo -e "${YELLOW}Proceed with restart? (Y/n): ${NC}")" -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "$containers" | while IFS= read -r container_id; do
                [[ -n "$container_id" ]] || continue
                local container_name
                container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
                log_info "Restarting $container_name..."
                docker restart "$container_id"
                sleep 2
            done

            echo ""
            log_info "All containers restarted!"

            # Show status after restart
            echo ""
            echo -e "${GREEN}Status after restart:${NC}"
            docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Status}}"
        else
            log_info "Restart cancelled"
        fi
    fi

    read -r -p "Press Enter to continue..."
}

## clean_docker_resources - Clean unused Docker resources
clean_docker_resources() {
    clear
    echo -e "${CYAN}🧹 CLEAN DOCKER RESOURCES${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}This will clean:${NC}"
    echo "  - Stopped containers"
    echo "  - Unused images"
    echo "  - Unused volumes"
    echo "  - Unused networks"
    echo ""
    echo -e "${RED}⚠️ This will NOT remove:${NC}"
    echo "  - Running containers"
    echo "  - Images used by running containers"
    echo "  - Volumes used by running containers"
    echo ""

    read -p "$(echo -e "${YELLOW}Proceed with cleanup? (y/N): ${NC}")" -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starting cleanup..."

        # Remove stopped containers
        echo ""
        echo -e "${YELLOW}Removing stopped containers...${NC}"
        docker container prune -f

        # Remove unused images
        echo ""
        echo -e "${YELLOW}Removing unused images...${NC}"
        docker image prune -f

        # Remove unused volumes
        echo ""
        echo -e "${YELLOW}Removing unused volumes...${NC}"
        docker volume prune -f

        # Remove unused networks
        echo ""
        echo -e "${YELLOW}Removing unused networks...${NC}"
        docker network prune -f

        echo ""
        log_info "Cleanup completed!"

        # Show disk space freed
        echo ""
        echo -e "${GREEN}Current Docker system usage:${NC}"
        docker system df
    else
        log_info "Cleanup cancelled"
    fi

    read -r -p "Press Enter to continue..."
}

## update_docker_compose - Update Docker Compose configuration
update_docker_compose() {
    clear
    echo -e "${CYAN}📦 UPDATE DOCKER COMPOSE${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${GREEN}Current working configuration (preserved):${NC}"
    echo "  Image: $NEXUS_IMAGE"
    echo "  NEXUS_HOME: $NEXUS_HOME"
    echo "  RUST_LOG: $RUST_LOG_LEVEL"
    echo "  Command format: start --headless --node-id"
    echo ""

    # Check if there are any compose files
    local compose_files=()
    if [[ -f "$WORKDIR/docker-compose.yml" ]]; then
        compose_files+=("$WORKDIR/docker-compose.yml")
    fi

    if [[ -f "$SCRIPT_DIR/docker-compose.working.yml" ]]; then
        compose_files+=("$SCRIPT_DIR/docker-compose.working.yml")
    fi

    if [[ ${#compose_files[@]} -gt 0 ]]; then
        echo -e "${GREEN}Found compose files:${NC}"
        for file in "${compose_files[@]}"; do
            echo "  - $file"
        done
        echo ""

        echo -e "${WHITE}📦 Pilih aksi update Docker Compose:${NC}"
        echo ""
        PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
        select opt in "🔄 Regenerate from saved nodes" "📋 Show current compose content" "🚪 Kembali"; do
            case $opt in
                "🔄 Regenerate from saved nodes")
                    echo -e "${CYAN}🔄 Regenerate dari node tersimpan...${NC}"
                    regenerate_compose_from_saved_nodes
                    break
                    ;;
                "📋 Show current compose content")
                    echo -e "${CYAN}📋 Menampilkan konten compose saat ini...${NC}"
                    show_compose_content
                    break
                    ;;
                "🚪 Kembali")
                    echo -e "${GREEN}↩️ Kembali ke menu sebelumnya...${NC}"
                    return
                    ;;
                *)
                    echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-3.${NC}"
                    sleep 1
                    ;;
            esac
        done
    else
        log_warn "No compose files found"
        echo ""
        read -p "$(echo -e "${YELLOW}Generate new compose file from saved nodes? (Y/n): ${NC}")" -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            regenerate_compose_from_saved_nodes
        fi
    fi

    read -r -p "Press Enter to continue..."
}

## regenerate_compose_from_saved_nodes - Regenerate compose from credentials
regenerate_compose_from_saved_nodes() {
    echo ""
    log_info "Regenerating docker-compose from saved nodes..."

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_warn "No credentials file found"
        return
    fi

    if ! command -v jq &> /dev/null; then
        log_warn "jq not available, cannot parse credentials"
        return
    fi

    local node_ids
    node_ids=$(jq -r '.node_ids[]? // empty' "$CREDENTIALS_FILE" 2>/dev/null || echo "")

    if [[ -z "$node_ids" ]]; then
        log_warn "No node IDs found in credentials"
        return
    fi

    ensure_directories || return 1

    local compose_file="$WORKDIR/docker-compose.yml"

    # Create header with preserved working config
    cat > "$compose_file" << EOF
# Generated from saved nodes with preserved working configuration
# Based on successful configuration with working Node IDs
# Image: $NEXUS_IMAGE (WORKING ✅)
# Command format: start --headless --node-id (WORKING ✅)

services:
EOF

    # Add each node
    echo "$node_ids" | while IFS= read -r node_id; do
        [[ -n "$node_id" ]] || continue

        local port=$((BASE_PORT + node_id))
        local container_name="nexus-node-$node_id"

        # Get proxy if available
        local proxy_url=""
        if [[ -f "$PROXY_FILE" ]]; then
            proxy_url=$(get_available_proxy "$PROXY_FILE" "$node_id" 2>/dev/null || echo "")
        fi

        # Add service
        cat >> "$compose_file" << EOF

  $container_name:
    image: $NEXUS_IMAGE
    container_name: $container_name
    restart: unless-stopped
    environment:
      - NEXUS_HOME=$NEXUS_HOME
      - RUST_LOG=$RUST_LOG_LEVEL
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

        # Add volumes, ports, and command
        cat >> "$compose_file" << EOF
    volumes:
      - nexus_data_$node_id:$NEXUS_HOME
    ports:
      - "$port:$port"
    command: ["start", "--headless", "--node-id", "$node_id"]
EOF
    done

    # Add volumes section
    cat >> "$compose_file" << EOF

volumes:
EOF

    echo "$node_ids" | while IFS= read -r node_id; do
        [[ -n "$node_id" ]] || continue
        cat >> "$compose_file" << EOF
  nexus_data_$node_id:
    external: false
EOF
    done

    log_info "Docker compose regenerated: $compose_file"
}

## show_compose_content - Show current compose file content
show_compose_content() {
    echo ""
    local compose_file="$WORKDIR/docker-compose.yml"

    if [[ -f "$compose_file" ]]; then
        echo -e "${GREEN}Content of $compose_file:${NC}"
        echo -e "${CYAN}═══════════════════════════════${NC}"
        cat "$compose_file"
        echo -e "${CYAN}═══════════════════════════════${NC}"
    else
        log_warn "Docker compose file not found: $compose_file"
    fi
}

## system_resources_monitor - Monitor system resources
system_resources_monitor() {
    clear
    echo -e "${CYAN}🔧 SYSTEM RESOURCES MONITOR${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # System information
    echo -e "${GREEN}📊 System Information:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p 2>/dev/null || echo "unknown")"
    echo "  CPU cores: $(nproc)"
    echo "  Load average: $(uptime | awk -F'load average:' '{print $2}' || echo "unknown")"
    echo ""

    # Memory usage
    echo -e "${GREEN}💾 Memory Usage:${NC}"
    free -h | grep -E "^Mem:|^Swap:" || echo "  Unable to get memory info"
    echo ""

    # Disk usage
    echo -e "${GREEN}💿 Disk Usage:${NC}"
    df -h / | tail -1 | awk '{print "  Root partition: " $3 " used, " $4 " available (" $5 " full)"}' || echo "  Unable to get disk info"
    echo ""

    # Docker resources
    echo -e "${GREEN}🐳 Docker Resources:${NC}"
    if docker info &> /dev/null; then
        docker system df 2>/dev/null || echo "  Unable to get Docker stats"
    else
        echo "  Docker daemon not running"
    fi
    echo ""

    # Running containers stats
    echo -e "${GREEN}📦 Container Stats:${NC}"
    local nexus_containers
    nexus_containers=$(docker ps --filter "name=nexus-node-" -q 2>/dev/null || echo "")

    if [[ -n "$nexus_containers" ]]; then
        docker stats --no-stream --filter "name=nexus-node-" --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || echo "  Unable to get container stats"
    else
        echo "  No Nexus containers running"
    fi

    read -r -p "Press Enter to continue..."
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
    return 1
}

## check_and_update_nexus_image - Check and auto-update Nexus image
check_and_update_nexus_image() {
    log_info "Checking for Nexus CLI updates..."

    # Get local image digest
    local local_digest
    local_digest=$(docker images --digests nexusxyz/nexus-cli:latest --format "{{.Digest}}" 2>/dev/null || echo "")

    if [[ -z "$local_digest" || "$local_digest" == "<none>" ]]; then
        log_warn "No local digest found, pulling latest..."
        pull_nexus_image_with_retry
        return
    fi

    # Check remote digest with timeout and rate limit handling
    log_info "Checking remote version..."
    local remote_digest
    remote_digest=$(check_rate_limit_and_retry "timeout 10 docker manifest inspect nexusxyz/nexus-cli:latest 2>/dev/null | grep -o '\"digest\":\"sha256:[^\"]*\"' | head -1 | cut -d'\"' -f4")

    if [[ -z "$remote_digest" ]]; then
        log_warn "Unable to check remote version (network/rate limit)"
        log_info "Using current local image"
        return
    fi

    # Compare digests
    if [[ "$local_digest" != "$remote_digest" ]]; then
        log_info "New version available! Auto-updating..."

        # Check if any containers are running before update
        local running_containers
        running_containers=$(docker ps --filter "ancestor=nexusxyz/nexus-cli:latest" -q 2>/dev/null || echo "")

        if [[ -n "$running_containers" ]]; then
            log_warn "Containers are running with current image"
            echo ""
            read -p "$(echo -e "${YELLOW}Update image and restart containers? (Y/n): ${NC}")" -n 1 -r
            echo ""

            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                update_image_and_restart_containers
            else
                log_info "Update skipped - containers will continue with current image"
            fi
        else
            # No running containers, safe to update
            pull_nexus_image_with_retry
        fi
    else
        log_info "Image is up to date"
    fi
}

## update_image_and_restart_containers - Update image and restart containers
update_image_and_restart_containers() {
    log_info "Updating image and restarting containers..."

    # Get list of running containers
    local running_containers
    running_containers=$(docker ps --filter "ancestor=nexusxyz/nexus-cli:latest" --format "{{.Names}}" 2>/dev/null || echo "")

    if [[ -n "$running_containers" ]]; then
        # Stop containers
        log_info "Stopping containers..."
        echo "$running_containers" | while IFS= read -r container_name; do
            [[ -n "$container_name" ]] || continue
            log_info "Stopping $container_name..."
            docker stop "$container_name" &> /dev/null || true
        done

        # Pull new image
        if pull_nexus_image_with_retry; then
            # Start containers again
            log_info "Restarting containers with new image..."
            echo "$running_containers" | while IFS= read -r container_name; do
                [[ -n "$container_name" ]] || continue
                log_info "Starting $container_name..."
                docker start "$container_name" &> /dev/null || {
                    log_warn "Failed to start $container_name, may need manual intervention"
                }
            done

            log_info "Update completed successfully!"
        else
            log_error_display "Failed to pull new image, restarting with old image..."
            # Restart with old image
            echo "$running_containers" | while IFS= read -r container_name; do
                [[ -n "$container_name" ]] || continue
                docker start "$container_name" &> /dev/null || true
            done
        fi
    else
        # No containers running, just pull
        pull_nexus_image_with_retry
    fi
}

## auto_pull_image_if_missing - Auto pull image if not present
auto_pull_image_if_missing() {
    if ! docker images | grep -q "nexusxyz/nexus-cli"; then
        log_info "Nexus CLI image not found, auto-pulling..."
        pull_nexus_image_with_retry
    fi
}

## check_rate_limit_and_retry - Check rate limit and implement smart retry
check_rate_limit_and_retry() {
    local command="$1"
    local max_retries=5
    local base_delay=10
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        local output
        output=$(eval "$command" 2>&1)
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            echo "$output"
            return 0
        fi

        # Check for rate limit indicators
        if echo "$output" | grep -qi "rate.limit\|too.many.requests\|429"; then
            local delay=$((base_delay * attempt))
            log_warn "Rate limit detected (attempt $attempt/$max_retries)"
            log_info "Waiting $delay seconds before retry..."
            sleep $delay
        else
            # Not a rate limit error, fail immediately
            echo "$output" >&2
            return $exit_code
        fi

        ((attempt++))
    done

    log_error_display "Command failed after $max_retries attempts due to rate limiting"
    return 1
}

## show_detailed_volumes - Show detailed volume information
show_detailed_volumes() {
    echo ""
    echo -e "${CYAN}📦 DETAILED VOLUME INFORMATION${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local volumes
    volumes=$(docker volume ls --filter "name=nexus" --format "{{.Name}}" 2>/dev/null)

    if [[ -n "$volumes" ]]; then
        echo -e "${GREEN}🔍 Nexus Docker Volumes:${NC}"
        echo ""

        local count=0
        while IFS= read -r volume; do
            [[ -n "$volume" ]] || continue
            count=$((count + 1))

            # Check if volume is in use
            local in_use
            in_use=$(docker ps -a --filter "volume=$volume" --format "{{.Names}}" 2>/dev/null)

            # Get volume info
            local volume_info
            volume_info=$(docker volume inspect "$volume" --format "{{.Mountpoint}}" 2>/dev/null || echo "unknown")

            echo "  $count) $volume"
            echo "     Mount: $volume_info"
            if [[ -n "$in_use" ]]; then
                echo -e "     Status: ${GREEN}In use by:${NC} $in_use"
            else
                echo -e "     Status: ${RED}Not in use${NC}"
            fi
            echo ""
        done <<< "$volumes"

        echo -e "${GREEN}📊 Summary: $count volume(s) found${NC}"
    else
        echo -e "${YELLOW}⚠️ No Nexus volumes found${NC}"
    fi

    echo ""
    read -r -p "Press Enter to continue..."
}

## cleanup_unused_volumes - Cleanup unused volumes
cleanup_unused_volumes() {
    echo ""
    echo -e "${CYAN}🧹 CLEANUP UNUSED VOLUMES${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local volumes
    volumes=$(docker volume ls --filter "name=nexus" --format "{{.Name}}" 2>/dev/null)
    local unused_volumes=()

    if [[ -n "$volumes" ]]; then
        echo -e "${YELLOW}🔍 Scanning for unused volumes...${NC}"
        echo ""

        while IFS= read -r volume; do
            [[ -n "$volume" ]] || continue

            local in_use
            in_use=$(docker ps -a --filter "volume=$volume" --format "{{.Names}}" 2>/dev/null)

            if [[ -z "$in_use" ]]; then
                unused_volumes+=("$volume")
                echo -e "${RED}❌ $volume (unused)${NC}"
            else
                echo -e "${GREEN}✅ $volume (in use by: $in_use)${NC}"
            fi
        done <<< "$volumes"

        echo ""

        if [[ ${#unused_volumes[@]} -eq 0 ]]; then
            echo -e "${GREEN}✅ All Nexus volumes are in use${NC}"
        else
            echo -e "${YELLOW}Found ${#unused_volumes[@]} unused volume(s)${NC}"
            echo ""
            echo -e "${RED}⚠️ WARNING: This will permanently delete unused volumes!${NC}"
            read -r -p "$(echo -e "${RED}Remove ${#unused_volumes[@]} unused volumes? (y/N): ${NC}")" confirm

            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                local removed_count=0
                for vol in "${unused_volumes[@]}"; do
                    if docker volume rm "$vol" 2>/dev/null; then
                        echo -e "${GREEN}✅ Removed: $vol${NC}"
                        removed_count=$((removed_count + 1))
                    else
                        echo -e "${RED}❌ Failed to remove: $vol${NC}"
                    fi
                done
                echo ""
                echo -e "${GREEN}✅ Cleanup complete! Removed $removed_count volume(s)${NC}"
            else
                echo -e "${YELLOW}Cleanup cancelled${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️ No Nexus volumes found${NC}"
    fi

    echo ""
    read -r -p "Press Enter to continue..."
}
