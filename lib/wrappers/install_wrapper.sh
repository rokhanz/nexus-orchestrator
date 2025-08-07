#!/bin/bash

# install_wrapper.sh - Installation Operations Wrapper
# Version: 4.0.0 - Complex installation operations for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# INSTALL WRAPPER CONFIGURATION
# =============================================================================

readonly INSTALL_WRAPPER_MAX_RETRIES=3
readonly INSTALL_WRAPPER_RETRY_DELAY=10
export INSTALL_WRAPPER_TIMEOUT=300  # Used externally

# =============================================================================
# MAIN INSTALL WRAPPER FUNCTION
# =============================================================================

install_wrapper() {
    local operation="$1"
    shift

    log_activity "Install wrapper: $operation operation requested"

    # Pre-execution validation
    if ! validate_system_requirements; then
        return 1
    fi

    # Execute operation with retry logic
    case "$operation" in
        "docker")
            install_docker_with_retry "$@"
            ;;
        "docker_compose")
            install_docker_compose_with_retry "$@"
            ;;
        "nexus_prover")
            install_nexus_prover_with_retry "$@"
            ;;
        "system_packages")
            install_system_packages_with_retry "$@"
            ;;
        *)
            log_error "Unknown installation operation: $operation"
            return 1
            ;;
    esac

    local exit_code=$?

    # Post-execution validation
    if [[ $exit_code -eq 0 ]]; then
        log_success "Install wrapper: $operation completed successfully"
    else
        handle_error "Install wrapper: $operation failed with exit code $exit_code"
    fi

    return $exit_code
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_system_requirements() {
    local validation_ok=true

    # Check if running as root or with sudo capabilities
    if [[ $EUID -ne 0 ]] && ! sudo -v >/dev/null 2>&1; then
        log_error "Root privileges required for installation operations"
        validation_ok=false
    fi

    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_warning "No internet connectivity detected"
    fi

    # Check available disk space (minimum 2GB)
    local available_space
    available_space=$(df /tmp | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then  # 2GB in KB
        log_warning "Low disk space: $((available_space/1024))MB available"
    fi

    [[ "$validation_ok" == true ]]
}

check_package_manager() {
    local package_manager=""

    if command -v apt-get >/dev/null 2>&1; then
        package_manager="apt"
    elif command -v yum >/dev/null 2>&1; then
        package_manager="yum"
    elif command -v dnf >/dev/null 2>&1; then
        package_manager="dnf"
    else
        log_error "No supported package manager found"
        return 1
    fi

    echo "$package_manager"
    return 0
}

# =============================================================================
# DOCKER INSTALLATION WITH RETRY
# =============================================================================

install_docker_with_retry() {
    local retries=0

    log_activity "Installing Docker with retry logic"

    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker is already installed"
        if docker --version >/dev/null 2>&1; then
            log_success "Docker installation verified"
            return 0
        fi
    fi

    while [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; do
        if install_docker_operation; then
            log_success "Docker installation completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Docker installation failed (attempt $retries), retrying in $INSTALL_WRAPPER_RETRY_DELAY seconds..."
                sleep $INSTALL_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Docker installation failed after $INSTALL_WRAPPER_MAX_RETRIES attempts"
    return 1
}

install_docker_operation() {
    local package_manager
    package_manager=$(check_package_manager) || return 1

    log_activity "Installing Docker using $package_manager"

    case "$package_manager" in
        "apt")
            install_docker_ubuntu_debian
            ;;
        "yum"|"dnf")
            install_docker_centos_rhel
            ;;
        *)
            log_error "Unsupported package manager: $package_manager"
            return 1
            ;;
    esac

    local install_result=$?

    if [[ $install_result -eq 0 ]]; then
        # Verify Docker installation
        if verify_docker_installation; then
            log_success "Docker installed and verified successfully"
            return 0
        else
            log_error "Docker installation verification failed"
            return 1
        fi
    else
        log_error "Docker installation failed"
        return 1
    fi
}

install_docker_ubuntu_debian() {
    log_activity "Installing Docker on Ubuntu/Debian"

    # Update package index
    if ! sudo apt-get update >/dev/null 2>&1; then
        log_error "Failed to update package index"
        return 1
    fi

    # Install prerequisites
    if ! sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release >/dev/null 2>&1; then
        log_error "Failed to install Docker prerequisites"
        return 1
    fi

    # Install Docker
    if ! sudo apt-get install -y docker.io >/dev/null 2>&1; then
        log_error "Failed to install Docker packages"
        return 1
    fi

    # Start Docker service
    if ! sudo systemctl start docker >/dev/null 2>&1; then
        log_error "Failed to start Docker service"
        return 1
    fi

    # Enable Docker service for auto-start
    if ! sudo systemctl enable docker >/dev/null 2>&1; then
        log_warning "Failed to enable Docker service for auto-start"
    fi

    return 0
}

install_docker_centos_rhel() {
    log_activity "Installing Docker on CentOS/RHEL"

    local package_manager
    package_manager=$(check_package_manager)

    # Install Docker
    if ! sudo "$package_manager" install -y docker >/dev/null 2>&1; then
        log_error "Failed to install Docker packages"
        return 1
    fi

    # Start Docker service
    if ! sudo systemctl start docker >/dev/null 2>&1; then
        log_error "Failed to start Docker service"
        return 1
    fi

    # Enable Docker service for auto-start
    if ! sudo systemctl enable docker >/dev/null 2>&1; then
        log_warning "Failed to enable Docker service for auto-start"
    fi

    return 0
}

