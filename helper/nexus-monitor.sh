#!/bin/bash
# Author: Rokhanz
# Date: August 13, 2025
# License: MIT
# Description: Nexus monitoring functions - Complete monitoring and analytics

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## monitor_logs_menu - Monitor logs submenu
monitor_logs_menu() {
    while true; do
        clear
        echo -e "${CYAN}📊 MONITOR LOGS${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}1) 🎯 Monitor Specific Node${NC}"
        echo -e "${GREEN}2) 📡 Monitor All Nodes (Real-time)${NC}"
        echo -e "${GREEN}3) 📈 Show Success Statistics${NC}"
        echo -e "${GREEN}4) ⚠️ Analyze Error Logs${NC}"
        echo -e "${GREEN}5) 📊 Show Performance Metrics${NC}"
        echo -e "${RED}6) 🚪 Kembali ke Main Menu${NC}"
        echo ""

        read -r -p "$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda [1-6]: ${NC}")" monitor_choice

        case $monitor_choice in
            1)
                echo -e "${CYAN}🎯 Opening Monitor Specific Node...${NC}"
                monitor_specific_node
                ;;
            2)
                echo -e "${CYAN}📡 Opening Monitor All Nodes...${NC}"
                monitor_all_nodes_realtime
                ;;
            3)
                echo -e "${CYAN}📈 Opening Success Statistics...${NC}"
                show_success_statistics
                ;;
            4)
                echo -e "${CYAN}⚠️ Opening Error Log Analysis...${NC}"
                analyze_error_logs
                ;;
            5)
                echo -e "${CYAN}📊 Opening Performance Metrics...${NC}"
                show_performance_metrics
                ;;
            6)
                echo -e "${GREEN}↩️ Kembali ke Main Menu...${NC}"
                break
                ;;
            *)
                echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-6.${NC}"
                wait_for_keypress
                ;;
        esac
    done
}

