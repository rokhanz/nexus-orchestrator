#!/bin/bash

# docker_wrapper.sh - Docker Operations Wrapper
# Version: 4.0.0 - Complex Docker operations for Nexus Orchestrator with error handling and retry logic

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# DOCKER WRAPPER CONFIGURATION
# =============================================================================

readonly DOCKER_WRAPPER_MAX_RETRIES=3
readonly DOCKER_WRAPPER_RETRY_DELAY=5
readonly DOCKER_WRAPPER_TIMEOUT=300

# =============================================================================
# MAIN DOCKER WRAPPER FUNCTION
# =============================================================================

docker_wrapper() {
    local operation="$1"
    shift

    log_activity "Docker wrapper: $operation operation requested"

    # Auto-build docker-compose if needed for container operations
    if [[ "$operation" =~ ^(start|restart|status|health)$ ]]; then
        if ! ensure_docker_compose_exists; then
            handle_error "Failed to auto-generate docker-compose.yml"
            return 1
        fi
    fi

    # Pre-execution validation
    if ! validate_docker_requirements; then
        handle_error "Docker requirements validation failed"
        return 1
    fi

    # Execute operation with retry logic
    case "$operation" in
        "start")
            start_containers_wrapper "$@"
            ;;
        "stop")
            stop_containers_wrapper "$@"
            ;;
        "restart")
            restart_containers_wrapper "$@"
            ;;
        "pull")
            pull_images_wrapper "$@"
            ;;
        "logs")
            get_logs_wrapper "$@"
            ;;
        "status")
            get_status_wrapper "$@"
            ;;
        "health")
            health_check_wrapper "$@"
            ;;
        "cleanup")
            cleanup_wrapper "$@"
            ;;
        "auto-build")
            auto_build_docker_compose
            ;;
        *)
            handle_error "Unknown Docker operation: $operation"
            return 1
            ;;
    esac

    local exit_code=$?

    # Post-execution validation
    if [[ $exit_code -eq 0 ]]; then
        verify_operation_success "$operation"
        log_success "Docker wrapper: $operation completed successfully"
    else
        handle_error "Docker wrapper: $operation failed with exit code $exit_code"
    fi

    return $exit_code
}

# =============================================================================
# AUTO-BUILD DOCKER COMPOSE
# =============================================================================

ensure_docker_compose_exists() {
    # Check if docker-compose.yml exists and is valid
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        if docker-compose -f "$DOCKER_COMPOSE_FILE" config >/dev/null 2>&1; then
            log_debug "Docker compose file exists and is valid"
            return 0
        else
            log_warning "Existing docker-compose.yml is invalid, rebuilding..."
            backup_file "$DOCKER_COMPOSE_FILE"
        fi
    fi

    # Auto-generate docker-compose.yml
    echo -e "${CYAN}🔄 Auto-generating docker-compose.yml...${NC}"
    if auto_build_docker_compose; then
        log_success "${GREEN}✅ Docker compose auto-generated successfully${NC}"
        return 0
    else
        log_error "${RED}❌ Failed to auto-generate docker-compose.yml${NC}"
        return 1
    fi
}

