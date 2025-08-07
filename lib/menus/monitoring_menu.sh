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
        echo "9. Auto Cache Management"
        echo "0. Return to Main Menu"
        echo ""

        read -rp "Choose option [0-9]: " choice

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
            9)
                auto_cache_management_menu
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

configure_threshold_alert() {
    local config_key="$1"
    local display_name="$2"

    echo ""
    read -rp "Enter $display_name usage threshold (1-100%): " threshold

    if [[ "$threshold" =~ ^[0-9]+$ ]] && [[ $threshold -ge 1 ]] && [[ $threshold -le 100 ]]; then
        write_config_value "alerts.$config_key" "$threshold"
        echo -e "${GREEN}✅ $display_name alert threshold set to $threshold%${NC}"
    else
        echo -e "${RED}❌ Invalid threshold value${NC}"
    fi

    read -rp "Press Enter to continue..."
}

configure_cpu_alert() {
    configure_threshold_alert "cpu_threshold" "CPU"
}

configure_memory_alert() {
    configure_threshold_alert "memory_threshold" "Memory"
}

configure_disk_alert() {
    configure_threshold_alert "disk_threshold" "Disk"
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
# AUTO CACHE MANAGEMENT SYSTEM
# =============================================================================

auto_cache_management_menu() {
    while true; do
        clear
        show_section_header "Auto Cache Management" "🧹"

        echo -e "${CYAN}Conservative Auto Cache Cleanup System${NC}"
        echo ""
        echo "1. View Auto Cache Status"
        echo "2. Configure Auto Cache Daemon"
        echo "3. Start Auto Cache Daemon"
        echo "4. Stop Auto Cache Daemon"
        echo "5. View Cache Daemon Logs"
        echo "6. Test Cache Conditions"
        echo "7. Manual Cache Cleanup"
        echo "0. Return to Monitoring Menu"
        echo ""

        read -rp "Choose option [0-7]: " choice

        case "$choice" in
            1)
                show_auto_cache_status
                ;;
            2)
                configure_auto_cache
                ;;
            3)
                start_auto_cache_daemon
                ;;
            4)
                stop_auto_cache_daemon
                ;;
            5)
                view_cache_daemon_logs
                ;;
            6)
                test_cache_conditions
                ;;
            7)
                manual_cache_cleanup
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

show_auto_cache_status() {
    show_section_header "Auto Cache Daemon Status" "📊"

    # Check if daemon is running
    local daemon_pid
    daemon_pid=$(pgrep -f "nexus_auto_cache_daemon" || echo "")

    echo -e "${CYAN}🔍 Auto Cache Daemon Status:${NC}"
    echo ""

    if [[ -n "$daemon_pid" ]]; then
        echo -e "${GREEN}✅ Daemon Status: RUNNING (PID: $daemon_pid)${NC}"

        # Check daemon uptime
        local uptime
        uptime=$(ps -o etime= -p "$daemon_pid" 2>/dev/null | tr -d ' ' || echo "Unknown")
        echo -e "${CYAN}⏱️  Uptime: $uptime${NC}"
    else
        echo -e "${RED}❌ Daemon Status: STOPPED${NC}"
    fi

    echo ""
    echo -e "${CYAN}📊 Current System Status:${NC}"

    # Memory usage
    local mem_usage
    mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    local mem_color="${GREEN}"
    [[ $mem_usage -gt 80 ]] && mem_color="${YELLOW}"
    [[ $mem_usage -gt 90 ]] && mem_color="${RED}"
    echo -e "${CYAN}💾 Memory Usage: ${mem_color}${mem_usage}%${NC}"

    # Swap usage
    local swap_usage
    swap_usage=$(free | awk 'NR==3{if($2>0) printf "%.0f", $3*100/$2; else print "0"}')
    local swap_color="${GREEN}"
    [[ $swap_usage -gt 60 ]] && swap_color="${YELLOW}"
    [[ $swap_usage -gt 80 ]] && swap_color="${RED}"
    echo -e "${CYAN}🔄 Swap Usage: ${swap_color}${swap_usage}%${NC}"

    # Available memory
    local mem_available
    mem_available=$(free -h | awk 'NR==2{print $7}')
    echo -e "${CYAN}🆓 Available Memory: ${GREEN}${mem_available}${NC}"

    # Container status
    local container_count
    container_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)
    echo -e "${CYAN}📦 Active Nexus Containers: ${GREEN}${container_count}${NC}"

    echo ""
    echo -e "${CYAN}⚙️  Configuration:${NC}"
    local config_file="/tmp/nexus-orchestrator/workdir/config/auto_cache_config.json"
    if [[ -f "$config_file" ]]; then
        local memory_threshold
        local swap_threshold
        local schedule_time
        memory_threshold=$(jq -r '.memory_threshold // 90' "$config_file" 2>/dev/null || echo "90")
        swap_threshold=$(jq -r '.swap_threshold // 80' "$config_file" 2>/dev/null || echo "80")
        schedule_time=$(jq -r '.schedule_time // "05:00"' "$config_file" 2>/dev/null || echo "05:00")

        echo -e "${CYAN}📈 Memory Trigger: ${YELLOW}${memory_threshold}%${NC}"
        echo -e "${CYAN}🔄 Swap Trigger: ${YELLOW}${swap_threshold}%${NC}"
        echo -e "${CYAN}🕐 Schedule Time: ${YELLOW}${schedule_time}${NC}"
    else
        echo -e "${YELLOW}⚠️  No configuration found (using defaults)${NC}"
    fi

    read -rp "Press Enter to continue..."
}