## monitor_specific_node - Monitor specific node
monitor_specific_node() {
    echo -e "${CYAN}🎯 MONITOR SPECIFIC NODE${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # Get list of running containers
    local containers
    # First check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker tidak berjalan atau tidak dapat diakses${NC}"
        echo -e "${YELLOW}💡 Solusi:${NC}"
        echo -e "${WHITE}1) Start Docker: ${YELLOW}sudo systemctl start docker${NC}"
        echo -e "${WHITE}2) Check permission: ${YELLOW}sudo usermod -aG docker \$USER${NC}"
        echo -e "${WHITE}3) Restart terminal setelah menambah user ke group docker${NC}"
        echo ""
        wait_for_keypress
        return
    fi

    # Get containers with nexus in name (more flexible)
    containers=$(docker ps --format "{{.Names}}" 2>/dev/null | grep -i nexus || true)

    if [[ -z "$containers" ]]; then
        echo -e "${RED}❌ Tidak ada container Nexus yang berjalan${NC}"
        echo -e "${YELLOW}💡 Gunakan: docker compose up -d${NC}"
        echo ""
        # Show all containers for reference
        local all_containers
        all_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
        if [[ -n "$all_containers" ]]; then
            echo -e "${CYAN}📋 Container yang sedang berjalan:${NC}"
            echo "$all_containers"
        else
            echo -e "${YELLOW}📋 Tidak ada container yang berjalan${NC}"
        fi
        echo ""
        echo -e "${CYAN}🔧 Solusi yang tersedia:${NC}"
        echo -e "${WHITE}1) Jalankan Nexus nodes: ${YELLOW}docker compose up -d${NC}"
        echo -e "${WHITE}2) Periksa docker-compose.yml di direktori ini${NC}"
        echo -e "${WHITE}3) Periksa status semua container: ${YELLOW}docker ps -a${NC}"
        echo ""
        wait_for_keypress
        return
    fi

    echo -e "${YELLOW}Running Nexus containers:${NC}"
    echo "$containers" | nl -w2 -s') '
    echo ""
    echo -e "${WHITE}0) 🚪 Kembali ke menu sebelumnya${NC}"
    echo ""

    read -r -p "$(echo -e "${YELLOW}Enter container name or number (0 to go back): ${NC}")" selection

    # Handle back option
    if [[ "$selection" == "0" ]]; then
        echo -e "${GREEN}↩️ Kembali ke menu sebelumnya...${NC}"
        return
    fi

    # Handle number selection
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        local container_name
        container_name=$(echo "$containers" | sed -n "${selection}p")
        if [[ -z "$container_name" ]]; then
            echo -e "${RED}❌ Invalid selection${NC}"
            echo -e "${YELLOW}💡 Gunakan nomor 1-$(echo "$containers" | wc -l) atau 0 untuk kembali${NC}"
            wait_for_keypress
            return
        fi
        selection="$container_name"
    fi

    # Validate container exists and is running
    if ! echo "$containers" | grep -q "^$selection$"; then
        echo -e "${RED}❌ Container '$selection' not found in running containers${NC}"
        echo -e "${YELLOW}💡 Available containers:${NC}"
        echo "$containers" | nl -w2 -s') '
        wait_for_keypress
        return
    fi

    echo -e "${GREEN}🔍 Monitoring container: $selection${NC}"
    echo -e "${YELLOW}Press 'q' and Enter to stop monitoring and return to menu${NC}"
    echo -e "${YELLOW}Monitoring will update every 10 seconds...${NC}"
    echo ""

    # Show initial container status
    echo -e "${CYAN}📊 NEXUS MONITORING DASHBOARD${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Container: $selection${NC}"
    local container_status
    container_status=$(docker inspect --format='{{.State.Status}}' "$selection" 2>/dev/null || echo "Unknown")
    echo -e "${YELLOW}Status: $container_status${NC}"
    echo -e "${YELLOW}Real-time monitoring dengan 10s refresh${NC}"
    echo ""

    # Monitor with color-coded output using interactive loop
    local refresh_count=0
    while true; do
        refresh_count=$((refresh_count + 1))

        # Get comprehensive logs for better visibility
        echo -e "${CYAN}📋 Log Update #$refresh_count ($(date '+%H:%M:%S'))${NC}"
        echo -e "${GRAY}────────────────────────────────────────${NC}"

        # Show last 25 lines to ensure we see activity
        local logs
        logs=$(docker logs --tail 25 "$selection" 2>&1)

        if [[ -n "$logs" ]]; then
            # Show logs with colors
            echo "$logs" | while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                case $line in
                    *"Success"*|*"Submitted"*|*"points"*)
                        echo -e "${GREEN}$line${NC}"
                        ;;
                    *"Error"*|*"Failed"*|*"error"*)
                        echo -e "${RED}$line${NC}"
                        ;;
                    *"Warning"*|*"warning"*)
                        echo -e "${YELLOW}$line${NC}"
                        ;;
                    *"Step"*)
                        echo -e "${CYAN}$line${NC}"
                        ;;
                    *"Refresh"*|*"Waiting"*)
                        echo -e "${BLUE}$line${NC}"
                        ;;
                    *)
                        echo "$line"
                        ;;
                esac
            done
        else
            echo -e "${YELLOW}📝 No logs found - container might be idle or starting up${NC}"
            echo -e "${YELLOW}   Check if container is running: docker ps | grep $selection${NC}"
        fi

        echo ""
        echo -e "${GRAY}────────────────────────────────────────${NC}"
        echo -e "${YELLOW}Type 'q' + Enter to return to menu, 'r' + Enter to force refresh (wait 10s)${NC}"

        # Check for user input with longer timeout for better UX
        if read -t 10 -r user_input; then
            case "$user_input" in
                "q"|"Q")
                    echo -e "${GREEN}↩️ Kembali ke menu sebelumnya...${NC}"
                    return
                    ;;
                "r"|"R")
                    echo -e "${CYAN}🔄 Force refresh...${NC}"
                    continue
                    ;;
            esac
        fi

        # Add separator and continue
        echo ""
        echo -e "${CYAN}🔄 Auto-refreshing logs...${NC}"
        echo ""
    done
}