auto_build_docker_compose() {
    # Check if credentials are configured
    local wallet_address
    wallet_address=$(read_config_value "wallet_address" 2>/dev/null)

    if [[ -z "$wallet_address" || "$wallet_address" == "null" ]]; then
        echo -e "${RED}❌ ${BOLD}Wallet address not configured${NC}"
        echo -e "${YELLOW}💡 ${BOLD}Please configure credentials first (Option 2 in main menu)${NC}"
        return 1
    fi

    local node_id
    node_id=$(read_config_value "node_id" 2>/dev/null || echo "[]")
    local node_count
    node_count=$(echo "$node_id" | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$node_count" -eq 0 ]]; then
        echo -e "${RED}❌ ${BOLD}No Node ID configured${NC}"
        echo -e "${YELLOW}💡 ${BOLD}Please configure Node ID first (Option 2 in main menu)${NC}"
        return 1
    fi

    echo -e "${CYAN}🏗️  ${BOLD}Building docker-compose.yml configuration:${NC}"
    echo -e "   ${YELLOW}📁 Target file:${NC} $DOCKER_COMPOSE_FILE"
    echo -e "   ${YELLOW}💳 Wallet:${NC} $wallet_address"
    echo -e "   ${YELLOW}🆔 Nodes:${NC} $node_count node(s) configured"
    echo ""

    # Show node details
    echo -e "${CYAN}📋 ${BOLD}Node Configuration:${NC}"
    local service_count=0
    echo "$node_id" | jq -r '.[]' | while IFS= read -r node_entry; do
        service_count=$((service_count + 1))
        local api_port=$((10000 + service_count - 1))
        echo -e "   ${GREEN}•${NC} ${CYAN}nexus-node-${node_entry}${NC} → Port: ${YELLOW}${api_port}${NC} (Node ID: ${PURPLE}${node_entry}${NC})"
    done
    echo ""

    # Generate docker-compose.yml
    echo -e "${CYAN}⚙️  ${BOLD}Generating docker-compose.yml...${NC}"
    create_smart_docker_compose "$wallet_address" "$node_id"

    # Validate generated file
    if [[ -f "$DOCKER_COMPOSE_FILE" ]] && docker-compose -f "$DOCKER_COMPOSE_FILE" config >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ${BOLD}Docker compose generated and validated successfully${NC}"
        echo ""
        echo -e "${CYAN}� ${BOLD}Generated Services:${NC}"
        docker-compose -f "$DOCKER_COMPOSE_FILE" config --services | while read -r service; do
            local node_id="${service#nexus-node-}"
            echo -e "   ${GREEN}✓${NC} Service: ${CYAN}$service${NC} (Node: ${PURPLE}$node_id${NC})"
        done
        echo ""
        echo -e "${YELLOW}💡 ${BOLD}Tips:${NC}"
        echo -e "   ${GRAY}• Use 'docker-compose up -d' to start all nodes${NC}"
        echo -e "   ${GRAY}• Access health checks via HTTP ports starting from 10000${NC}"
        echo -e "   ${GRAY}• Credentials are automatically mounted from: $CREDENTIALS_FILE${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ ${BOLD}Generated docker-compose.yml is invalid${NC}"
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            echo -e "${YELLOW}⚠️  ${BOLD}Validation errors:${NC}"
            docker-compose -f "$DOCKER_COMPOSE_FILE" config 2>&1 | head -10
        fi
        return 1
    fi
}

create_smart_docker_compose() {
    local wallet_address="$1"
    local node_id="$2"

    ensure_directories

    # Create docker-compose header
    cat > "$DOCKER_COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
EOF

    # Add each node as a service
    local service_count=0
    echo "$node_id" | jq -r '.[]' | while IFS= read -r node_entry; do
        service_count=$((service_count + 1))
        local container_name="nexus-node-${node_entry}"
        local api_port=$((10000 + service_count - 1))  # Start from 10000

        cat >> "$DOCKER_COMPOSE_FILE" << EOF

  $container_name:
    image: nexusxyz/nexus-cli:latest
    container_name: $container_name
    restart: unless-stopped
    networks:
      - nexus-network
    ports:
      - "${api_port}:10000"
    environment:
      - RUST_LOG=info
      - NEXUS_HOME=/app/.nexus
      - NETWORK=testnet3
      - TZ=Asia/Jakarta
      - NODE_ID=$node_id
    volumes:
      - nexus_data_${node_id}:/app/.nexus
      - $CREDENTIALS_FILE:/app/.nexus/credentials.json:ro
    command: ["start", "--headless", "--node-id", "$node_id"]
    labels:
      - "nexus.network=true"
      - "nexus.service=prover"
      - "nexus.node_id=$node_id"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:10000/health", "||", "exit", "1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    done

    # Add volumes section
    cat >> "$DOCKER_COMPOSE_FILE" << 'EOF'

volumes:
EOF

    # Add volumes for each node
    echo "$node_id" | jq -r '.[]' | while IFS= read -r node_entry; do
        cat >> "$DOCKER_COMPOSE_FILE" << EOF
  nexus_data_${node_entry}:
    driver: local
EOF
    done

    # Add networks section
    cat >> "$DOCKER_COMPOSE_FILE" << 'EOF'

networks:
  nexus-network:
    driver: bridge
EOF

    return 0
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_docker_requirements() {
    local validation_ok=true

    # Check Docker daemon
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        log_error "${RED}❌ Docker daemon is not running${NC}"
        echo -e "${YELLOW}💡 Please start Docker: ${CYAN}sudo systemctl start docker${NC}"
        validation_ok=false
    fi

    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "${RED}❌ Docker Compose not available${NC}"
        echo -e "${YELLOW}💡 Please install Docker Compose${NC}"
        validation_ok=false
    fi

    # Skip docker-compose file check - will be auto-generated
    # Note: We don't check DOCKER_COMPOSE_FILE existence here as it will be auto-created

    # Check disk space
    local available_space
    available_space=$(df "$WORKDIR" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then  # 2GB in KB
        log_warning "${YELLOW}⚠️  Low disk space: $((available_space/1024))MB available (recommended: 2GB+)${NC}"
    fi

    # Check if Docker daemon is accessible
    if ! docker info >/dev/null 2>&1; then
        log_error "${RED}❌ Cannot connect to Docker daemon${NC}"
        echo -e "${YELLOW}💡 Please check Docker permissions or run with sudo${NC}"
        validation_ok=false
    fi

    [[ "$validation_ok" == true ]]
}

verify_operation_success() {
    local operation="$1"

    case "$operation" in
        "start")
            # Verify containers are running
            local expected_containers
            expected_containers=$(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services | wc -l)
            local running_containers
            running_containers=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

            if [[ $running_containers -lt $expected_containers ]]; then
                log_warning "Only $running_containers/$expected_containers containers are running"
                return 1
            fi
            ;;
        "stop")
            # Verify containers are stopped
            local running_containers
            running_containers=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

            if [[ $running_containers -gt 0 ]]; then
                log_warning "$running_containers containers still running"
                return 1
            fi
            ;;
    esac

    return 0
}

# =============================================================================
# CONTAINER OPERATIONS WITH RETRY LOGIC
# =============================================================================

start_containers_wrapper() {
    local service_name="${1:-}"
    local retries=0

    log_activity "Starting containers${service_name:+ for service: $service_name}"

    while [[ $retries -lt $DOCKER_WRAPPER_MAX_RETRIES ]]; do
        echo -e "${CYAN}🚀 ${BOLD}Starting containers${NC} ${YELLOW}(attempt $((retries + 1))/$DOCKER_WRAPPER_MAX_RETRIES)${NC}${CYAN}...${NC}"

        # Build docker-compose command
        local compose_cmd="docker-compose -f '$DOCKER_COMPOSE_FILE' up -d --remove-orphans"
        if [[ -n "$service_name" ]]; then
            compose_cmd="$compose_cmd '$service_name'"
        fi

        # Execute with timeout
        if timeout "$DOCKER_WRAPPER_TIMEOUT" bash -c "$compose_cmd"; then
            echo -e "${GREEN}✅ ${BOLD}Containers started, waiting for stabilization...${NC}"
            # Wait for containers to stabilize
            sleep 10

            # Verify containers are running
            if verify_containers_healthy; then
                log_success "${GREEN}✅ ${BOLD}Containers started successfully${NC}"
                show_container_status
                return 0
            else
                echo -e "${YELLOW}⚠️  ${BOLD}Containers started but health check failed${NC}"
            fi
        else
            echo -e "${RED}❌ ${BOLD}Container start failed${NC} ${YELLOW}(attempt $((retries + 1)))${NC}"
        fi

        ((retries++))
        if [[ $retries -lt $DOCKER_WRAPPER_MAX_RETRIES ]]; then
            echo -e "${CYAN}🔄 ${BOLD}Retrying in $DOCKER_WRAPPER_RETRY_DELAY seconds...${NC}"
            sleep "$DOCKER_WRAPPER_RETRY_DELAY"
        fi
    done

    handle_error "${RED}❌ ${BOLD}Failed to start containers after $DOCKER_WRAPPER_MAX_RETRIES attempts${NC}"
    return 1
}

stop_containers_wrapper() {
    local service_name="${1:-}"
    local force="${2:-false}"
    local retries=0

    log_activity "Stopping containers${service_name:+ for service: $service_name}"

    while [[ $retries -lt $DOCKER_WRAPPER_MAX_RETRIES ]]; do
        echo -e "${CYAN}⏹️  ${BOLD}Stopping containers${NC} ${YELLOW}(attempt $((retries + 1))/$DOCKER_WRAPPER_MAX_RETRIES)${NC}${CYAN}...${NC}"

        # Build docker-compose command
        local compose_cmd
        if [[ "$force" == "true" ]]; then
            compose_cmd="docker-compose -f '$DOCKER_COMPOSE_FILE' down --remove-orphans"
            echo -e "${RED}🔨 ${BOLD}Force stopping containers...${NC}"
        else
            compose_cmd="docker-compose -f '$DOCKER_COMPOSE_FILE' stop"
            echo -e "${CYAN}🛑 ${BOLD}Gracefully stopping containers...${NC}"
        fi

        if [[ -n "$service_name" ]]; then
            compose_cmd="$compose_cmd '$service_name'"
        fi

        # Execute with timeout
        if timeout "$DOCKER_WRAPPER_TIMEOUT" bash -c "$compose_cmd"; then
            echo -e "${GREEN}✅ ${BOLD}Stop command executed, verifying...${NC}"
            # Verify containers are stopped
            sleep 5

            local running_containers
            if [[ -n "$service_name" ]]; then
                running_containers=$(docker ps --filter "name=$service_name" --format "{{.Names}}" | wc -l)
            else
                running_containers=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)
            fi

            if [[ $running_containers -eq 0 ]]; then
                log_success "${GREEN}✅ ${BOLD}Containers stopped successfully${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️  ${BOLD}$running_containers containers still running${NC}"
            fi
        else
            echo -e "${RED}❌ ${BOLD}Container stop failed${NC} ${YELLOW}(attempt $((retries + 1)))${NC}"
        fi

        ((retries++))
        if [[ $retries -lt $DOCKER_WRAPPER_MAX_RETRIES ]]; then
            echo -e "${CYAN}🔄 ${BOLD}Retrying in $DOCKER_WRAPPER_RETRY_DELAY seconds...${NC}"
            sleep "$DOCKER_WRAPPER_RETRY_DELAY"
        fi
    done

    # Force stop if graceful stop failed
    if [[ "$force" != "true" ]]; then
        echo -e "${YELLOW}⚠️  ${BOLD}Graceful stop failed, attempting force stop...${NC}"
        stop_containers_wrapper "$service_name" "true"
        return $?
    fi

    handle_error "${RED}❌ ${BOLD}Failed to stop containers after $DOCKER_WRAPPER_MAX_RETRIES attempts${NC}"
    return 1
}