configure_auto_cache() {
    show_section_header "Configure Auto Cache System" "⚙️"

    local config_dir="/tmp/nexus-orchestrator/workdir/config"
    local config_file="$config_dir/auto_cache_config.json"

    # Ensure config directory exists
    mkdir -p "$config_dir"

    echo -e "${CYAN}🔧 Conservative Auto Cache Configuration${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Conservative Mode: System cache cleaned first, Nexus cache only if critical${NC}"
    echo ""

    # Current settings or defaults
    local current_memory=90
    local current_swap=80
    local current_schedule="05:00"
    local current_enabled=false

    if [[ -f "$config_file" ]]; then
        current_memory=$(jq -r '.memory_threshold // 90' "$config_file" 2>/dev/null || echo "90")
        current_swap=$(jq -r '.swap_threshold // 80' "$config_file" 2>/dev/null || echo "80")
        current_schedule=$(jq -r '.schedule_time // "05:00"' "$config_file" 2>/dev/null || echo "05:00")
        current_enabled=$(jq -r '.enabled // false' "$config_file" 2>/dev/null || echo "false")
    fi

    echo -e "${CYAN}Current Configuration:${NC}"
    echo -e "Memory Threshold: ${YELLOW}${current_memory}%${NC}"
    echo -e "Swap Threshold: ${YELLOW}${current_swap}%${NC}"
    echo -e "Schedule Time: ${YELLOW}${current_schedule}${NC}"
    echo -e "Auto Start: ${YELLOW}${current_enabled}${NC}"
    echo ""

    # Configure memory threshold
    echo -e "${CYAN}💾 Memory Usage Threshold (recommended: 90%):${NC}"
    read -rp "Enter memory threshold [current: $current_memory%]: " memory_input
    local memory_threshold="${memory_input:-$current_memory}"

    # Validate memory threshold
    if ! [[ "$memory_threshold" =~ ^[0-9]+$ ]] || [[ $memory_threshold -lt 50 ]] || [[ $memory_threshold -gt 95 ]]; then
        echo -e "${RED}❌ Invalid memory threshold. Using default: 90%${NC}"
        memory_threshold=90
    fi

    # Configure swap threshold
    echo -e "${CYAN}🔄 Swap Usage Threshold (recommended: 80%):${NC}"
    read -rp "Enter swap threshold [current: $current_swap%]: " swap_input
    local swap_threshold="${swap_input:-$current_swap}"

    # Validate swap threshold
    if ! [[ "$swap_threshold" =~ ^[0-9]+$ ]] || [[ $swap_threshold -lt 50 ]] || [[ $swap_threshold -gt 90 ]]; then
        echo -e "${RED}❌ Invalid swap threshold. Using default: 80%${NC}"
        swap_threshold=80
    fi

    # Configure schedule time
    echo -e "${CYAN}🕐 Daily Cleanup Schedule (HH:MM format):${NC}"
    read -rp "Enter schedule time [current: $current_schedule]: " schedule_input
    local schedule_time="${schedule_input:-$current_schedule}"

    # Validate schedule time
    if ! [[ "$schedule_time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
        echo -e "${RED}❌ Invalid time format. Using default: 05:00${NC}"
        schedule_time="05:00"
    fi

    # Auto start with containers
    echo -e "${CYAN}🚀 Auto Start Daemon with Nexus Containers?${NC}"
    read -rp "Enable auto start? [y/N]: " auto_start_input
    local auto_start=false
    [[ "${auto_start_input,,}" == "y" ]] && auto_start=true

    # Create configuration
    cat > "$config_file" << EOF
{
    "memory_threshold": $memory_threshold,
    "swap_threshold": $swap_threshold,
    "schedule_time": "$schedule_time",
    "enabled": $auto_start,
    "conservative_mode": true,
    "min_free_memory_gb": 3,
    "backup_before_cleanup": true,
    "log_all_activities": true,
    "container_lifecycle_mode": true
}
EOF

    echo ""
    echo -e "${GREEN}✅ Configuration saved successfully!${NC}"
    echo ""
    echo -e "${CYAN}📋 New Configuration:${NC}"
    echo -e "Memory Threshold: ${YELLOW}${memory_threshold}%${NC}"
    echo -e "Swap Threshold: ${YELLOW}${swap_threshold}%${NC}"
    echo -e "Schedule Time: ${YELLOW}${schedule_time}${NC}"
    echo -e "Auto Start: ${YELLOW}${auto_start}${NC}"
    echo -e "Conservative Mode: ${YELLOW}Enabled${NC}"
    echo -e "Minimum Free Memory: ${YELLOW}3GB${NC}"

    read -rp "Press Enter to continue..."
}

start_auto_cache_daemon() {
    show_section_header "Starting Auto Cache Daemon" "🚀"

    # Check if already running
    local daemon_pid
    daemon_pid=$(pgrep -f "nexus_auto_cache_daemon" || echo "")

    if [[ -n "$daemon_pid" ]]; then
        echo -e "${YELLOW}⚠️  Auto cache daemon is already running (PID: $daemon_pid)${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    # Check configuration
    local config_file="/tmp/nexus-orchestrator/workdir/config/auto_cache_config.json"
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}❌ No configuration found. Please configure first.${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${CYAN}🚀 Starting Auto Cache Daemon...${NC}"
    echo ""

    # Create daemon script
    create_auto_cache_daemon

    # Start daemon in background
    nohup bash /tmp/nexus-orchestrator/nexus_auto_cache_daemon.sh > /tmp/nexus-orchestrator/workdir/logs/auto_cache_daemon.log 2>&1 &
    local daemon_new_pid=$!

    # Wait a moment and check if it started
    sleep 2
    if kill -0 "$daemon_new_pid" 2>/dev/null; then
        echo -e "${GREEN}✅ Auto cache daemon started successfully (PID: $daemon_new_pid)${NC}"
        echo -e "${CYAN}📝 Logs: /tmp/nexus-orchestrator/workdir/logs/auto_cache_daemon.log${NC}"
    else
        echo -e "${RED}❌ Failed to start auto cache daemon${NC}"
    fi

    read -rp "Press Enter to continue..."
}

stop_auto_cache_daemon() {
    show_section_header "Stopping Auto Cache Daemon" "🛑"

    local daemon_pid
    daemon_pid=$(pgrep -f "nexus_auto_cache_daemon" || echo "")

    if [[ -z "$daemon_pid" ]]; then
        echo -e "${YELLOW}⚠️  Auto cache daemon is not running${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${CYAN}🛑 Stopping Auto Cache Daemon (PID: $daemon_pid)...${NC}"
    echo ""

    # Send TERM signal
    if kill "$daemon_pid" 2>/dev/null; then
        echo -e "${GREEN}✅ Auto cache daemon stopped successfully${NC}"
    else
        echo -e "${RED}❌ Failed to stop daemon. Trying force kill...${NC}"
        kill -9 "$daemon_pid" 2>/dev/null && echo -e "${GREEN}✅ Daemon force killed${NC}" || echo -e "${RED}❌ Failed to kill daemon${NC}"
    fi

    read -rp "Press Enter to continue..."
}

view_cache_daemon_logs() {
    show_section_header "Auto Cache Daemon Logs" "📝"

    local log_file="/tmp/nexus-orchestrator/workdir/logs/auto_cache_daemon.log"

    if [[ ! -f "$log_file" ]]; then
        echo -e "${YELLOW}⚠️  No daemon log file found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${CYAN}📝 Recent Auto Cache Daemon Activity:${NC}"
    echo ""

    # Show last 50 lines with color coding
    tail -50 "$log_file" | while IFS= read -r line; do
        if [[ "$line" =~ ERROR|CRITICAL|Failed ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" =~ WARNING|Threshold ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" =~ SUCCESS|Cleaned|Completed ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ "$line" =~ INFO|Starting|Checking ]]; then
            echo -e "${CYAN}$line${NC}"
        else
            echo -e "${WHITE}$line${NC}"
        fi
    done

    echo ""
    echo -e "${CYAN}📁 Full log: $log_file${NC}"

    read -rp "Press Enter to continue..."
}

test_cache_conditions() {
    show_section_header "Test Cache Conditions" "🧪"

    echo -e "${CYAN}🧪 Testing Current System Conditions...${NC}"
    echo ""

    # Load configuration
    local config_file="/tmp/nexus-orchestrator/workdir/config/auto_cache_config.json"
    local memory_threshold=90
    local swap_threshold=80

    if [[ -f "$config_file" ]]; then
        memory_threshold=$(jq -r '.memory_threshold // 90' "$config_file" 2>/dev/null || echo "90")
        swap_threshold=$(jq -r '.swap_threshold // 80' "$config_file" 2>/dev/null || echo "80")
    fi

    # Get current usage
    local current_memory
    current_memory=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    local current_swap
    current_swap=$(free | awk 'NR==3{if($2>0) printf "%.0f", $3*100/$2; else print "0"}')

    # Check containers
    local container_count
    container_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    echo -e "${CYAN}📊 Current Conditions:${NC}"
    echo -e "Memory Usage: ${YELLOW}${current_memory}%${NC} (threshold: ${memory_threshold}%)"
    echo -e "Swap Usage: ${YELLOW}${current_swap}%${NC} (threshold: ${swap_threshold}%)"
    echo -e "Active Containers: ${YELLOW}${container_count}${NC}"
    echo ""

    # Test conditions
    local memory_trigger=false
    local swap_trigger=false
    local container_trigger=false

    [[ $current_memory -ge $memory_threshold ]] && memory_trigger=true
    [[ $current_swap -ge $swap_threshold ]] && swap_trigger=true
    [[ $container_count -gt 0 ]] && container_trigger=true

    echo -e "${CYAN}🔍 Trigger Analysis:${NC}"

    if [[ "$memory_trigger" == "true" ]]; then
        echo -e "${RED}❌ Memory threshold exceeded (${current_memory}% >= ${memory_threshold}%)${NC}"
    else
        echo -e "${GREEN}✅ Memory threshold OK (${current_memory}% < ${memory_threshold}%)${NC}"
    fi

    if [[ "$swap_trigger" == "true" ]]; then
        echo -e "${RED}❌ Swap threshold exceeded (${current_swap}% >= ${swap_threshold}%)${NC}"
    else
        echo -e "${GREEN}✅ Swap threshold OK (${current_swap}% < ${swap_threshold}%)${NC}"
    fi

    if [[ "$container_trigger" == "true" ]]; then
        echo -e "${GREEN}✅ Nexus containers are running (${container_count} active)${NC}"
    else
        echo -e "${YELLOW}⚠️  No Nexus containers running${NC}"
    fi

    echo ""
    echo -e "${CYAN}🎯 Cleanup Decision:${NC}"

    if [[ "$memory_trigger" == "true" && "$swap_trigger" == "true" && "$container_trigger" == "true" ]]; then
        echo -e "${RED}🚨 WOULD TRIGGER: Conservative cleanup would start${NC}"
        echo -e "${YELLOW}📋 Actions: System cache → Check memory → Nexus cache if needed${NC}"
    else
        echo -e "${GREEN}✅ NO ACTION: Conditions not met for cleanup${NC}"
        if [[ "$container_trigger" == "false" ]]; then
            echo -e "${CYAN}ℹ️  Note: Daemon only runs when Nexus containers are active${NC}"
        fi
    fi

    read -rp "Press Enter to continue..."
}

manual_cache_cleanup() {
    show_section_header "Manual Cache Cleanup" "🧹"

    echo -e "${CYAN}🧹 Manual Conservative Cache Cleanup${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  This will perform the same cleanup as the auto daemon${NC}"
    echo ""

    # Check if we should proceed
    read -rp "Continue with manual cleanup? [y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && return 0

    echo ""
    echo -e "${CYAN}🚀 Starting manual cleanup...${NC}"

    # Source cache cleanup functions from port_manager.sh
    if [[ -f "/tmp/nexus-orchestrator/lib/port_manager.sh" ]]; then
        # Run conservative cleanup
        echo -e "${CYAN}🧽 Step 1: System cache cleanup...${NC}"
        bash -c "source /tmp/nexus-orchestrator/lib/port_manager.sh && cleanup_system_cache"

        # Check memory after system cleanup
        local mem_after_system
        mem_after_system=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')

        echo -e "${CYAN}📊 Memory after system cleanup: ${YELLOW}${mem_after_system}%${NC}"

        # Only clean nexus cache if still critical
        if [[ $mem_after_system -ge 85 ]]; then
            echo -e "${CYAN}🧽 Step 2: Nexus cache cleanup (memory still high)...${NC}"
            bash -c "source /tmp/nexus-orchestrator/lib/port_manager.sh && cleanup_nexus_cache"
        else
            echo -e "${GREEN}✅ System cleanup sufficient, skipping Nexus cache cleanup${NC}"
        fi

        echo ""
        echo -e "${GREEN}✅ Manual cleanup completed${NC}"
    else
        echo -e "${RED}❌ Cache cleanup functions not found${NC}"
    fi

    read -rp "Press Enter to continue..."
}

create_auto_cache_daemon() {
    local daemon_script="/tmp/nexus-orchestrator/nexus_auto_cache_daemon.sh"
    local config_file="/tmp/nexus-orchestrator/workdir/config/auto_cache_config.json"
    local log_dir="/tmp/nexus-orchestrator/workdir/logs"

    # Ensure log directory exists
    mkdir -p "$log_dir"

    cat > "$daemon_script" << 'EOF'
#!/bin/bash

# nexus_auto_cache_daemon.sh - Conservative Auto Cache Cleanup Daemon
# Monitors memory/swap usage and container status for automatic cache cleanup

SCRIPT_DIR="/tmp/nexus-orchestrator"
CONFIG_FILE="$SCRIPT_DIR/workdir/config/auto_cache_config.json"
LOG_FILE="$SCRIPT_DIR/workdir/logs/auto_cache_daemon.log"
PID_FILE="$SCRIPT_DIR/workdir/auto_cache_daemon.pid"

# Store daemon PID
echo $$ > "$PID_FILE"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

cleanup_on_exit() {
    log_message "INFO" "Auto cache daemon shutting down..."
    rm -f "$PID_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup_on_exit SIGTERM SIGINT

log_message "INFO" "Auto cache daemon starting..."

# Main daemon loop
while true; do
    # Check if Nexus containers are running (container lifecycle mode)
    container_count=$(docker ps --filter "name=nexus-node" --format "{{.Names}}" | wc -l)

    if [[ $container_count -eq 0 ]]; then
        log_message "INFO" "No Nexus containers running, sleeping..."
        sleep 300  # Sleep 5 minutes when no containers
        continue
    fi

    # Load configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_message "ERROR" "Configuration file not found: $CONFIG_FILE"
        sleep 300
        continue
    fi

    memory_threshold=$(jq -r '.memory_threshold // 90' "$CONFIG_FILE" 2>/dev/null || echo "90")
    swap_threshold=$(jq -r '.swap_threshold // 80' "$CONFIG_FILE" 2>/dev/null || echo "80")
    schedule_time=$(jq -r '.schedule_time // "05:00"' "$CONFIG_FILE" 2>/dev/null || echo "05:00")

    # Get current usage
    current_memory=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    current_swap=$(free | awk 'NR==3{if($2>0) printf "%.0f", $3*100/$2; else print "0"}')
    current_time=$(date '+%H:%M')

    # Check if scheduled time
    schedule_trigger=false
    if [[ "$current_time" == "$schedule_time" ]]; then
        schedule_trigger=true
        log_message "INFO" "Scheduled cleanup time reached: $schedule_time"
    fi

    # Check memory/swap thresholds
    memory_trigger=false
    swap_trigger=false

    if [[ $current_memory -ge $memory_threshold ]]; then
        memory_trigger=true
        log_message "WARNING" "Memory threshold exceeded: ${current_memory}% >= ${memory_threshold}%"
    fi

    if [[ $current_swap -ge $swap_threshold ]]; then
        swap_trigger=true
        log_message "WARNING" "Swap threshold exceeded: ${current_swap}% >= ${swap_threshold}%"
    fi

    # Trigger cleanup if conditions are met
    if [[ "$memory_trigger" == "true" && "$swap_trigger" == "true" ]] || [[ "$schedule_trigger" == "true" ]]; then
        log_message "INFO" "Starting conservative cleanup - Memory: ${current_memory}%, Swap: ${current_swap}%"

        # Check minimum free memory requirement
        free_memory_gb=$(free -g | awk 'NR==2{print $7}')
        if [[ $free_memory_gb -lt 3 ]]; then
            log_message "CRITICAL" "Free memory below 3GB: ${free_memory_gb}GB - Starting emergency cleanup"
        fi

        # Backup configuration before cleanup
        backup_dir="$SCRIPT_DIR/workdir/backup/auto_cleanup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r "$SCRIPT_DIR/workdir/config" "$backup_dir/" 2>/dev/null
        log_message "INFO" "Configuration backed up to: $backup_dir"

        # Step 1: System cache cleanup (conservative approach)
        log_message "INFO" "Step 1: System cache cleanup..."
        if source "$SCRIPT_DIR/lib/port_manager.sh" && cleanup_system_cache >> "$LOG_FILE" 2>&1; then
            log_message "SUCCESS" "System cache cleanup completed"
        else
            log_message "ERROR" "System cache cleanup failed"
        fi

        # Check memory after system cleanup
        mem_after_system=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        log_message "INFO" "Memory after system cleanup: ${mem_after_system}%"

        # Step 2: Nexus cache cleanup only if still critical
        if [[ $mem_after_system -ge 85 ]] || [[ $free_memory_gb -lt 3 ]]; then
            log_message "INFO" "Step 2: Nexus cache cleanup (memory still critical)..."
            if source "$SCRIPT_DIR/lib/port_manager.sh" && cleanup_nexus_cache >> "$LOG_FILE" 2>&1; then
                log_message "SUCCESS" "Nexus cache cleanup completed"
            else
                log_message "ERROR" "Nexus cache cleanup failed"
            fi
        else
            log_message "INFO" "Step 2: Skipping Nexus cache cleanup (memory acceptable)"
        fi

        # Final memory check
        final_memory=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        final_swap=$(free | awk 'NR==3{if($2>0) printf "%.0f", $3*100/$2; else print "0"}')
        log_message "INFO" "Cleanup completed - Final Memory: ${final_memory}%, Swap: ${final_swap}%"

        # Sleep longer after cleanup
        sleep 1800  # Sleep 30 minutes after cleanup
    else
        # Normal monitoring interval
        sleep 180  # Check every 3 minutes
    fi
done
EOF

    chmod +x "$daemon_script"
    log_message "INFO" "Auto cache daemon script created: $daemon_script"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f monitoring_menu real_time_monitor container_metrics network_statistics
export -f resource_history proof_statistics health_dashboard export_report
export -f configure_alerts configure_cpu_alert configure_memory_alert
export -f configure_disk_alert configure_container_alert
export -f auto_cache_management_menu show_auto_cache_status configure_auto_cache
export -f start_auto_cache_daemon stop_auto_cache_daemon view_cache_daemon_logs
export -f test_cache_conditions manual_cache_cleanup create_auto_cache_daemon

log_success "Monitoring & statistics menu loaded successfully"
