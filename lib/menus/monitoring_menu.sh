#!/bin/bash

# monitoring_menu.sh - Monitoring & Statistics Menu Module
# Version: 4.0.0 - Modular menu system for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# MONITORING MENU FUNCTIONS
# =============================================================================

monitoring_menu() {
    while true; do
        clear
        show_section_header "Monitoring & Statistics" "📊"

        echo -e "${CYAN}Select monitoring option:${NC}"
        echo ""
        echo "1. Real-time System Monitor"
        echo "2. Container Performance Metrics"
        echo "3. Network Statistics"
        echo "4. Resource Usage History"
        echo "5. Proof Generation Statistics"
        echo "6. System Health Dashboard"
        echo "7. Export Performance Report"
        echo "8. Set Monitoring Alerts"
        echo "0. Return to Main Menu"
        echo ""

        read -rp "Choose option [0-8]: " choice

        case "$choice" in
            1)
                real_time_monitor
                ;;
            2)
                container_metrics
                ;;
            3)
                network_statistics
                ;;
            4)
                resource_history
                ;;
            5)
                proof_statistics
                ;;
            6)
                health_dashboard
                ;;
            7)
                export_report
                ;;
            8)
                configure_alerts
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# REAL-TIME MONITORING
# =============================================================================

real_time_monitor() {
    show_section_header "Real-time System Monitor" "📈"

    echo -e "${CYAN}Starting real-time monitor... Press Ctrl+C to stop${NC}"
    echo ""

    # Function to display system stats
    display_stats() {
        clear
        echo -e "${CYAN}${BOLD}📊 REAL-TIME SYSTEM MONITOR${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
        echo ""

        # System information
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${BOLD}Timestamp: ${CYAN}$timestamp${NC}"
        echo ""

        # CPU usage
        local cpu_usage
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        echo -e "${BOLD}CPU Usage: ${GREEN}$cpu_usage%${NC}"

        # Memory usage
        local mem_info
        mem_info=$(free -h | awk 'NR==2{printf "Used: %s/%s (%.2f%%)", $3,$2,$3*100/$2}')
        echo -e "${BOLD}Memory: ${GREEN}$mem_info${NC}"

        # Disk usage
        local disk_usage
        disk_usage=$(df -h / | awk 'NR==2{printf "Used: %s/%s (%s)", $3,$2,$5}')
        echo -e "${BOLD}Disk: ${GREEN}$disk_usage${NC}"

        # Docker containers
        if command -v docker >/dev/null 2>&1; then
            local running_containers
            running_containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" | wc -l)
            echo -e "${BOLD}Running Containers: ${GREEN}$running_containers${NC}"
        fi

        echo ""
        echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    }

    # Trap to handle Ctrl+C
    trap 'echo -e "\n${GREEN}Monitoring stopped${NC}"; return 0' INT

    # Main monitoring loop
    while true; do
        display_stats
        sleep 2
    done
}

# =============================================================================
# CONTAINER METRICS
# =============================================================================

