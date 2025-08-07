#!/bin/bash

# nexus_logs.sh - Simple Colored Log Viewer for Nexus Orchestrator
# Usage: ./nexus_logs.sh [node_name] [lines]

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

show_colored_logs() {
    local container="$1"
    local lines="${2:-50}"

    echo -e "${BLUE}📋 Viewing logs for: ${CYAN}$container${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop${NC}"
    echo ""

    docker logs -f --tail="$lines" "$container" 2>&1 | while IFS= read -r line; do
        local timestamp
        timestamp=$(date '+%H:%M:%S')

        if [[ "$line" =~ Error|Failed|ERROR|failed ]]; then
            # Errors - Red
            echo -e "${RED}[$timestamp] ❌ $line${NC}"
        elif [[ "$line" =~ Success|success|completed|Step\ 2\ of\ 4 ]]; then
            # Success - Green
            echo -e "${GREEN}[$timestamp] ✅ $line${NC}"
        elif [[ "$line" =~ "Step 1 of 4"|"Step 3 of 4"|Requesting|Submitting ]]; then
            # Processing - Cyan
            echo -e "${CYAN}[$timestamp] 🔄 $line${NC}"
        elif [[ "$line" =~ "Status: 429"|"Rate limit"|"rate limited" ]]; then
            # Rate limiting - Yellow
            echo -e "${YELLOW}[$timestamp] ⚠️  $line${NC}"
        elif [[ "$line" =~ Task-[0-9]+ ]]; then
            # Task IDs - Purple
            echo -e "${PURPLE}[$timestamp] 🎯 $line${NC}"
        elif [[ "$line" =~ Refresh|Waiting ]]; then
            # Waiting states - Gray
            echo -e "${GRAY}[$timestamp] ⏳ $line${NC}"
        else
            # Default - White
            echo -e "${WHITE}[$timestamp] ℹ️  $line${NC}"
        fi
    done
}

show_menu() {
    clear
    echo -e "${CYAN}📋 NEXUS NODE LOG VIEWER${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get running containers
    local containers
    mapfile -t containers < <(docker ps --filter "name=nexus-node" --format "{{.Names}}" | sort)

    if [[ ${#containers[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No running Nexus nodes found${NC}"
        echo -e "${BLUE}💡 Start some nodes first: cd /root/nexus-orchestrator && ./main.sh${NC}"
        exit 1
    fi

    echo -e "${GREEN}📋 Running Nodes:${NC}"
    echo ""

    for i in "${!containers[@]}"; do
        local container="${containers[$i]}"
        local node_id
        node_id=$(echo "$container" | grep -o '[0-9]\+$')
        echo -e "  ${GREEN}$((i + 1)).${NC} ${CYAN}$container${NC} ${GRAY}(Node ID: $node_id)${NC}"
    done

    echo ""
    echo -e "  ${GREEN}A.${NC} ${PURPLE}All Nodes (Combined)${NC}"
    echo -e "  ${GREEN}0.${NC} ${YELLOW}Exit${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"

    read -rp "$(echo -e "${WHITE}Select node [1-${#containers[@]}/A/0]: ${NC}")" choice
    echo ""

    case "$choice" in
        [1-9]*)
            local index=$((choice - 1))
            if [[ $index -ge 0 && $index -lt ${#containers[@]} ]]; then
                show_colored_logs "${containers[$index]}" 100
            else
                echo -e "${RED}❌ Invalid selection${NC}"
                sleep 2
                show_menu
            fi
            ;;
        [Aa])
            show_combined_logs
            ;;
        0)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            sleep 2
            show_menu
            ;;
    esac
}

show_combined_logs() {
    echo -e "${PURPLE}📋 Combined Logs from All Nodes${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop${NC}"
    echo ""

    cd /root/nexus-orchestrator || exit 1
    docker-compose -f workdir/docker-compose.yml logs -f --tail=30 2>&1 | while IFS= read -r line; do
        local timestamp
        timestamp=$(date '+%H:%M:%S')

        # Extract container name if present
        local container_prefix=""
        if [[ "$line" =~ nexus-node-([0-9]+) ]]; then
            local node_id="${BASH_REMATCH[1]}"
            container_prefix="${CYAN}[Node-$node_id]${NC} "
        fi

        if [[ "$line" =~ Error|Failed|ERROR|failed ]]; then
            echo -e "$container_prefix${RED}[$timestamp] ❌ $line${NC}"
        elif [[ "$line" =~ Success|success|completed|Step\ 2\ of\ 4 ]]; then
            echo -e "$container_prefix${GREEN}[$timestamp] ✅ $line${NC}"
        elif [[ "$line" =~ "Step 1 of 4"|"Step 3 of 4"|Requesting|Submitting ]]; then
            echo -e "$container_prefix${CYAN}[$timestamp] 🔄 $line${NC}"
        elif [[ "$line" =~ "Status: 429"|"Rate limit"|"rate limited" ]]; then
            echo -e "$container_prefix${YELLOW}[$timestamp] ⚠️  $line${NC}"
        elif [[ "$line" =~ Task-[0-9]+ ]]; then
            echo -e "$container_prefix${PURPLE}[$timestamp] 🎯 $line${NC}"
        elif [[ "$line" =~ Refresh|Waiting ]]; then
            echo -e "$container_prefix${GRAY}[$timestamp] ⏳ $line${NC}"
        else
            echo -e "$container_prefix${WHITE}[$timestamp] ℹ️  $line${NC}"
        fi
    done
}

# Main execution
if [[ $# -eq 0 ]]; then
    show_menu
else
    show_colored_logs "$1" "${2:-50}"
fi
