# 🚀 Nexus Orchestrator

## Advanced Docker-based Node Management System for Nexus Network

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Enabled-blue.svg)](https://www.docker.com/)
[![Nexus](https://img.shields.io/badge/Nexus-Network-purple.svg)](https://nexus.xyz/)

## 📋 Overview

Nexus Orchestrator is a comprehensive, modular Docker management system designed specifically for Nexus Network nodes. It provides an intuitive interface for managing multiple nodes, monitoring performance, handling wallets, and maintaining system health.

### 🌟 Key Features

- **🏗️ Modular Architecture**: Clean separation of concerns with specialized modules
- **🐳 Docker Integration**: Full Docker and Docker Compose management
- **📊 Real-time Monitoring**: Live node monitoring with performance metrics
- **🔑 Wallet Management**: Secure wallet creation, import, and backup
- **🌐 Multi-Node Support**: Manage multiple nodes simultaneously
- **🔧 Advanced Tools**: UFW firewall, proxy configuration, network diagnostics
- **📚 Comprehensive Guides**: Built-in documentation and troubleshooting
- **🔒 Security First**: Best practices for secure node operations

## 🎯 Quick Start

### Prerequisites

- **Operating System**: Ubuntu 20.04+ or similar Linux distribution
- **Architecture**: x86_64 (AMD64)
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: Minimum 50GB free space
- **Network**: Stable internet connection

### 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/rokhanz/nexus-orchestrator.git

# Navigate to directory
cd nexus-orchestrator

# Make executable
chmod +x main.sh
chmod +x helper/*.sh

# Run the orchestrator
bash main.sh
```

### ⚡ Auto-Setup

Nexus Orchestrator features **automatic dependency management**:

```bash
# Dependencies installed automatically:
- Docker (from official repository)
- Docker Compose (latest from GitHub)
- System packages (curl, jq, tar, gzip)
- User permissions (docker group)
```

## 📖 Usage Guide

### 🎯 First Time Setup

1. **Launch Orchestrator**
   ```bash
   cd nexus-orchestrator
   bash main.sh
   ```

2. **Setup Wallet & Node**

   - Navigate to `Wallet & Node Management` (Option 3)
   - Choose `Setup New Wallet + Node`
   - Follow the guided setup process
   - **Important**: Keep your credentials secure!

3. **Register Node**

   - Go to `Node Management` (Option 4)
   - Select `Register New Node`
   - Follow the prompts to register with Nexus Network

4. **Start Mining**

   - Use `Start with Existing Node ID`
   - Monitor progress in `Monitor Logs` (Option 2)

### 🔧 Main Menu Options

| Option                         | Description                                                     |
| ------------------------------ | --------------------------------------------------------------- |
| **🔧 Manage Docker & System**   | Docker health checks, container management, resource monitoring |
| **📊 Monitor Logs**             | Real-time log monitoring, statistics, error analysis            |
| **🔑 Wallet & Node Management** | Unified wallet and node ID management                           |
| **🌐 Node Management**          | Node registration, multi-node operations, statistics            |
| **⚙️ Advanced Tools**           | UFW firewall, proxy config, network diagnostics, backups        |
| **📚 How to Use**               | Complete usage guide and troubleshooting                        |

## 🏗️ Architecture

### Modular Design

```text
nexus-orchestrator/
├── main.sh                    # 🎯 Main entry point (routing only)
├── helper/
│   ├── common.sh              # 🔧 Shared utilities and dependencies
│   ├── docker-manager.sh      # 🐳 Docker operations and system management
│   ├── nexus-monitor.sh       # 📊 Monitoring, logs, and statistics
│   ├── node-manager.sh        # 🌐 Node operations and multi-node management
│   ├── wallet-manager.sh      # 🔑 Unified wallet and node operations
│   └── tools-manager.sh       # ⚙️ Advanced tools and system utilities
└── workdir/                   # 💾 Runtime data and configurations
    ├── credentials.json       # 🔐 Secure configuration storage
    ├── config/               # ⚙️ Node configurations
    ├── logs/                 # 📝 Application logs
    └── backup/               # 💾 Backup files
```

### Design Principles

- **🎯 Single Responsibility**: Each module has a clear, focused purpose
- **🔗 Loose Coupling**: Modules interact through well-defined interfaces
- **🛡️ Error Handling**: Comprehensive error checking and graceful degradation
- **📝 Logging**: Detailed logging for debugging and monitoring
- **🔒 Security**: Secure credential handling and system operations

## 📊 Features Detail

### 🐳 Docker Management

- **Health Monitoring**: Comprehensive system health checks
- **Resource Monitoring**: CPU, memory, disk usage tracking
- **Container Operations**: Start, stop, restart, clean operations
- **Compose Management**: Dynamic docker-compose.yml generation
- **Image Management**: Automatic image updates and cleanup

### 📈 Real-time Monitoring

- **Individual Node Monitoring**: Detailed logs with 10-second refresh
- **Multi-Node Dashboard**: All nodes overview with 15-second updates
- **Success Rate Analytics**: Performance statistics and trend analysis
- **Error Analysis**: Automated error detection and solutions
- **Performance Metrics**: System resource utilization tracking

### 🔐 Security Features

- **Secure Configuration**: Protected credential storage
- **UFW Firewall Management**: Automated port configuration
- **Proxy Support**: Rate limiting avoidance
- **Backup Encryption**: Secure configuration backups
- **Permission Management**: Proper user privilege handling

### 🌐 Multi-Node Operations

- **Bulk Operations**: Start/stop multiple nodes simultaneously
- **Load Balancing**: Distribute workload across nodes
- **Resource Allocation**: Monitor per-node resource usage
- **Configuration Sync**: Consistent settings across nodes
- **Health Monitoring**: Individual node health tracking

## 🔧 Advanced Configuration

### Environment Variables

```bash
# Optional environment variables
export NEXUS_HOME="/root/.nexus"
export RUST_LOG="info"
export TZ="Asia/Jakarta"

# Proxy configuration (if needed)
export HTTP_PROXY="http://user:pass@proxy:port"
export HTTPS_PROXY="http://user:pass@proxy:port"
```

### Docker Compose Customization

The system automatically generates `docker-compose.yml` files, but you can customize:

```yaml
# Example customization in generated compose
services:
  nexus-node-{ID}:
    image: nexusxyz/nexus-cli:latest
    container_name: nexus-node-{ID}
    restart: unless-stopped
    environment:
      - NEXUS_HOME=/root/.nexus
      - RUST_LOG=info
      - NODE_ID={ID}
      # Custom proxy settings
      - HTTP_PROXY=http://proxy:port
    volumes:
      - nexus_data_{ID}:/root/.nexus
    ports:
      - "{PORT}:{PORT}"
    command: ["start", "--headless", "--node-id", "{ID}"]
```

## 🔍 Troubleshooting

### Common Issues

| Issue                         | Solution                                                      |
| ----------------------------- | ------------------------------------------------------------- |
| **Docker daemon not running** | `sudo systemctl start docker && sudo systemctl enable docker` |
| **Permission denied**         | `sudo usermod -aG docker $USER` (then logout/login)           |
| **Node registration fails**   | Check internet connection and configuration                   |
| **Container restarts**        | Monitor logs and check system resources                       |
| **Rate limiting**             | Configure proxy in Advanced Tools                             |

### Log Locations

```bash
# Application logs
tail -f /root/nexus-orchestrator/workdir/nexus-manager.log

# Docker container logs
docker logs nexus-node-{NODE_ID}

# System logs
journalctl -u docker -f
```

### Diagnostic Commands

```bash
# System health
docker ps -a                    # Show all containers
docker system df               # Docker disk usage
sudo ufw status               # Firewall status
df -h                         # Disk space
free -h                       # Memory usage

# Network diagnostics
curl -s https://ipinfo.io/ip   # Public IP
ping nexus.xyz                # Network connectivity
docker network ls            # Docker networks
```

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Follow** our coding standards (see `.github/copilot-instructions.md`)
4. **Test** your changes thoroughly
5. **Commit** with clear messages
6. **Submit** a pull request

### Development Guidelines

- **Modular Architecture**: Maintain separation of concerns
- **Error Handling**: Include comprehensive error checking
- **Documentation**: Update README and inline comments
- **Testing**: Test on clean Ubuntu systems
- **Shell Standards**: Follow shellcheck recommendations

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Nexus Network** - For the innovative zk-proof network
- **Docker Community** - For containerization technology
- **Open Source Contributors** - For inspiration and tools

## 📞 Support

### Documentation

- **Built-in Guide**: Use Option 6 in main menu for comprehensive guides
- **Troubleshooting**: Detailed solutions for common issues
- **Best Practices**: Performance optimization tips

### Community & Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/rokhanz/nexus-orchestrator/issues)
- **Documentation**: Comprehensive guides available within the application
- **Support**: Check built-in troubleshooting guides

### 💝 Support Development

If this project helps you, consider supporting the development:

[![Support via Saweria](https://img.shields.io/badge/Support-Saweria-orange.svg)](https://saweria.co/rokhanz)

**Saweria**: [saweria.co/rokhanz](https://saweria.co/rokhanz)

## 🔄 Updates

### Latest Version Features

- ✅ **Auto-dependency management** with Docker installation
- ✅ **Enhanced UFW management** with IPv4/IPv6 simultaneous handling
- ✅ **Comprehensive How-to-Use guides** with 8 detailed sections
- ✅ **Improved error handling** and user feedback
- ✅ **Production-ready** modular architecture

### Update Instructions

```bash
# Backup current installation
cp -r nexus-orchestrator nexus-orchestrator-backup

# Pull latest changes
cd nexus-orchestrator
git pull origin main

# Restart with new features
bash main.sh
```

---

## ⭐ Star this repository if it helped you

**Made with ❤️ by [Rokhanz](https://github.com/rokhanz)**

### 🚀 Happy Mining with Nexus Network

---

## 🏷️ Tags

`nexus-network` `docker` `blockchain` `zk-proofs` `node-management` `orchestrator` `automation` `linux` `bash` `cryptocurrency` `mining` `multi-node`
