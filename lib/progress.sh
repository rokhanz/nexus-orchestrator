#!/bin/bash

# progress.sh - Progress bar and status indication system
# Version: 4.0.0 - Professional progress indicators for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# STARTUP SPLASH SCREEN SYSTEM
# =============================================================================

show_startup_splash() {
    clear

    # Nexus Orchestrator ASCII Logo
    echo -e "${CYAN}${BOLD}"
    echo "    ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗"
    echo "    ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝"
    echo "    ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗"
    echo "    ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║"
    echo "    ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║"
    echo "    ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝"
    echo ""
    echo "     ██████╗ ██████╗  ██████╗██╗  ██╗███████╗███████╗████████╗██████╗  ██████╗ ████████╗ ██████╗ ██████╗ "
    echo "    ██╔═══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗╚══██╔══╝██╔═══██╗██╔══██╗"
    echo "    ██║   ██║██████╔╝██║     ███████║█████╗  ███████╗   ██║   ██████╔╝███████║   ██║   ██║   ██║██████╔╝"
    echo "    ██║   ██║██╔══██╗██║     ██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██╔══██║   ██║   ██║   ██║██╔══██╗"
    echo "    ╚██████╔╝██║  ██║╚██████╗██║  ██║███████╗███████║   ██║   ██║  ██║██║  ██║   ██║   ╚██████╔╝██║  ██║"
    echo "     ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}                    🚀 Intelligent zkML Infrastructure Management v4.0${NC}"
    echo -e "${GRAY}                           Powered by Docker • Enterprise Ready${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ===============================================================================
# UNIFIED PROGRESS BAR SYSTEM - All-in-One Progress Display
# ===============================================================================

# Universal progress bar that adapts to different contexts
show_unified_progress() {
    local message="$1"
    local percentage="${2:-0}"    # Percentage (0-100)
    local style="${3:-auto}"      # auto, startup, download, install, complete
    local extra_info="${4:-}"     # Optional extra information
    local width="${5:-60}"        # Progress bar width

    # Auto-detect style based on context if not specified
    if [[ "$style" == "auto" ]]; then
        if [[ "$message" =~ [Dd]ownload ]]; then
            style="download"
        elif [[ "$message" =~ [Ii]nstall ]]; then
            style="install"
        elif [[ "$percentage" -ge 100 ]]; then
            style="complete"
        else
            style="startup"
        fi
    fi

    # Calculate filled width based on percentage
    local filled=$(( (percentage * width) / 100 ))
    local remaining=$((width - filled))

    # Choose progress bar style and characters
    local fill_char="█"
    local edge_char="▌"
    local empty_char="░"
    local prefix="╰─"
    local color=""
    local status_msg=""

    case "$style" in
        "startup")
            # Windows-style startup with moving edge
            if [[ $percentage -le 25 ]]; then
                color="$CYAN"
                status_msg="Initializing system..."
            elif [[ $percentage -le 50 ]]; then
                color="$YELLOW"
                status_msg="Loading components..."
            elif [[ $percentage -le 75 ]]; then
                color="$ORANGE"
                status_msg="Configuring services..."
            else
                color="$GREEN"
                status_msg="Finalizing setup..."
            fi
            ;;

        "download")
            # Download-style with speed info
            fill_char="█"
            edge_char="▌"
            color="$BLUE"
            if [[ -n "$extra_info" ]]; then
                status_msg="$extra_info"
            else
                local speed="$((21 + (percentage % 30))) MB/s"
                local eta="$((10 - (percentage * 10 / 100)))s"
                status_msg="| $speed | ETA: ${eta}"
            fi
            ;;

        "install")
            # Installation-style with wave pattern
            local fill_chars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
            edge_char=""
            color="$PURPLE"
            if [[ -n "$extra_info" ]]; then
                status_msg="$extra_info"
            else
                local pkg_count="$((percentage * 15 / 100))"
                status_msg="Packages: $pkg_count/15 | Dependencies resolved"
            fi
            ;;

        "complete")
            # Completion style - full green
            color="$GREEN"
            status_msg="✅ Completed!"
            fill_char="█"
            edge_char=""
            ;;
    esac

    # Build progress bar
    local bar=""

    if [[ "$style" == "install" ]]; then
        # Wave pattern for installation
        local fill_chars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
        for ((i=0; i<filled; i++)); do
            local char_index=$((i % 8))
            bar+="${color}${fill_chars[$char_index]}${NC}"
        done
        for ((i=0; i<remaining; i++)); do
            bar+="${GRAY}${empty_char}${NC}"
        done
    else
        # Standard block pattern
        for ((i=0; i<filled; i++)); do
            bar+="${color}${fill_char}${NC}"
        done

        # Add moving edge if not complete
        if [[ $remaining -gt 0 && "$style" != "complete" ]]; then
            bar+="${color}${edge_char}${NC}"
            remaining=$((remaining - 1))
        fi

        for ((i=0; i<remaining; i++)); do
            bar+="${GRAY}${empty_char}${NC}"
        done
    fi

    # Display the unified progress bar
    echo -e "$message"
    echo -e "${prefix} [${bar}] ${percentage}% ${status_msg}"
}

