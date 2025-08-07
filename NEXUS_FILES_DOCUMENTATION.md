# 📋 Nexus Orchestrator - File Structure Documentation

## 🏗️ **Project Architecture Overview**

Nexus Orchestrator adalah enterprise-grade orchestration tool untuk Nexus zero-knowledge machine learning infrastructure dengan arsitektur modular yang terorganisir.

## 📁 **Core Directory Structure**

```
nexus-orchestrator/
├── 📄 main.sh                          # Entry point utama aplikasi
├── 📁 lib/                             # Core libraries dan modules
│   ├── 📄 common.sh                    # Shared utilities dan functions
│   ├── 📄 dependency_manager.sh        # System dependency management
│   ├── 📄 docker_memory_optimizer.sh   # Memory optimization untuk Docker
│   ├── 📄 log_viewer.sh                # Log viewing utilities
│   ├── 📄 logging.sh                   # Logging system
│   ├── 📄 port_manager.sh              # UFW firewall port management
│   ├── 📄 progress.sh                  # Progress bar system
│   ├── 📁 menus/                       # Interactive menu modules
│   │   ├── 📄 setup_menu.sh            # Initial setup dan konfigurasi
│   │   ├── 📄 manage_menu.sh           # Node management operations
│   │   ├── 📄 proxy_menu.sh            # Proxy configuration
│   │   ├── 📄 backup_menu.sh           # Backup dan restore system
│   │   ├── 📄 monitoring_menu.sh       # Real-time monitoring
│   │   └── 📄 uninstall_menu.sh        # System cleanup operations
│   └── 📁 wrappers/                    # API dan service wrappers
│       ├── 📄 api_wrapper.sh           # Nexus API communication
│       ├── 📄 backup_wrapper.sh        # Backup operations wrapper
│       ├── 📄 docker_wrapper.sh        # Docker operations wrapper
│       └── 📄 install_wrapper.sh       # Installation wrapper
├── 📁 workdir/                         # Working directory
│   ├── 📄 credentials.json             # User credentials storage
│   ├── 📄 docker-compose.yml           # Docker services configuration
│   ├── 📄 docker-compose-optimized.yml # Memory-optimized Docker config
│   ├── 📁 config/                      # Configuration files
│   │   └── 📄 auto_cache_config.json   # Auto cache configuration
│   ├── 📁 backup/                      # Backup storage
│   └── 📁 logs/                        # System logs
├── 📄 nexus_auto_cache_daemon.sh       # Background cache management daemon
├── 📄 nexus_cache_cleanup.sh           # Manual cache cleanup utility
└── 📄 nexus_logs.sh                    # Log management utility
```

## 🔧 **Core Components**

### **1. Main Entry Point**
- **`main.sh`**: Aplikasi utama dengan command-line interface, argument parsing, dan menu navigation

### **2. Core Libraries (`lib/`)**

#### **System Management:**
- **`common.sh`**: 150+ shared functions untuk utilities, logging, file operations, validation
- **`dependency_manager.sh`**: Auto-detection dan instalasi system dependencies (Docker, curl, jq, dll)
- **`docker_memory_optimizer.sh`**: Memory monitoring dan optimization untuk Docker containers
- **`port_manager.sh`**: UFW firewall management dan port configuration
- **`progress.sh`**: Unified progress bar system dengan multi-step operations

#### **Menu Modules (`lib/menus/`):**
- **`setup_menu.sh`**: Initial setup, wallet configuration, Node ID management
- **`manage_menu.sh`**: Node start/stop/restart, status monitoring, individual node control
- **`proxy_menu.sh`**: HTTP/HTTPS/SOCKS5 proxy configuration dan auto-detection
- **`backup_menu.sh`**: Full system backup, configuration backup, automated backup scheduling
- **`monitoring_menu.sh`**: Real-time monitoring, performance metrics, alert configuration
- **`uninstall_menu.sh`**: System cleanup, Docker component removal, factory reset

#### **Service Wrappers (`lib/wrappers/`):**
- **`api_wrapper.sh`**: Nexus API communication dan network status checking
- **`docker_wrapper.sh`**: Docker operations wrapper dengan error handling
- **`backup_wrapper.sh`**: Backup operations dengan compression dan verification
- **`install_wrapper.sh`**: Installation process wrapper dengan progress tracking

### **3. Working Directory (`workdir/`)**

#### **Configuration Files:**
- **`credentials.json`**: User wallet address, Node IDs, dan authentication data
- **`docker-compose.yml`**: Standard Docker services configuration
- **`docker-compose-optimized.yml`**: Memory-optimized Docker configuration
- **`config/auto_cache_config.json`**: Auto cache daemon configuration

#### **Data Storage:**
- **`backup/`**: Automated backup storage dengan timestamped files
- **`logs/`**: System logs, error logs, dan performance metrics

### **4. Daemon Scripts**
- **`nexus_auto_cache_daemon.sh`**: Background daemon untuk memory management
- **`nexus_cache_cleanup.sh`**: Manual cache cleanup operations
- **`nexus_logs.sh`**: Log management dan rotation

## ⚙️ **Technical Features**

### **🛡️ Shell Script Compliance:**
- ✅ **ShellCheck**: 100% compliant, no errors
- ✅ **Bash Standards**: `set -euo pipefail`, proper error handling
- ✅ **Security**: Input validation, safe file operations
- ✅ **Performance**: Optimized functions, minimal resource usage

### **🎯 Modular Architecture:**
- ✅ **Single Responsibility**: Each module has specific purpose
- ✅ **Dependency Injection**: Clean module loading dan sourcing
- ✅ **Error Isolation**: Proper error boundaries
- ✅ **Extensible**: Easy to add new modules

### **📊 Advanced Features:**
- ✅ **Real-time Monitoring**: Live container metrics
- ✅ **Memory Optimization**: Docker memory management
- ✅ **Auto Cache Management**: Background cleanup daemon
- ✅ **Multi-node Support**: Multiple Nexus nodes management
- ✅ **Backup System**: Automated backup dengan restoration
- ✅ **UFW Integration**: Firewall port management

## 🚀 **Usage Statistics**

```
Total Files: 42 files
Core Scripts: 23 shell scripts
Configuration: 6 config files
Documentation: 6 markdown files
Lines of Code: ~8,000+ lines
Functions: 200+ functions
Menus: 6 interactive menus
Features: 50+ features
```

## 🔄 **Data Flow Architecture**

```
User Input → main.sh → Menu Modules → Core Libraries → Service Wrappers → External Services
     ↓              ↓           ↓             ↓                ↓
Configuration → workdir/ → Docker Compose → Docker Containers → Nexus Network
     ↓              ↓           ↓             ↓
 Backup System → Logs → Monitoring → Alerts → Cache Management
```

## 🎯 **Key Advantages**

1. **Enterprise-Ready**: Professional-grade code quality dan error handling
2. **User-Friendly**: Interactive menus dengan clear guidance
3. **Automated**: Dependency detection, installation, dan management
4. **Scalable**: Multi-node support dengan individual control
5. **Reliable**: Comprehensive backup dan restore capabilities
6. **Optimized**: Memory management dan performance tuning
7. **Secure**: Permission checking dan validation
8. **Maintainable**: Clean code architecture dengan documentation

---

**Nexus Orchestrator v4.0** - *Enterprise zkML Infrastructure Management*