restart_containers_wrapper() {
    local service_name="${1:-}"

    log_activity "Restarting containers${service_name:+ for service: $service_name}"

    # Stop containers first
    if stop_containers_wrapper "$service_name"; then
        # Wait a moment before starting
        sleep 3

        # Start containers
        if start_containers_wrapper "$service_name"; then
            log_success "Containers restarted successfully"
            return 0
        else
            handle_error "Failed to start containers after restart"
            return 1
        fi
    else
        handle_error "Failed to stop containers for restart"
        return 1
    fi
}

# =============================================================================
# IMAGE OPERATIONS
# =============================================================================

pull_images_wrapper() {
    local retries=0

    log_activity "Pulling Docker images"

    while [[ $retries -lt $DOCKER_WRAPPER_MAX_RETRIES ]]; do
        echo -e "${CYAN}📦 ${BOLD}Pulling images${NC} ${YELLOW}(attempt $((retries + 1))/$DOCKER_WRAPPER_MAX_RETRIES)${NC}${CYAN}...${NC}"

        if timeout "$DOCKER_WRAPPER_TIMEOUT" docker-compose -f "$DOCKER_COMPOSE_FILE" pull; then
            log_success "${GREEN}✅ ${BOLD}Images pulled successfully${NC}"
            return 0
        else
            echo -e "${RED}❌ ${BOLD}Image pull failed${NC} ${YELLOW}(attempt $((retries + 1)))${NC}"
        fi

        ((retries++))
        if [[ $retries -lt $DOCKER_WRAPPER_MAX_RETRIES ]]; then
            echo -e "${CYAN}🔄 ${BOLD}Retrying in $DOCKER_WRAPPER_RETRY_DELAY seconds...${NC}"
            sleep "$DOCKER_WRAPPER_RETRY_DELAY"
        fi
    done

    handle_error "${RED}❌ ${BOLD}Failed to pull images after $DOCKER_WRAPPER_MAX_RETRIES attempts${NC}"
    return 1
}