## monitor_all_nodes_realtime - Monitor all nodes realtime
monitor_all_nodes_realtime() {
    echo -e "${CYAN}📡 MONITOR ALL NODES (REAL-TIME)${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker tidak berjalan atau tidak dapat diakses${NC}"
        wait_for_keypress
        return
    fi

    local containers
    containers=$(docker ps --format "{{.Names}}" 2>/dev/null | grep -i nexus || true)

    if [[ -z "$containers" ]]; then
        echo -e "${RED}❌ Tidak ada container Nexus yang berjalan${NC}"
        wait_for_keypress
        return
    fi

    echo -e "${GREEN}🔍 Monitoring all Nexus containers in real-time...${NC}"
    echo -e "${YELLOW}Press 'q' and Enter to stop monitoring${NC}"
    echo ""

    local refresh_count=0
    while true; do
        refresh_count=$((refresh_count + 1))
        clear
        echo -e "${CYAN}📊 ALL NODES MONITORING DASHBOARD #$refresh_count${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""

        while IFS= read -r container; do
            [[ -n "$container" ]] || continue
            echo -e "${CYAN}📦 Container: $container${NC}"

            # Get last 10 lines for each container with better formatting
            local logs
            logs=$(docker logs --tail 10 "$container" 2>&1 | tail -10)

            if [[ -n "$logs" ]]; then
                echo "$logs" | while IFS= read -r line; do
                    [[ -z "$line" ]] && continue

                    # Parse timestamp and message
                    local timestamp message
                    if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\](.*)$ ]]; then
                        timestamp="${BASH_REMATCH[1]}"
                        message="${BASH_REMATCH[2]}"
                    else
                        timestamp=""
                        message="$line"
                    fi

                    # Format based on content
                    case $message in
                        *"Success"*|*"Submitted"*|*"points"*|*"Step"*"4"*|*"Generating proof"*)
                            echo -e "  ${GREEN}Success${NC} ${LIGHT_BLUE}[$timestamp]${NC} $message"
                            ;;
                        *"Error"*|*"Failed"*|*"error"*|*"timeout"*)
                            echo -e "  ${RED}Error${NC} ${LIGHT_BLUE}[$timestamp]${NC} $message"
                            ;;
                        *"Waiting"*|*"rate limited"*|*"retrying"*)
                            echo -e "  ${YELLOW}Waiting${NC} ${LIGHT_BLUE}[$timestamp]${NC} $message"
                            ;;
                        *"Step 1"*|*"Requesting task"*)
                            echo -e "  ${CYAN}Refresh${NC} ${LIGHT_BLUE}[$timestamp]${NC} $message"
                            ;;
                        *)
                            echo "  $line"
                            ;;
                    esac
                done
            else
                echo -e "  ${YELLOW}No recent activity${NC}"
            fi
            echo ""
        done <<< "$containers"

        echo -e "${YELLOW}Type 'q' + Enter to return to menu (refresh every 15s)${NC}"

        if read -t 15 -r user_input; then
            case "$user_input" in
                "q"|"Q")
                    echo -e "${GREEN}↩️ Kembali ke menu sebelumnya...${NC}"
                    return
                    ;;
            esac
        fi
    done
}

## show_success_statistics - Show success rate statistics
show_success_statistics() {
    echo -e "${CYAN}📈 SUCCESS RATE STATISTICS${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local containers
    containers=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${RED}❌ No running Nexus containers found${NC}"
        wait_for_keypress
        return
    fi

    echo -e "${GREEN}📊 Container Statistics:${NC}"
    echo ""

    local total_containers=0
    local total_success=0
    local total_errors=0

    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            total_containers=$((total_containers + 1))

            echo -e "${YELLOW}Container: $container${NC}"

            # Get recent logs (last 100 lines)
            local logs
            logs=$(docker logs --tail 100 "$container" 2>&1 || echo "")

            # Count success patterns
            local success_count
            success_count=$(echo "$logs" | grep -c -E "(Success|Submitted|points)" 2>/dev/null || echo "0")
            # Ensure success_count is numeric
            [[ "$success_count" =~ ^[0-9]+$ ]] || success_count=0

            # Count error patterns
            local error_count
            error_count=$(echo "$logs" | grep -c -E "(Error|Failed|error)" 2>/dev/null || echo "0")
            # Ensure error_count is numeric
            [[ "$error_count" =~ ^[0-9]+$ ]] || error_count=0

            total_success=$((total_success + success_count))
            total_errors=$((total_errors + error_count))

            echo "  ✅ Success messages: $success_count"
            echo "  ❌ Error messages: $error_count"

            # Calculate success rate for this container
            local total_messages=$((success_count + error_count))
            if [[ $total_messages -gt 0 ]] && [[ "$total_messages" =~ ^[0-9]+$ ]]; then
                local success_rate=$((success_count * 100 / total_messages))
                echo "  📈 Success rate: $success_rate%"
            else
                echo "  📈 Success rate: No data"
            fi
            echo ""
        fi
    done <<< "$containers"

    echo -e "${GREEN}📊 Overall Statistics:${NC}"
    echo "  🔧 Total containers: $total_containers"
    echo "  ✅ Total success messages: $total_success"
    echo "  ❌ Total error messages: $total_errors"

    local overall_total=$((total_success + total_errors))
    if [[ $overall_total -gt 0 ]]; then
        local overall_rate=$((total_success * 100 / overall_total))
        echo "  📈 Overall success rate: $overall_rate%"
    else
        echo "  📈 Overall success rate: No data"
    fi

    wait_for_keypress
}

