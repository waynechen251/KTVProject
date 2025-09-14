#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)][string]$Url,   # 位置參數 → 只給網址即可
    [string]$OutputDir = '.',
    [string]$FfmpegDir = '.\ffmpeg\bin'
)

$ErrorActionPreference = 'Stop'

if (-not $Url) {
    $Url = Read-Host -Prompt '請輸入影片網址'
    if (-not $Url) { throw '未提供網址。' }
}

# 1. 確認 yt-dlp
$yt = (Get-Command yt-dlp -ErrorAction SilentlyContinue).Source
if (-not $yt) { throw 'yt-dlp.exe 未安裝或未加入 PATH。' }

# 2. 建立輸出資料夾
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# 3. 下載 + 轉檔參數
$arguments = @(
    $Url
    '--ffmpeg-location', $FfmpegDir                      # 指定 ffmpeg 目錄
    '-f', 'bestvideo+bestaudio/best'                    # 最高畫質＋音質
    '--recode-video', 'mp4'                             # 下載後若非 MP4 立即轉
    '--postprocessor-args', '-c:v libx264 -crf 22 -preset fast -c:a copy'
    '-o', "$OutputDir\%(title)s.%(ext)s"                # 檔名：標題.mp4
    '--no-mtime'
    '--restrict-filenames'
)

# 4. 執行（下載 MP4，然後從產生的 MP4 擷取 MP3）
& $yt @arguments

# 找到剛剛產生的 mp4（選取輸出資料夾中最新的 .mp4）
$mp4 = Get-ChildItem -Path $OutputDir -Filter '*.mp4' -File |
Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $mp4) {
    throw '找不到下載完成的 MP4 檔案。'
}

# 確認 ffmpeg
$ffmpeg = Join-Path $FfmpegDir 'ffmpeg.exe'
if (-not (Test-Path $ffmpeg)) { throw "ffmpeg.exe 未在指定路徑找到：$ffmpeg" }

# 產生 MP3 路徑，與 MP4 同名但副檔名為 .mp3
$mp3Path = [System.IO.Path]::ChangeExtension($mp4.FullName, '.mp3')

# 使用 ffmpeg 擷取音訊為 mp3（libmp3lame，品質 q:a 2）
& $ffmpeg -y -i $mp4.FullName -vn -c:a libmp3lame -q:a 2 $mp3Path

Write-Output "已產生：`nMP4: $($mp4.FullName)`nMP3: $mp3Path"