verify_docker_installation() {
    log_activity "Verifying Docker installation"

    # Check if Docker command is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker command not found"
        return 1
    fi

    # Check Docker version
    if ! docker --version >/dev/null 2>&1; then
        log_error "Docker version check failed"
        return 1
    fi

    return 0
}

# =============================================================================
# DOCKER COMPOSE INSTALLATION WITH RETRY
# =============================================================================

install_docker_compose_with_retry() {
    local retries=0

    log_activity "Installing Docker Compose with retry logic"

    # Check if Docker Compose is already installed
    if command -v docker-compose >/dev/null 2>&1; then
        log_info "Docker Compose is already installed"
        if docker-compose --version >/dev/null 2>&1; then
            log_success "Docker Compose installation verified"
            return 0
        fi
    fi

    while [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; do
        if install_docker_compose_operation; then
            log_success "Docker Compose installation completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Docker Compose installation failed (attempt $retries), retrying in $INSTALL_WRAPPER_RETRY_DELAY seconds..."
                sleep $INSTALL_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Docker Compose installation failed after $INSTALL_WRAPPER_MAX_RETRIES attempts"
    return 1
}

install_docker_compose_operation() {
    log_activity "Installing Docker Compose"

    local package_manager
    package_manager=$(check_package_manager) || return 1

    case "$package_manager" in
        "apt")
            sudo apt-get install -y docker-compose >/dev/null 2>&1
            ;;
        "yum"|"dnf")
            sudo "$package_manager" install -y docker-compose >/dev/null 2>&1
            ;;
        *)
            log_error "Unsupported package manager: $package_manager"
            return 1
            ;;
    esac

    # Verify installation
    if verify_docker_compose_installation; then
        log_success "Docker Compose installed successfully"
        return 0
    else
        log_error "Docker Compose installation verification failed"
        return 1
    fi
}

verify_docker_compose_installation() {
    log_activity "Verifying Docker Compose installation"

    # Check if Docker Compose command is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose command not found"
        return 1
    fi

    # Check Docker Compose version
    if ! docker-compose --version >/dev/null 2>&1; then
        log_error "Docker Compose version check failed"
        return 1
    fi

    return 0
}

# =============================================================================
# NEXUS PROVER INSTALLATION WITH RETRY
# =============================================================================

install_nexus_prover_with_retry() {
    local retries=0

    log_activity "Installing Nexus Prover with retry logic"

    while [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; do
        if install_nexus_prover_operation; then
            log_success "Nexus Prover installation completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; then
                log_warning "Nexus Prover installation failed (attempt $retries), retrying in $INSTALL_WRAPPER_RETRY_DELAY seconds..."
                sleep $INSTALL_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "Nexus Prover installation failed after $INSTALL_WRAPPER_MAX_RETRIES attempts"
    return 1
}

install_nexus_prover_operation() {
    log_activity "Installing Nexus Prover"

    # Ensure Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required for Nexus Prover installation"
        return 1
    fi

    # Pull Nexus Prover Docker image
    if ! docker pull nexus-labs/nexus-prover:latest >/dev/null 2>&1; then
        log_error "Failed to pull Nexus Prover Docker image"
        return 1
    fi

    log_success "Nexus Prover Docker image installed successfully"
    return 0
}

# =============================================================================
# SYSTEM PACKAGES INSTALLATION WITH RETRY
# =============================================================================

install_system_packages_with_retry() {
    local packages=("$@")
    local retries=0

    log_activity "Installing system packages with retry logic: ${packages[*]}"

    while [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; do
        if install_system_packages_operation "${packages[@]}"; then
            log_success "System packages installation completed"
            return 0
        else
            retries=$((retries + 1))
            if [[ $retries -lt $INSTALL_WRAPPER_MAX_RETRIES ]]; then
                log_warning "System packages installation failed (attempt $retries), retrying in $INSTALL_WRAPPER_RETRY_DELAY seconds..."
                sleep $INSTALL_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "System packages installation failed after $INSTALL_WRAPPER_MAX_RETRIES attempts"
    return 1
}

install_system_packages_operation() {
    local packages=("$@")
    local package_manager
    package_manager=$(check_package_manager) || return 1

    log_activity "Installing packages using $package_manager: ${packages[*]}"

    case "$package_manager" in
        "apt")
            # Update package index
            sudo apt-get update >/dev/null 2>&1 || {
                log_error "Failed to update package index"
                return 1
            }

            # Install packages
            sudo apt-get install -y "${packages[@]}" >/dev/null 2>&1 || {
                log_error "Failed to install packages with apt"
                return 1
            }
            ;;
        "yum")
            sudo yum install -y "${packages[@]}" >/dev/null 2>&1 || {
                log_error "Failed to install packages with yum"
                return 1
            }
            ;;
        "dnf")
            sudo dnf install -y "${packages[@]}" >/dev/null 2>&1 || {
                log_error "Failed to install packages with dnf"
                return 1
            }
            ;;
        *)
            log_error "Unsupported package manager: $package_manager"
            return 1
            ;;
    esac

    log_success "System packages installed successfully"
    return 0
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f install_wrapper validate_system_requirements check_package_manager
export -f install_docker_with_retry install_docker_operation
export -f install_docker_ubuntu_debian install_docker_centos_rhel
export -f verify_docker_installation install_docker_compose_with_retry
export -f install_docker_compose_operation verify_docker_compose_installation
export -f install_nexus_prover_with_retry install_nexus_prover_operation
export -f install_system_packages_with_retry install_system_packages_operation

log_success "Install wrapper loaded successfully"