# =============================================================================
# MONITORING OPERATIONS
# =============================================================================

get_logs_wrapper() {
    local service_name="${1:-}"
    local lines="${2:-50}"
    local follow="${3:-false}"

    log_activity "Getting logs${service_name:+ for service: $service_name}"

    if [[ -z "$service_name" ]]; then
        # Get logs for all services
        local services
        services=$(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services)

        while IFS= read -r service; do
            echo -e "${CYAN}${BOLD}=== Logs for $service ===${NC}"

            if [[ "$follow" == "true" ]]; then
                docker logs -f --tail "$lines" "$service" 2>/dev/null &
            else
                docker logs --tail "$lines" "$service" 2>/dev/null || {
                    echo -e "${RED}❌ Failed to get logs for $service${NC}"
                }
            fi

            echo ""
        done <<< "$services"

        if [[ "$follow" == "true" ]]; then
            wait
        fi
    else
        # Get logs for specific service
        if [[ "$follow" == "true" ]]; then
            docker logs -f --tail "$lines" "$service_name" 2>/dev/null || {
                handle_error "Failed to get logs for $service_name"
                return 1
            }
        else
            docker logs --tail "$lines" "$service_name" 2>/dev/null || {
                handle_error "Failed to get logs for $service_name"
                return 1
            }
        fi
    fi

    return 0
}

