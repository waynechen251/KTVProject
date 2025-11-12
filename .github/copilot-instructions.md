# Mini KTV 專案 - AI 開發指南

## 專案概覽
這是一個網頁版 KTV 系統，採用 **Nginx 靜態託管架構**，支援 HLS (HTTP Live Streaming) 串流、雙聲道音訊切換（伴奏/原唱）以及點歌佇列管理。核心特色是使用 FFmpeg 離線處理，將 MP4 影片與雙軌音訊（backing.m4a / vocal.m4a）轉換為 HLS 格式，透過 hls.js 在瀏覽器中實現即時音軌切換。

## 架構設計

### 前端架構（Vanilla JavaScript）
- **狀態管理**：使用全域物件 `S` 集中管理所有應用狀態（`src/app.js:1-7`）
  ```javascript
  const S = {
    songs: [],        // 歌曲資料庫
    queue: [],        // 播放佇列（儲存歌曲 ID）
    currentIndex: -1, // 當前播放索引
    mode: "instrumental", // 音訊模式："instrumental" (伴奏) 或 "vocal" (原唱)
    masterVolume: 1   // 主音量 0-1
  };
  ```
- **播放器整合**：使用 hls.js 實現 HLS 播放與雙音軌切換（`applyMode()` 函式）
- **UI 更新**：採用 `requestAnimationFrame` 進行即時進度條更新（`src/app.js:107-118`）

### 資料流架構
1. **歌曲來源**：`workspace/<artist>/<song>/` 包含 `mv.mp4`、`backing.mp3`、`vocal.mp3`
2. **HLS 轉換**：`tools/m3u8.ps1` 使用 FFmpeg 將影片與雙音軌轉換為 HLS 格式
3. **輸出結構**：`db/songs/<artist>/<song>/hls/` 包含 `master.m3u8` 與 segment 檔案
4. **前端載入**：`src/config/songs.json` 定義歌曲索引，指向 HLS 路徑

### HLS 音軌映射規範
- **重要**：FFmpeg 生成的音軌命名為 `backing`（伴奏）和 `vocal`（原唱）
- 前端音軌切換邏輯：
  - `S.mode === 'instrumental'` → 搜尋 `track.name === 'audio_1'`（實際應為 `backing`）
  - `S.mode === 'vocal'` → 搜尋 `track.name === 'audio_2'`（實際應為 `vocal`）
  - **已知問題**：`applyMode()` 中的音軌名稱映射與 FFmpeg 輸出不一致，需修正為 `backing` 和 `vocal`

## 關鍵開發工作流程

### 歌曲製作完整流程

**工作流目錄說明**：
- `workspace/<artist>/<song>/`：工作流產物（原始素材）
- `db/songs/<artist>/<song>/`：最終產物（HLS 串流檔案）

**標準製作流程**：
1. **下載影音素材**
   ```powershell
   # 使用 yt-dlp 下載影片與音訊
   pwsh ./tools/ytdownload.ps1 -Url "https://youtube.com/watch?v=..."
   # 輸出：<title>_video.mp4 (無聲影片) 和 <title>_audio.mp3 (原始音訊)
   ```

2. **去人聲處理**（使用第三方工具）
   - 將 `<title>_audio.mp3` 分離為：
     - `backing.mp3`：伴奏（無人聲）
     - `vocal.mp3`：原唱（含人聲）
   - 推薦工具：UVR (Ultimate Vocal Remover)、Spleeter

3. **上字幕**（手動環節）
   - 使用影片編輯軟體（如 Aegisub、剪映）為 `<title>_video.mp4` 嵌入字幕
   - 輸出為 `mv.mp4`（含字幕的影片）

4. **整理檔案到 workspace**
   ```
   workspace/<artist>/<song>/
   ├── mv.mp4        # 含字幕的影片
   ├── backing.mp3   # 伴奏音訊
   └── vocal.mp3     # 原唱音訊
   ```

5. **轉換為 HLS 格式**
   ```powershell
   # 將 workspace 中的歌曲複製到 db/songs，然後執行：
   pwsh ./tools/m3u8.ps1
   # 自動掃描 db/songs/<artist>/<song>/ 並生成 hls/ 目錄
   ```

6. **更新歌曲資料庫**
   編輯 `src/config/songs.json`，新增項目：
   ```json
   {
     "id": "unique_id",
     "title": "歌名",
     "artist": "歌手",
     "rootUrl": "db/songs/<artist>/<song>/",
     "hlsUrl": "hls/master.m3u8",
     "duration": 187
   }
   ```

### HLS 轉換機制（tools/m3u8.ps1）
- **輸入檢測**：掃描 `db/songs/` 下所有包含 `mv.mp4`、`backing.mp3`、`vocal.mp3` 的目錄
- **FFmpeg 指令關鍵參數**（第 87-98 行）：
  ```powershell
  -map 0:v:0 -map 1:a:0 -map 2:a:0  # 映射影片 + 雙音軌
  -var_stream_map 'v:0,agroup:audio a:0,agroup:audio,name:backing,default:yes a:1,agroup:audio,name:vocal'
  ```
