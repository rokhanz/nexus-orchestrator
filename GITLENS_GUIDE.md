# 🔧 CARA MENGGUNAKAN GITLENS

## 📋 OVERVIEW GITLENS

GitLens adalah extension VS Code yang powerful untuk Git version control. Ini akan membantu Anda memahami perubahan kode, melihat history, dan berkolaborasi lebih efektif.

## 🚀 INSTALASI GITLENS

### 1. Install GitLens Extension
```bash
# Atau install melalui VS Code Extensions:
# 1. Buka VS Code
# 2. Tekan Ctrl+Shift+X (Extensions)
# 3. Search "GitLens"
# 4. Install "GitLens — Git supercharged" by GitKraken
```

### 2. Initialize Git Repository (jika belum)
```bash
cd /root/nexus-orchestrator
git init
git add .
git commit -m "Initial commit: Conservative Auto Cache System"
```

## 🎯 FITUR UTAMA GITLENS

### 1. 📊 **Blame Annotations**
- **Fungsi**: Melihat siapa yang mengubah baris kode tertentu dan kapan
- **Cara Pakai**:
  - Buka file apa saja (misal: `lib/menus/monitoring_menu.sh`)
  - Tekan `Ctrl+Shift+P` → ketik "GitLens: Toggle File Blame"
  - Setiap baris akan menampilkan author, tanggal, dan commit message

### 2. 🔍 **Code Lens**
- **Fungsi**: Inline information tentang Git history
- **Yang Terlihat**:
  - "Recently changed" di atas functions
  - Jumlah authors yang pernah mengubah function
  - Click untuk melihat details

### 3. 📝 **Commit Graph**
- **Cara Akses**: `Ctrl+Shift+P` → "GitLens: Show Commit Graph"
- **Fungsi**: Visual representation dari commit history
- **Bisa Lihat**: Branch, merge, commit relationships

### 4. 📂 **File History**
- **Cara Pakai**:
  - Right-click pada file → "Open File History"
  - Atau Command Palette: "GitLens: Show File History"
- **Fungsi**: Melihat semua perubahan pada file tertentu

### 5. 🔄 **Interactive Rebase**
- **Cara Pakai**: GitLens sidebar → Commits → Right-click → "Rebase"
- **Fungsi**: Menggabungkan, mengedit, atau menghapus commits

## 🛠️ WORKFLOW DENGAN GITLENS

### 1. 📋 **Daily Workflow**
```bash
# 1. Check status perubahan
git status

# 2. Lihat apa yang berubah
git diff

# 3. Stage changes
git add .

# 4. Commit dengan message yang jelas
git commit -m "feat: add conservative auto cache system to monitoring menu"

# 5. Push ke remote repository
git push origin main
```

### 2. 🔍 **Investigating Changes**
1. **Open GitLens Sidebar**: View → Open View → GitLens
2. **Explore Repositories**: Lihat semua perubahan dalam project
3. **Check File History**: Right-click file → "Open File History"
4. **Compare Changes**: Click pada commit untuk melihat diff

### 3. 📊 **Reviewing Code**
1. **Hover Over Lines**: GitLens menampilkan blame info saat hover
2. **Click Blame Info**: Melihat full commit details
3. **Navigate History**: Use arrows untuk previous/next changes

## 🎯 GITLENS UNTUK NEXUS ORCHESTRATOR

### 1. 📍 **Tracking Auto Cache System**
```bash
# Commit auto cache implementation
git add lib/menus/monitoring_menu.sh nexus_auto_cache_daemon.sh
git commit -m "feat: implement conservative auto cache system

- Add auto cache management menu to monitoring_menu.sh
- Create background daemon with container lifecycle integration
- Progressive cleanup: system cache first, nexus cache if needed
- Memory/swap thresholds: 90%/80% with 5AM schedule
- Comprehensive logging and safety features"
```

### 2. 🔄 **Branching Strategy**
```bash
# Create feature branch
git checkout -b feature/auto-cache-enhancements

# Work on improvements
# ... edit files ...

# Commit changes
git add .
git commit -m "enhance: improve auto cache daemon stability"

# Merge back to main
git checkout main
git merge feature/auto-cache-enhancements
```

### 3. 📝 **Tagging Releases**
```bash
# Tag stable release
git tag -a v4.0.0 -m "Release v4.0.0: Conservative Auto Cache System"
git push origin v4.0.0
```

## 🎨 GITLENS SIDEBAR EXPLAINED

### 📊 **Sections dalam GitLens Sidebar**:

1. **🔍 SEARCH & COMPARE**
   - Search commits, files, changes
   - Compare branches, tags, commits

2. **📝 COMMITS**
   - Browse commit history
   - See file changes per commit
   - Interactive rebase options

3. **📂 FILE HISTORY**
   - History untuk file yang sedang dibuka
   - Quick navigation between changes

4. **📊 LINE HISTORY**
   - History untuk baris tertentu
   - Tracking specific changes

5. **🌿 BRANCHES**
   - Visual branch representation
   - Easy branch switching

6. **🔖 TAGS**
   - All project tags
   - Release management

7. **📡 REMOTES**
   - Remote repository management
   - Push/pull operations

## 🚀 TIPS ADVANCED GITLENS

### 1. 🎯 **Custom Blame Format**
- Settings → Extensions → GitLens → Blame
- Customize blame annotation format

### 2. 📊 **Heat Map**
- `Ctrl+Shift+P` → "GitLens: Toggle File Heatmap"
- Visual representation dari frequency changes

### 3. 🔍 **Quick Commit Navigation**
- `Alt+,` : Previous commit
- `Alt+.` : Next commit

### 4. 📝 **Commit Message Templates**
```bash
# Setup commit templates
git config commit.template ~/.gitmessage

# Create template file
echo "feat/fix/docs/style/refactor/test/chore:

# What was changed:
#

# Why it was changed:
#

# References:
# " > ~/.gitmessage
```

## 🎯 GITLENS UNTUK TEAM COLLABORATION

### 1. 👥 **Multi-Author Projects**
- GitLens menampilkan kontributor per function
- Easy identification siapa yang bertanggung jawab untuk code tertentu

### 2. 📊 **Code Review**
- Inline blame annotations
- Easy diff viewing
- Historical context untuk setiap perubahan

### 3. 🔄 **Merge Conflict Resolution**
- Visual merge conflict resolution
- 3-way merge editor
- Historical context untuk conflicts

## 📋 CHEAT SHEET GITLENS

| Shortcut                               | Function                 |
| -------------------------------------- | ------------------------ |
| `Ctrl+Shift+G`                         | Open Source Control      |
| `Ctrl+Shift+P` → "GitLens"             | All GitLens commands     |
| `Alt+B`                                | Toggle Blame annotations |
| `Ctrl+Shift+P` → "Show Commit Graph"   | Visual commit history    |
| Right-click file → "Open File History" | File change history      |
| Hover over line                        | Quick blame info         |
| `Alt+,`                                | Previous commit          |
| `Alt+.`                                | Next commit              |

## 🎯 RECOMMENDED SETTINGS

### VS Code Settings untuk GitLens:
```json
{
    "gitlens.blame.format": "${author}, ${agoOrDate}",
    "gitlens.blame.heatmap.enabled": true,
    "gitlens.codeLens.enabled": true,
    "gitlens.currentLine.enabled": true,
    "gitlens.hovers.enabled": true,
    "gitlens.statusBar.enabled": true
}
```

GitLens akan sangat membantu dalam tracking perubahan Conservative Auto Cache System yang baru saja kita implement!
