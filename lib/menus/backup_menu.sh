#!/bin/bash

# backup_menu.sh - Backup & Restore Menu Module
# Version: 4.0.0 - Modular menu system for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# BACKUP MENU FUNCTIONS
# =============================================================================

backup_menu() {
    while true; do
        clear
        show_section_header "Backup & Restore" "💾"

        echo -e "${CYAN}Select backup/restore option:${NC}"
        echo ""
        echo "1. Create Full Backup"
        echo "2. Create Configuration Backup"
        echo "3. Create Logs Backup"
        echo "4. Restore from Backup"
        echo "5. List Available Backups"
        echo "6. Delete Old Backups"
        echo "7. Automated Backup Settings"
        echo "8. Export Backup to External Storage"
        echo "0. Return to Main Menu"
        echo ""

        read -rp "Choose option [0-8]: " choice

        case "$choice" in
            1)
                create_full_backup
                ;;
            2)
                create_config_backup
                ;;
            3)
                create_logs_backup
                ;;
            4)
                restore_from_backup
                ;;
            5)
                list_backups
                ;;
            6)
                cleanup_old_backups
                ;;
            7)
                configure_automated_backup
                ;;
            8)
                export_backup
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
# BACKUP CREATION FUNCTIONS
# =============================================================================

create_full_backup() {
    show_section_header "Create Full Backup" "💾"

    echo -e "${CYAN}Creating comprehensive backup of Nexus Orchestrator...${NC}"
    echo ""

    # Prepare backup
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="nexus_full_backup_$timestamp"
    local backup_dir="$DEFAULT_WORKDIR/backup/$backup_name"

    ensure_directory "$backup_dir"

    init_multi_step 6

    next_step "Backing up configuration files"
    if backup_configuration "$backup_dir"; then
        log_success "Configuration backup completed"
    else
        log_error "Configuration backup failed"
        return 1
    fi

    next_step "Backing up credentials and keys"
    if backup_credentials "$backup_dir"; then
        log_success "Credentials backup completed"
    else
        log_error "Credentials backup failed"
        return 1
    fi

    next_step "Backing up Docker configurations"
    if backup_docker_config "$backup_dir"; then
        log_success "Docker configuration backup completed"
    else
        log_error "Docker configuration backup failed"
        return 1
    fi

    next_step "Backing up logs"
    if backup_logs "$backup_dir"; then
        log_success "Logs backup completed"
    else
        log_warning "Logs backup had issues but continuing"
    fi

    next_step "Creating backup manifest"
    if create_backup_manifest "$backup_dir" "full"; then
        log_success "Backup manifest created"
    else
        log_error "Failed to create backup manifest"
        return 1
    fi

    next_step "Compressing backup archive"
    if compress_backup "$backup_dir" "$backup_name"; then
        log_success "Backup compression completed"
    else
        log_error "Backup compression failed"
        return 1
    fi

    complete_multi_step

    echo ""
    echo -e "${GREEN}✅ Full backup created successfully${NC}"
    echo -e "${CYAN}Backup location: $DEFAULT_WORKDIR/backup/${backup_name}.tar.gz${NC}"

    # Show backup size
    local backup_size
    backup_size=$(du -h "$DEFAULT_WORKDIR/backup/${backup_name}.tar.gz" 2>/dev/null | cut -f1)
    echo -e "${CYAN}Backup size: $backup_size${NC}"

    echo ""
    read -rp "Press Enter to continue..."
}

