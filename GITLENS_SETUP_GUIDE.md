# 🔧 GitLens Setup Guide untuk Nexus Orchestrator

## ✅ **Git Configuration Berhasil Dikonfigurasi**

### **🎯 Global Git Settings:**
```bash
git config --global user.name "rokhanz"
git config --global user.email "rokputrahanz@gmail.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
```

### **📋 Verifikasi Konfigurasi:**
```bash
# Cek konfigurasi Git
git config --list --global

# Output yang terlihat:
user.name=rokhanz
user.email=rokputrahanz@gmail.com
init.defaultbranch=main
core.editor=code --wait
```

---

## 🎨 **GitLens VS Code Configuration**

### **✅ GitLens Features yang Diaktifkan:**

#### **1. Blame Information:**
- **Compact blame view**: Menampilkan author dan tanggal per baris
- **Blame heatmap**: Visualisasi perubahan dengan warna
- **Blame highlighting**: Highlight baris yang dipilih

#### **2. Code Lens:**
- **Authors enabled**: Menampilkan author di atas function/class
- **Recent changes**: Menampilkan perubahan terbaru
- **Document scope**: CodeLens aktif di dokumen yang dibuka

#### **3. Current Line Information:**
- **Enabled**: Menampilkan info commit di baris aktif
- **Format**: `${author} • ${agoOrDate} • ${message}`
- **Scrollable**: Bisa di-scroll untuk melihat info lengkap

#### **4. Hovers & Tooltips:**
- **Line hovers**: Info commit saat hover di baris code
- **Annotation details**: Detail perubahan dan commit
- **Current line hovers**: Info mendalam untuk baris aktif

#### **5. Status Bar:**
- **Position**: Kanan status bar
- **Format**: `${author} • ${agoOrDate}`
- **Click**: Quick access ke GitLens commands

#### **6. Views & Panels:**
- **File History**: Riwayat perubahan file
- **Branches**: Visualisasi branch dan commits
- **Repositories**: Overview semua repositories
- **Search**: Pencarian commits dan changes

---

## 🚀 **Cara Menggunakan GitLens**

### **1. Melihat Blame Information:**
```
- Tekan: Ctrl+Shift+P → "GitLens: Toggle File Blame"
- Atau: Klik ikon GitLens di toolbar
- Hasil: Setiap baris menunjukkan author dan tanggal
```

### **2. Melihat File History:**
```
- Klik kanan file → "GitLens: Show File History"
- Atau: Tekan Alt+H
- Hasil: Panel history dengan semua commits file
```

### **3. Compare Changes:**
```
- Pilih baris code → Klik "Compare with Previous"
- Atau: Ctrl+Shift+P → "GitLens: Compare File with Previous"
- Hasil: Side-by-side diff view
```

### **4. Search Commits:**
```
- Tekan: Ctrl+Shift+P → "GitLens: Search Commits"
- Input: Author, message, atau file name
- Hasil: Filtered commit history
```

### **5. Explore Repository:**
```
- View → Open View → GitLens
- Pilih: Repositories, Branches, atau Search
- Navigate: Explore commits, files, dan changes
```

---

## ⚙️ **GitLens Keyboard Shortcuts**

### **Essential Shortcuts:**
```bash
Alt+B              # Toggle File Blame
Alt+H              # Show File History
Ctrl+Shift+G L     # Focus GitLens View
Ctrl+Alt+G C       # Show Commits View
Ctrl+Alt+G R       # Show Repositories View
```

### **Navigation:**
```bash
Alt+.              # Show Next Commit
Alt+,              # Show Previous Commit
Ctrl+Alt+G S       # Search Commits
Ctrl+Alt+G B       # Switch Branch/Tag
```

### **Comparison:**
```bash
Ctrl+Alt+G D       # Compare with Working Tree
Ctrl+Alt+G P       # Compare with Previous
Ctrl+Alt+G N       # Compare with Next
```

---

## 🎯 **GitLens untuk Nexus Orchestrator Workflow**

### **1. Code Review Process:**
```bash
# Melihat siapa yang mengubah function tertentu
- Buka file (misal: main.sh)
- Enable blame (Alt+B)
- Hover di baris function untuk detail commit

# Melihat riwayat perubahan file
- Right-click file → Show File History
- Review semua commits yang mempengaruhi file
```

