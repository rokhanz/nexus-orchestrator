#!/bin/bash

# log_viewer.sh - Enhanced Log Viewer with Color Coding
# Version: 4.0.0 - Beautiful colored log output for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# ENHANCED LOG VIEWER FUNCTIONS
# =============================================================================

# Function to colorize Nexus logs
colorize_nexus_logs() {
    local container_name="$1"
    local lines="${2:-50}"

    echo -e "${CYAN}${BOLD}📋 Live Logs: $container_name${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"

    # Follow logs with colorization
    docker logs -f --tail="$lines" "$container_name" 2>&1 | while IFS= read -r line; do
        # Add timestamp prefix if not present
        local timestamp
        timestamp=$(date '+%H:%M:%S')

        # Color coding based on content
        if [[ "$line" =~ "Error"|"error"|"ERROR"|"Failed"|"failed" ]]; then
            # Error lines - Red
            echo -e "${RED}${BOLD}[$timestamp] ❌ $line${NC}"
        elif [[ "$line" =~ "Success"|"success"|"SUCCESS"|"✅"|"completed" ]]; then
            # Success lines - Green
            echo -e "${GREEN}${BOLD}[$timestamp] ✅ $line${NC}"
        elif [[ "$line" =~ "Warning"|"warning"|"WARN"|"⚠️" ]]; then
            # Warning lines - Yellow
            echo -e "${YELLOW}${BOLD}[$timestamp] ⚠️  $line${NC}"
        elif [[ "$line" =~ "Step [0-9]+ of [0-9]+"|"Requesting task"|"Computing"|"Submitting" ]]; then
            # Progress steps - Cyan
            echo -e "${CYAN}[$timestamp] 🔄 $line${NC}"
        elif [[ "$line" =~ Task-[0-9]+ ]]; then
            # Task IDs - Purple
            echo -e "${PURPLE}[$timestamp] 🎯 $line${NC}"
        elif [[ "$line" =~ Status:\ [0-9]+ ]]; then
            # HTTP Status codes
            if [[ "$line" =~ Status:\ 2[0-9][0-9] ]]; then
                echo -e "${GREEN}[$timestamp] 📡 $line${NC}"
            elif [[ "$line" =~ Status:\ 4[0-9][0-9] ]]; then
                echo -e "${YELLOW}[$timestamp] 📡 $line${NC}"
            elif [[ "$line" =~ Status:\ 5[0-9][0-9] ]]; then
                echo -e "${RED}[$timestamp] 📡 $line${NC}"
            else
                echo -e "${BLUE}[$timestamp] 📡 $line${NC}"
            fi
        elif [[ "$line" =~ "Refresh"|"Waiting" ]]; then
            # Refresh/Waiting - Gray
            echo -e "${GRAY}[$timestamp] ⏳ $line${NC}"
        else
            # Default - White
            echo -e "${WHITE}[$timestamp] ℹ️  $line${NC}"
        fi
    done
}