create_config_backup() {
    show_section_header "Create Configuration Backup" "⚙️"

    echo -e "${CYAN}Creating configuration backup...${NC}"
    echo ""

    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="nexus_config_backup_$timestamp"
    local backup_dir="$DEFAULT_WORKDIR/backup/$backup_name"

    ensure_directory "$backup_dir"

    init_multi_step 3

    next_step "Backing up configuration files"
    if backup_configuration "$backup_dir"; then
        log_success "Configuration files backed up"
    else
        log_error "Configuration backup failed"
        return 1
    fi

    next_step "Creating backup manifest"
    if create_backup_manifest "$backup_dir" "config"; then
        log_success "Backup manifest created"
    else
        log_error "Failed to create backup manifest"
        return 1
    fi

    next_step "Compressing backup"
    if compress_backup "$backup_dir" "$backup_name"; then
        log_success "Configuration backup compressed"
    else
        log_error "Backup compression failed"
        return 1
    fi

    complete_multi_step

    echo ""
    echo -e "${GREEN}✅ Configuration backup created successfully${NC}"
    echo -e "${CYAN}Backup location: $DEFAULT_WORKDIR/backup/${backup_name}.tar.gz${NC}"

    echo ""
    read -rp "Press Enter to continue..."
}

create_logs_backup() {
    show_section_header "Create Logs Backup" "📝"

    echo -e "${CYAN}Creating logs backup...${NC}"
    echo ""

    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="nexus_logs_backup_$timestamp"
    local backup_dir="$DEFAULT_WORKDIR/backup/$backup_name"

    ensure_directory "$backup_dir"

    init_multi_step 3

    next_step "Backing up log files"
    if backup_logs "$backup_dir"; then
        log_success "Log files backed up"
    else
        log_error "Logs backup failed"
        return 1
    fi

    next_step "Creating backup manifest"
    if create_backup_manifest "$backup_dir" "logs"; then
        log_success "Backup manifest created"
    else
        log_error "Failed to create backup manifest"
        return 1
    fi

    next_step "Compressing backup"
    if compress_backup "$backup_dir" "$backup_name"; then
        log_success "Logs backup compressed"
    else
        log_error "Backup compression failed"
        return 1
    fi

    complete_multi_step

    echo ""
    echo -e "${GREEN}✅ Logs backup created successfully${NC}"
    echo -e "${CYAN}Backup location: $DEFAULT_WORKDIR/backup/${backup_name}.tar.gz${NC}"

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# BACKUP HELPER FUNCTIONS
# =============================================================================

backup_configuration() {
    local backup_dir="$1"
    local config_backup_dir="$backup_dir/config"

    ensure_directory "$config_backup_dir"

    # Copy configuration files
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        cp "$CREDENTIALS_FILE" "$config_backup_dir/" || return 1
    fi

    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        cp "$DOCKER_COMPOSE_FILE" "$config_backup_dir/" || return 1
    fi

    if [[ -f "$PROVER_ID_FILE" ]]; then
        cp "$PROVER_ID_FILE" "$config_backup_dir/" || return 1
    fi

    # Copy entire config directory if it exists
    if [[ -d "$DEFAULT_CONFIG_DIR" ]]; then
        cp -r "$DEFAULT_CONFIG_DIR"/* "$config_backup_dir/" 2>/dev/null || true
    fi

    return 0
}

backup_credentials() {
    local backup_dir="$1"
    local creds_backup_dir="$backup_dir/credentials"

    ensure_directory "$creds_backup_dir"

    # Backup credentials file with proper permissions
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        cp "$CREDENTIALS_FILE" "$creds_backup_dir/credentials.json" || return 1
        chmod 600 "$creds_backup_dir/credentials.json"
    fi

    # Backup any key files
    if [[ -f "$PROVER_ID_FILE" ]]; then
        cp "$PROVER_ID_FILE" "$creds_backup_dir/" || return 1
        chmod 600 "$creds_backup_dir/$(basename "$PROVER_ID_FILE")"
    fi

    return 0
}

backup_docker_config() {
    local backup_dir="$1"
    local docker_backup_dir="$backup_dir/docker"

    ensure_directory "$docker_backup_dir"

    # Backup Docker Compose file
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        cp "$DOCKER_COMPOSE_FILE" "$docker_backup_dir/" || return 1
    fi

    # Backup Docker environment files
    if [[ -f "$DEFAULT_WORKDIR/proxy.env" ]]; then
        cp "$DEFAULT_WORKDIR/proxy.env" "$docker_backup_dir/" || return 1
    fi

    # Export Docker image list
    if command -v docker >/dev/null 2>&1; then
        docker images --format "{{.Repository}}:{{.Tag}}" > "$docker_backup_dir/docker_images.txt" 2>/dev/null || true
    fi

    return 0
}

backup_logs() {
    local backup_dir="$1"
    local logs_backup_dir="$backup_dir/logs"

    ensure_directory "$logs_backup_dir"

    # Backup main log file
    if [[ -f "$NEXUS_MANAGER_LOG" ]]; then
        cp "$NEXUS_MANAGER_LOG" "$logs_backup_dir/" || return 1
    fi

    # Backup log directory
    if [[ -d "$DEFAULT_LOG_DIR" ]]; then
        cp -r "$DEFAULT_LOG_DIR"/* "$logs_backup_dir/" 2>/dev/null || true
    fi

    # Export container logs if available
    if command -v docker >/dev/null 2>&1; then
        local containers
        containers=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)

        if [[ -n "$containers" ]]; then
            local container_logs_dir="$logs_backup_dir/containers"
            ensure_directory "$container_logs_dir"

            while IFS= read -r container; do
                if [[ -n "$container" ]]; then
                    docker logs "$container" > "$container_logs_dir/${container}.log" 2>&1 || true
                fi
            done <<< "$containers"
        fi
    fi

    return 0
}

create_backup_manifest() {
    local backup_dir="$1"
    local backup_type="$2"

    local manifest_file="$backup_dir/backup_manifest.json"

    # Create backup manifest
    cat > "$manifest_file" << EOF
{
  "backup_type": "$backup_type",
  "timestamp": "$(date -Iseconds)",
  "orchestrator_version": "4.0.0",
  "system_info": {
    "hostname": "$(hostname)",
    "os": "$(uname -s)",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)"
  },
  "files": [
EOF

    # Add file list
    {
        find "$backup_dir" -type f ! -name "backup_manifest.json" -printf '    "%P",\n' 2>/dev/null | sed '$s/,$//'
        echo '  ]'
        echo '}'
    } >> "$manifest_file"

    return 0
}

compress_backup() {
    local backup_dir="$1"
    local backup_name="$2"

    local backup_parent
    backup_parent=$(dirname "$backup_dir")

    # Compress the backup directory
    if tar -czf "$backup_parent/${backup_name}.tar.gz" -C "$backup_parent" "$(basename "$backup_dir")" 2>/dev/null; then
        # Remove uncompressed directory
        rm -rf "$backup_dir"
        return 0
    else
        return 1
    fi
}

# =============================================================================
# RESTORE FUNCTIONS
# =============================================================================

restore_from_backup() {
    show_section_header "Restore from Backup" "🔄"

    echo -e "${CYAN}Available backups:${NC}"
    echo ""

    # List available backups
    local backup_files
    backup_files=$(find "$DEFAULT_WORKDIR/backup" -name "*.tar.gz" -type f 2>/dev/null | sort -r)

    if [[ -z "$backup_files" ]]; then
        echo -e "${YELLOW}⚠️  No backup files found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    # Show numbered list of backups
    local backup_array=()
    local index=1

    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" ]]; then
            local backup_name
            backup_name=$(basename "$backup_file" .tar.gz)
            local backup_size
            backup_size=$(du -h "$backup_file" | cut -f1)
            local backup_date
            backup_date=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1)

            printf "%d. %s (%s, %s)\n" "$index" "$backup_name" "$backup_size" "$backup_date"
            backup_array+=("$backup_file")
            index=$((index + 1))
        fi
    done <<< "$backup_files"

    echo ""
    read -rp "Select backup to restore [1-$((index-1))] or 0 to cancel: " choice

    if [[ "$choice" == "0" ]]; then
        return 0
    fi

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backup_array[@]} ]]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    local selected_backup="${backup_array[$((choice-1))]}"
    local backup_name
    backup_name=$(basename "$selected_backup" .tar.gz)

    echo ""
    echo -e "${YELLOW}⚠️  This will restore: $backup_name${NC}"
    echo -e "${YELLOW}⚠️  Current configuration will be backed up first${NC}"
    read -rp "Are you sure? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    fi

    # Perform restore
    perform_restore "$selected_backup"
}

perform_restore() {
    local backup_file="$1"
    local backup_name
    backup_name=$(basename "$backup_file" .tar.gz)

    echo ""
    echo -e "${CYAN}Restoring from backup: $backup_name${NC}"
    echo ""

    init_multi_step 5

    next_step "Creating safety backup of current configuration"
    if create_safety_backup; then
        log_success "Safety backup created"
    else
        log_warning "Could not create safety backup"
    fi

    next_step "Extracting backup archive"
    local restore_dir="$DEFAULT_WORKDIR/restore_temp"
    ensure_directory "$restore_dir"

    if tar -xzf "$backup_file" -C "$restore_dir" 2>/dev/null; then
        log_success "Backup extracted successfully"
    else
        log_error "Failed to extract backup"
        return 1
    fi

    next_step "Validating backup integrity"
    local extracted_dir="$restore_dir/$backup_name"
    if [[ ! -f "$extracted_dir/backup_manifest.json" ]]; then
        log_error "Invalid backup: missing manifest"
        rm -rf "$restore_dir"
        return 1
    fi

    next_step "Restoring configuration files"
    if restore_configuration "$extracted_dir"; then
        log_success "Configuration restored"
    else
        log_error "Configuration restore failed"
        rm -rf "$restore_dir"
        return 1
    fi

    next_step "Cleaning up temporary files"
    rm -rf "$restore_dir"
    log_success "Cleanup completed"

    complete_multi_step

    echo ""
    echo -e "${GREEN}✅ Restore completed successfully${NC}"
    echo -e "${YELLOW}💡 Please restart Nexus Orchestrator to apply changes${NC}"
    echo ""
    read -rp "Press Enter to continue..."
}

create_safety_backup() {
    local safety_backup_name
    safety_backup_name="safety_backup_$(date '+%Y%m%d_%H%M%S')"
    local safety_backup_dir="$DEFAULT_WORKDIR/backup/$safety_backup_name"

    ensure_directory "$safety_backup_dir"

    # Quick backup of current state
    backup_configuration "$safety_backup_dir" && \
    backup_credentials "$safety_backup_dir" && \
    create_backup_manifest "$safety_backup_dir" "safety" && \
    compress_backup "$safety_backup_dir" "$safety_backup_name"
}

restore_configuration() {
    local extracted_dir="$1"

    # Restore configuration files
    if [[ -d "$extracted_dir/config" ]]; then
        if [[ -f "$extracted_dir/config/credentials.json" ]]; then
            cp "$extracted_dir/config/credentials.json" "$CREDENTIALS_FILE" || return 1
        fi

        if [[ -f "$extracted_dir/config/docker-compose.yml" ]]; then
            cp "$extracted_dir/config/docker-compose.yml" "$DOCKER_COMPOSE_FILE" || return 1
        fi

        if [[ -f "$extracted_dir/config/prover-id" ]]; then
            cp "$extracted_dir/config/prover-id" "$PROVER_ID_FILE" || return 1
        fi
    fi

    # Restore credentials with proper permissions
    if [[ -d "$extracted_dir/credentials" ]]; then
        if [[ -f "$extracted_dir/credentials/credentials.json" ]]; then
            cp "$extracted_dir/credentials/credentials.json" "$CREDENTIALS_FILE" || return 1
            chmod 600 "$CREDENTIALS_FILE"
        fi
    fi

    return 0
}

# =============================================================================
# BACKUP MANAGEMENT FUNCTIONS
# =============================================================================

list_backups() {
    show_section_header "Available Backups" "📋"

    local backup_files
    backup_files=$(find "$DEFAULT_WORKDIR/backup" -name "*.tar.gz" -type f 2>/dev/null | sort -r)

    if [[ -z "$backup_files" ]]; then
        echo -e "${YELLOW}⚠️  No backup files found${NC}"
        echo ""
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${CYAN}Found backup files:${NC}"
    echo ""

    printf "%-40s %-10s %-12s %s\n" "Backup Name" "Size" "Date" "Type"
    echo "──────────────────────────────────────────────────────────────────────────────"

    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" ]]; then
            local backup_name
            backup_name=$(basename "$backup_file" .tar.gz)

            local backup_size
            backup_size=$(du -h "$backup_file" | cut -f1)

            local backup_date
            backup_date=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1)

            # Determine backup type from name
            local backup_type="unknown"
            if [[ "$backup_name" =~ _full_ ]]; then
                backup_type="full"
            elif [[ "$backup_name" =~ _config_ ]]; then
                backup_type="config"
            elif [[ "$backup_name" =~ _logs_ ]]; then
                backup_type="logs"
            elif [[ "$backup_name" =~ _safety_ ]]; then
                backup_type="safety"
            fi

            printf "%-40s %-10s %-12s %s\n" "$backup_name" "$backup_size" "$backup_date" "$backup_type"
        fi
    done <<< "$backup_files"

    echo ""

    # Show total backup space usage
    local total_size
    total_size=$(du -sh "$DEFAULT_WORKDIR/backup" 2>/dev/null | cut -f1)
    echo "Total backup space used: $total_size"

    echo ""
    read -rp "Press Enter to continue..."
}

cleanup_old_backups() {
    show_section_header "Cleanup Old Backups" "🗑️"

    echo -e "${CYAN}Backup cleanup options:${NC}"
    echo ""
    echo "1. Delete backups older than 30 days"
    echo "2. Delete backups older than 7 days"
    echo "3. Keep only last 5 backups"
    echo "4. Delete all safety backups"
    echo "5. Custom cleanup"
    echo "0. Cancel"
    echo ""

    read -rp "Choose cleanup option [0-5]: " choice

    case "$choice" in
        1)
            cleanup_by_age 30
            ;;
        2)
            cleanup_by_age 7
            ;;
        3)
            cleanup_by_count 5
            ;;
        4)
            cleanup_safety_backups
            ;;
        5)
            custom_cleanup
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

cleanup_by_age() {
    local days="$1"

    echo ""
    echo -e "${CYAN}Deleting backups older than $days days...${NC}"

    local old_backups
    old_backups=$(find "$DEFAULT_WORKDIR/backup" -name "*.tar.gz" -type f -mtime +"$days" 2>/dev/null)

    if [[ -z "$old_backups" ]]; then
        echo -e "${GREEN}✅ No old backups found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${YELLOW}Backups to be deleted:${NC}"
    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" ]]; then
            echo "  - $(basename "$backup_file")"
        fi
    done <<< "$old_backups"

    echo ""
    read -rp "Delete these backups? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        local deleted_count=0
        while IFS= read -r backup_file; do
            if [[ -n "$backup_file" ]]; then
                rm -f "$backup_file" && deleted_count=$((deleted_count + 1))
            fi
        done <<< "$old_backups"

        echo -e "${GREEN}✅ Deleted $deleted_count old backup(s)${NC}"
    fi

    read -rp "Press Enter to continue..."
}

cleanup_by_count() {
    local keep_count="$1"

    echo ""
    echo -e "${CYAN}Keeping only the last $keep_count backups...${NC}"

    local all_backups
    all_backups=$(find "$DEFAULT_WORKDIR/backup" -name "*.tar.gz" -type f 2>/dev/null | sort -r)

    local backup_count
    backup_count=$(echo "$all_backups" | wc -l)

    if [[ $backup_count -le $keep_count ]]; then
        echo -e "${GREEN}✅ Less than $keep_count backups found, nothing to delete${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    local old_backups
    old_backups=$(echo "$all_backups" | tail -n +$((keep_count + 1)))

    echo -e "${YELLOW}Backups to be deleted:${NC}"
    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" ]]; then
            echo "  - $(basename "$backup_file")"
        fi
    done <<< "$old_backups"

    echo ""
    read -rp "Delete these backups? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        local deleted_count=0
        while IFS= read -r backup_file; do
            if [[ -n "$backup_file" ]]; then
                rm -f "$backup_file" && deleted_count=$((deleted_count + 1))
            fi
        done <<< "$old_backups"

        echo -e "${GREEN}✅ Deleted $deleted_count old backup(s)${NC}"
    fi

    read -rp "Press Enter to continue..."
}

cleanup_safety_backups() {
    echo ""
    echo -e "${CYAN}Deleting all safety backups...${NC}"

    local safety_backups
    safety_backups=$(find "$DEFAULT_WORKDIR/backup" -name "*safety_backup*.tar.gz" -type f 2>/dev/null)

    if [[ -z "$safety_backups" ]]; then
        echo -e "${GREEN}✅ No safety backups found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${YELLOW}Safety backups to be deleted:${NC}"
    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" ]]; then
            echo "  - $(basename "$backup_file")"
        fi
    done <<< "$safety_backups"

    echo ""
    read -rp "Delete these safety backups? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        local deleted_count=0
        while IFS= read -r backup_file; do
            if [[ -n "$backup_file" ]]; then
                rm -f "$backup_file" && deleted_count=$((deleted_count + 1))
            fi
        done <<< "$safety_backups"

        echo -e "${GREEN}✅ Deleted $deleted_count safety backup(s)${NC}"
    fi

    read -rp "Press Enter to continue..."
}

custom_cleanup() {
    echo ""
    echo -e "${CYAN}Custom backup cleanup:${NC}"
    echo ""

    read -rp "Delete backups older than how many days? (1-365): " days

    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ $days -lt 1 ]] || [[ $days -gt 365 ]]; then
        echo -e "${RED}❌ Invalid number of days${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    cleanup_by_age "$days"
}

# =============================================================================
# AUTOMATED BACKUP CONFIGURATION
# =============================================================================

configure_automated_backup() {
    show_section_header "Automated Backup Settings" "⏰"

    echo -e "${CYAN}Configure automated backup settings:${NC}"
    echo ""
    echo "1. Enable daily automated backups"
    echo "2. Enable weekly automated backups"
    echo "3. Disable automated backups"
    echo "4. View current backup schedule"
    echo "0. Back to backup menu"
    echo ""

    read -rp "Choose option [0-4]: " choice

    case "$choice" in
        1)
            setup_daily_backup
            ;;
        2)
            setup_weekly_backup
            ;;
        3)
            disable_automated_backup
            ;;
        4)
            show_backup_schedule
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

setup_daily_backup() {
    echo ""
    echo -e "${CYAN}Setting up daily automated backups...${NC}"

    # Create backup script
    local backup_script="$DEFAULT_WORKDIR/scripts/automated_backup.sh"
    ensure_directory "$(dirname "$backup_script")"

    cat > "$backup_script" << 'EOF'
#!/bin/bash
# Automated backup script for Nexus Orchestrator

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/backup_wrapper.sh"

# Create daily backup
backup_wrapper create_config_backup

# Cleanup old backups (keep last 7 days)
cleanup_by_age 7
EOF

    chmod +x "$backup_script"

    # Add to crontab (daily at 2 AM)
    local cron_entry="0 2 * * * $backup_script"

    if crontab -l 2>/dev/null | grep -q "automated_backup.sh"; then
        echo -e "${YELLOW}⚠️  Automated backup already configured${NC}"
    else
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        echo -e "${GREEN}✅ Daily automated backup configured${NC}"
        echo -e "${CYAN}Backup will run daily at 2:00 AM${NC}"
    fi

    read -rp "Press Enter to continue..."
}

setup_weekly_backup() {
    echo ""
    echo -e "${CYAN}Setting up weekly automated backups...${NC}"

    # Similar to daily but with weekly cron schedule
    local cron_entry="0 2 * * 0 $DEFAULT_WORKDIR/scripts/automated_backup.sh"

    if crontab -l 2>/dev/null | grep -q "automated_backup.sh"; then
        echo -e "${YELLOW}⚠️  Automated backup already configured${NC}"
    else
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        echo -e "${GREEN}✅ Weekly automated backup configured${NC}"
        echo -e "${CYAN}Backup will run weekly on Sunday at 2:00 AM${NC}"
    fi

    read -rp "Press Enter to continue..."
}

disable_automated_backup() {
    echo ""
    echo -e "${CYAN}Disabling automated backups...${NC}"

    # Remove from crontab
    crontab -l 2>/dev/null | grep -v "automated_backup.sh" | crontab -

    echo -e "${GREEN}✅ Automated backup disabled${NC}"
    read -rp "Press Enter to continue..."
}

show_backup_schedule() {
    echo ""
    echo -e "${CYAN}Current backup schedule:${NC}"
    echo ""

    local cron_entries
    cron_entries=$(crontab -l 2>/dev/null | grep "automated_backup.sh" || echo "")

    if [[ -z "$cron_entries" ]]; then
        echo "No automated backups configured"
    else
        echo "$cron_entries"
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# EXPORT BACKUP
# =============================================================================

export_backup() {
    show_section_header "Export Backup to External Storage" "💽"

    echo -e "${CYAN}Export backup options:${NC}"
    echo ""
    echo "1. Export to USB drive"
    echo "2. Export to network location"
    echo "3. Export to cloud storage (SCP)"
    echo "0. Cancel"
    echo ""

    read -rp "Choose export option [0-3]: " choice

    case "$choice" in
        1)
            export_to_usb
            ;;
        2)
            export_to_network
            ;;
        3)
            export_to_cloud
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

export_to_usb() {
    echo ""
    echo -e "${CYAN}Exporting to USB drive...${NC}"
    echo ""

    # List available backups
    local backup_files
    backup_files=$(find "$DEFAULT_WORKDIR/backup" -name "*.tar.gz" -type f 2>/dev/null | sort -r)

    if [[ -z "$backup_files" ]]; then
        echo -e "${YELLOW}⚠️  No backup files found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    # Select backup
    echo "Available backups:"
    local backup_array=()
    local index=1

    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" ]]; then
            local backup_name
            backup_name=$(basename "$backup_file")
            echo "$index. $backup_name"
            backup_array+=("$backup_file")
            index=$((index + 1))
        fi
    done <<< "$backup_files"

    echo ""
    read -rp "Select backup [1-$((index-1))]: " backup_choice

    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || [[ $backup_choice -lt 1 ]] || [[ $backup_choice -gt ${#backup_array[@]} ]]; then
        echo -e "${RED}❌ Invalid selection${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    local selected_backup="${backup_array[$((backup_choice-1))]}"

    # Get USB mount point
    read -rp "Enter USB mount point (e.g., /media/usb): " usb_path

    if [[ ! -d "$usb_path" ]]; then
        echo -e "${RED}❌ USB path not found${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    # Copy backup
    echo ""
    echo -e "${CYAN}Copying backup to USB...${NC}"

    if cp "$selected_backup" "$usb_path/"; then
        echo -e "${GREEN}✅ Backup exported to USB successfully${NC}"
    else
        echo -e "${RED}❌ Failed to export backup${NC}"
    fi

    read -rp "Press Enter to continue..."
}

export_to_network() {
    echo ""
    echo -e "${CYAN}Export to network location not implemented yet${NC}"
    read -rp "Press Enter to continue..."
}

export_to_cloud() {
    echo ""
    echo -e "${CYAN}Export to cloud storage not implemented yet${NC}"
    read -rp "Press Enter to continue..."
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f backup_menu create_full_backup create_config_backup create_logs_backup
export -f backup_configuration backup_credentials backup_docker_config backup_logs
export -f create_backup_manifest compress_backup restore_from_backup perform_restore
export -f create_safety_backup restore_configuration list_backups cleanup_old_backups
export -f cleanup_by_age cleanup_by_count cleanup_safety_backups custom_cleanup
export -f configure_automated_backup setup_daily_backup setup_weekly_backup
export -f disable_automated_backup show_backup_schedule export_backup
export -f export_to_usb export_to_network export_to_cloud

log_success "Backup & restore menu loaded successfully"