- **輸出驗證**：自動列印生成的 `.m3u8` 檔案內容供檢查（第 111-119 行）
- **日誌記錄**：完整轉換日誌保存於 `tools/m3u8.log`

### 部署環境差異

#### Docker 部署（推薦用於生產環境）
- 使用 `build.bat` / `run.bat` 快速部署
- Docker Compose 配置：
  - 容器內路徑固定為 `/usr/share/nginx/html/`
  - Volume 映射：`db/` 和 `config/` 為唯讀掛載
  - 埠映射：主機 8080 → 容器 80

#### Windows 本機部署
- Nginx 配置路徑需手動替換為絕對路徑（參考 `readme.md:53-57`）
- FFmpeg 工具放置於 `ffmpeg/bin/` 目錄

## 專案特定慣例

### 檔案命名規範
- 歌曲目錄：`<artist>/<song>/`（允許中文與空格）
- 音訊檔案：強制命名為 `backing.mp3`（伴奏）、`vocal.mp3`（原唱）
- 影片檔案：強制命名為 `mv.mp4`

### 狀態管理模式
- 所有狀態變更必須更新全域 `S` 物件，並呼叫對應的 `render*()` 函式
- 範例：新增歌曲到佇列 → `S.queue.push(id)` → `renderQueue()`

### Nginx CORS 與快取設定
- HLS 檔案（.m3u8、.ts）必須設定 `Access-Control-Allow-Origin: *`（`src/nginx.conf:21-24`）
- 所有回應預設 `Cache-Control: no-store` 以避免開發時快取問題

## 整合點與相依性

### 外部工具
- **FFmpeg**：HLS 轉換核心，自動從專案 `ffmpeg/bin/` 目錄載入
- **yt-dlp**：YouTube 下載工具，需透過 `winget install yt-dlp` 安裝
- **UVR / Spleeter**：第三方去人聲工具（手動操作）

### 腳本工具說明
專案提供三個 PowerShell 腳本於 `tools/` 目錄：
1. **ytdownload.ps1**：下載 YouTube 影音，支援互動式輸入與錯誤提示
2. **m3u8.ps1**：批次 HLS 轉換，支援 `-Force` 重新轉換、自動跳過已處理歌曲
3. **mp42mp3.ps1**：影片轉 MP3 輔助工具（非主要工作流）

所有腳本已改善為：
- 移除硬編碼路徑，自動偵測專案結構
- 加入友善的錯誤訊息與使用說明
- 支援互動式輸入（未提供參數時自動詢問）
- 提供彩色輸出與進度提示
- 完整的 PowerShell Help 文件（使用 `Get-Help <script> -Full` 查看）

詳細使用方式請參考 `tools/README.md`

### 瀏覽器 API 依賴
- **hls.js**：處理 HLS 播放與音軌切換（需透過 CDN 載入）
- **HTML5 Video API**：Fallback 支援（Safari 原生 HLS）

### 跨元件通訊
- 歌曲清單 → 播放器：透過 `enqueue(id)` 傳遞歌曲 ID
- 播放器 → 佇列：`handleEnded()` 自動播放下一首並更新佇列
- 模式切換 → 播放器：`applyMode()` 即時切換 hls.js audioTrack

## 常見開發任務

### 修復音軌切換
如音軌切換無效，檢查：
1. `master.m3u8` 是否包含正確的音軌名稱（`backing` / `vocal`）
2. `applyMode()` 中的 `targetTrackName` 是否匹配 FFmpeg 輸出

### 新增播放器功能
修改 `src/app.js`，在 `S` 物件中新增狀態，並在 `initEventListeners()` 綁定 UI 事件。

### 除錯 HLS 轉換
- 執行 `m3u8.ps1` 後檢查 `tools/m3u8.log` 日誌
- 使用 FFprobe 手動檢查音軌：`ffprobe -show_streams mv.mp4`

## 重要注意事項
- **音訊同步**：backing.mp3 和 vocal.mp3 必須與 mv.mp4 時長完全一致
- **編碼格式**：HLS 音訊統一轉換為 AAC 192k（`-b:a 192k`）
- **UI 互動鎖定**：首次播放前需使用者點擊觸發（`isInteracted` 標誌，`src/app.js:154-158`）
- **PowerShell 執行策略**：在 Windows 上需設定 `Set-ExecutionPolicy RemoteSigned`
- **PowerShell 腳本編碼**：所有 `.ps1` 腳本必須使用 **UTF-8 with BOM** 編碼，否則中文會出現亂碼導致執行失敗
  - VS Code 設定方式：開啟檔案 → 右下角編碼 → 「透過編碼儲存」 → 「UTF-8 with BOM」
  - 或在 `settings.json` 加入：`"[powershell]": { "files.encoding": "utf8bom" }`
  - 詳見 `tools/ENCODING-FIX.md`
- **不需要自動化測試**：專案無測試環節，品質控管依賴手動驗證與播放測試