# Function to show all node logs with selection
show_enhanced_node_logs() {
    clear
    echo -e "${CYAN}${BOLD}📋 ENHANCED NODE LOG VIEWER${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get running containers
    local containers=()
    mapfile -t containers < <(docker ps --filter "name=nexus-node" --format "{{.Names}}" | sort)

    if [[ ${#containers[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No running Nexus nodes found${NC}"
        echo -e "${BLUE}💡 Start some nodes first before viewing logs${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${GREEN}📋 Available Nodes:${NC}"
    echo ""

    for i in "${!containers[@]}"; do
        local container="${containers[$i]}"
        local status
        status=$(docker inspect "$container" --format '{{.State.Status}}')
        local uptime
        uptime=$(docker inspect "$container" --format '{{.State.StartedAt}}' | sed 's/T/ /' | cut -d'.' -f1)

        echo -e "  ${GREEN}$((i + 1)).${NC} ${CYAN}$container${NC} ${GRAY}(Status: $status, Started: $uptime)${NC}"
    done

    echo ""
    echo -e "  ${GREEN}A.${NC} ${PURPLE}View All Nodes (Combined)${NC}"
    echo -e "  ${GREEN}0.${NC} ${YELLOW}Return to Menu${NC}"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"

    read -rp "$(echo -e "${BOLD}Select node to view logs [1-${#containers[@]}/A/0]:${NC} ")" choice
    echo ""

    case "$choice" in
        [1-9]*)
            local index=$((choice - 1))
            if [[ $index -ge 0 && $index -lt ${#containers[@]} ]]; then
                echo -e "${BLUE}🔍 Press Ctrl+C to stop following logs${NC}"
                echo ""
                sleep 2
                colorize_nexus_logs "${containers[$index]}" 100
            else
                echo -e "${RED}❌ Invalid selection${NC}"
                sleep 2
                show_enhanced_node_logs
            fi
            ;;
        [Aa])
            show_combined_logs "${containers[@]}"
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            sleep 2
            show_enhanced_node_logs
            ;;
    esac
}

# Function to show combined logs from all nodes
show_combined_logs() {
    local containers=("$@")

    echo -e "${PURPLE}${BOLD}📋 Combined Logs from All Nodes${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔍 Press Ctrl+C to stop following logs${NC}"
    echo ""
    sleep 2

    # Use docker-compose logs for combined output
    cd /root/nexus-orchestrator || return 1
    docker-compose -f workdir/docker-compose.yml logs -f --tail=50 | while IFS= read -r line; do
        # Extract container name and log content
        if [[ "$line" =~ ^([^|]+)\|(.*)$ ]]; then
            local container_part="${BASH_REMATCH[1]}"
            local log_content="${BASH_REMATCH[2]}"
            local timestamp
            timestamp=$(date '+%H:%M:%S')

            # Color container name
            local colored_container=""
            if [[ "$container_part" =~ nexus-node-[0-9]+ ]]; then
                colored_container="${CYAN}${BOLD}[$container_part]${NC}"
            else
                colored_container="${GRAY}[$container_part]${NC}"
            fi

            # Color log content
            if [[ "$log_content" =~ "Error"|"error"|"ERROR"|"Failed"|"failed" ]]; then
                echo -e "$colored_container ${RED}❌ $log_content${NC}"
            elif [[ "$log_content" =~ "Success"|"success"|"SUCCESS"|"✅"|"completed" ]]; then
                echo -e "$colored_container ${GREEN}✅ $log_content${NC}"
            elif [[ "$log_content" =~ "Warning"|"warning"|"WARN"|"⚠️" ]]; then
                echo -e "$colored_container ${YELLOW}⚠️  $log_content${NC}"
            elif [[ "$log_content" =~ "Step [0-9]+ of [0-9]+"|"Requesting task"|"Computing"|"Submitting" ]]; then
                echo -e "$colored_container ${CYAN}🔄 $log_content${NC}"
            elif [[ "$log_content" =~ Task-[0-9]+ ]]; then
                echo -e "$colored_container ${PURPLE}🎯 $log_content${NC}"
            elif [[ "$log_content" =~ Status:\ [0-9]+ ]]; then
                if [[ "$log_content" =~ Status:\ 4[0-9][0-9] ]]; then
                    echo -e "$colored_container ${YELLOW}📡 $log_content${NC}"
                else
                    echo -e "$colored_container ${BLUE}📡 $log_content${NC}"
                fi
            else
                echo -e "$colored_container ${WHITE}ℹ️  $log_content${NC}"
            fi
        else
            # Fallback for lines that don't match expected format
            echo -e "${GRAY}[$(date '+%H:%M:%S')] $line${NC}"
        fi
    done
}

# Function to analyze log patterns
analyze_log_patterns() {
    local container_name="$1"

    echo -e "${CYAN}${BOLD}📊 Log Analysis: $container_name${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════${NC}"

    local logs
    logs=$(docker logs "$container_name" 2>&1 | tail -100)

    # Count different types of events
    local error_count
    error_count=$(echo "$logs" | grep -c -i "error\|failed" || echo "0")
    local success_count
    success_count=$(echo "$logs" | grep -c -i "success\|completed" || echo "0")
    local task_count
    task_count=$(echo "$logs" | grep -c "Task-" || echo "0")
    local rate_limit_count
    rate_limit_count=$(echo "$logs" | grep -c "429" || echo "0")

    echo -e "${GREEN}📈 Statistics (Last 100 lines):${NC}"
    echo -e "  ${RED}❌ Errors/Failures: $error_count${NC}"
    echo -e "  ${GREEN}✅ Successes: $success_count${NC}"
    echo -e "  ${PURPLE}🎯 Tasks Processed: $task_count${NC}"
    echo -e "  ${YELLOW}⚠️  Rate Limits (429): $rate_limit_count${NC}"
    echo ""

    # Show recent errors if any
    if [[ $error_count -gt 0 ]]; then
        echo -e "${RED}${BOLD}🚨 Recent Errors:${NC}"
        echo "$logs" | grep -i "error\|failed" | tail -3 | while IFS= read -r error_line; do
            echo -e "  ${RED}• $error_line${NC}"
        done
        echo ""
    fi

    # Show recent successes
    if [[ $success_count -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ Recent Successes:${NC}"
        echo "$logs" | grep -i "success\|completed" | tail -2 | while IFS= read -r success_line; do
            echo -e "  ${GREEN}• $success_line${NC}"
        done
        echo ""
    fi

    read -rp "Press Enter to continue..."
}

# Export functions
export -f colorize_nexus_logs show_enhanced_node_logs show_combined_logs analyze_log_patterns

log_info "Enhanced log viewer loaded successfully"