## analyze_error_logs - Analyze error logs
analyze_error_logs() {
    echo -e "${CYAN}⚠️ ERROR LOG ANALYSIS${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local containers
    containers=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${RED}❌ No running Nexus containers found${NC}"
        wait_for_keypress
        return
    fi

    echo -e "${YELLOW}🔍 Analyzing errors from all containers...${NC}"
    echo ""

    local total_errors=0

    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -e "${YELLOW}📦 Container: $container${NC}"

            # Get error logs
            local error_logs
            error_logs=$(docker logs --tail 50 "$container" 2>&1 | grep -E "(Error|Failed|error|ERROR)" || echo "")

            if [[ -n "$error_logs" ]]; then
                local error_count
                error_count=$(echo "$error_logs" | wc -l)
                total_errors=$((total_errors + error_count))

                echo -e "${RED}  Found $error_count error(s):${NC}"
                echo "$error_logs" | head -5 | sed 's/^/    /'

                if [[ $error_count -gt 5 ]]; then
                    echo "    ... and $((error_count - 5)) more errors"
                fi
            else
                echo -e "${GREEN}  ✅ No errors found${NC}"
            fi
            echo ""
        fi
    done <<< "$containers"

    echo -e "${GREEN}📊 Error Summary:${NC}"
    echo "  ❌ Total errors found: $total_errors"

    if [[ $total_errors -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}💡 Common solutions:${NC}"
        echo "  1. Check network connectivity"
        echo "  2. Verify node registration status"
        echo "  3. Restart problematic containers"
        echo "  4. Check rate limiting issues"
    fi

    wait_for_keypress
}

## show_performance_metrics - Show performance metrics
show_performance_metrics() {
    echo -e "${CYAN}📊 PERFORMANCE METRICS${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # System resources
    echo -e "${GREEN}💻 System Resources:${NC}"
    echo "  CPU cores: $(nproc)"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  Load average: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""

    # Docker stats
    echo -e "${GREEN}🐳 Docker Container Stats:${NC}"
    local nexus_containers
    nexus_containers=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null || echo "")

    if [[ -n "$nexus_containers" ]]; then
        echo "  Container             CPU%    Memory       Network"
        echo "  ──────────────────── ────── ───────────── ─────────"

        # Get stats for each container individually (compatibility method)
        while IFS= read -r container_name; do
            [[ -n "$container_name" ]] || continue

            local stats_output
            stats_output=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" "$container_name" 2>/dev/null || printf "unavailable\tunavailable\tunavailable")

            local cpu_usage memory_usage network_io
            cpu_usage=$(echo "$stats_output" | cut -f1)
            memory_usage=$(echo "$stats_output" | cut -f2)
            network_io=$(echo "$stats_output" | cut -f3)

            # Truncate network field if too long to prevent line wrapping
            if [[ ${#network_io} -gt 12 ]]; then
                network_io="${network_io:0:9}..."
            fi

            printf "  %-20s %-7s %-13s %-12s\n" "$container_name" "$cpu_usage" "$memory_usage" "$network_io"
        done <<< "$nexus_containers"
    else
        echo "  No Nexus containers running"
    fi
    echo ""

    # Disk usage
    echo -e "${GREEN}💿 Disk Usage:${NC}"
    df -h / | awk 'NR==2 {print "  Root: " $3 " used / " $2 " total (" $5 " full)"}'

    # Docker volumes
    echo ""
    echo -e "${GREEN}📦 Docker Volumes:${NC}"
    local nexus_volumes
    nexus_volumes=$(docker volume ls --filter "name=nexus" --format "{{.Name}}" | wc -l)
    echo "  Nexus volumes: $nexus_volumes"

    # Network ports
    echo ""
    echo -e "${GREEN}🌐 Network Ports:${NC}"
    local nexus_ports
    nexus_ports=$(docker ps --filter "name=nexus-node-" --format "{{.Ports}}" | grep -o '[0-9]*->[0-9]*' | wc -l)
    echo "  Active Nexus ports: $nexus_ports"

    echo ""
    wait_for_keypress
}
