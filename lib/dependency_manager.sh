#!/bin/bash

# dependency_manager.sh - Auto-dependency installation system
# Version: 4.0.0 - Smart dependency management for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
# shellcheck source=lib/progress.sh
source "$(dirname "${BASH_SOURCE[0]}")/progress.sh"

# =============================================================================
# DEPENDENCY DEFINITIONS
# =============================================================================

# Critical dependencies (must install)
readonly CRITICAL_DEPS=(
    "docker:Docker Engine:Modern containerization platform"
    "docker-compose:Docker Compose:Container orchestration tool"
    "jq:JSON Processor:JSON parsing and manipulation"
    "curl:HTTP Client:Network communication tool"
)

# Optional dependencies (install with confirmation)
readonly OPTIONAL_DEPS=(
    "netstat:Network Statistics:Port monitoring utility"
    "htop:Process Monitor:System resource monitoring"
    "git:Version Control:Code repository management"
)

# =============================================================================
# DEPENDENCY CHECKING FUNCTIONS
# =============================================================================

check_dependency() {
    local dep_info="$1"
    local cmd_name="${dep_info%%:*}"
    local display_name="${dep_info#*:}"
    display_name="${display_name%%:*}"

    if command -v "$cmd_name" >/dev/null 2>&1; then
        local version=""
        case "$cmd_name" in
            "docker")
                version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
                ;;
            "docker-compose")
                version=$(docker-compose --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
                ;;
            "jq")
                version=$(jq --version 2>/dev/null | tr -d 'jq-')
                ;;
            "curl")
                version=$(curl --version 2>/dev/null | head -n1 | cut -d' ' -f2)
                ;;
        esac

        show_check_status "$display_name" "pass" "v$version"
        return 0
    else
        show_check_status "$display_name" "missing" "Not installed"
        return 1
    fi
}

check_all_dependencies() {
    local missing_critical=()
    local missing_optional=()

    echo -e "${CYAN}${BOLD}🔍 Checking system dependencies...${NC}"
    echo ""

    # Check critical dependencies
    echo -e "${BOLD}Critical Dependencies:${NC}"
    for dep in "${CRITICAL_DEPS[@]}"; do
        if ! check_dependency "$dep"; then
            missing_critical+=("$dep")
        fi
    done

    echo ""

    # Check optional dependencies
    echo -e "${BOLD}Optional Dependencies:${NC}"
    for dep in "${OPTIONAL_DEPS[@]}"; do
        if ! check_dependency "$dep"; then
            missing_optional+=("$dep")
        fi
    done

    echo ""

    # Export results
    export MISSING_CRITICAL_COUNT=${#missing_critical[@]}
    export MISSING_OPTIONAL_COUNT=${#missing_optional[@]}

    if [[ ${#missing_critical[@]} -eq 0 ]]; then
        log_success "All critical dependencies are installed"
        return 0
    else
        log_warning "${#missing_critical[@]} critical dependencies missing"
        # Store missing deps for installation
        printf '%s\n' "${missing_critical[@]}" > /tmp/nexus-missing-critical.txt
        return 1
    fi
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

install_package() {
    local dep_info="$1"
    local cmd_name="${dep_info%%:*}"
    local display_name="${dep_info#*:}"
    display_name="${display_name%%:*}"

    case "$cmd_name" in
        "docker")
            install_docker_with_progress
            ;;
        "docker-compose")
            install_docker_compose_with_progress
            ;;
        "jq")
            install_with_progress "jq" "$display_name"
            ;;
        "curl")
            install_with_progress "curl" "$display_name"
            ;;
        "netstat")
            install_with_progress "net-tools" "$display_name"
            ;;
        "htop")
            install_with_progress "htop" "$display_name"
            ;;
        "git")
            install_with_progress "git" "$display_name"
            ;;
        *)
            install_with_progress "$cmd_name" "$display_name"
            ;;
    esac
}

install_docker_with_progress() {
    echo -e "${CYAN}📦 Installing Docker Engine...${NC}"

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "Docker installation requires root privileges"
        return 1
    fi

    init_multi_step 5

    next_step "Updating package repositories"
    apt-get update >/dev/null 2>&1 || {
        handle_error "Failed to update package repositories"
        return 1
    }

    next_step "Installing prerequisites"
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release >/dev/null 2>&1 || {
        handle_error "Failed to install prerequisites"
        return 1
    }

    next_step "Adding Docker GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >/dev/null 2>&1 || {
        handle_error "Failed to add Docker GPG key"
        return 1
    }

    next_step "Adding Docker repository"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1 || {
        handle_error "Failed to add Docker repository"
        return 1
    }

    next_step "Installing Docker Engine"
    apt-get update >/dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1 || {
        handle_error "Failed to install Docker Engine"
        return 1
    }

    # Start and enable Docker
    systemctl start docker >/dev/null 2>&1
    systemctl enable docker >/dev/null 2>&1

    complete_multi_step
    log_success "Docker Engine installed successfully"
}