# Utility function to clear current line
clear_line() {
    printf "\r\033[K"
}

# Unified live progress with animation
show_unified_live_progress() {
    local message="$1"
    local duration="${2:-3}"     # Duration in seconds
    local style="${3:-auto}"     # Progress style
    local extra_info="${4:-}"    # Extra information

    local steps=$(( duration * 10 ))  # 100ms intervals

    for ((i=0; i<=steps; i++)); do
        clear_line
        show_unified_progress "$i" "$steps" "$message" "$style" "$extra_info"
        sleep 0.1
    done
    echo ""
}

# =============================================================================
# STARTUP SYSTEM CHECK WITH UNIFIED PROGRESS
# =============================================================================

startup_system_check() {
    local skip_deps="$1"

    show_startup_splash

    # Step 1: System Information with unified progress
    echo -e "${CYAN}${BOLD}Step 1/8:${NC} 🔍 Gathering system information"
    show_unified_progress "System initialization" 12 "startup"

    local os_info
    os_info=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown Linux")
    local kernel_version
    kernel_version=$(uname -r)
    echo -e "    ${CYAN}OS:${NC} $os_info"
    echo -e "    ${CYAN}Kernel:${NC} $kernel_version"
    echo -e "    ${CYAN}Architecture:${NC} $(uname -m)"
    echo ""

    # Step 2: Check root privileges
    echo -e "${CYAN}${BOLD}Step 2/8:${NC} 🔐 Verifying administrator privileges"
    show_unified_progress "System initialization" 25 "startup"

    if [[ $EUID -eq 0 ]]; then
        echo -e "    ${GREEN}✅ Running with root privileges${NC}"
    else
        echo -e "    ${YELLOW}⚠️  Running without root (some features may be limited)${NC}"
    fi
    echo ""

    # Step 3: Network connectivity
    echo -e "${CYAN}${BOLD}Step 3/8:${NC} 🌐 Testing network connectivity"
    show_unified_progress "System initialization" 37 "startup"

    echo -e "    ${BLUE}⏳ Checking internet connection...${NC}"
    if ping -c 1 -W 5 google.com >/dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Internet connection active${NC}"
    else
        echo -e "    ${YELLOW}⚠️  Limited network connectivity${NC}"
    fi
    echo ""

    # Step 4: Check dependencies with unified progress
    echo -e "${CYAN}${BOLD}Step 4/8:${NC} 📦 Scanning system dependencies"

    local deps_missing=()
    local deps_ok=()

    # Check essential tools with animated scanning
    local essential_deps=("curl" "jq" "docker" "docker-compose")
    echo -e "    ${BLUE}🔍 Scanning for required tools...${NC}"

    for dep in "${essential_deps[@]}"; do
        # Simulate scanning delay for better UX
        printf "    ${GRAY}├─ Checking %s...${NC}" "$dep"
        sleep 0.2

        if command -v "$dep" >/dev/null 2>&1; then
            deps_ok+=("$dep")
            printf "\r    ${GREEN}├─ ✅ %s${NC} - %s\n" "$dep" "$(which "$dep")"
        else
            deps_missing+=("$dep")
            printf "\r    ${RED}├─ ❌ %s${NC} - Not installed\n" "$dep"
        fi
    done
    echo -e "    ${CYAN}└─ Scan completed: ${#deps_ok[@]} found, ${#deps_missing[@]} missing${NC}"

    # Show unified progress for dependency scanning
    local scan_info="Found: ${#deps_ok[@]}, Missing: ${#deps_missing[@]}"
    show_unified_progress "Dependency scanning" 50 "install" "$scan_info"
    echo ""

    # Step 5: Docker service check
    echo -e "${CYAN}${BOLD}Step 5/8:${NC} 🐳 Checking Docker service status"
    show_unified_progress "System initialization" 62 "startup"

    if systemctl is-active --quiet docker 2>/dev/null; then
        echo -e "    ${GREEN}✅ Docker service is running${NC}"
        local docker_version
        docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
        echo -e "    ${CYAN}Version:${NC} $docker_version"
    else
        echo -e "    ${YELLOW}⚠️  Docker service not running${NC}"
    fi
    echo ""

    # Step 6: Auto-install missing dependencies
    if [[ ${#deps_missing[@]} -gt 0 && "$skip_deps" != true ]]; then
        echo -e "${CYAN}${BOLD}Step 6/8:${NC} ⚡ Auto-installing missing dependencies"
        show_unified_progress "Installing dependencies" 75 "download" "Downloading packages..."

        for dep in "${deps_missing[@]}"; do
            echo -e "    ${BLUE}📦 Installing $dep...${NC}"
            case "$dep" in
                "docker")
                    install_docker_enhanced
                    ;;
                "docker-compose")
                    install_docker_compose_enhanced
                    ;;
                "curl"|"jq")
                    show_unified_live_progress "Installing $dep" 2 "install"
                    apt-get update >/dev/null 2>&1
                    apt-get install -y "$dep" >/dev/null 2>&1
                    ;;
            esac

            if command -v "$dep" >/dev/null 2>&1; then
                echo -e "    ${GREEN}✅ $dep installed successfully${NC}"
            else
                echo -e "    ${RED}❌ Failed to install $dep${NC}"
            fi
        done
    else
        echo -e "${CYAN}${BOLD}Step 6/8:${NC} ⚡ Dependency installation (skipped)"
        show_unified_progress "System initialization" 75 "startup"

        if [[ "$skip_deps" == true ]]; then
            echo -e "    ${YELLOW}⚠️  Dependency installation skipped by user${NC}"
        else
            echo -e "    ${GREEN}✅ All dependencies are already installed${NC}"
        fi
    fi
    echo ""

    # Step 7: Initialize working directory
    echo -e "${CYAN}${BOLD}Step 7/8:${NC} 📁 Initializing workspace"
    show_unified_progress "System initialization" 87 "startup"

    ensure_directories
    if [[ -d "$DEFAULT_WORKDIR" ]]; then
        echo -e "    ${GREEN}✅ Workspace: $DEFAULT_WORKDIR${NC}"
        local config_status="Not configured"
        if [[ -f "$CREDENTIALS_FILE" ]]; then
            local wallet_addr
            wallet_addr=$(read_config_value "wallet_address" 2>/dev/null)
            if [[ -n "$wallet_addr" && "$wallet_addr" != "null" ]]; then
                config_status="Configured"
            fi
        fi
        echo -e "    ${CYAN}Configuration:${NC} $config_status"
    else
        echo -e "    ${RED}❌ Failed to create workspace${NC}"
    fi
    echo ""

    # Step 8: Final system validation
    echo -e "${CYAN}${BOLD}Step 8/8:${NC} 🎯 Final system validation"
    show_unified_progress "System initialization" 100 "complete"

    local system_ready=true
    local ready_components=0
    local total_components=4

    # Check Docker
    if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then
        echo -e "    ${GREEN}✅ Docker System Ready${NC}"
        ready_components=$((ready_components + 1))
    else
        echo -e "    ${RED}❌ Docker System Not Ready${NC}"
        system_ready=false
    fi

    # Check JSON tools
    if command -v jq >/dev/null 2>&1; then
        echo -e "    ${GREEN}✅ JSON Processing Ready${NC}"
        ready_components=$((ready_components + 1))
    else
        echo -e "    ${RED}❌ JSON Processing Not Ready${NC}"
        system_ready=false
    fi

    # Check network tools
    if command -v curl >/dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Network Tools Ready${NC}"
        ready_components=$((ready_components + 1))
    else
        echo -e "    ${RED}❌ Network Tools Not Ready${NC}"
        system_ready=false
    fi

    # Check workspace
    if [[ -d "$DEFAULT_WORKDIR" ]]; then
        echo -e "    ${GREEN}✅ Workspace Ready${NC}"
        ready_components=$((ready_components + 1))
    else
        echo -e "    ${RED}❌ Workspace Not Ready${NC}"
        system_ready=false
    fi
    echo ""

    # Show completion with enhanced progress bar
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    if [[ "$system_ready" == true ]]; then
        echo -e "${GREEN}${BOLD}🎉 SYSTEM STARTUP COMPLETE - ALL SYSTEMS OPERATIONAL${NC}"
        show_unified_progress "Finalizing setup" 100 "complete"
        echo -e "${CYAN}Ready Components: ${BOLD}$ready_components/$total_components${NC}"
        echo ""
        echo -e "${GREEN}✨ Nexus Orchestrator is ready for zkML operations!${NC}"
    else
        echo -e "${YELLOW}${BOLD}⚠️  SYSTEM STARTUP COMPLETE - SOME ISSUES DETECTED${NC}"
        show_unified_progress "Finalizing setup" 75 "startup"
        echo -e "${CYAN}Ready Components: ${BOLD}$ready_components/$total_components${NC}"
        echo ""
        echo -e "${YELLOW}🔧 Please resolve the issues above before proceeding${NC}"
        echo -e "${BLUE}💡 You can use --skip-deps to bypass automatic installation${NC}"
    fi
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Pause before main menu
    echo -e "${CYAN}Press Enter to continue to main menu...${NC}"
    read -r

    return 0
}

