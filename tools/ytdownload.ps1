#Requires -Version 5.1
<#
.SYNOPSIS
    從 YouTube 下載影片與音訊，分離為無聲影片與純音訊檔案

.DESCRIPTION
    使用 yt-dlp 下載最高品質的影片（無聲）和音訊，用於後續 KTV 製作流程

.PARAMETER Url
    YouTube 影片網址

.PARAMETER OutputDir
    輸出目錄，預設為當前目錄

.EXAMPLE
    pwsh ytdownload.ps1 -Url "https://youtube.com/watch?v=dQw4w9WgXcQ"
    
.EXAMPLE
    pwsh ytdownload.ps1
    # 會互動式詢問網址
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Url,
    [string]$OutputDir = '.'
)

$ErrorActionPreference = 'Stop'

Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan
Write-Host '  YouTube 影音下載工具 (KTV 製作用)' -ForegroundColor Cyan
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan
Write-Host ''

# 互動式輸入網址
if (-not $Url) {
    $Url = Read-Host -Prompt '請輸入 YouTube 影片網址'
    if (-not $Url) { 
        Write-Host '❌ 未提供網址，程式結束' -ForegroundColor Red
        exit 1
    }
}

# 檢查 yt-dlp 是否安裝
$yt = (Get-Command yt-dlp -ErrorAction SilentlyContinue).Source
if (-not $yt) { 
    Write-Host '❌ 錯誤：找不到 yt-dlp' -ForegroundColor Red
    Write-Host ''
    Write-Host '請先安裝 yt-dlp：' -ForegroundColor Yellow
    Write-Host '  方法 1: winget install yt-dlp' -ForegroundColor Gray
    Write-Host '  方法 2: 從 https://github.com/yt-dlp/yt-dlp/releases 下載' -ForegroundColor Gray
    Write-Host ''
    exit 1
}

# 建立輸出目錄
if (-not (Test-Path $OutputDir)) {
    Write-Host "📁 建立輸出目錄: $OutputDir" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host '🔍 正在獲取影片資訊...' -ForegroundColor Yellow

# 獲取影片標題作為基礎檔名
try {
    $baseNameTemplate = [IO.Path]::Combine($OutputDir, '%(title)s')
    $titleArgs = @($Url, '--get-filename', '-o', $baseNameTemplate, '--restrict-filenames')
    $baseFilePath = (& $yt @titleArgs | Select-Object -First 1).Trim()
    $videoTitle = [IO.Path]::GetFileName($baseFilePath)
    Write-Host "📺 影片標題: $videoTitle" -ForegroundColor Cyan
}
catch {
    Write-Host '❌ 無法獲取影片資訊，請檢查網址是否正確' -ForegroundColor Red
    exit 1
}

Write-Host ''

# 1. 下載最高品質的無聲影片
$videoPath = $baseFilePath + '_video.mp4'
$ytDlpVideoArgs = @(
    $Url
    '-f', 'bestvideo[ext=mp4]/bestvideo' # 優先下載 MP4 格式的純影像
    '--recode-video', 'mp4'              # 如果不是 MP4，則轉換為 MP4
    '-o', $videoPath
    '--no-mtime'
    '--restrict-filenames'
)
Write-Host '⬇️  [1/2] 下載影片（無聲音）...' -ForegroundColor Yellow
& $yt @ytDlpVideoArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host '❌ 影片下載失敗' -ForegroundColor Red
    exit 1
}

# 2. 下載最高品質的純音訊
$audioPath = $baseFilePath + '_audio.mp3'
$ytDlpAudioArgs = @(
    $Url
    '-f', 'bestaudio'
    '-x'                                 # 提取音訊
    '--audio-format', 'mp3'              # 轉換為 mp3 格式
    '--audio-quality', '0'               # 最高品質
    '-o', $audioPath
    '--no-mtime'
    '--restrict-filenames'
)
Write-Host '⬇️  [2/2] 下載音訊...' -ForegroundColor Yellow
& $yt @ytDlpAudioArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host '❌ 音訊下載失敗' -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
Write-Host '✅ 下載完成！' -ForegroundColor Green
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
Write-Host ''
Write-Host '📁 輸出檔案：' -ForegroundColor Cyan
Write-Host "   影片 (無聲)：$videoPath" -ForegroundColor Gray
Write-Host "   音訊：      $audioPath" -ForegroundColor Gray
Write-Host ''
Write-Host '📝 下一步：' -ForegroundColor Yellow
Write-Host '   1. 使用 UVR 或 Spleeter 將音訊分離為 backing.mp3 和 vocal.mp3' -ForegroundColor Gray
Write-Host '   2. 使用影片編輯軟體為影片加上字幕，輸出為 mv.mp4' -ForegroundColor Gray
Write-Host '   3. 將三個檔案整理到 workspace/<artist>/<song>/ 目錄' -ForegroundColor Gray
Write-Host ''