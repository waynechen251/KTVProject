# Mini KTV

一個現代化的網頁版 KTV 系統，支援雙聲道音訊切換（伴奏/原唱）、HLS 串流播放和完整的點歌佇列管理。

## 功能特色

- 🎵 **雙聲道音訊模式**：支援伴奏/原唱模式切換
- 📱 **響應式設計**：適配桌面端和移動端
- 🎬 **HLS 串流播放**：支援 m3u8 格式的高品質影音串流
- 🎤 **點歌佇列管理**：完整的排隊、插播、刪除功能
- 🔍 **歌曲搜尋**：支援歌名和歌手搜尋
- 🎛️ **播放控制**：播放/暫停、重唱、切歌、音量調節
- 🐳 **Docker 部署**：輕鬆容器化部署

## 項目結構

```
KTVProject/
├── src/                    # 前端源碼
│   ├── app.js             # 主要應用邏輯
│   ├── index.html         # 主頁面
│   ├── styles.css         # 樣式表
│   ├── nginx.conf         # Nginx 配置
│   └── Dockerfile         # 容器構建文件
├── db/songs/              # 歌曲資料庫目錄
├── ffmpeg/                # FFmpeg 工具
├── tools/                 # 輔助工具腳本
│   ├── m3u8.ps1          # HLS 轉換腳本
│   ├── mp42mp3.ps1       # 音訊格式轉換
│   └── ytdownload.ps1    # YouTube 下載工具
├── build.bat             # 構建腳本
├── push.bat              # 推送腳本
├── run.bat               # 運行腳本
└── docker-compose.yml    # Docker Compose 配置
```

## 安裝與部署

### 前置需求

- Docker 和 Docker Compose
- PowerShell 5.1+ （用於工具腳本）
- FFmpeg （用於媒體處理）

### 快速開始

1. **克隆項目**
   ```bash
   git clone https://github.com/waynechen251/KTVProject.git
   cd KTVProject
   ```

2. **構建 Docker 映像**
   ```batch
   build.bat
   ```

3. **運行服務**
   ```batch
   run.bat
   ```

4. **訪問應用**
   打開瀏覽器訪問：`http://localhost:8080`

### 手動部署

1. **準備歌曲檔案**
   - 在 `db/songs/` 目錄下建立歌手/歌曲資料夾
   - 每個歌曲資料夾需包含：
     - `mv.mp4` - 影片檔案(無聲影片+字幕)
     - `backing.m4a` - 伴奏音軌(無人聲)
     - `vocal.m4a` - 原唱音軌(原始音訊)

2. **生成 HLS 串流**
   ```powershell
   .\tools\m3u8.ps1
   ```

3. **更新歌曲資料庫**
   將歌曲資訊更新到 [`songs.json`](songs.json)
   ```json
   [
     {
       "id": "unique_int_song_id",
       "title": "song_title",
       "artist": "artist_name",
       "path": "songs/artist_name/song_title/"
     }
   ]
   ```

## 使用方法

### 播放控制

- **播放/暫停**：使用 [`updatePlayPauseButton`](src/app.js) 函數控制
- **模式切換**：透過 [`applyMode`](src/app.js) 在伴奏/原唱間切換
- **音量調節**：使用 [`applyVolume`](src/app.js) 調整主音量
- **進度控制**：透過 [`handleSeek`](src/app.js) 調整播放進度

### 點歌功能

- **搜尋歌曲**：在搜尋框輸入歌名或歌手名稱
- **加入佇列**：點擊「點歌」按鈕使用 [`enqueue`](src/app.js) 函數
- **佇列管理**：支援刪除、插播等操作

### 佇列管理

- **插播功能**：使用 [`insertAfterCurrent`](src/app.js) 將歌曲插入到當前播放後
- **移動位置**：透過 [`moveTo`](src/app.js) 調整歌曲順序
- **移除歌曲**：使用 [`removeAt`](src/app.js) 從佇列中刪除

## 工具腳本

### HLS 轉換工具

[`tools/m3u8.ps1`](tools/m3u8.ps1) - 將 MP4 和音訊檔案轉換為 HLS 格式

```powershell
.\tools\m3u8.ps1
```

### 音訊轉換工具

[`tools/mp42mp3.ps1`](tools/mp42mp3.ps1) - 將 MP4 轉換為 MP3 格式

```powershell
.\tools\mp42mp3.ps1 -InputPath "input.mp4" -OutputPath "output.mp3"
```

### YouTube 下載工具

[`tools/ytdownload.ps1`](tools/ytdownload.ps1) - 從 YouTube 下載影片和音訊

```powershell
.\tools\ytdownload.ps1 -Url "https://youtube.com/watch?v=..." -OutputDir "output/"
```

## 技術架構

### 前端技術

- **JavaScript ES6+**：主要應用邏輯
- **HLS.js**：HTTP Live Streaming 播放支援
- **CSS Grid & Flexbox**：響應式佈局
- **vConsole**：移動端調試支援

### 後端架構

- **Nginx**：靜態檔案服務和反向代理
- **Docker**：容器化部署
- **HLS**：自適應位元率串流

### 核心功能實作

#### 音訊軌道切換

```javascript
function applyMode() {
  const isInstrumental = S.mode === 'instrumental';
  const targetTrackName = isInstrumental ? 'audio_1' : 'audio_2';
  // 切換 HLS 或原生音軌
}
```

#### 佇列管理

```javascript
function enqueue(id) {
  S.queue.push(id);
  if (S.currentIndex === -1) {
    S.currentIndex = 0;
    playCurrent();
  }
  renderQueue();
}
```

## 配置說明

### Docker 配置

[`docker-compose.yml`](docker-compose.yml) 定義了服務配置：
- 端口映射
- 數據卷掛載
- 網路設定

### Nginx 配置

[`src/nginx.conf`](src/nginx.conf) 包含：
- 靜態檔案服務
- MIME 類型配置
- 緩存策略

## 開發指南

### 添加新歌曲

1. 在 `db/songs/歌手名稱/歌曲名稱/` 創建資料夾
2. 放入必要的媒體檔案：`mv.mp4`、`backing.m4a`、`vocal.m4a`
3. 執行 HLS 轉換：`.\tools\m3u8.ps1`
4. 更新 [`songs.json`](songs.json) 資料庫

### 客製化樣式

修改 [`src/styles.css`](src/styles.css) 中的 CSS 變數：

```css
:root {
  --accent: #1e90ff;     /* 主色調 */
  --bg-primary: #111;    /* 主背景色 */
  --text: #eee;          /* 文字顏色 */
}
```

## 授權條款

本項目採用 GNU General Public License v3.0 授權。詳見 [`LICENSE`](LICENSE) 檔案。

## 貢獻指南

歡迎提交 Issue 和 Pull Request！請確保：

1. 遵循現有的代碼風格
2. 添加適當的註釋
3. 測試新功能的相容性

## 故障排除

### 常見問題

1. **HLS 播放失敗**
   - 檢查 [`m3u8.ps1`](tools/m3u8.ps1) 腳本執行是否成功
   - 確認 `.m3u8` 檔案格式正確

2. **音軌切換無效**
   - 確認音訊檔案包含正確的軌道標籤
   - 檢查 [`applyMode`](src/app.js) 函數的軌道名稱匹配

3. **Docker 容器啟動失敗**
   - 檢查端口是否被佔用
   - 確認 Docker 服務正常運行

### 日誌查看

- HLS 轉換日誌：[`tools/m3u8.log`](tools/m3u8.log)
- FFmpeg 處理日誌：檢查對應的 `ffmpeg-logs` 資料夾

---

🎤 **享受您的 KTV 體驗！**