### **2. Debugging & Troubleshooting:**
```bash
# Mencari kapan bug diintroduce
- GitLens: Search Commits
- Input kata kunci atau file name
- Trace perubahan yang mencurigakan

# Compare versi sebelumnya
- Pilih commit di history
- Compare with Working Tree
- Identifikasi perubahan yang menyebabkan issue
```

### **3. Collaboration:**
```bash
# Melihat kontribusi team
- Repositories view → Contributors
- Filter by author atau time range
- Review commit patterns dan frequency

# Understanding code context
- Hover di baris code untuk commit message
- Klik CodeLens untuk detail commit
- Navigate ke related changes
```

---

## 📊 **GitLens Views Explained**

### **1. Repositories View:**
```
├── 📁 nexus-orchestrator
    ├── 🌿 Branches (main, feature/*, etc.)
    ├── 🏷️  Tags (v4.0.0, releases)
    ├── 📋 Contributors (rokhanz, others)
    ├── 📁 Recent Files (modified files)
    └── 🔍 Search (commit search)
```

### **2. File History View:**
```
📄 main.sh
├── 🟢 feat: add permission checks (2 days ago) - rokhanz
├── 🔵 fix: duplicate dependency check (3 days ago) - rokhanz
├── 🟡 refactor: optimize memory usage (1 week ago) - rokhanz
└── 📊 Statistics: 45 commits, 8 contributors
```

### **3. Search View:**
```
🔍 Search Results for "permission"
├── 📝 Add permission checking system - rokhanz (2 days ago)
├── 🔧 Fix permission validation - rokhanz (3 days ago)
├── ⚡ Improve permission flow - rokhanz (1 week ago)
```

---

## 🎨 **Visual Indicators**

### **Blame Colors:**
- 🟢 **Recent changes** (green): Last 24 hours
- 🟡 **Medium age** (yellow): Last week
- 🔴 **Old changes** (red): Older commits
- ⚫ **Very old** (gray): Very old commits

### **Status Indicators:**
- `M` - Modified files
- `A` - Added files
- `D` - Deleted files
- `R` - Renamed files
- `?` - Untracked files

### **CodeLens Information:**
```javascript
// Example CodeLens display
function check_permissions() {    // 👤 rokhanz, 2 days ago • 📝 Add permission system
    // Function body...
}
```

---

## 🔧 **Advanced GitLens Tips**

### **1. Custom Date Formats:**
```json
"gitlens.currentLine.dateFormat": "MMMM Do, YYYY h:mma"
// Output: August 7th, 2025 3:45pm
```

### **2. Blame Toggle Modes:**
```bash
File mode    # Blame entire file
Window mode  # Blame visible area only
Line mode    # Blame current line only
```

### **3. Integration with Git Commands:**
```bash
# GitLens menambahkan context ke Git commands
git log --oneline    # Enhanced dengan GitLens info
git blame filename   # Visual di editor dengan colors
git diff HEAD~1      # Side-by-side view di VS Code
```

---

## 🚀 **Workflow Best Practices**

### **1. Daily Development:**
```bash
Morning routine:
1. Open GitLens Repositories view
2. Check recent commits dari team
3. Review file changes dengan blame
4. Update local branch

Code review:
1. Enable blame untuk context
2. Check file history untuk background
3. Compare changes dengan previous versions
4. Document findings di commit messages
```

### **2. Debugging Session:**
```bash
When bug found:
1. Enable blame pada file yang bermasalah
2. Identify commit yang introduce bug
3. Check commit message dan related changes
4. Compare dengan working version
5. Create fix dengan proper context
```

### **3. Feature Development:**
```bash
Before coding:
1. Review related file history
2. Understand previous implementations
3. Check patterns dari similar features

During coding:
1. Use blame untuk understand context
2. Reference previous commits dalam messages
3. Follow established patterns

After coding:
1. Review changes dengan GitLens
2. Ensure proper commit messages
3. Check file history untuk consistency
```

---

## 🎯 **GitLens Integration Success!**

✅ **Git Global Config**: Username dan email configured
✅ **GitLens Settings**: Optimal configuration applied
✅ **VS Code Integration**: Full GitLens features enabled
✅ **Keyboard Shortcuts**: Essential shortcuts configured
✅ **Workflow Guide**: Complete usage documentation

**🎉 GitLens sekarang siap digunakan untuk Nexus Orchestrator development dengan optimal configuration!**
