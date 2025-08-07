# 📁 STRUKTUR FILE DAN FOLDER NEXUS ORCHESTRATOR

## 🏗️ STRUKTUR UTAMA

```
nexus-orchestrator/
├── 📄 main.sh                          # Entry point utama aplikasi
├── 📄 nexus_cache_cleanup.sh           # Utility manual cache cleanup
├── 📄 nexus_logs.sh                    # Enhanced log viewer dengan warna
├── 📄 nexus_auto_cache_daemon.sh       # Background daemon auto cache
├── 📄 README.md                        # Dokumentasi utama
├── 📄 SYSTEM_READY.md                  # Status sistem siap deploy
├── 📄 COPILOT.INSTRUCTIONS.md          # Instruksi untuk AI assistant
├── 📄 .gitignore                       # Git ignore rules
│
├── 📁 .vscode/                         # VS Code configuration
│   ├── settings.json                   # Editor settings
│   └── keybindings.json               # Keyboard shortcuts
│
├── 📁 lib/                             # Library modules
│   ├── 📄 common.sh                    # Common functions & variables
│   ├── 📄 dependency_manager.sh        # Dependency management
│   ├── 📄 log_viewer.sh               # Advanced log viewer functions
│   ├── 📄 logging.sh                  # Logging system
│   ├── 📄 port_manager.sh             # Port & cache management
│   ├── 📄 progress.sh                 # Progress bar system
│   │
│   ├── 📁 menus/                      # Menu modules
│   │   ├── backup_menu.sh             # Backup & restore functions
│   │   ├── manage_menu.sh             # Node management menu
│   │   ├── monitoring_menu.sh         # Monitoring & auto cache menu
│   │   ├── proxy_menu.sh              # Proxy configuration
│   │   ├── setup_menu.sh              # Initial setup & configuration
│   │   └── uninstall_menu.sh          # Uninstall & cleanup
│   │
│   └── 📁 wrappers/                   # Wrapper modules
│       ├── api_wrapper.sh             # API communication wrapper
│       ├── backup_wrapper.sh          # Backup operations wrapper
│       ├── docker_wrapper.sh          # Docker operations wrapper
│       └── install_wrapper.sh         # Installation wrapper
│
└── 📁 workdir/                        # Working directory
    ├── 📄 credentials.json             # Node credentials
    ├── 📄 docker-compose.yml          # Docker configuration
    ├── 📄 nexus-manager.log           # Manager logs
    ├── 📄 nexus-orchestrator.log      # Main application logs
    ├── 📄 proxy_list.txt.example      # Proxy configuration example
    │
    ├── 📁 backup/                     # Backup storage
    │   ├── credentials.json.backup    # Credential backups
    │   ├── docker-compose.yml.backup  # Docker config backups
    │   └── test_file.txt.backup      # Test file backups
    │
    ├── 📁 config/                     # Configuration files
    │   └── auto_cache_config.json     # Auto cache daemon config
    │
    └── 📁 logs/                       # Log directory
        └── (auto_cache_daemon.log)    # Daemon logs (generated)
```

## 🎯 FUNGSI SETIAP KOMPONEN

### 📋 Core Files
- **main.sh**: Entry point utama, menu navigation
- **nexus_cache_cleanup.sh**: Manual cache cleanup utility
- **nexus_logs.sh**: Enhanced log viewer dengan color coding
- **nexus_auto_cache_daemon.sh**: Background daemon untuk auto cache cleanup

### 📚 Library Modules (lib/)
- **common.sh**: Functions umum, logging, validasi
- **dependency_manager.sh**: Management dependencies sistem
- **log_viewer.sh**: Advanced log viewing functions
- **logging.sh**: Comprehensive logging system
- **port_manager.sh**: Port management & cache cleanup functions
- **progress.sh**: Progress bar dan status display

### 📋 Menu Modules (lib/menus/)
- **setup_menu.sh**: Initial configuration, credential setup
- **manage_menu.sh**: Node management, start/stop/restart
- **monitoring_menu.sh**: **🧹 AUTO CACHE MANAGEMENT** + monitoring
- **backup_menu.sh**: Backup & restore operations
- **proxy_menu.sh**: Proxy configuration
- **uninstall_menu.sh**: Complete system removal

### 🔧 Wrapper Modules (lib/wrappers/)
- **docker_wrapper.sh**: Docker operations with error handling
- **api_wrapper.sh**: API communication wrapper
- **backup_wrapper.sh**: Backup operations wrapper
- **install_wrapper.sh**: Installation operations wrapper

### 📁 Working Directory (workdir/)
- **credentials.json**: Node wallet & ID configuration
- **docker-compose.yml**: Docker container configuration
- **config/**: Auto cache daemon configuration
- **backup/**: Automatic backups
- **logs/**: Application & daemon logs

## 🎯 CONSERVATIVE AUTO CACHE SYSTEM

### 📍 Lokasi Fitur Auto Cache:
- **Menu**: Monitoring & Statistics → Auto Cache Management
- **File**: `lib/menus/monitoring_menu.sh` (lines 730-1300+)
- **Config**: `workdir/config/auto_cache_config.json`
- **Daemon**: `nexus_auto_cache_daemon.sh`
- **Functions**: `lib/port_manager.sh` (cleanup functions)

### ⚙️ Komponen Auto Cache:
1. **Menu Interface**: 8 opsi management dalam monitoring menu
2. **Configuration**: JSON-based config dengan thresholds
3. **Background Daemon**: Process monitoring container lifecycle
4. **Cleanup Functions**: Progressive system→nexus cache cleanup
5. **Logging**: Comprehensive activity logging
6. **Safety Features**: Backup sebelum cleanup, minimum memory check