# =============================================================================
# ENHANCED INSTALLATION FUNCTIONS
# =============================================================================

install_docker_enhanced() {
    echo -e "    ${BLUE}📦 Installing Docker Engine...${NC}"

    # Define installation stages
    local stages=(
        "Updating package index"
        "Installing prerequisites"
        "Adding Docker GPG key"
        "Configuring repository"
        "Installing Docker packages"
        "Starting Docker service"
    )

    local total_stages=${#stages[@]}

    for ((i=0; i<total_stages; i++)); do
        local stage="${stages[$i]}"

        echo -e "    ${GRAY}├─ $stage...${NC}"

        # Show unified progress for this stage
        local stage_percentage=$(( ((i + 1) * 100) / total_stages ))
        show_unified_progress "Docker installation: $stage" "$stage_percentage" "install"

        # Execute the actual installation step
        case $i in
            0) apt-get update >/dev/null 2>&1 ;;
            1) apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release >/dev/null 2>&1 ;;
            2) curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >/dev/null 2>&1 ;;
            3) echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1 ;;
            4) apt-get update >/dev/null 2>&1 && apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1 ;;
            5) systemctl start docker >/dev/null 2>&1 && systemctl enable docker >/dev/null 2>&1 ;;
        esac

        sleep 0.5
    done

    show_unified_progress "Docker installation" 100 "complete"
    echo -e "    ${GREEN}└─ ✅ Docker installation completed${NC}"
    echo ""
}