container_metrics() {
    show_section_header "Container Performance Metrics" "🐳"

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker not installed${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    # Get all Nexus containers
    local containers
    containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}⚠️  No Nexus containers running${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${CYAN}Container performance metrics:${NC}"
    echo ""

    # Header
    printf "%-20s %-10s %-10s %-15s %-10s\n" "Container" "CPU %" "Memory" "Network I/O" "Status"
    echo "────────────────────────────────────────────────────────────────────"

    # Get stats for each container
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            local stats
            stats=$(docker stats "$container" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null | tail -n 1)

            local status
            status=$(docker inspect "$container" --format "{{.State.Status}}" 2>/dev/null || echo "unknown")

            # Parse stats
            local cpu_perc memory_usage net_io
            cpu_perc=$(echo "$stats" | awk '{print $1}')
            memory_usage=$(echo "$stats" | awk '{print $2}')
            net_io=$(echo "$stats" | awk '{print $3}')

            # Color code status
            local status_color="$GREEN"
            if [[ "$status" != "running" ]]; then
                status_color="$RED"
            fi

            printf "%-20s %-10s %-10s %-15s %b%-10s%b\n" \
                "$container" "$cpu_perc" "$memory_usage" "$net_io" "$status_color" "$status" "$NC"
        fi
    done <<< "$containers"

    echo ""

    # Additional container details
    echo -e "${CYAN}Detailed container information:${NC}"
    echo ""

    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -e "${BOLD}$container:${NC}"

            # Uptime
            local created
            created=$(docker inspect "$container" --format "{{.Created}}" 2>/dev/null)
            if [[ -n "$created" ]]; then
                local uptime
                uptime=$(date -d "$created" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
                echo "  Created: $uptime"
            fi

            # Restart count
            local restart_count
            restart_count=$(docker inspect "$container" --format "{{.RestartCount}}" 2>/dev/null || echo "0")
            echo "  Restarts: $restart_count"

            # Image
            local image
            image=$(docker inspect "$container" --format "{{.Config.Image}}" 2>/dev/null || echo "unknown")
            echo "  Image: $image"

            echo ""
        fi
    done <<< "$containers"

    read -rp "Press Enter to continue..."
}

# =============================================================================
# NETWORK STATISTICS
# =============================================================================

network_statistics() {
    show_section_header "Network Statistics" "🌐"

    echo -e "${CYAN}Network interface statistics:${NC}"
    echo ""

    # Network interfaces
    if command -v ip >/dev/null 2>&1; then
        ip -s link show | grep -E "^[0-9]|RX:|TX:" | \
        awk '/^[0-9]/ {iface=$2; gsub(/:/, "", iface)}
             /RX:/ {rx_bytes=$2; getline; rx_packets=$1}
             /TX:/ {tx_bytes=$2; getline; tx_packets=$1;
                    printf "%-12s RX: %10s bytes (%8s packets)  TX: %10s bytes (%8s packets)\n",
                    iface, rx_bytes, rx_packets, tx_bytes, tx_packets}'
    fi

    echo ""

    # Docker network statistics
    if command -v docker >/dev/null 2>&1; then
        echo -e "${CYAN}Docker network usage:${NC}"
        echo ""

        local containers
        containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)

        if [[ -n "$containers" ]]; then
            printf "%-20s %-15s %-15s\n" "Container" "Network In" "Network Out"
            echo "──────────────────────────────────────────────────────────"

            while IFS= read -r container; do
                if [[ -n "$container" ]]; then
                    local net_stats
                    net_stats=$(docker stats "$container" --no-stream --format "{{.NetIO}}" 2>/dev/null)

                    local net_in net_out
                    net_in=$(echo "$net_stats" | cut -d'/' -f1 | tr -d ' ')
                    net_out=$(echo "$net_stats" | cut -d'/' -f2 | tr -d ' ')

                    printf "%-20s %-15s %-15s\n" "$container" "$net_in" "$net_out"
                fi
            done <<< "$containers"
        else
            echo "No containers running"
        fi
    fi

    echo ""

    # Connection statistics
    echo -e "${CYAN}Network connections:${NC}"
    echo ""

    if command -v netstat >/dev/null 2>&1; then
        local tcp_connections
        tcp_connections=$(netstat -tn 2>/dev/null | grep -c ESTABLISHED || echo "0")

        local listening_ports
        listening_ports=$(netstat -ln 2>/dev/null | grep -c LISTEN || echo "0")

        echo "TCP Established: $tcp_connections"
        echo "Listening ports: $listening_ports"
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# RESOURCE HISTORY
# =============================================================================

resource_history() {
    show_section_header "Resource Usage History" "📈"

    echo -e "${CYAN}Analyzing resource usage history...${NC}"
    echo ""

    # Create history data directory
    local history_dir="$DEFAULT_WORKDIR/monitoring"
    ensure_directory "$history_dir"

    # Collect current stats
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')

    local disk_usage
    disk_usage=$(df / | awk 'NR==2{print $5}' | cut -d'%' -f1)

    # Save to history file
    echo "$timestamp,$cpu_usage,$mem_usage,$disk_usage" >> "$history_dir/resource_history.csv"

    # Show recent history (last 20 entries)
    if [[ -f "$history_dir/resource_history.csv" ]]; then
        echo -e "${CYAN}Recent resource usage (last 20 entries):${NC}"
        echo ""
        printf "%-20s %-10s %-10s %-10s\n" "Timestamp" "CPU %" "Memory %" "Disk %"
        echo "─────────────────────────────────────────────────────────────"

        tail -n 20 "$history_dir/resource_history.csv" | while IFS=',' read -r ts cpu mem disk; do
            printf "%-20s %-10s %-10s %-10s\n" "$ts" "$cpu" "$mem" "$disk"
        done
    else
        echo "No history data available yet"
    fi

    echo ""

    # Show summary statistics
    if [[ -f "$history_dir/resource_history.csv" ]]; then
        echo -e "${CYAN}Summary statistics:${NC}"
        echo ""

        local avg_cpu avg_mem avg_disk
        avg_cpu=$(awk -F',' '{sum+=$2; count++} END{printf "%.2f", sum/count}' "$history_dir/resource_history.csv")
        avg_mem=$(awk -F',' '{sum+=$3; count++} END{printf "%.2f", sum/count}' "$history_dir/resource_history.csv")
        avg_disk=$(awk -F',' '{sum+=$4; count++} END{printf "%.2f", sum/count}' "$history_dir/resource_history.csv")

        echo "Average CPU usage: $avg_cpu%"
        echo "Average Memory usage: $avg_mem%"
        echo "Average Disk usage: $avg_disk%"
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# PROOF STATISTICS
# =============================================================================

proof_statistics() {
    show_section_header "Proof Generation Statistics" "🔐"

    echo -e "${CYAN}Analyzing proof generation statistics...${NC}"
    echo ""

    # Check for proof logs in container logs
    local containers
    containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}⚠️  No Nexus containers running${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    local total_proofs=0
    local successful_proofs=0
    local failed_proofs=0

    echo -e "${CYAN}Proof statistics by container:${NC}"
    echo ""

    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -e "${BOLD}$container:${NC}"

            # Get logs from container (last 1000 lines)
            local logs
            logs=$(docker logs "$container" --tail 1000 2>/dev/null || echo "")

            # Count proof-related log entries
            local container_proofs
            container_proofs=$(echo "$logs" | grep -c "proof" 2>/dev/null || echo "0")

            local container_success
            container_success=$(echo "$logs" | grep -c "success\|completed\|finished" 2>/dev/null || echo "0")

            local container_errors
            container_errors=$(echo "$logs" | grep -c "error\|failed\|timeout" 2>/dev/null || echo "0")

            echo "  Total proof attempts: $container_proofs"
            echo "  Successful: $container_success"
            echo "  Failed: $container_errors"

            # Calculate uptime
            local uptime
            uptime=$(docker inspect "$container" --format "{{.State.StartedAt}}" 2>/dev/null)
            if [[ -n "$uptime" ]]; then
                local start_time
                start_time=$(date -d "$uptime" +%s 2>/dev/null || echo "0")
                local current_time
                current_time=$(date +%s)
                local uptime_hours
                uptime_hours=$(( (current_time - start_time) / 3600 ))
                echo "  Uptime: ${uptime_hours} hours"
            fi

            echo ""

            # Add to totals
            total_proofs=$((total_proofs + container_proofs))
            successful_proofs=$((successful_proofs + container_success))
            failed_proofs=$((failed_proofs + container_errors))
        fi
    done <<< "$containers"

    # Overall statistics
    echo -e "${CYAN}Overall statistics:${NC}"
    echo ""
    echo "Total proof attempts: $total_proofs"
    echo "Successful proofs: $successful_proofs"
    echo "Failed proofs: $failed_proofs"

    if [[ $total_proofs -gt 0 ]]; then
        local success_rate
        success_rate=$(( (successful_proofs * 100) / total_proofs ))
        echo "Success rate: $success_rate%"
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# HEALTH DASHBOARD
# =============================================================================

health_dashboard() {
    show_section_header "System Health Dashboard" "🏥"

    echo -e "${CYAN}System Health Overview:${NC}"
    echo ""

    # System health checks
    local health_score=0
    local total_checks=0

    # Check 1: System resources
    echo -e "${BOLD}1. System Resources:${NC}"
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)

    if [[ $cpu_usage -lt 80 ]]; then
        echo "   CPU: ${GREEN}✅ Good ($cpu_usage%)${NC}"
        health_score=$((health_score + 1))
    else
        echo "   CPU: ${RED}❌ High ($cpu_usage%)${NC}"
    fi
    total_checks=$((total_checks + 1))

    # Memory check
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

    if [[ $mem_usage -lt 85 ]]; then
        echo "   Memory: ${GREEN}✅ Good ($mem_usage%)${NC}"
        health_score=$((health_score + 1))
    else
        echo "   Memory: ${RED}❌ High ($mem_usage%)${NC}"
    fi
    total_checks=$((total_checks + 1))

    # Disk check
    local disk_usage
    disk_usage=$(df / | awk 'NR==2{print $5}' | cut -d'%' -f1)

    if [[ $disk_usage -lt 90 ]]; then
        echo "   Disk: ${GREEN}✅ Good ($disk_usage%)${NC}"
        health_score=$((health_score + 1))
    else
        echo "   Disk: ${RED}❌ High ($disk_usage%)${NC}"
    fi
    total_checks=$((total_checks + 1))

    echo ""

    # Check 2: Docker service
    echo -e "${BOLD}2. Docker Service:${NC}"
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo "   Status: ${GREEN}✅ Running${NC}"
        health_score=$((health_score + 1))
    else
        echo "   Status: ${RED}❌ Not running${NC}"
    fi
    total_checks=$((total_checks + 1))

    # Check 3: Containers
    echo -e "${BOLD}3. Nexus Containers:${NC}"
    local running_containers
    running_containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" | wc -l)

    if [[ $running_containers -gt 0 ]]; then
        echo "   Running: ${GREEN}✅ $running_containers containers${NC}"
        health_score=$((health_score + 1))
    else
        echo "   Running: ${YELLOW}⚠️  No containers${NC}"
    fi
    total_checks=$((total_checks + 1))

    # Check 4: Network connectivity
    echo -e "${BOLD}4. Network Connectivity:${NC}"
    if ping -c 1 google.com >/dev/null 2>&1; then
        echo "   Internet: ${GREEN}✅ Connected${NC}"
        health_score=$((health_score + 1))
    else
        echo "   Internet: ${RED}❌ No connection${NC}"
    fi
    total_checks=$((total_checks + 1))

    echo ""

    # Overall health score
    local health_percentage
    health_percentage=$(( (health_score * 100) / total_checks ))

    echo -e "${BOLD}Overall Health Score: "
    if [[ $health_percentage -ge 80 ]]; then
        echo -e "${GREEN}$health_percentage% (Excellent)${NC}"
    elif [[ $health_percentage -ge 60 ]]; then
        echo -e "${YELLOW}$health_percentage% (Good)${NC}"
    else
        echo -e "${RED}$health_percentage% (Needs attention)${NC}"
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# EXPORT REPORT
# =============================================================================

export_report() {
    show_section_header "Export Performance Report" "📄"

    echo -e "${CYAN}Generating performance report...${NC}"
    echo ""

    local report_file
    report_file="$DEFAULT_WORKDIR/performance_report_$(date '+%Y%m%d_%H%M%S').txt"

    # Create report
    {
        echo "Nexus Orchestrator Performance Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "======================================"
        echo ""

        echo "System Information:"
        echo "- OS: $(uname -s -r)"
        echo "- Architecture: $(uname -m)"
        echo "- CPU Cores: $(nproc)"
        echo "- Total Memory: $(free -h | awk 'NR==2{print $2}')"
        echo ""

        echo "Current Resource Usage:"
        echo "- CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
        echo "- Memory: $(free -h | awk 'NR==2{printf "Used: %s/%s", $3,$2}')"
        echo "- Disk: $(df -h / | awk 'NR==2{printf "Used: %s/%s (%s)", $3,$2,$5}')"
        echo ""

        echo "Container Status:"
        if command -v docker >/dev/null 2>&1; then
            local containers
            containers=$(docker ps --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)
            if [[ -n "$containers" ]]; then
                while IFS= read -r container; do
                    echo "- $container: $(docker inspect "$container" --format "{{.State.Status}}" 2>/dev/null)"
                done <<< "$containers"
            else
                echo "- No containers running"
            fi
        else
            echo "- Docker not available"
        fi

    } > "$report_file"

    echo -e "${GREEN}✅ Report exported to: $report_file${NC}"
    echo ""

    # Show file size
    local file_size
    file_size=$(du -h "$report_file" | cut -f1)
    echo "Report size: $file_size"

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# CONFIGURE ALERTS
# =============================================================================

configure_alerts() {
    show_section_header "Configure Monitoring Alerts" "🚨"

    echo -e "${CYAN}Configure system monitoring alerts:${NC}"
    echo ""
    echo "1. CPU usage threshold"
    echo "2. Memory usage threshold"
    echo "3. Disk usage threshold"
    echo "4. Container failure alerts"
    echo "0. Back to monitoring menu"
    echo ""

    read -rp "Choose option [0-4]: " choice

    case "$choice" in
        1)
            configure_cpu_alert
            ;;
        2)
            configure_memory_alert
            ;;
        3)
            configure_disk_alert
            ;;
        4)
            configure_container_alert
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            sleep 2
            ;;
    esac
}

configure_cpu_alert() {
    echo ""
    read -rp "Enter CPU usage threshold (1-100%): " cpu_threshold

    if [[ "$cpu_threshold" =~ ^[0-9]+$ ]] && [[ $cpu_threshold -ge 1 ]] && [[ $cpu_threshold -le 100 ]]; then
        write_config_value "alerts.cpu_threshold" "$cpu_threshold"
        echo -e "${GREEN}✅ CPU alert threshold set to $cpu_threshold%${NC}"
    else
        echo -e "${RED}❌ Invalid threshold value${NC}"
    fi

    read -rp "Press Enter to continue..."
}

configure_memory_alert() {
    echo ""
    read -rp "Enter memory usage threshold (1-100%): " mem_threshold

    if [[ "$mem_threshold" =~ ^[0-9]+$ ]] && [[ $mem_threshold -ge 1 ]] && [[ $mem_threshold -le 100 ]]; then
        write_config_value "alerts.memory_threshold" "$mem_threshold"
        echo -e "${GREEN}✅ Memory alert threshold set to $mem_threshold%${NC}"
    else
        echo -e "${RED}❌ Invalid threshold value${NC}"
    fi

    read -rp "Press Enter to continue..."
}

configure_disk_alert() {
    echo ""
    read -rp "Enter disk usage threshold (1-100%): " disk_threshold

    if [[ "$disk_threshold" =~ ^[0-9]+$ ]] && [[ $disk_threshold -ge 1 ]] && [[ $disk_threshold -le 100 ]]; then
        write_config_value "alerts.disk_threshold" "$disk_threshold"
        echo -e "${GREEN}✅ Disk alert threshold set to $disk_threshold%${NC}"
    else
        echo -e "${RED}❌ Invalid threshold value${NC}"
    fi

    read -rp "Press Enter to continue..."
}

configure_container_alert() {
    echo ""
    echo -e "${CYAN}Container failure alert options:${NC}"
    echo "1. Enable container failure notifications"
    echo "2. Disable container failure notifications"
    echo ""

    read -rp "Choose option [1-2]: " alert_choice

    case "$alert_choice" in
        1)
            write_config_value "alerts.container_failures" "true"
            echo -e "${GREEN}✅ Container failure alerts enabled${NC}"
            ;;
        2)
            write_config_value "alerts.container_failures" "false"
            echo -e "${YELLOW}⚠️  Container failure alerts disabled${NC}"
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            ;;
    esac

    read -rp "Press Enter to continue..."
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f monitoring_menu real_time_monitor container_metrics network_statistics
export -f resource_history proof_statistics health_dashboard export_report
export -f configure_alerts configure_cpu_alert configure_memory_alert
export -f configure_disk_alert configure_container_alert

log_success "Monitoring & statistics menu loaded successfully"
