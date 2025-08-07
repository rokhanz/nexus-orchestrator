#!/bin/bash

# uninstall_menu.sh - Uninstall Operations Menu Module
# Version: 4.0.0 - Modular menu system for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# UNINSTALL MENU FUNCTIONS
# =============================================================================

uninstall_menu() {
    while true; do
        clear
        show_section_header "Uninstall Operations" "🗑️"

        echo -e "${CYAN}Select uninstall option:${NC}"
        echo ""
        echo "1. Remove Nexus Containers Only"
        echo "2. Remove Nexus Configuration"
        echo "3. Complete Nexus Uninstall"
        echo "4. Remove Docker Components"
        echo "5. System Cleanup"
        echo "6. Factory Reset (Remove Everything)"
        echo "0. Return to Main Menu"
        echo ""

        read -rp "Choose option [0-6]: " choice

        case "$choice" in
            1)
                remove_containers_only
                ;;
            2)
                remove_configuration
                ;;
            3)
                complete_nexus_uninstall
                ;;
            4)
                remove_docker_components
                ;;
            5)
                system_cleanup
                ;;
            6)
                factory_reset
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
# CONTAINER REMOVAL
# =============================================================================

remove_containers_only() {
    show_section_header "Remove Nexus Containers Only" "🐳"

    echo -e "${CYAN}This will remove all Nexus containers but keep configuration${NC}"
    echo -e "${YELLOW}⚠️  Container data will be lost${NC}"
    echo ""

    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker not available${NC}"
        echo -e "${YELLOW}💡 Please install Docker first${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    # Show current containers
    local containers
    containers=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        echo -e "${GREEN}✅ No Nexus containers found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${CYAN}Individual Node Status:${NC}"
    local container_array=()
    local i=1
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
            local status
            status=$(docker inspect "$container" --format "{{.State.Status}}" 2>/dev/null || echo "unknown")
            local status_icon="❌"
            local status_color="$RED"

            case "$status" in
                "running")
                    status_icon="✅"
                    status_color="$GREEN"
                    ;;
                "paused")
                    status_icon="⏸️"
                    status_color="$YELLOW"
                    ;;
                "restarting")
                    status_icon="🔄"
                    status_color="$CYAN"
                    ;;
                *)
                    status_icon="❌"
                    status_color="$RED"
                    status="Stopped"
                    ;;
            esac

            echo -e "    ${GREEN}$i.${NC} ${CYAN}$container${NC}  ${status_color}$status_icon $status${NC}"
            ((i++))
        fi
    done <<< "$containers"
    echo ""

    # Add option for individual container management
    echo -e "${CYAN}Options:${NC}"
    echo -e "  ${GREEN}A.${NC} Remove All Containers"
    echo -e "  ${GREEN}I.${NC} Stop/Remove Individual Container"
    echo -e "  ${GREEN}C.${NC} Cancel"
    echo ""

    read -rp "Select option [A/I/C]: " remove_choice
    case "$remove_choice" in
        [Aa])
            # Continue with all containers removal
            ;;
        [Ii])
            echo ""
            read -rp "Enter container number to stop/remove (1-$((i-1))): " container_num
            if [[ "$container_num" =~ ^[0-9]+$ ]] && [[ $container_num -ge 1 && $container_num -le $((i-1)) ]]; then
                local selected_container="${container_array[$((container_num-1))]}"
                echo -e "${CYAN}Removing container: ${BOLD}$selected_container${NC}"

                # Stop and remove individual container
                docker stop "$selected_container" 2>/dev/null || true
                if docker rm -f "$selected_container" 2>/dev/null; then
                    echo -e "${GREEN}✅ Container $selected_container removed successfully${NC}"
                else
                    echo -e "${RED}❌ Failed to remove container $selected_container${NC}"
                fi
            else
                echo -e "${RED}❌ Invalid container number${NC}"
            fi
            read -rp "Press Enter to continue..."
            return 0
            ;;
        [Cc])
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            read -rp "Press Enter to continue..."
            return 0
            ;;
    esac

    # Only ask for confirmation if proceeding with all containers removal
    echo ""
    read -rp "Are you sure you want to remove ALL these containers? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    fi

    init_multi_step 3

    next_step "Stopping running containers"
    # Use --remove-orphans to clean up orphaned containers and networks
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans 2>/dev/null; then
        log_success "Containers stopped and orphans cleaned"
    else
        log_warning "Some containers may not have stopped gracefully - trying force cleanup"
        # Force cleanup if normal stop fails
        local containers
        containers=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)
        if [[ -n "$containers" ]]; then
            while IFS= read -r container; do
                if [[ -n "$container" ]]; then
                    docker rm -f "$container" 2>/dev/null || true
                fi
            done <<< "$containers"
        fi
        # Force remove networks with active endpoints
        docker network ls --filter "name=nexus" --format "{{.Name}}" | while read -r network; do
            if [[ -n "$network" ]]; then
                docker network rm "$network" 2>/dev/null || true
            fi
        done
    fi

    next_step "Removing containers"
    local removed_count=0
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            if docker rm -f "$container" 2>/dev/null; then
                removed_count=$((removed_count + 1))
            fi
        fi
    done <<< "$containers"

    log_success "Removed $removed_count container(s)"

    next_step "Cleaning up container volumes"
    if docker volume prune -f 2>/dev/null; then
        log_success "Container volumes cleaned"
    else
        log_warning "Volume cleanup may have failed"
    fi

    complete_multi_step

    echo ""
    echo -e "${GREEN}✅ Nexus containers removed successfully${NC}"
    echo -e "${CYAN}Configuration files preserved in $DEFAULT_WORKDIR${NC}"
    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# CONFIGURATION REMOVAL
