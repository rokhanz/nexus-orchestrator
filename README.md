# 🚀 Nexus Orchestrator v4.0

[![Nexus Network](https://img.shields.io/badge/Nexus-Network-blue?style=for-the-badge&logo=ethereum&logoColor=white)](https://nexus.xyz)
[![Shell Script](https://img.shields.io/badge/Shell-Script-green?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Version](https://img.shields.io/badge/Version-4.0.0-brightgreen?style=for-the-badge)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

[![Quality](https://img.shields.io/badge/Code-Quality-A+?style=flat-square&color=success)](https://shellcheck.net)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passing-success?style=flat-square)](https://shellcheck.net)
[![Modular](https://img.shields.io/badge/Architecture-Modular-informational?style=flat-square)](https://github.com)
[![Enterprise](https://img.shields.io/badge/Grade-Enterprise-purple?style=flat-square)](https://github.com)

---

## ☕ Support Development

Jika project ini membantu Anda, pertimbangkan untuk mendukung pengembangan lebih lanjut:

[![Saweria](https://img.shields.io/badge/☕_Support_via-Saweria-orange?style=for-the-badge&logo=buy-me-a-coffee&logoColor=white)](https://saweria.co/rokhanz)

**[🎁 Dukung via Saweria.co/rokhanz](https://saweria.co/rokhanz)**

---

## 📖 Overview

**Nexus Orchestrator** adalah enterprise-grade orchestration tool untuk mengelola **Nexus zero-knowledge machine learning infrastructure**. Tool ini menyediakan interface yang user-friendly untuk deployment, monitoring, dan management node Nexus dengan fitur-fitur advanced seperti:

- 🔧 **Automated Setup**: Dependency detection dan installation otomatis
- 🎮 **Node Management**: Multi-node deployment, monitoring, dan control
- 🌐 **Proxy Support**: HTTP/HTTPS/SOCKS5 proxy configuration
- 📊 **Real-time Monitoring**: Live performance metrics dan health checks
- 💾 **Backup System**: Automated backup dan restore capabilities
- 🔥 **Memory Optimization**: Docker memory management dan auto-cleanup
- 🛡️ **Security**: Permission checking dan firewall management

## ✨ Key Features

### 🚀 **Enterprise-Ready**
- Professional-grade code quality dengan 100% ShellCheck compliance
- Comprehensive error handling dan logging system
- Modular architecture dengan single responsibility principle
- Advanced memory optimization untuk production deployment

### 🎯 **User Experience**
- Interactive menu system dengan clear navigation
- Automated dependency detection dan installation
- Real-time progress indicators dan status updates
- Contextual help dan troubleshooting guidance

### ⚙️ **Advanced Management**
- Multi-node Nexus deployment dengan individual control
- Docker container orchestration dengan memory optimization
- UFW firewall integration untuk port management
- Automated backup scheduling dengan compression

### 📊 **Monitoring & Analytics**
- Real-time container metrics dan performance monitoring
- Alert system dengan customizable thresholds
- Log aggregation dan analysis tools
- Export reports untuk performance analysis

## 🛠️ Installation

### Prerequisites

- **Operating System**: Linux (Ubuntu 18.04+, Debian 10+, CentOS 7+)
- **Architecture**: x86_64 atau ARM64
- **Memory**: Minimum 2GB RAM (Recommended: 4GB+)
- **Disk Space**: Minimum 5GB available space
- **Permissions**: Root access atau sudo privileges

### Quick Install

```bash
# Download Nexus Orchestrator
git clone https://github.com/rokhanz/nexus-orchestrator.git
cd nexus-orchestrator

# Make executable
chmod +x main.sh

# Run with automated setup
sudo ./main.sh
```

### Advanced Installation

```bash
# Install with specific options
./main.sh --health-check          # Run system health check only
./main.sh --skip-deps             # Skip dependency installation
./main.sh --skip-permissions      # Skip permission checks
./main.sh --dev-mode              # Enable debug mode
```

## 📋 Usage Guide

### 🔧 **Initial Setup**

1. **Run Setup Menu**:
   ```bash
   sudo ./main.sh
   # Select: 1. Initial Setup & Configuration
   ```

2. **Configure Components**:
   - Setup Nexus Docker images
   - Configure wallet address for NEX rewards
   - Setup Node IDs (single atau multiple nodes)
   - Verify installation

### 🎮 **Node Management**

```bash
# Access Management Menu
# Select: 2. Nexus Management

# Available Operations:
- Start All Nodes              # Launch all configured nodes
- Stop All Nodes               # Graceful shutdown all nodes
- Restart All Nodes            # Restart all services
- Individual Node Control      # Manage specific nodes
- Performance Metrics          # View detailed stats
- Cache Cleanup                # Memory optimization
```

### 🌐 **Proxy Configuration**

```bash
# Configure proxy settings
# Select: 3. Proxy Configuration

# Supported Proxy Types:
- HTTP/HTTPS Proxy            # Standard web proxy
- SOCKS5 Proxy               # Advanced proxy protocol
- Auto-Detection             # Automatic proxy discovery
- Proxy Testing              # Connection verification
```

### 📊 **Monitoring & Analytics**

```bash
# Advanced monitoring features
# Select: 2. Management → 7. Performance Metrics

# Monitor:
- Real-time container metrics
- Memory usage dan optimization
- Network statistics
- Proof generation statistics
- Health dashboard
- Alert configuration
```

## 📁 Project Structure

```
nexus-orchestrator/
├── main.sh                     # Main application entry point
├── lib/                        # Core libraries
│   ├── common.sh              # Shared utilities (150+ functions)
│   ├── dependency_manager.sh  # System dependency management
│   ├── docker_memory_optimizer.sh # Memory optimization
│   ├── menus/                 # Interactive menu modules (6 menus)
│   └── wrappers/              # Service wrappers (4 modules)
├── workdir/                   # Working directory
│   ├── credentials.json       # User configuration
│   ├── docker-compose.yml     # Docker services
│   ├── config/               # Configuration files
│   ├── backup/              # Backup storage
│   └── logs/                # System logs
└── nexus_*.sh               # Daemon scripts & utilities
```

## 🔧 Configuration

### Environment Variables

```bash
# Core Configuration
NEXUS_WALLET_ADDRESS="0x..."      # Your Ethereum wallet address
NEXUS_NODE_IDS='["id1","id2"]'    # Node IDs (JSON array)

# Advanced Settings
NEXUS_WORKDIR="/path/to/workdir"   # Working directory path
NEXUS_LOG_LEVEL="INFO"             # Logging level (DEBUG/INFO/WARN/ERROR)
NEXUS_AUTO_CLEANUP="true"          # Enable auto cache cleanup
NEXUS_MEMORY_LIMIT="512m"          # Docker memory limit per container
```

### Configuration Files

- **`workdir/credentials.json`**: User credentials dan node configuration
- **`workdir/docker-compose.yml`**: Docker services configuration
- **`workdir/config/auto_cache_config.json`**: Auto cache daemon settings

## 📊 Performance & Optimization

### Memory Management

```bash
# Automatic memory optimization
./main.sh
# Select: 2. Management → C. Cache Cleanup

# Features:
- Docker container memory monitoring
- Automatic cache cleanup daemon
- Memory usage alerts
- Container restart optimization
```

### Multi-Node Deployment

```bash
# Configure multiple nodes
# Setup Menu → 3. Setup Node ID

# Benefits:
- Load distribution across nodes
- Redundancy untuk high availability
- Individual node monitoring
- Scalable resource management
```

## 🛡️ Security Features

### Permission Management
- Root privilege checking
- Docker daemon access verification
- File system permission validation
- UFW firewall integration

### Data Protection
- Encrypted credential storage
- Automated backup dengan compression
- Safe configuration management
- Secure API communication

## 📈 Monitoring & Alerts

### Real-time Metrics
- Container CPU/Memory usage
- Network throughput statistics
- Proof generation performance
- System health indicators

### Alert System
```bash
# Configure alerts
# Management Menu → Performance Metrics → Configure Alerts

# Alert Types:
- CPU usage thresholds
- Memory usage limits
- Disk space warnings
- Container health status
```

## 🔄 Backup & Restore

### Automated Backup
```bash
# Backup Management
# Select: Management → Advanced Features → Backup Menu

# Backup Types:
- Full System Backup          # Complete system state
- Configuration Backup        # Settings dan credentials only
- Logs Backup                # System logs archive
- Automated Scheduling       # Periodic backups
```

### Restore Operations
- Point-in-time restoration
- Selective file recovery
- Configuration rollback
- Safety backup verification

## 🐛 Troubleshooting

### Common Issues

**1. Docker Permission Denied**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Logout and login again
```

**2. Memory Issues**
```bash
# Enable memory optimization
./main.sh
# Select: Management → C. Cache Cleanup
```

**3. Network Connectivity**
```bash
# Test network dan proxy
./main.sh
# Select: 3. Proxy Configuration → 4. Test Connection
```

### Debug Mode

```bash
# Enable detailed error reporting
./main.sh --dev-mode

# Check logs
tail -f workdir/logs/nexus-orchestrator.log
```

## 🆘 Support & Community

### Getting Help

- 📖 **Documentation**: Complete documentation dalam project
- 🐛 **Bug Reports**: Use GitHub Issues untuk bug reports
- 💡 **Feature Requests**: Submit enhancement ideas
- 💬 **Community**: Join Nexus Network community

### Contributing

Kontribusi sangat diterima! Silakan:

1. Fork repository ini
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push ke branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 Changelog

### v4.0.0 (Latest)
- ✅ Complete rewrite dengan modular architecture
- ✅ Advanced memory optimization dan monitoring
- ✅ Multi-node support dengan individual control
- ✅ Automated backup dan restore system
- ✅ Real-time performance metrics
- ✅ UFW firewall integration
- ✅ 100% ShellCheck compliance
- ✅ Enterprise-grade error handling

### v3.x.x (Legacy)
- Basic node management
- Simple Docker deployment
- Manual configuration

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⭐ Acknowledgments

- **Nexus Network** - For the innovative zkML infrastructure
- **Docker Community** - For containerization technology
- **Shell Script Community** - For best practices dan standards
- **Contributors** - For continuous improvement

---

<div align="center">

## 🎯 **Nexus Orchestrator v4.0**
### *Enterprise zkML Infrastructure Management*

**[🎁 Support Development via Saweria](https://saweria.co/rokhanz)**

[![Saweria](https://img.shields.io/badge/☕_Donate-Saweria-orange?style=for-the-badge)](https://saweria.co/rokhanz)

*Made with ❤️ for the Nexus Community*

</div>

---

**© 2025 Nexus Orchestrator - Enterprise zkML Infrastructure Management**

🎛️ **Intelligent zkML Infrastructure Management** - Enterprise Edition

## 📋 Overview

Nexus Orchestrator adalah alat manajemen infrastruktur enterprise-grade untuk sistem zero-knowledge machine learning (zkML) Nexus. Sistem ini menyediakan interface terpadu untuk mengatur, memantau, dan mengelola node-node Nexus dengan mudah.

## ✨ Features

- **🔧 Initial Setup & Configuration** - Konfigurasi wallet dan node ID
- **🎮 Nexus Management** - Start, stop, dan monitor layanan
- **🌐 Proxy Configuration** - Manajemen proxy untuk koneksi
- **📊 API & Network Monitoring** - Pemantauan real-time
- **🗑️ System Uninstall & Cleanup** - Pembersihan sistem yang aman
- **📋 Progress Bar Terpadu** - Sistem progress bar yang unified

## 🚀 Quick Start

```bash
# Jalankan dengan mode normal
./main.sh

# Skip dependency check
./main.sh --skip-deps

# Health check only
./main.sh --health-check

# Development mode
./main.sh --dev-mode
```

## 📁 Struktur Project

```
nexus-orchestrator/
├── main.sh                    # Entry point utama
├── README.md                  # Dokumentasi ini
├── SYSTEM_READY.md           # Status sistem
├── lib/
│   ├── common.sh             # Fungsi-fungsi umum
│   ├── progress.sh           # Sistem progress bar unified
│   ├── dependency_manager.sh # Manajemen dependensi
│   ├── menus/               # Menu-menu interface
│   └── wrappers/            # Wrapper untuk layanan
└── workdir/                 # Directory kerja
    ├── credentials.json     # Konfigurasi kredensial
    ├── docker-compose.yml   # Docker configuration
    └── logs/               # Log files
```

## 🔧 Configuration

Semua konfigurasi disimpan dalam `workdir/credentials.json`:

```json
{
  "wallet_address": "your_wallet_address",
  "node_id": ["node1", "node2", "..."]
}
```

## 🛡️ Security Features

- ✅ Validasi input yang ketat
- ✅ Backup otomatis konfigurasi
- ✅ Error handling yang robust
- ✅ Shellcheck compliance
- ✅ Logging yang komprehensif

## 📊 System Status

Sistem ini mendukung:
- Multiple Node ID management
- Real-time monitoring
- Docker containerization
- Proxy configuration
- API monitoring

## 🆘 Support

Untuk bantuan:
1. Gunakan menu Help (Option 7)
2. Periksa log files di `workdir/logs/`
3. Jalankan `--health-check` untuk diagnostik

## 📝 Version

- **Version**: 4.0.0
- **Build**: $(date '+%Y-%m-%d')
- **Architecture**: Intelligent zkML Infrastructure Management
