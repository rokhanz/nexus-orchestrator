# 📁 Nexus Orchestrator - File Usage Summary

## 🎯 **File yang Terpakai dalam Nexus Orchestrator v4.0**

### **📊 Total Statistics:**
- **Total Files**: 42 files
- **Shell Scripts**: 23 files (.sh)
- **Configuration**: 6 files (.json/.yml)
- **Documentation**: 6 files (.md)
- **Lines of Code**: ~8,000+ lines
- **Functions**: 200+ functions

---

## 🔧 **Core Application Files**

### **1. Main Entry Point:**
```bash
main.sh                    # Main application dengan CLI interface
├─ Command line parsing
├─ Menu navigation system
├─ Permission checking
└─ Module loading
```

### **2. Core Libraries (lib/):**
```bash
common.sh                  # 150+ shared functions
├─ Logging system
├─ File operations
├─ Input validation
├─ Error handling
├─ Color output
└─ Utility functions

dependency_manager.sh      # System dependency management
├─ Auto-detect OS dan architecture
├─ Install Docker, curl, jq, dll
├─ System requirements checking
└─ Progress tracking

docker_memory_optimizer.sh # Memory optimization
├─ Container memory monitoring
├─ Auto cleanup daemon
├─ Memory usage alerts
└─ Performance tuning

port_manager.sh           # UFW firewall management
├─ Port opening/closing
├─ UFW status checking
├─ Firewall rules management
└─ Security validation

progress.sh               # Progress bar system
├─ Multi-step progress tracking
├─ Real-time updates
├─ Status indicators
└─ User feedback
```

### **3. Interactive Menus (lib/menus/):**
```bash
setup_menu.sh             # Initial setup dan konfigurasi
├─ Docker image installation
├─ Wallet address configuration
├─ Node ID management (multi-node)
├─ Installation verification
└─ System prerequisites

manage_menu.sh            # Node management operations
├─ Start/Stop/Restart nodes
├─ Individual node control
├─ Performance monitoring
├─ Status checking
├─ Log viewing
└─ Cache cleanup

proxy_menu.sh             # Proxy configuration
├─ HTTP/HTTPS proxy setup
├─ SOCKS5 proxy configuration
├─ Auto-detection
├─ Connection testing
└─ Proxy validation

backup_menu.sh            # Backup dan restore system
├─ Full system backup
├─ Configuration backup
├─ Logs backup
├─ Automated scheduling
├─ Restore operations
└─ Backup verification

monitoring_menu.sh        # Real-time monitoring
├─ Container metrics
├─ Resource monitoring
├─ Performance statistics
├─ Alert configuration
├─ Health dashboard
└─ Export reports

uninstall_menu.sh         # System cleanup
├─ Container removal
├─ Configuration cleanup
├─ Docker component removal
├─ System cleanup
├─ Factory reset
└─ Safe uninstallation
```

### **4. Service Wrappers (lib/wrappers/):**
```bash
api_wrapper.sh            # Nexus API communication
├─ Network status checking
├─ API connectivity tests
├─ Reward checking
└─ Error handling

docker_wrapper.sh         # Docker operations wrapper
├─ Container management
├─ Image operations
├─ Docker compose handling
└─ Error recovery

backup_wrapper.sh         # Backup operations
├─ File compression
├─ Backup verification
├─ Restore operations
└─ Safety checks

install_wrapper.sh        # Installation wrapper
├─ Package installation
├─ Progress tracking
├─ Error handling
└─ Dependency resolution
```

---

## 💾 **Configuration & Data Files**

### **Working Directory (workdir/):**
```bash
credentials.json          # User configuration
├─ Wallet address
├─ Node IDs (JSON array)
├─ User preferences
└─ Authentication data

docker-compose.yml        # Standard Docker config
├─ Container definitions
├─ Network configuration
├─ Volume mappings
└─ Environment variables

docker-compose-optimized.yml # Memory-optimized config
├─ Memory limits
├─ Resource constraints
├─ Performance tuning
└─ Production settings

config/
├─ auto_cache_config.json # Cache daemon settings
├─ monitoring_config.json # Alert thresholds
└─ proxy_config.json      # Proxy settings

backup/                   # Backup storage
├─ Full system backups
├─ Configuration backups
├─ Timestamped archives
└─ Recovery points

logs/                     # System logs
├─ Application logs
├─ Error logs
├─ Performance metrics
└─ Audit trails
```

---

## 🤖 **Daemon & Utility Scripts**

```bash
nexus_auto_cache_daemon.sh # Background cache management
├─ Memory monitoring
├─ Automatic cleanup
├─ Resource optimization
└─ Performance tuning

nexus_cache_cleanup.sh    # Manual cache cleanup
├─ Docker system prune
├─ Log rotation
├─ Temporary file cleanup
└─ Disk space recovery

nexus_logs.sh            # Log management utility
├─ Log aggregation
├─ Log filtering
├─ Log rotation
└─ Export functionality
```

---

## 📚 **Documentation Files**

```bash
README.md                 # Main project documentation
├─ Installation guide
├─ Usage instructions
├─ Feature descriptions
├─ Troubleshooting
└─ Support information

NEXUS_FILES_DOCUMENTATION.md # File structure guide
├─ Architecture overview
├─ Component descriptions
├─ Technical details
└─ Data flow diagrams

SYSTEM_READY.md          # System readiness guide
DOCKER_MEMORY_IMPLEMENTATION.md # Memory optimization docs
STRUKTUR_FILE.md         # File structure reference
COPILOT.INSTRUCTIONS.md  # Development guidelines
```

---

## ⚙️ **Development & Configuration**

```bash
.vscode/                  # VS Code settings
├─ settings.json         # Editor configuration
└─ keybindings.json      # Keyboard shortcuts

.gitignore               # Git ignore rules
├─ Temporary files
├─ Log files
├─ Sensitive data
└─ Build artifacts
```

---

## 🔄 **Data Flow Architecture**

```
User → main.sh → Menu Modules → Core Libraries → Service Wrappers → External Services
  ↓        ↓          ↓             ↓                 ↓              ↓
Config → workdir/ → credentials.json → docker-compose.yml → Docker → Nexus Network
  ↓        ↓          ↓             ↓                 ↓              ↓
Backup → backup/ → logs/ → monitoring → alerts → cache cleanup → optimization
```

---

## 🎯 **Key File Categories**

### **🔧 Core System (4 files):**
- main.sh
- lib/common.sh
- lib/dependency_manager.sh
- lib/progress.sh

### **🎮 Interactive Modules (6 files):**
- lib/menus/*.sh (6 menu modules)

### **🌐 Service Integration (4 files):**
- lib/wrappers/*.sh (4 wrapper modules)

### **💾 Configuration (6 files):**
- workdir/*.json
- workdir/*.yml
- workdir/config/*.json

### **🤖 Automation (3 files):**
- nexus_auto_cache_daemon.sh
- nexus_cache_cleanup.sh
- nexus_logs.sh

### **📚 Documentation (6 files):**
- README.md
- NEXUS_FILES_DOCUMENTATION.md
- Various .md files

---

## 🚀 **Usage Pattern**

1. **Entry Point**: `main.sh` → Parse arguments → Load libraries
2. **Menu System**: Interactive navigation → Menu modules
3. **Operations**: Core libraries → Service wrappers → External calls
4. **Data Storage**: Configuration → workdir/ → JSON/YAML files
5. **Monitoring**: Real-time metrics → Alerts → Optimization
6. **Maintenance**: Background daemons → Cleanup → Backup

---

**🎯 Total: 42 files working together to provide enterprise-grade Nexus zkML infrastructure management.**