install_docker_compose_with_progress() {
    echo -e "${CYAN}📦 Installing Docker Compose...${NC}"

    init_multi_step 3

    next_step "Fetching latest version information"
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | \
                    jq -r '.tag_name' 2>/dev/null || echo "v2.20.0") || {
        handle_error "Failed to fetch Docker Compose version"
        return 1
    }

    next_step "Downloading Docker Compose $latest_version"
    curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose >/dev/null 2>&1 || {
        handle_error "Failed to download Docker Compose"
        return 1
    }

    next_step "Setting executable permissions"
    chmod +x /usr/local/bin/docker-compose || {
        handle_error "Failed to set permissions for Docker Compose"
        return 1
    }

    complete_multi_step
    log_success "Docker Compose installed successfully"
}

# =============================================================================
# AUTO-INSTALLATION WORKFLOW
# =============================================================================

auto_install_dependencies() {
    local force_install="${1:-false}"

    show_section_header "Dependency Management" "📦"

    # Check current state
    if ! check_all_dependencies; then
        echo ""

        if [[ "$force_install" == "true" ]] || [[ $EUID -eq 0 ]]; then
            echo -e "${YELLOW}🔧 Auto-installing missing critical dependencies...${NC}"
            echo ""

            # Install missing critical dependencies
            if [[ -f /tmp/nexus-missing-critical.txt ]]; then
                local total_deps
                total_deps=$(wc -l < /tmp/nexus-missing-critical.txt)
                local current_dep=0

                while IFS= read -r dep; do
                    ((current_dep++))
                    echo -e "${BLUE}Installing dependency $current_dep/$total_deps${NC}"

                    if install_package "$dep"; then
                        show_progress "$current_dep" "$total_deps" "Dependency Installation"
                    else
                        handle_error "Failed to install critical dependency: ${dep%%:*}"
                        return 1
                    fi
                done < /tmp/nexus-missing-critical.txt

                rm -f /tmp/nexus-missing-critical.txt
                echo ""
                log_success "All critical dependencies installed successfully"
            fi
        else
            echo -e "${RED}❌ Missing critical dependencies detected${NC}"
            echo -e "${YELLOW}💡 Please run with sudo/root privileges for auto-installation${NC}"
            echo ""
            echo -e "${BOLD}Manual installation commands:${NC}"

            if [[ -f /tmp/nexus-missing-critical.txt ]]; then
                while IFS= read -r dep; do
                    local cmd_name="${dep%%:*}"
                    case "$cmd_name" in
                        "docker")
                            echo -e "  ${CYAN}curl -fsSL https://get.docker.com | sh${NC}"
                            ;;
                        "docker-compose")
                            echo -e "  ${CYAN}sudo apt-get install docker-compose-plugin${NC}"
                            ;;
                        *)
                            echo -e "  ${CYAN}sudo apt-get install $cmd_name${NC}"
                            ;;
                    esac
                done < /tmp/nexus-missing-critical.txt
            fi

            echo ""
            echo -e "${YELLOW}⚠️  Please install these dependencies and restart the application${NC}"
            return 1
        fi
    fi

    # Verify installation
    echo -e "${CYAN}🔍 Verifying installation...${NC}"
    echo ""

    if check_all_dependencies >/dev/null 2>&1; then
        log_success "All dependencies verified successfully"
        return 0
    else
        handle_error "Dependency verification failed"
        return 1
    fi
}

# =============================================================================
# SYSTEM REQUIREMENTS CHECK
# =============================================================================

check_system_requirements() {
    show_section_header "System Requirements" "🖥️"

    local requirements_met=true

    # Check OS
    if [[ "$(uname -s)" == "Linux" ]]; then
        show_check_status "Operating System" "pass" "Linux $(uname -r)"
    else
        show_check_status "Operating System" "fail" "$(uname -s) not supported"
        requirements_met=false
    fi

    # Check architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]] || [[ "$arch" == "aarch64" ]]; then
        show_check_status "Architecture" "pass" "$arch"
    else
        show_check_status "Architecture" "warning" "$arch (may have compatibility issues)"
        requirements_met=false
    fi

    # Check memory
    local memory_gb
    memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $memory_gb -ge 2 ]]; then
        show_check_status "Memory" "pass" "${memory_gb}GB RAM"
    else
        show_check_status "Memory" "warning" "${memory_gb}GB RAM (minimum 2GB recommended)"
        requirements_met=false
    fi

    # Check disk space
    local disk_gb
    disk_gb=$(df -BG "$PWD" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $disk_gb -ge 5 ]]; then
        show_check_status "Disk Space" "pass" "${disk_gb}GB available"
    else
        show_check_status "Disk Space" "warning" "${disk_gb}GB available (minimum 5GB recommended)"
        requirements_met=false
    fi

    echo ""

    if [[ "$requirements_met" == true ]]; then
        log_success "System requirements check passed"
        return 0
    else
        log_warning "Some system requirements not optimal"
        return 1
    fi
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

ensure_dependencies() {
    local skip_auto="${1:-false}"

    # Always check system requirements first
    check_system_requirements
    echo ""

    # Check and install dependencies
    if [[ "$skip_auto" == "true" ]]; then
        check_all_dependencies
    else
        auto_install_dependencies false
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f check_dependency check_all_dependencies install_package
export -f install_docker_with_progress install_docker_compose_with_progress
export -f auto_install_dependencies check_system_requirements ensure_dependencies

log_success "Dependency manager loaded successfully"