get_status_wrapper() {
    log_activity "Getting container status"

    echo -e "${CYAN}${BOLD}Container Status Overview:${NC}"
    echo ""

    # Overall summary
    local total_services
    total_services=$(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services | wc -l)
    local running_containers
    running_containers=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    echo -e "📊 ${BOLD}Summary:${NC} $running_containers/$total_services containers running"
    echo ""

    # Detailed status table
    printf "%-20s %-15s %-25s %-15s %s\n" "SERVICE" "STATUS" "UPTIME" "PORTS" "HEALTH"
    echo "────────────────────────────────────────────────────────────────────────────────────"

    docker-compose -f "$DOCKER_COMPOSE_FILE" config --services | while read -r service; do
        local status
        status=$(get_container_status "$service")

        local uptime="N/A"
        local ports="N/A"
        local health="Unknown"

        if [[ "$status" =~ ^Up ]]; then
            # Extract uptime
            if [[ "$status" =~ Up[[:space:]]+(.+) ]]; then
                uptime="${BASH_REMATCH[1]}"
                uptime="${uptime%% (*}"  # Remove port info
            fi

            # Get ports
            ports=$(docker port "$service" 2>/dev/null | head -1 | cut -d' ' -f3 || echo "N/A")

            # Get health
            local health_status
            health_status=$(docker inspect "$service" --format='{{.State.Health.Status}}' 2>/dev/null)
            case "$health_status" in
                "healthy") health="✅ Healthy" ;;
                "unhealthy") health="❌ Unhealthy" ;;
                "starting") health="🔄 Starting" ;;
                *) health="❓ No check" ;;
            esac

            printf "%-20s %b✅ Running%b      %-25s %-15s %s\n" "$service" "$GREEN" "$NC" "$uptime" "$ports" "$health"
        else
            printf "%-20s %b❌ Stopped%b      %-25s %-15s %s\n" "$service" "$RED" "$NC" "$uptime" "$ports" "$health"
        fi
    done

    echo ""
    return 0
}

health_check_wrapper() {
    local service_name="${1:-}"

    log_activity "Performing health check${service_name:+ for service: $service_name}"

    if [[ -n "$service_name" ]]; then
        # Check specific service
        if check_service_health "$service_name"; then
            echo -e "${GREEN}✅ $service_name is healthy${NC}"
            return 0
        else
            echo -e "${RED}❌ $service_name is unhealthy${NC}"
            return 1
        fi
    else
        # Check all services
        local unhealthy_services=0
        while read -r service; do
            if check_service_health "$service"; then
                echo -e "${GREEN}✅ $service is healthy${NC}"
            else
                echo -e "${RED}❌ $service is unhealthy${NC}"
                ((unhealthy_services++))
            fi
        done < <(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services)
    fi

    if [[ "$unhealthy_services" -eq 0 ]]; then
        log_success "All services are healthy"
        return 0
    else
        log_warning "Some services are unhealthy"
        return 1
    fi
}

# =============================================================================
# CLEANUP OPERATIONS
# =============================================================================

cleanup_wrapper() {
    local cleanup_type="${1:-basic}"

    log_activity "Performing Docker cleanup: $cleanup_type"

    case "$cleanup_type" in
        "basic")
            basic_cleanup
            ;;
        "full")
            full_cleanup
            ;;
        "images")
            image_cleanup
            ;;
        "volumes")
            volume_cleanup
            ;;
        *)
            handle_error "Unknown cleanup type: $cleanup_type"
            return 1
            ;;
    esac
}

