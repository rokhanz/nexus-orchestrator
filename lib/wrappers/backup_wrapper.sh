#!/bin/bash

# backup_wrapper.sh - Backup Operations Wrapper
# Version: 4.0.0 - Complex backup operations for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# BACKUP WRAPPER CONFIGURATION
# =============================================================================

readonly BACKUP_WRAPPER_MAX_RETRIES=3
readonly BACKUP_WRAPPER_RETRY_DELAY=5
readonly BACKUP_WRAPPER_COMPRESSION_LEVEL=6

# =============================================================================
# MAIN BACKUP WRAPPER FUNCTION
# =============================================================================

backup_wrapper() {
    local operation="$1"
    shift

    log_activity "Backup wrapper: $operation operation requested"

    # Pre-execution validation
    if ! validate_backup_requirements; then
        return 1
    fi

    # Execute operation with retry logic
    case "$operation" in
        "create_full_backup")
            create_full_backup_with_retry "$@"
            ;;
        "create_config_backup")
            create_config_backup_with_retry "$@"
            ;;
        "create_logs_backup")
            create_logs_backup_with_retry "$@"
            ;;
        "restore_backup")
            restore_backup_with_retry "$@"
            ;;
        "verify_backup")
            verify_backup_integrity "$@"
            ;;
        "compress_backup")
            compress_backup_with_retry "$@"
            ;;
        "cleanup_old_backups")
            cleanup_old_backups_with_retry "$@"
            ;;
        *)
            log_error "Unknown backup operation: $operation"
            return 1
            ;;
    esac

    local exit_code=$?

    # Post-execution validation
    if [[ $exit_code -eq 0 ]]; then
        log_success "Backup wrapper: $operation completed successfully"
    else
        handle_error "Backup wrapper: $operation failed with exit code $exit_code"
    fi

    return $exit_code
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_backup_requirements() {
    local validation_ok=true

    # Check required commands
    local required_commands=("tar" "gzip" "find" "du")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            validation_ok=false
        fi
    done

    # Check backup directory exists
    ensure_directory "$DEFAULT_WORKDIR/backup" || {
        log_error "Failed to create backup directory"
        validation_ok=false
    }

    # Check available disk space (minimum 1GB for backups)
    local available_space
    available_space=$(df "$DEFAULT_WORKDIR" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # 1GB in KB
        log_warning "Low disk space: $((available_space/1024))MB available"
        # Don't fail validation, but warn user
    fi

    [[ "$validation_ok" == true ]]
}

verify_backup_integrity() {
    local backup_file="$1"

    log_activity "Verifying backup integrity: $(basename "$backup_file")"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Check if it's a valid tar.gz file
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_error "Backup file is corrupted or not a valid tar.gz archive"
        return 1
    fi

    # Check for manifest file
    if ! tar -tzf "$backup_file" | grep -q "backup_manifest.json"; then
        log_warning "Backup manifest not found in archive"
        return 1
    fi

    log_success "Backup integrity verification passed"
    return 0
}

# =============================================================================
# FULL BACKUP OPERATIONS
# =============================================================================

create_full_backup_with_retry() {
    local custom_name="$1"
    local retries=0

    log_activity "Creating full backup with retry logic"

    while [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; do
        if create_full_backup_operation "$custom_name"; then
            log_success "Full backup creation completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Full backup failed (attempt $retries), retrying in $BACKUP_WRAPPER_RETRY_DELAY seconds..."
                sleep $BACKUP_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Full backup creation failed after $BACKUP_WRAPPER_MAX_RETRIES attempts"
    return 1
}

create_full_backup_operation() {
    local custom_name="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')

    local backup_name
    if [[ -n "$custom_name" ]]; then
        backup_name="${custom_name}_${timestamp}"
    else
        backup_name="nexus_full_backup_${timestamp}"
    fi

    local backup_dir="$DEFAULT_WORKDIR/backup/$backup_name"
    local backup_archive="$DEFAULT_WORKDIR/backup/${backup_name}.tar.gz"

    # Create backup directory
    ensure_directory "$backup_dir" || return 1

    # Backup configuration
    if ! backup_configuration_files "$backup_dir"; then
        log_error "Configuration backup failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Backup credentials
    if ! backup_credentials_files "$backup_dir"; then
        log_error "Credentials backup failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Backup Docker configurations
    if ! backup_docker_configurations "$backup_dir"; then
        log_error "Docker configuration backup failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Backup logs
    if ! backup_log_files "$backup_dir"; then
        log_warning "Log backup had issues but continuing"
    fi

    # Create manifest
    if ! create_backup_manifest_file "$backup_dir" "full"; then
        log_error "Failed to create backup manifest"
        rm -rf "$backup_dir"
        return 1
    fi

    # Compress backup
    if ! compress_directory_to_archive "$backup_dir" "$backup_archive"; then
        log_error "Backup compression failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Verify compressed backup
    if ! verify_backup_integrity "$backup_archive"; then
        log_error "Backup verification failed"
        rm -f "$backup_archive"
        return 1
    fi

    # Clean up uncompressed directory
    rm -rf "$backup_dir"

    log_success "Full backup created: $backup_archive"
    return 0
}

# =============================================================================
# CONFIGURATION BACKUP OPERATIONS
# =============================================================================

create_config_backup_with_retry() {
    local custom_name="$1"
    local retries=0

    log_activity "Creating configuration backup with retry logic"

    while [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; do
        if create_config_backup_operation "$custom_name"; then
            log_success "Configuration backup creation completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Configuration backup failed (attempt $retries), retrying in $BACKUP_WRAPPER_RETRY_DELAY seconds..."
                sleep $BACKUP_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Configuration backup creation failed after $BACKUP_WRAPPER_MAX_RETRIES attempts"
    return 1
}

create_config_backup_operation() {
    local custom_name="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')

    local backup_name
    if [[ -n "$custom_name" ]]; then
        backup_name="${custom_name}_${timestamp}"
    else
        backup_name="nexus_config_backup_${timestamp}"
    fi

    local backup_dir="$DEFAULT_WORKDIR/backup/$backup_name"
    local backup_archive="$DEFAULT_WORKDIR/backup/${backup_name}.tar.gz"

    # Create backup directory
    ensure_directory "$backup_dir" || return 1

    # Backup configuration files
    if ! backup_configuration_files "$backup_dir"; then
        log_error "Configuration backup failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Create manifest
    if ! create_backup_manifest_file "$backup_dir" "config"; then
        log_error "Failed to create backup manifest"
        rm -rf "$backup_dir"
        return 1
    fi

    # Compress backup
    if ! compress_directory_to_archive "$backup_dir" "$backup_archive"; then
        log_error "Backup compression failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Clean up uncompressed directory
    rm -rf "$backup_dir"

    log_success "Configuration backup created: $backup_archive"
    return 0
}

# =============================================================================
# LOGS BACKUP OPERATIONS
# =============================================================================

create_logs_backup_with_retry() {
    local custom_name="$1"
    local retries=0

    log_activity "Creating logs backup with retry logic"

    while [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; do
        if create_logs_backup_operation "$custom_name"; then
            log_success "Logs backup creation completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Logs backup failed (attempt $retries), retrying in $BACKUP_WRAPPER_RETRY_DELAY seconds..."
                sleep $BACKUP_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Logs backup creation failed after $BACKUP_WRAPPER_MAX_RETRIES attempts"
    return 1
}

create_logs_backup_operation() {
    local custom_name="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')

    local backup_name
    if [[ -n "$custom_name" ]]; then
        backup_name="${custom_name}_${timestamp}"
    else
        backup_name="nexus_logs_backup_${timestamp}"
    fi

    local backup_dir="$DEFAULT_WORKDIR/backup/$backup_name"
    local backup_archive="$DEFAULT_WORKDIR/backup/${backup_name}.tar.gz"

    # Create backup directory
    ensure_directory "$backup_dir" || return 1

    # Backup log files
    if ! backup_log_files "$backup_dir"; then
        log_error "Logs backup failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Create manifest
    if ! create_backup_manifest_file "$backup_dir" "logs"; then
        log_error "Failed to create backup manifest"
        rm -rf "$backup_dir"
        return 1
    fi

    # Compress backup
    if ! compress_directory_to_archive "$backup_dir" "$backup_archive"; then
        log_error "Backup compression failed"
        rm -rf "$backup_dir"
        return 1
    fi

    # Clean up uncompressed directory
    rm -rf "$backup_dir"

    log_success "Logs backup created: $backup_archive"
    return 0
}

# =============================================================================
# BACKUP HELPER FUNCTIONS
# =============================================================================

backup_configuration_files() {
    local backup_dir="$1"
    local config_backup_dir="$backup_dir/config"

    ensure_directory "$config_backup_dir" || return 1

    log_activity "Backing up configuration files"

    # Copy main configuration files
    local config_files=(
        "$CREDENTIALS_FILE"
        "$DOCKER_COMPOSE_FILE"
        "$PROVER_ID_FILE"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "$config_backup_dir/" 2>/dev/null || {
                log_error "Failed to backup $config_file"
                return 1
            }
        fi
    done

    # Copy configuration directory if it exists
    if [[ -d "$DEFAULT_CONFIG_DIR" ]]; then
        cp -r "$DEFAULT_CONFIG_DIR"/* "$config_backup_dir/" 2>/dev/null || true
    fi

    # Copy environment files
    if [[ -f "$DEFAULT_WORKDIR/proxy.env" ]]; then
        cp "$DEFAULT_WORKDIR/proxy.env" "$config_backup_dir/" 2>/dev/null || true
    fi

    log_success "Configuration files backed up"
    return 0
}

backup_credentials_files() {
    local backup_dir="$1"
    local creds_backup_dir="$backup_dir/credentials"

    ensure_directory "$creds_backup_dir" || return 1

    log_activity "Backing up credentials files"

    # Backup credentials with proper permissions
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        cp "$CREDENTIALS_FILE" "$creds_backup_dir/credentials.json" 2>/dev/null || {
            log_error "Failed to backup credentials file"
            return 1
        }
        chmod 600 "$creds_backup_dir/credentials.json"
    fi

    # Backup prover ID file
    if [[ -f "$PROVER_ID_FILE" ]]; then
        cp "$PROVER_ID_FILE" "$creds_backup_dir/" 2>/dev/null || {
            log_error "Failed to backup prover ID file"
            return 1
        }
        chmod 600 "$creds_backup_dir/$(basename "$PROVER_ID_FILE")"
    fi

    log_success "Credentials files backed up"
    return 0
}

backup_docker_configurations() {
    local backup_dir="$1"
    local docker_backup_dir="$backup_dir/docker"

    ensure_directory "$docker_backup_dir" || return 1

    log_activity "Backing up Docker configurations"

    # Backup Docker Compose file
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        cp "$DOCKER_COMPOSE_FILE" "$docker_backup_dir/" 2>/dev/null || {
            log_error "Failed to backup Docker Compose file"
            return 1
        }
    fi

    # Backup Docker environment files
    if [[ -f "$DEFAULT_WORKDIR/proxy.env" ]]; then
        cp "$DEFAULT_WORKDIR/proxy.env" "$docker_backup_dir/" 2>/dev/null || true
    fi

    # Export Docker image list
    if command -v docker >/dev/null 2>&1; then
        docker images --format "{{.Repository}}:{{.Tag}}" > "$docker_backup_dir/docker_images.txt" 2>/dev/null || true

        # Export container configurations
        local containers
        containers=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)
        if [[ -n "$containers" ]]; then
            local containers_dir="$docker_backup_dir/containers"
            ensure_directory "$containers_dir"

            while IFS= read -r container; do
                if [[ -n "$container" ]]; then
                    # Export container configuration
                    docker inspect "$container" > "$containers_dir/${container}_config.json" 2>/dev/null || true
                fi
            done <<< "$containers"
        fi
    fi

    log_success "Docker configurations backed up"
    return 0
}

backup_log_files() {
    local backup_dir="$1"
    local logs_backup_dir="$backup_dir/logs"

    ensure_directory "$logs_backup_dir" || return 1

    log_activity "Backing up log files"

    # Backup main log file
    if [[ -f "$NEXUS_MANAGER_LOG" ]]; then
        cp "$NEXUS_MANAGER_LOG" "$logs_backup_dir/" 2>/dev/null || {
            log_warning "Failed to backup main log file"
        }
    fi

    # Backup log directory
    if [[ -d "$DEFAULT_LOG_DIR" ]]; then
        cp -r "$DEFAULT_LOG_DIR"/* "$logs_backup_dir/" 2>/dev/null || true
    fi

    # Export container logs if Docker is available
    if command -v docker >/dev/null 2>&1; then
        local containers
        containers=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)

        if [[ -n "$containers" ]]; then
            local container_logs_dir="$logs_backup_dir/containers"
            ensure_directory "$container_logs_dir"

            while IFS= read -r container; do
                if [[ -n "$container" ]]; then
                    # Export container logs (last 1000 lines to avoid huge files)
                    docker logs --tail 1000 "$container" > "$container_logs_dir/${container}.log" 2>&1 || true
                fi
            done <<< "$containers"
        fi
    fi

    log_success "Log files backed up"
    return 0
}

create_backup_manifest_file() {
    local backup_dir="$1"
    local backup_type="$2"

    local manifest_file="$backup_dir/backup_manifest.json"

    log_activity "Creating backup manifest"

    # Create backup manifest with system information
    cat > "$manifest_file" << EOF
{
  "backup_type": "$backup_type",
  "timestamp": "$(date -Iseconds)",
  "orchestrator_version": "4.0.0",
  "system_info": {
    "hostname": "$(hostname)",
    "os": "$(uname -s)",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)",
    "user": "$(whoami)"
  },
  "backup_info": {
    "created_by": "backup_wrapper",
    "compression_level": $BACKUP_WRAPPER_COMPRESSION_LEVEL,
    "source_directory": "$DEFAULT_WORKDIR"
  },
  "files": [
EOF

    # Add file list (excluding the manifest itself)
    {
        find "$backup_dir" -type f ! -name "backup_manifest.json" -printf '    "%P",\n' 2>/dev/null | sed '$s/,$//'
        echo '  ]'
        echo '}'
    } >> "$manifest_file"

    log_success "Backup manifest created"
    return 0
}

compress_directory_to_archive() {
    local source_dir="$1"
    local target_archive="$2"

    log_activity "Compressing backup directory"

    local source_parent
    source_parent=$(dirname "$source_dir")
    local source_name
    source_name=$(basename "$source_dir")

    # Create compressed archive
    if tar -czf "$target_archive" -C "$source_parent" "$source_name" 2>/dev/null; then
        log_success "Backup compressed successfully"
        return 0
    else
        log_error "Backup compression failed"
        return 1
    fi
}

# =============================================================================
# RESTORE OPERATIONS
# =============================================================================

restore_backup_with_retry() {
    local backup_file="$1"
    local restore_path="$2"
    local retries=0

    log_activity "Restoring backup with retry logic"

    while [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; do
        if restore_backup_operation "$backup_file" "$restore_path"; then
            log_success "Backup restoration completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Backup restoration failed (attempt $retries), retrying in $BACKUP_WRAPPER_RETRY_DELAY seconds..."
                sleep $BACKUP_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Backup restoration failed after $BACKUP_WRAPPER_MAX_RETRIES attempts"
    return 1
}

restore_backup_operation() {
    local backup_file="$1"
    local restore_path="${2:-$DEFAULT_WORKDIR}"

    log_activity "Restoring backup: $(basename "$backup_file")"

    # Verify backup integrity first
    if ! verify_backup_integrity "$backup_file"; then
        log_error "Backup integrity check failed"
        return 1
    fi

    # Create temporary restore directory
    local temp_restore_dir
    temp_restore_dir=$(mktemp -d)

    # Extract backup
    if ! tar -xzf "$backup_file" -C "$temp_restore_dir" 2>/dev/null; then
        log_error "Failed to extract backup archive"
        rm -rf "$temp_restore_dir"
        return 1
    fi

    # Find the extracted directory
    local extracted_dir
    extracted_dir=$(find "$temp_restore_dir" -maxdepth 1 -type d ! -path "$temp_restore_dir" | head -n 1)

    if [[ ! -d "$extracted_dir" ]]; then
        log_error "Could not find extracted backup directory"
        rm -rf "$temp_restore_dir"
        return 1
    fi

    # Restore files based on backup type
    local manifest_file="$extracted_dir/backup_manifest.json"
    if [[ -f "$manifest_file" ]]; then
        local backup_type
        backup_type=$(jq -r '.backup_type // "unknown"' "$manifest_file" 2>/dev/null)

        case "$backup_type" in
            "full")
                restore_full_backup_files "$extracted_dir" "$restore_path"
                ;;
            "config")
                restore_config_backup_files "$extracted_dir" "$restore_path"
                ;;
            "logs")
                restore_logs_backup_files "$extracted_dir" "$restore_path"
                ;;
            *)
                log_warning "Unknown backup type: $backup_type, attempting generic restore"
                restore_generic_backup_files "$extracted_dir" "$restore_path"
                ;;
        esac
    else
        log_warning "No manifest found, attempting generic restore"
        restore_generic_backup_files "$extracted_dir" "$restore_path"
    fi

    local restore_result=$?

    # Clean up temporary directory
    rm -rf "$temp_restore_dir"

    if [[ $restore_result -eq 0 ]]; then
        log_success "Backup restored successfully"
        return 0
    else
        log_error "Backup restoration failed"
        return 1
    fi
}

restore_full_backup_files() {
    local extracted_dir="$1"
    local restore_path="$2"

    log_activity "Restoring full backup files"

    # Restore configuration files
    if [[ -d "$extracted_dir/config" ]]; then
        cp -r "$extracted_dir/config"/* "$restore_path/" 2>/dev/null || {
            log_error "Failed to restore configuration files"
            return 1
        }
    fi

    # Restore credentials with proper permissions
    if [[ -d "$extracted_dir/credentials" ]]; then
        cp -r "$extracted_dir/credentials"/* "$restore_path/" 2>/dev/null || {
            log_error "Failed to restore credentials files"
            return 1
        }

        # Fix permissions
        if [[ -f "$restore_path/credentials.json" ]]; then
            chmod 600 "$restore_path/credentials.json"
        fi
    fi

    # Restore logs
    if [[ -d "$extracted_dir/logs" ]]; then
        ensure_directory "$DEFAULT_LOG_DIR"
        cp -r "$extracted_dir/logs"/* "$DEFAULT_LOG_DIR/" 2>/dev/null || {
            log_warning "Failed to restore some log files"
        }
    fi

    log_success "Full backup files restored"
    return 0
}

restore_config_backup_files() {
    local extracted_dir="$1"
    local restore_path="$2"

    log_activity "Restoring configuration backup files"

    if [[ -d "$extracted_dir/config" ]]; then
        cp -r "$extracted_dir/config"/* "$restore_path/" 2>/dev/null || {
            log_error "Failed to restore configuration files"
            return 1
        }
    fi

    log_success "Configuration backup files restored"
    return 0
}

restore_logs_backup_files() {
    local extracted_dir="$1"
    local restore_path="$2"

    log_activity "Restoring logs backup files"

    if [[ -d "$extracted_dir/logs" ]]; then
        ensure_directory "$DEFAULT_LOG_DIR"
        cp -r "$extracted_dir/logs"/* "$DEFAULT_LOG_DIR/" 2>/dev/null || {
            log_error "Failed to restore log files"
            return 1
        }
    fi

    log_success "Logs backup files restored"
    return 0
}

restore_generic_backup_files() {
    local extracted_dir="$1"
    local restore_path="$2"

    log_activity "Performing generic backup restoration"

    # Copy all files from extracted directory
    cp -r "$extracted_dir"/* "$restore_path/" 2>/dev/null || {
        log_error "Failed to restore backup files"
        return 1
    }

    log_success "Generic backup files restored"
    return 0
}

# =============================================================================
# COMPRESSION OPERATIONS
# =============================================================================

compress_backup_with_retry() {
    local source_dir="$1"
    local target_file="$2"
    local retries=0

    log_activity "Compressing backup with retry logic"

    while [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; do
        if compress_directory_to_archive "$source_dir" "$target_file"; then
            log_success "Backup compression completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Backup compression failed (attempt $retries), retrying in $BACKUP_WRAPPER_RETRY_DELAY seconds..."
                sleep $BACKUP_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Backup compression failed after $BACKUP_WRAPPER_MAX_RETRIES attempts"
    return 1
}

# =============================================================================
# CLEANUP OPERATIONS
# =============================================================================

cleanup_old_backups_with_retry() {
    local max_age_days="$1"
    local max_count="$2"
    local retries=0

    log_activity "Cleaning up old backups with retry logic"

    while [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; do
        if cleanup_old_backups_operation "$max_age_days" "$max_count"; then
            log_success "Old backup cleanup completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $BACKUP_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Old backup cleanup failed (attempt $retries), retrying in $BACKUP_WRAPPER_RETRY_DELAY seconds..."
                sleep $BACKUP_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Old backup cleanup failed after $BACKUP_WRAPPER_MAX_RETRIES attempts"
    return 1
}

cleanup_old_backups_operation() {
    local max_age_days="${1:-30}"
    local max_count="${2:-0}"

    log_activity "Cleaning up backups older than $max_age_days days"

    local backup_location="$DEFAULT_WORKDIR/backup"
    local deleted_count=0

    # Cleanup by age
    if [[ $max_age_days -gt 0 ]]; then
        local old_backups
        old_backups=$(find "$backup_location" -name "*.tar.gz" -type f -mtime +"$max_age_days" 2>/dev/null)

        while IFS= read -r backup_file; do
            if [[ -n "$backup_file" ]]; then
                rm -f "$backup_file" && deleted_count=$((deleted_count + 1))
                log_info "Deleted old backup: $(basename "$backup_file")"
            fi
        done <<< "$old_backups"
    fi

    # Cleanup by count (keep only the newest N backups)
    if [[ $max_count -gt 0 ]]; then
        local all_backups
        all_backups=$(find "$backup_location" -name "*.tar.gz" -type f 2>/dev/null | sort -r)

        local backup_count
        backup_count=$(echo "$all_backups" | wc -l)

        if [[ $backup_count -gt $max_count ]]; then
            local excess_backups
            excess_backups=$(echo "$all_backups" | tail -n +$((max_count + 1)))

            while IFS= read -r backup_file; do
                if [[ -n "$backup_file" ]]; then
                    rm -f "$backup_file" && deleted_count=$((deleted_count + 1))
                    log_info "Deleted excess backup: $(basename "$backup_file")"
                fi
            done <<< "$excess_backups"
        fi
    fi

    log_success "Cleanup completed: $deleted_count backup(s) deleted"
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f backup_wrapper validate_backup_requirements verify_backup_integrity
export -f create_full_backup_with_retry create_full_backup_operation
export -f create_config_backup_with_retry create_config_backup_operation
export -f create_logs_backup_with_retry create_logs_backup_operation
export -f backup_configuration_files backup_credentials_files backup_docker_configurations
export -f backup_log_files create_backup_manifest_file compress_directory_to_archive
export -f restore_backup_with_retry restore_backup_operation
export -f restore_full_backup_files restore_config_backup_files restore_logs_backup_files
export -f restore_generic_backup_files compress_backup_with_retry
export -f cleanup_old_backups_with_retry cleanup_old_backups_operation

log_success "Backup wrapper loaded successfully"