# =============================================================================

remove_configuration() {
    show_section_header "Remove Nexus Configuration" "⚙️"

    echo -e "${CYAN}This will remove all Nexus configuration files${NC}"
    echo -e "${YELLOW}⚠️  You will need to reconfigure from scratch${NC}"
    echo ""

    # Show what will be removed
    echo -e "${CYAN}Configuration files to be removed:${NC}"
    local config_files=(
        "$CREDENTIALS_FILE"
        "$DOCKER_COMPOSE_FILE"
        "$PROVER_ID_FILE"
        "$DEFAULT_CONFIG_DIR"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]] || [[ -d "$config_file" ]]; then
            echo "  - $config_file"
        fi
    done
    echo ""

    read -rp "Create backup before removal? [Y/n]: " create_backup

    if [[ ! "$create_backup" =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${CYAN}Creating configuration backup...${NC}"

        # Create backup using backup menu functions
        if command -v create_config_backup >/dev/null 2>&1; then
            create_config_backup
        else
            # Simple backup if function not available
            local backup_dir
            backup_dir="$DEFAULT_WORKDIR/backup/config_backup_$(date '+%Y%m%d_%H%M%S')"
            ensure_directory "$backup_dir"

            for config_file in "${config_files[@]}"; do
                if [[ -f "$config_file" ]]; then
                    cp "$config_file" "$backup_dir/" 2>/dev/null || true
                elif [[ -d "$config_file" ]]; then
                    cp -r "$config_file" "$backup_dir/" 2>/dev/null || true
                fi
            done

            echo -e "${GREEN}✅ Backup created in $backup_dir${NC}"
        fi
        echo ""
    fi

    read -rp "Are you sure you want to remove configuration? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    fi

    init_multi_step 2

    next_step "Removing configuration files"
    local removed_count=0

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            rm -f "$config_file" && removed_count=$((removed_count + 1))
        elif [[ -d "$config_file" ]]; then
            rm -rf "$config_file" && removed_count=$((removed_count + 1))
        fi
    done

    log_success "Removed $removed_count configuration item(s)"

    next_step "Cleaning up environment files"
    if [[ -f "$DEFAULT_WORKDIR/proxy.env" ]]; then
        rm -f "$DEFAULT_WORKDIR/proxy.env"
    fi

    # Clear environment variables
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    log_success "Environment cleanup completed"

    complete_multi_step

    echo ""
    echo -e "${GREEN}✅ Configuration removed successfully${NC}"
    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# COMPLETE NEXUS UNINSTALL
# =============================================================================

complete_nexus_uninstall() {
    show_section_header "Complete Nexus Uninstall" "🗑️"

    echo -e "${CYAN}This will completely remove Nexus Orchestrator${NC}"
    echo -e "${RED}⚠️  This action cannot be undone${NC}"
    echo ""
    echo -e "${YELLOW}The following will be removed:${NC}"
    echo "  - All Nexus containers and images"
    echo "  - All configuration files"
    echo "  - All log files"
    echo "  - Working directory and data"
    echo ""

    read -rp "Create full backup before uninstall? [Y/n]: " create_backup

    if [[ ! "$create_backup" =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${CYAN}Creating full backup...${NC}"

        if command -v create_full_backup >/dev/null 2>&1; then
            create_full_backup
        else
            echo -e "${YELLOW}⚠️  Backup function not available${NC}"
        fi
        echo ""
    fi

    echo -e "${RED}${BOLD}FINAL WARNING: This will completely remove Nexus Orchestrator${NC}"
    read -rp "Type 'REMOVE' to confirm complete uninstall: " confirmation

    if [[ "$confirmation" != "REMOVE" ]]; then
        echo -e "${YELLOW}Uninstall cancelled${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    perform_complete_uninstall
}

perform_complete_uninstall() {
    echo ""
    echo -e "${CYAN}Performing complete Nexus uninstall...${NC}"
    echo ""

    init_multi_step 6

    next_step "Stopping all Nexus containers"
    if command -v docker >/dev/null 2>&1; then
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
        fi

        # Force stop any remaining Nexus containers
        local containers
        containers=$(docker ps -a --filter "name=nexus" --format "{{.Names}}" 2>/dev/null)
        if [[ -n "$containers" ]]; then
            while IFS= read -r container; do
                if [[ -n "$container" ]]; then
                    docker rm -f "$container" 2>/dev/null || true
                fi
            done <<< "$containers"
        fi
        log_success "Containers stopped and removed"
    else
        log_warning "Docker not available"
    fi

    next_step "Removing Nexus Docker images"
    if command -v docker >/dev/null 2>&1; then
        local images
        images=$(docker images --filter "reference=*nexus*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)
        if [[ -n "$images" ]]; then
            while IFS= read -r image; do
                if [[ -n "$image" ]]; then
                    docker rmi -f "$image" 2>/dev/null || true
                fi
            done <<< "$images"
        fi
        log_success "Docker images removed"
    else
        log_warning "Docker not available"
    fi

    next_step "Removing configuration files"
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        rm -f "$CREDENTIALS_FILE"
    fi
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        rm -f "$DOCKER_COMPOSE_FILE"
    fi
    if [[ -f "$PROVER_ID_FILE" ]]; then
        rm -f "$PROVER_ID_FILE"
    fi
    if [[ -d "$DEFAULT_CONFIG_DIR" ]]; then
        rm -rf "$DEFAULT_CONFIG_DIR"
    fi
    log_success "Configuration files removed"

    next_step "Removing log files"
    if [[ -f "$NEXUS_MANAGER_LOG" ]]; then
        rm -f "$NEXUS_MANAGER_LOG"
    fi
    if [[ -d "$DEFAULT_LOG_DIR" ]]; then
        rm -rf "$DEFAULT_LOG_DIR"
    fi
    log_success "Log files removed"

    next_step "Cleaning up working directory"
    # Keep backup directory but remove everything else
    find "$DEFAULT_WORKDIR" -type f ! -path "*/backup/*" -delete 2>/dev/null || true
    find "$DEFAULT_WORKDIR" -type d -empty ! -path "*/backup*" -delete 2>/dev/null || true
    log_success "Working directory cleaned"

    next_step "Final cleanup"
    # Clear environment variables
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

    # Remove any cron jobs
    crontab -l 2>/dev/null | grep -v "automated_backup.sh" | crontab - 2>/dev/null || true
    log_success "Final cleanup completed"

    complete_multi_step

    echo ""
    echo -e "${GREEN}✅ Complete Nexus uninstall finished${NC}"
    echo ""
    echo -e "${CYAN}Nexus Orchestrator has been completely removed from your system${NC}"
    echo -e "${YELLOW}💡 Backups are preserved in $DEFAULT_WORKDIR/backup${NC}"
    echo ""

    read -rp "Press Enter to exit..."
    exit 0
}

# =============================================================================
# DOCKER COMPONENT REMOVAL
# =============================================================================

remove_docker_components() {
    show_section_header "Remove Docker Components" "🐳"

    echo -e "${CYAN}Docker component removal options:${NC}"
    echo ""
    echo "1. Remove Nexus Docker images only"
    echo "2. Remove all unused Docker images"
    echo "3. Remove Docker volumes"
    echo "4. Remove Docker networks"
    echo "5. Complete Docker cleanup"
    echo "0. Back to uninstall menu"
    echo ""

    read -rp "Choose option [0-5]: " choice

    case "$choice" in
        1)
            remove_nexus_images
            ;;
        2)
            remove_unused_images
            ;;
        3)
            remove_docker_volumes
            ;;
        4)
            remove_docker_networks
            ;;
        5)
            complete_docker_cleanup
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

remove_nexus_images() {
    echo ""
    echo -e "${CYAN}Removing Nexus Docker images...${NC}"

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker not available${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    local images
    images=$(docker images --filter "reference=*nexus*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)

    if [[ -z "$images" ]]; then
        echo -e "${GREEN}✅ No Nexus images found${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo -e "${CYAN}Found Nexus images:${NC}"
    while IFS= read -r image; do
        if [[ -n "$image" ]]; then
            echo "  - $image"
        fi
    done <<< "$images"
    echo ""

    read -rp "Remove these images? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        local removed_count=0
        while IFS= read -r image; do
            if [[ -n "$image" ]]; then
                if docker rmi "$image" 2>/dev/null; then
                    removed_count=$((removed_count + 1))
                fi
            fi
        done <<< "$images"

        echo -e "${GREEN}✅ Removed $removed_count image(s)${NC}"
    fi

    read -rp "Press Enter to continue..."
}

remove_unused_images() {
    echo ""
    echo -e "${CYAN}Removing all unused Docker images...${NC}"

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker not available${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${YELLOW}⚠️  This will remove all unused Docker images${NC}"
    read -rp "Are you sure? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if docker image prune -a -f 2>/dev/null; then
            echo -e "${GREEN}✅ Unused images removed${NC}"
        else
            echo -e "${RED}❌ Failed to remove unused images${NC}"
        fi
    fi

    read -rp "Press Enter to continue..."
}

remove_docker_volumes() {
    echo ""
    echo -e "${CYAN}Removing Docker volumes...${NC}"

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker not available${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${YELLOW}⚠️  This will remove all unused Docker volumes${NC}"
    read -rp "Are you sure? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if docker volume prune -f 2>/dev/null; then
            echo -e "${GREEN}✅ Unused volumes removed${NC}"
        else
            echo -e "${RED}❌ Failed to remove volumes${NC}"
        fi
    fi

    read -rp "Press Enter to continue..."
}

remove_docker_networks() {
    echo ""
    echo -e "${CYAN}Removing Docker networks...${NC}"

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker not available${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    echo -e "${YELLOW}⚠️  This will remove all unused Docker networks${NC}"
    read -rp "Are you sure? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if docker network prune -f 2>/dev/null; then
            echo -e "${GREEN}✅ Unused networks removed${NC}"
        else
            echo -e "${RED}❌ Failed to remove networks${NC}"
        fi
    fi

    read -rp "Press Enter to continue..."
}

complete_docker_cleanup() {
    echo ""
    echo -e "${CYAN}Complete Docker cleanup...${NC}"
    echo ""
    echo -e "${RED}⚠️  This will remove ALL unused Docker resources${NC}"
    echo "  - Unused containers"
    echo "  - Unused images"
    echo "  - Unused volumes"
    echo "  - Unused networks"
    echo ""

    read -rp "Are you absolutely sure? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${CYAN}Performing complete Docker cleanup...${NC}"

        if docker system prune -a -f --volumes 2>/dev/null; then
            echo -e "${GREEN}✅ Complete Docker cleanup finished${NC}"
        else
            echo -e "${RED}❌ Docker cleanup failed${NC}"
        fi
    fi

    read -rp "Press Enter to continue..."
}

# =============================================================================
# SYSTEM CLEANUP
# =============================================================================

system_cleanup() {
    show_section_header "System Cleanup" "🧹"

    echo -e "${CYAN}System cleanup options:${NC}"
    echo ""
    echo "1. Clean temporary files"
    echo "2. Clean log files"
    echo "3. Clean package cache"
    echo "4. Clean user cache"
    echo "5. Complete system cleanup"
    echo "0. Back to uninstall menu"
    echo ""

    read -rp "Choose option [0-5]: " choice

    case "$choice" in
        1)
            clean_temp_files
            ;;
        2)
            clean_log_files
            ;;
        3)
            clean_package_cache
            ;;
        4)
            clean_user_cache
            ;;
        5)
            complete_system_cleanup
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

clean_temp_files() {
    echo ""
    echo -e "${CYAN}Cleaning temporary files...${NC}"

    local temp_dirs=("/tmp" "/var/tmp")
    local cleaned_count=0

    for temp_dir in "${temp_dirs[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            # Clean files older than 7 days
            if find "$temp_dir" -type f -atime +7 -delete 2>/dev/null; then
                cleaned_count=$((cleaned_count + 1))
            fi
        fi
    done

    echo -e "${GREEN}✅ Temporary files cleaned${NC}"
    read -rp "Press Enter to continue..."
}

clean_log_files() {
    echo ""
    echo -e "${CYAN}Cleaning system log files...${NC}"

    if command -v journalctl >/dev/null 2>&1; then
        # Clean systemd logs older than 7 days
        journalctl --vacuum-time=7d 2>/dev/null || true
        echo -e "${GREEN}✅ System logs cleaned${NC}"
    else
        echo -e "${YELLOW}⚠️  journalctl not available${NC}"
    fi

    read -rp "Press Enter to continue..."
}

clean_package_cache() {
    echo ""
    echo -e "${CYAN}Cleaning package cache...${NC}"

    if command -v apt >/dev/null 2>&1; then
        apt autoremove -y 2>/dev/null || true
        apt autoclean 2>/dev/null || true
        echo -e "${GREEN}✅ APT cache cleaned${NC}"
    elif command -v yum >/dev/null 2>&1; then
        yum clean all 2>/dev/null || true
        echo -e "${GREEN}✅ YUM cache cleaned${NC}"
    else
        echo -e "${YELLOW}⚠️  No supported package manager found${NC}"
    fi

    read -rp "Press Enter to continue..."
}

clean_user_cache() {
    echo ""
    echo -e "${CYAN}Cleaning user cache...${NC}"

    # Clean current user's cache
    if [[ -d "$HOME/.cache" ]]; then
        find "$HOME/.cache" -type f -atime +30 -delete 2>/dev/null || true
        echo -e "${GREEN}✅ User cache cleaned${NC}"
    else
        echo -e "${YELLOW}⚠️  No user cache directory found${NC}"
    fi

    read -rp "Press Enter to continue..."
}

complete_system_cleanup() {
    echo ""
    echo -e "${CYAN}Complete system cleanup...${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  This will clean all temporary files, caches, and logs${NC}"
    read -rp "Are you sure? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        clean_temp_files
        clean_log_files
        clean_package_cache
        clean_user_cache

        echo ""
        echo -e "${GREEN}✅ Complete system cleanup finished${NC}"
    fi

    read -rp "Press Enter to continue..."
}

# =============================================================================
# FACTORY RESET
# =============================================================================

factory_reset() {
    show_section_header "Factory Reset" "🔄"

    echo -e "${RED}${BOLD}⚠️  FACTORY RESET WARNING ⚠️${NC}"
    echo ""
    echo -e "${RED}This will completely remove:${NC}"
    echo "  - All Nexus containers and images"
    echo "  - All configuration files"
    echo "  - All log files and data"
    echo "  - All backups"
    echo "  - Working directory"
    echo "  - Docker cleanup"
    echo "  - System cleanup"
    echo ""
    echo -e "${RED}${BOLD}THIS ACTION CANNOT BE UNDONE!${NC}"
    echo ""

    read -rp "Type 'FACTORY-RESET' to confirm: " confirmation

    if [[ "$confirmation" != "FACTORY-RESET" ]]; then
        echo -e "${YELLOW}Factory reset cancelled${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    echo ""
    echo -e "${RED}${BOLD}FINAL CONFIRMATION${NC}"
    read -rp "Type 'YES-DELETE-EVERYTHING' to proceed: " final_confirmation

    if [[ "$final_confirmation" != "YES-DELETE-EVERYTHING" ]]; then
        echo -e "${YELLOW}Factory reset cancelled${NC}"
        read -rp "Press Enter to continue..."
        return 0
    fi

    perform_factory_reset
}

perform_factory_reset() {
    echo ""
    echo -e "${RED}${BOLD}Performing factory reset...${NC}"
    echo ""

    init_multi_step 8

    next_step "Stopping all containers"
    if command -v docker >/dev/null 2>&1; then
        docker stop "$(docker ps -aq)" 2>/dev/null || true
        log_success "All containers stopped"
    else
        log_warning "Docker not available"
    fi

    next_step "Removing all containers"
    if command -v docker >/dev/null 2>&1; then
        docker rm -f "$(docker ps -aq)" 2>/dev/null || true
        log_success "All containers removed"
    else
        log_warning "Docker not available"
    fi

    next_step "Removing all Docker images"
    if command -v docker >/dev/null 2>&1; then
        docker rmi -f "$(docker images -aq)" 2>/dev/null || true
        log_success "All images removed"
    else
        log_warning "Docker not available"
    fi

    next_step "Complete Docker cleanup"
    if command -v docker >/dev/null 2>&1; then
        docker system prune -a -f --volumes 2>/dev/null || true
        log_success "Docker system cleaned"
    else
        log_warning "Docker not available"
    fi

    next_step "Removing working directory"
    if [[ -d "$DEFAULT_WORKDIR" ]]; then
        rm -rf "$DEFAULT_WORKDIR"
        log_success "Working directory removed"
    else
        log_warning "Working directory not found"
    fi

    next_step "Removing cron jobs"
    crontab -r 2>/dev/null || true
    log_success "Cron jobs removed"

    next_step "Clearing environment variables"
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    unset VERBOSE DEBUG
    log_success "Environment cleared"

    next_step "System cleanup"
    # Clean temporary files
    find /tmp -name "*nexus*" -delete 2>/dev/null || true
    find /var/tmp -name "*nexus*" -delete 2>/dev/null || true
    log_success "System cleanup completed"

    complete_multi_step

    echo ""
    echo -e "${RED}${BOLD}🔥 FACTORY RESET COMPLETED 🔥${NC}"
    echo ""
    echo -e "${GREEN}✅ All Nexus Orchestrator components have been removed${NC}"
    echo -e "${GREEN}✅ System has been reset to factory state${NC}"
    echo ""
    echo -e "${CYAN}Thank you for using Nexus Orchestrator v4.0${NC}"
    echo ""

    read -rp "Press Enter to exit..."
    exit 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f uninstall_menu remove_containers_only remove_configuration
export -f complete_nexus_uninstall perform_complete_uninstall
export -f remove_docker_components remove_nexus_images remove_unused_images
export -f remove_docker_volumes remove_docker_networks complete_docker_cleanup
export -f system_cleanup clean_temp_files clean_log_files clean_package_cache
export -f clean_user_cache complete_system_cleanup factory_reset perform_factory_reset

log_success "Uninstall operations menu loaded successfully"
