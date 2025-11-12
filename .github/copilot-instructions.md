# Mini KTV 專案 - AI 開發指南

## 專案概覽
這是一個網頁版 KTV 系統，採用 **Nginx 靜態託管架構**，支援 HLS (HTTP Live Streaming) 串流、雙聲道音訊切換（伴奏/原唱）以及點歌佇列管理。核心特色是使用 FFmpeg 離線處理，將 MP4 影片與雙軌音訊（backing.mp3/.m4a / vocal.mp3/.m4a）轉換為 HLS 格式，透過 hls.js 在瀏覽器中實現即時音軌切換。

## UI/UX 設計規範

### 色彩系統
- **主色調（橘色）**：
  - `#ED7D31` - 小按鈕、時間軸
  - 背景色：`#F2F2F2`（淺灰）
  
- **深色元素（深灰）**：
  - `#595959` - 大按鈕、時間軸、彈出視窗、搜尋欄、標籤標題、內文、彈出視窗按鈕、歌曲庫內文
  - `#D9D9D9` - 隱藏標籤
  
- **淡色元素（淺灰/白）**：
  - `#F2F2F2` - 背景色、彈出視窗內文、伴奏/原唱按鈕、歌曲庫按鈕
  - 彈出視窗背景：`#F2F2F2` with 15% 透明度

### 文字系統
- **字型**：Agency FB
- **字級與樣式**：
  - 標籤標題：32pt / Bold (`#595959`)
  - 標題與時間軸：36pt (`#595959`)
  - 內文：28pt (`#595959`)
  - 彈出視窗按鈕：24pt / Bold (`#595959`)
  - 歌曲庫內文：24pt / Bold (`#595959`)
  - 彈出視窗內文與伴奏/原唱按鈕：36pt (`#F2F2F2`)
  - 歌曲庫按鈕：24pt (`#F2F2F2`)

### UI 元件配色
- **按鈕**：
  - 小按鈕：`#ED7D31`
  - 大按鈕、時間軸、彈出視窗、搜尋欄：`#595959`
  - 彈出視窗按鈕：`#595959` 背景，文字 24pt Bold
  - 歌曲庫按鈕：`#F2F2F2` 背景，文字 24pt
  
- **圖標（Icon）**：
  - 小按鈕與時間軸：`#ED7D31`
  - 大按鈕、時間軸、彈出視窗、搜尋欄：`#595959`

### 響應式設計原則
- **設計理念**：以移動端為主，電腦版保持相同的版面結構
- **佈局一致性**：所有裝置使用單欄佈局、橫向標籤切換
- **差異僅在於**：
  - 大螢幕（1024px+）增加最大寬度限制（1200px）以提升閱讀體驗
  - 間距與按鈕尺寸略微調整
- **避免**：電腦版不使用多欄 grid 佈局或卡片式標籤

## 架構設計

### 前端架構（Vanilla JavaScript）
- **狀態管理**：使用全域物件 `S` 集中管理所有應用狀態
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
- **UI 更新**：採用 `requestAnimationFrame` 進行即時進度條更新

### 資料流架構
1. **歌曲來源**：`workspace/<artist>/<song>/` 包含原始素材（`mv.mp4`、`backing.mp3/.m4a`、`vocal.mp3/.m4a`）
2. **HLS 轉換**：`tools/m3u8.ps1` 從 `workspace/` 讀取原始檔案，使用 FFmpeg 轉換為 HLS 格式
3. **輸出結構**：轉換後的 HLS 檔案輸出到 `db/songs/<artist>/<song>/hls/`，包含 `master.m3u8` 與 segment 檔案
4. **前端載入**：`src/config/songs.json` 定義歌曲索引，指向 `db/songs/` 下的 HLS 路徑

### HLS 音軌映射規範
- **重要**：FFmpeg 配置使用 `name:backing` 和 `name:vocal`，但實際生成的 HLS 檔案中音軌名稱為 `audio_1`（伴奏）和 `audio_2`（原唱）
- 前端音軌切換邏輯（`src/app.js` 中的 `applyMode()` 函式）：
  - `S.mode === 'instrumental'` → 搜尋 `track.name === 'audio_1'`（伴奏）
  - `S.mode === 'vocal'` → 搜尋 `track.name === 'audio_2'`（原唱）
