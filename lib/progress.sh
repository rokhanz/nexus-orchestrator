#!/bin/bash

# progress.sh - Progress bar and status indication system
# Version: 4.0.0 - Professional progress indicators for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# PROGRESS BAR FUNCTIONS
# =============================================================================

# Show progress bar with percentage
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    local width="${4:-50}"

    # Calculate percentage
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done

    # Display progress
    printf "\r${CYAN}%s${NC} [%s] ${BOLD}%3d%%${NC} " "$message" "$bar" "$percentage"

    # Add newline when complete
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Animated spinner for indefinite operations
show_spinner() {
    local message="$1"
    local pid="$2"
    local delay=0.1
    local spin_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        local char="${spin_chars:$i:1}"
        printf "\r${CYAN}%s${NC} %s " "$message" "$char"
        sleep $delay
        i=$(( (i + 1) % ${#spin_chars} ))
    done

    printf "\r${GREEN}%s${NC} ✅\n" "$message"
}

# Multi-step progress indicator
init_multi_step() {
    local total_steps="$1"
    export PROGRESS_CURRENT_STEP=0
    export PROGRESS_TOTAL_STEPS="$total_steps"

    echo -e "${CYAN}${BOLD}📋 Starting $total_steps-step operation...${NC}"
    echo ""
}

next_step() {
    local step_name="$1"
    PROGRESS_CURRENT_STEP=$((PROGRESS_CURRENT_STEP + 1))

    echo -e "${BLUE}Step $PROGRESS_CURRENT_STEP/$PROGRESS_TOTAL_STEPS:${NC} $step_name"
    show_progress "$PROGRESS_CURRENT_STEP" "$PROGRESS_TOTAL_STEPS" "Overall Progress"
    echo ""
}

complete_multi_step() {
    echo ""
    echo -e "${GREEN}✅ All $PROGRESS_TOTAL_STEPS steps completed successfully!${NC}"
    echo ""
    unset PROGRESS_CURRENT_STEP PROGRESS_TOTAL_STEPS
}

# =============================================================================
# DEPENDENCY INSTALLATION PROGRESS
# =============================================================================

install_with_progress() {
    local package="$1"
    local description="$2"

    echo -e "${CYAN}📦 Installing $description...${NC}"

    # Start installation in background
    case "$package" in
        "docker")
            install_docker_quietly &
            ;;
        "docker-compose")
            install_docker_compose_quietly &
            ;;
        "jq")
            apt-get update >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1 &
            ;;
        "curl")
            apt-get update >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1 &
            ;;
        *)
            apt-get update >/dev/null 2>&1 && apt-get install -y "$package" >/dev/null 2>&1 &
            ;;
    esac

    local install_pid=$!
    show_spinner "Installing $description" "$install_pid"

    # Check if installation was successful
    wait "$install_pid"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "$description installed successfully"
        return 0
    else
        log_error "Failed to install $description"
        return 1
    fi
}

# =============================================================================
# DOCKER INSTALLATION HELPERS
# =============================================================================

install_docker_quietly() {
    # Update package index
    apt-get update >/dev/null 2>&1

    # Install prerequisites
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release >/dev/null 2>&1

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >/dev/null 2>&1

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1

    # Install Docker
    apt-get update >/dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1

    # Start Docker service
    systemctl start docker >/dev/null 2>&1
    systemctl enable docker >/dev/null 2>&1
}

install_docker_compose_quietly() {
    # Get latest version
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | \
                    jq -r '.tag_name' 2>/dev/null || echo "v2.20.0")

    # Download and install
    curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose >/dev/null 2>&1

    chmod +x /usr/local/bin/docker-compose >/dev/null 2>&1
}

# =============================================================================
# STATUS INDICATORS
# =============================================================================

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

# Progress for file operations
show_file_progress() {
    local operation="$1"
    local file_path="$2"
    local current_size="$3"
    local total_size="$4"

    if [[ -n "$total_size" && "$total_size" -gt 0 ]]; then
        local percentage=$((current_size * 100 / total_size))
        printf "\r${CYAN}%s${NC} %s... ${BOLD}%d%%${NC}" "$operation" "$(basename "$file_path")" "$percentage"
    else
        printf "\r${CYAN}%s${NC} %s..." "$operation" "$(basename "$file_path")"
    fi
}

# =============================================================================
# COUNTDOWN TIMER
# =============================================================================

countdown() {
    local seconds="$1"
    local message="$2"

    while [[ $seconds -gt 0 ]]; do
        printf "\r${YELLOW}%s${NC} ${BOLD}%d${NC} seconds..." "$message" "$seconds"
        sleep 1
        ((seconds--))
    done
    printf "\r${GREEN}%s${NC} ✅\n" "$message"
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f show_progress show_spinner init_multi_step next_step complete_multi_step
export -f install_with_progress install_docker_quietly install_docker_compose_quietly
export -f show_check_status show_file_progress countdown

log_info "Progress bar system loaded successfully"