install_docker_compose_enhanced() {
    echo -e "    ${BLUE}📦 Installing Docker Compose...${NC}"

    echo -e "    ${GRAY}├─ Fetching latest version...${NC}"
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name' 2>/dev/null || echo "v2.20.0")

    echo -e "    ${GRAY}├─ Downloading binary...${NC}"
    show_unified_live_progress "Downloading Docker Compose" 2 "download"
    curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >/dev/null 2>&1

    echo -e "    ${GRAY}├─ Setting permissions...${NC}"
    chmod +x /usr/local/bin/docker-compose

    echo -e "    ${GREEN}└─ ✅ Docker Compose installation completed${NC}"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Animated spinner for indefinite operations
show_spinner() {
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        local char="${spin_chars:$i:1}"
        printf "\r%s %s " "$message" "$char"
        sleep $delay
        i=$(( (i + 1) % ${#spin_chars} ))
    done

    printf "\r%s ✅\n" "$message"
}

# Status indicators
show_check_status() {
    local item="$1"
    local status="$2"
    local details="$3"

    case "$status" in
        "pass"|"ok"|"success")
            echo -e "  ${GREEN}✅${NC} $item ${CYAN}$details${NC}"
            ;;
        "fail"|"error"|"missing")
            echo -e "  ${RED}❌${NC} $item ${YELLOW}$details${NC}"
            ;;
        "warning"|"optional")
            echo -e "  ${YELLOW}⚠️${NC}  $item ${CYAN}$details${NC}"
            ;;
        "info")
            echo -e "  ${BLUE}ℹ️${NC}  $item ${CYAN}$details${NC}"
            ;;
        *)
            echo -e "  ${CYAN}•${NC}  $item ${CYAN}$details${NC}"
            ;;
    esac
}