basic_cleanup() {
    echo -e "${CYAN}🧹 ${BOLD}Performing basic cleanup...${NC}"

    # Remove stopped containers
    local stopped_containers
    stopped_containers=$(docker ps -a --filter "status=exited" --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    if [[ $stopped_containers -gt 0 ]]; then
        echo -e "${CYAN}🗑️  ${BOLD}Removing $stopped_containers stopped containers...${NC}"
        if docker ps -a --filter "status=exited" --filter "name=nexus-node" --format "{{.Names}}" | xargs docker rm 2>/dev/null; then
            echo -e "${GREEN}✅ ${BOLD}Stopped containers removed${NC}"
        else
            echo -e "${RED}❌ ${BOLD}Failed to remove some stopped containers${NC}"
        fi
    else
        echo -e "${GREEN}✅ ${BOLD}No stopped containers to remove${NC}"
    fi

    # Remove dangling images
    local dangling_images
    dangling_images=$(docker images -f "dangling=true" -q | wc -l)

    if [[ $dangling_images -gt 0 ]]; then
        echo -e "${CYAN}🗑️  ${BOLD}Removing $dangling_images dangling images...${NC}"
        if docker image prune -f >/dev/null 2>&1; then
            echo -e "${GREEN}✅ ${BOLD}Dangling images removed${NC}"
        else
            echo -e "${RED}❌ ${BOLD}Failed to remove dangling images${NC}"
        fi
    else
        echo -e "${GREEN}✅ ${BOLD}No dangling images to remove${NC}"
    fi

    log_success "${GREEN}✅ ${BOLD}Basic cleanup completed${NC}"
}

full_cleanup() {
    echo -e "${CYAN}🧹 ${BOLD}Performing full cleanup...${NC}"
    echo -e "${YELLOW}⚠️  ${BOLD}This will remove all stopped containers, unused networks, and dangling images${NC}"

    read -rp "$(echo -e "${RED}${BOLD}Are you sure? [y/N]:${NC} ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}✋ ${BOLD}Cleanup cancelled${NC}"
        return 0
    fi

    echo -e "${CYAN}🔄 ${BOLD}Running full system prune...${NC}"
    # Full system prune
    if docker system prune -f >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ${BOLD}System prune completed${NC}"
    else
        echo -e "${RED}❌ ${BOLD}System prune failed${NC}"
    fi

    log_success "${GREEN}✅ ${BOLD}Full cleanup completed${NC}"
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

verify_containers_healthy() {
    local unhealthy_count=0

    while read -r service; do
        if ! check_service_health "$service"; then
            ((unhealthy_count++))
        fi
    done < <(docker-compose -f "$DOCKER_COMPOSE_FILE" config --services)

    [[ $unhealthy_count -eq 0 ]]
}

check_service_health() {
    local service="$1"
    local max_wait=60
    local wait_time=0

    # Check if container is running
    if ! is_container_running "$service"; then
        return 1
    fi

    # Wait for health check if available
    while [[ $wait_time -lt $max_wait ]]; do
        local health_status
        health_status=$(docker inspect "$service" --format='{{.State.Health.Status}}' 2>/dev/null)

        case "$health_status" in
            "healthy")
                return 0
                ;;
            "unhealthy")
                return 1
                ;;
            "starting")
                sleep 5
                wait_time=$((wait_time + 5))
                ;;
            *)
                # No health check defined, check if container is running
                return 0
                ;;
        esac
    done

    # Timeout waiting for health check
    return 1
}

show_container_status() {
    echo ""
    echo -e "${CYAN}${BOLD}Current Container Status:${NC}"
    docker ps --filter "name=nexus-node" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || {
        echo -e "${RED}❌ Failed to get container status${NC}"
    }
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f docker_wrapper ensure_docker_compose_exists auto_build_docker_compose create_smart_docker_compose
export -f validate_docker_requirements verify_operation_success
export -f start_containers_wrapper stop_containers_wrapper restart_containers_wrapper
export -f pull_images_wrapper get_logs_wrapper get_status_wrapper health_check_wrapper
export -f cleanup_wrapper basic_cleanup full_cleanup verify_containers_healthy
export -f check_service_health show_container_status

log_success "${GREEN}✅ ${BOLD}Docker wrapper loaded successfully${NC}"