- **注意**：前端程式碼與實際 HLS 輸出已正確匹配，使用 `audio_1` / `audio_2` 命名

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
   ├── mv.mp4               # 含字幕的影片
   ├── backing.mp3/.m4a     # 伴奏音訊（支援 mp3 或 m4a）
   └── vocal.mp3/.m4a       # 原唱音訊（支援 mp3 或 m4a）
   ```

5. **轉換為 HLS 格式**
   ```powershell
   # 從 workspace 讀取原始檔案，自動輸出到 db/songs
   pwsh ./tools/m3u8.ps1
   # 掃描 workspace/<artist>/<song>/ 並將 HLS 輸出到 db/songs/<artist>/<song>/hls/
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
   - **注意**：舊版 `videoUrl`、`backingUrl`、`vocalUrl` 欄位已不再使用（系統現在只使用 HLS）

### HLS 轉換機制（tools/m3u8.ps1）
- **輸入來源**：掃描 `workspace/` 下所有包含 `mv.mp4`、`backing.mp3/.m4a`、`vocal.mp3/.m4a` 的目錄
- **輸出目標**：將 HLS 檔案輸出到對應的 `db/songs/<artist>/<song>/hls/` 路徑
- **格式支援**：同時支援 `.mp3` 和 `.m4a` 音訊格式，自動偵測可用格式
- **FFmpeg 指令關鍵參數**：
  ```powershell
  -map 0:v:0 -map 1:a:0 -map 2:a:0  # 映射影片 + 雙音軌
  -var_stream_map 'v:0,agroup:audio a:0,agroup:audio,name:backing,default:yes a:1,agroup:audio,name:vocal'
  ```
- **輸出驗證**：使用 `-Verbose` 參數可顯示生成的 `.m3u8` 檔案內容
- **日誌記錄**：完整轉換日誌保存於 `tools/m3u8.log`
- **強制重轉**：使用 `-Force` 參數可強制重新轉換已存在的 HLS 檔案

### 部署環境差異

#### Docker 部署（推薦用於生產環境）
- 使用 `build.bat` / `run.bat` 快速部署
- Docker Compose 配置：
  - 容器內路徑固定為 `/usr/share/nginx/html/`
  - Volume 映射：`db/` 和 `config/` 為唯讀掛載
  - 埠映射：主機 8080 → 容器 80

#### Windows 本機部署
- Nginx 配置路徑需手動替換為絕對路徑（參考 `readme.md` 中的「本機開發」章節）
- FFmpeg 工具放置於 `ffmpeg/bin/` 目錄

## 專案特定慣例

### 檔案命名規範
- 歌曲目錄：`<artist>/<song>/`（允許中文與空格）
- 音訊檔案：命名為 `backing.mp3` 或 `backing.m4a`（伴奏）、`vocal.mp3` 或 `vocal.m4a`（原唱）
- 影片檔案：強制命名為 `mv.mp4`

### 狀態管理模式
- 所有狀態變更必須更新全域 `S` 物件，並呼叫對應的 `render*()` 函式
- 範例：新增歌曲到佇列 → `S.queue.push(id)` → `renderQueue()`

### Nginx CORS 與快取設定
- HLS 檔案（.m3u8、.ts）必須設定 `Access-Control-Allow-Origin: *`（參考 `src/nginx.conf`）
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
1. `master.m3u8` 是否包含正確的音軌名稱（`audio_1` / `audio_2`）
2. `applyMode()` 中的 `targetTrackName` 是否匹配 HLS 實際輸出（應為 `audio_1` / `audio_2`）

### 新增播放器功能
修改 `src/app.js`，在 `S` 物件中新增狀態，並在 `initEventListeners()` 綁定 UI 事件。

### 除錯 HLS 轉換
- 執行 `m3u8.ps1` 後檢查 `tools/m3u8.log` 日誌
- 使用 FFprobe 手動檢查音軌：`ffprobe -show_streams mv.mp4`

## 重要注意事項
- **音訊同步**：backing 和 vocal 音訊檔案（.mp3 或 .m4a）必須與 mv.mp4 時長完全一致
- **編碼格式**：HLS 音訊統一轉換為 AAC 192k（`-b:a 192k`）
- **UI 互動鎖定**：首次播放前需使用者點擊觸發（`isInteracted` 標誌，參考 `src/app.js` 中的 `enqueue()` 函式）
- **PowerShell 執行策略**：在 Windows 上需設定 `Set-ExecutionPolicy RemoteSigned`
- **PowerShell 腳本編碼**：所有 `.ps1` 腳本必須使用 **UTF-8 with BOM** 編碼，否則中文會出現亂碼導致執行失敗
  - VS Code 設定方式：開啟檔案 → 右下角編碼 → 「透過編碼儲存」 → 「UTF-8 with BOM」
  - 或在 `settings.json` 加入：`"[powershell]": { "files.encoding": "utf8bom" }`