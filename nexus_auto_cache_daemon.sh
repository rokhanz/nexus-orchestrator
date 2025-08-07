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
