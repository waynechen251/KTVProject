# 工具腳本使用說明

本目錄包含 KTV 歌曲製作所需的輔助腳本。

## 📋 工作流程概覽

```
下載影音 → 去人聲 → 上字幕 → HLS轉換 → 更新資料庫
  (1)       (2)      (3)      (4)        (5)
```

## 🛠️ 腳本說明

### 1️⃣ ytdownload.ps1 - YouTube 影音下載

從 YouTube 下載影片（無聲）和音訊檔案。

**使用方式：**
```powershell
# 互動式使用（推薦新手）
pwsh ytdownload.ps1

# 直接指定網址
pwsh ytdownload.ps1 -Url "https://youtube.com/watch?v=..."

# 指定輸出目錄
pwsh ytdownload.ps1 -Url "..." -OutputDir "workspace/artist/song"
```

**輸出檔案：**
- `<title>_video.mp4` - 無聲影片
- `<title>_audio.mp3` - 原始音訊

**前置需求：**
- 需安裝 `yt-dlp`（執行 `winget install yt-dlp`）

---

### 2️⃣ [手動步驟] 去人聲與上字幕

使用第三方工具處理：

**去人聲（分離音訊）：**
- 推薦工具：[UVR (Ultimate Vocal Remover)](https://github.com/Anjok07/ultimatevocalremovergui)
- 將 `<title>_audio.mp3` 分離為：
  - `backing.mp3` - 伴奏（無人聲）
  - `vocal.mp3` - 原唱（含人聲）

**上字幕：**
- 推薦工具：Aegisub、剪映、DaVinci Resolve
- 為 `<title>_video.mp4` 嵌入字幕，輸出為 `mv.mp4`

**整理檔案：**
將三個檔案移動到：
```
workspace/<artist>/<song>/
├── mv.mp4        # 含字幕的影片
├── backing.mp3   # 伴奏音訊
└── vocal.mp3     # 原唱音訊
```

---

### 3️⃣ m3u8.ps1 - HLS 批次轉換

將歌曲轉換為 HLS 串流格式（m3u8）。

**使用方式：**
```powershell
# 轉換所有未處理的歌曲
pwsh m3u8.ps1

# 強制重新轉換所有歌曲
pwsh m3u8.ps1 -Force

# 顯示詳細的 m3u8 內容（除錯用）
pwsh m3u8.ps1 -Verbose
```

**轉換條件：**
腳本會掃描 `db/songs/` 目錄，找出包含以下三個檔案的目錄：
- `mv.mp4`
- `backing.mp3`
- `vocal.mp3`

**輸出結構：**
```
db/songs/<artist>/<song>/
├── mv.mp4
├── backing.mp3
├── vocal.mp3
└── hls/                    # 新增
    ├── master.m3u8        # 主播放清單
    ├── stream_0.m3u8      # 影片串流
    ├── stream_1.m3u8      # 伴奏音軌
    ├── stream_2.m3u8      # 原唱音軌
    └── segment_*.ts       # 影音片段
```

**日誌檔案：**
完整的轉換日誌會保存在 `tools/m3u8.log`

---

### 4️⃣ mp42mp3.ps1 - 影片轉 MP3（輔助工具）

從影片檔案提取音訊並轉換為 MP3。

**使用方式：**
```powershell
# 互動式使用
pwsh mp42mp3.ps1

# 指定輸入檔案（支援拖曳）
pwsh mp42mp3.ps1 -InputPath "video.mp4"

# 指定輸出路徑
pwsh mp42mp3.ps1 -InputPath "video.mp4" -OutputPath "audio.mp3"
```

---

## 📝 完整工作流程範例

### 情境：新增一首歌曲

**步驟 1：下載影音**
```powershell
cd tools
pwsh ytdownload.ps1 -Url "https://youtube.com/watch?v=dQw4w9WgXcQ" -OutputDir "../workspace/Rick_Astley/Never_Gonna_Give_You_Up"
```

**步驟 2：去人聲**
1. 開啟 UVR
2. 載入 `<title>_audio.mp3`
3. 選擇 vocal separation 模型
4. 導出 `backing.mp3` 和 `vocal.mp3`

**步驟 3：上字幕**
1. 使用影片編輯軟體開啟 `<title>_video.mp4`
2. 加入歌詞字幕
3. 導出為 `mv.mp4`

**步驟 4：整理檔案**
```powershell
# 確保三個檔案在正確位置
workspace/Rick_Astley/Never_Gonna_Give_You_Up/
├── mv.mp4
├── backing.mp3
└── vocal.mp3

# 複製到 db/songs/
Copy-Item -Recurse workspace/Rick_Astley db/songs/
```

**步驟 5：轉換 HLS**
```powershell
pwsh m3u8.ps1
```

**步驟 6：更新歌曲資料庫**
編輯 `src/config/songs.json`，新增：
```json
{
  "id": "rick_astley_never_gonna_give_you_up",
  "title": "Never Gonna Give You Up",
  "artist": "Rick Astley",
  "rootUrl": "db/songs/Rick_Astley/Never_Gonna_Give_You_Up/",
  "hlsUrl": "hls/master.m3u8",
  "duration": 213
}
```

---

## ⚠️ 常見問題

### 1. PowerShell 腳本無法執行
**錯誤訊息：** `無法載入檔案，因為這個系統上已停用指令碼執行。`

**解決方式：**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. 找不到 yt-dlp
**解決方式：**
```powershell
winget install yt-dlp
```

### 3. 找不到 FFmpeg
**解決方式：**
- 下載 FFmpeg：https://github.com/BtbN/FFmpeg-Builds/releases
- 解壓縮到專案的 `ffmpeg/` 目錄
- 確保 `ffmpeg/bin/ffmpeg.exe` 存在

### 4. m3u8.ps1 轉換失敗
**檢查項目：**
1. 確認三個檔案都存在且命名正確
2. 確認音訊和影片時長一致
3. 查看 `tools/m3u8.log` 取得詳細錯誤資訊

### 5. 音訊不同步
**原因：** backing.mp3 和 vocal.mp3 的時長與 mv.mp4 不一致

**解決方式：**
- 重新分離音訊，確保使用完整的原始音訊
- 檢查影片是否被剪輯過

---

## 📚 相關資源

- **yt-dlp**: https://github.com/yt-dlp/yt-dlp
- **UVR**: https://github.com/Anjok07/ultimatevocalremovergui
- **FFmpeg**: https://ffmpeg.org/
- **Aegisub**: https://aegisub.org/

---

## 🆘 需要協助？

如果遇到問題，請：
1. 檢查 `tools/m3u8.log` 日誌檔案
2. 確認所有前置需求都已安裝
3. 查看本專案的 `.github/copilot-instructions.md`