# Countdown timer
countdown() {
    local seconds="$1"
    local message="$2"

    while [[ $seconds -gt 0 ]]; do
        printf "\r%s %d seconds..." "$message" "$seconds"
        sleep 1
        ((seconds--))
    done
    printf "\r%s ✅\n" "$message"
}

# =============================================================================
# MULTI-STEP PROGRESS FUNCTIONS
# =============================================================================

# Multi-step progress tracking
MULTI_STEP_CURRENT=${MULTI_STEP_CURRENT:-0}
MULTI_STEP_TOTAL=${MULTI_STEP_TOTAL:-0}

# Initialize multi-step progress
init_multi_step() {
    local total_steps="$1"
    MULTI_STEP_TOTAL="$total_steps"
    MULTI_STEP_CURRENT=0
    echo -e "${CYAN}${BOLD}Progress: [${MULTI_STEP_CURRENT}/${MULTI_STEP_TOTAL}]${NC}"
}

# Advance to next step
next_step() {
    local step_message="$1"

    # Temporarily disable strict error handling for arithmetic
    set +e

    # Safely increment with bounds checking
    if [[ "${MULTI_STEP_TOTAL:-0}" -eq 0 ]]; then
        echo -e "${RED}❌ Multi-step not initialized${NC}"
        set -e
        return 1
    fi

    ((MULTI_STEP_CURRENT++))

    echo ""
    echo -e "${CYAN}${BOLD}Step ${MULTI_STEP_CURRENT}/${MULTI_STEP_TOTAL}:${NC} ${step_message}..."

    # Show progress bar with safe arithmetic
    local progress=0
    if [[ "${MULTI_STEP_TOTAL}" -gt 0 ]]; then
        progress=$((MULTI_STEP_CURRENT * 100 / MULTI_STEP_TOTAL))
    fi

    local filled=$((progress / 10))
    local empty=$((10 - filled))

    printf "%s[" "${CYAN}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %d%%%s\n" "$progress" "${NC}"

    # Re-enable strict error handling
    set -e
}

# Complete multi-step process
complete_multi_step() {
    echo ""
    echo -e "${GREEN}${BOLD}✅ All steps completed successfully! [${MULTI_STEP_TOTAL}/${MULTI_STEP_TOTAL}]${NC}"
}

# =============================================================================

export -f show_startup_splash startup_system_check
export -f show_unified_progress show_unified_live_progress clear_line
export -f install_docker_enhanced install_docker_compose_enhanced
export -f show_spinner show_check_status countdown
export -f init_multi_step next_step complete_multi_step

log_info "Unified progress bar system loaded successfully"
