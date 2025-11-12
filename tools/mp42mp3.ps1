<#
.SYNOPSIS
    將 MP4 影片轉換為 MP3 音訊檔案

.DESCRIPTION
    使用 FFmpeg 從影片檔案提取音訊並轉換為 MP3 格式（192k bitrate）
    支援拖曳檔案到腳本、指定輸入檔案，或互動式選擇

.PARAMETER InputPath
    輸入的影片檔案路徑（支援 MP4、MKV、AVI 等格式）

.PARAMETER OutputPath
    輸出的 MP3 檔案路徑（選填，預設為輸入檔案同目錄，檔名改為 .mp3）

.EXAMPLE
    pwsh mp42mp3.ps1 -InputPath "video.mp4"
    # 輸出到 video.mp3
    
.EXAMPLE
    pwsh mp42mp3.ps1 -InputPath "video.mp4" -OutputPath "audio.mp3"
    # 指定輸出路徑
    
.EXAMPLE
    pwsh mp42mp3.ps1
    # 互動式輸入檔案路徑
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$InputPath,
    
    [Parameter(Position = 1)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan
Write-Host '  影片轉 MP3 工具' -ForegroundColor Cyan
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan
Write-Host ''

# 取得專案根目錄的 FFmpeg 路徑
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$ffmpegPath = Join-Path $projectRoot 'ffmpeg\bin\ffmpeg.exe'

# 檢查 FFmpeg
if (-not (Test-Path $ffmpegPath)) {
    Write-Host '❌ 錯誤：找不到 ffmpeg.exe' -ForegroundColor Red
    Write-Host "   預期位置：$ffmpegPath" -ForegroundColor Gray
    Write-Host ''
    Write-Host '請將 FFmpeg 解壓縮到專案的 ffmpeg/ 目錄' -ForegroundColor Yellow
    exit 1
}

# 互動式輸入檔案路徑
if (-not $InputPath) {
    $InputPath = Read-Host -Prompt '請輸入影片檔案路徑（可拖曳檔案到此視窗）'
    if (-not $InputPath) {
        Write-Host '❌ 未提供輸入檔案' -ForegroundColor Red
        exit 1
    }
    # 移除拖曳檔案可能帶來的引號
    $InputPath = $InputPath.Trim('"', "'")
}

# 檢查輸入檔案是否存在
if (-not (Test-Path $InputPath)) {
    Write-Host "❌ 錯誤：找不到檔案 '$InputPath'" -ForegroundColor Red
    exit 1
}

$InputFile = Get-Item $InputPath
Write-Host "📁 輸入檔案：$($InputFile.FullName)" -ForegroundColor Cyan
Write-Host "   大小：$([math]::Round($InputFile.Length / 1MB, 2)) MB" -ForegroundColor Gray
Write-Host ''

# 自動產生輸出檔案路徑
if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($InputFile.FullName, '.mp3')
}

# 檢查輸出檔案是否已存在
if (Test-Path $OutputPath) {
    $overwrite = Read-Host "⚠️  檔案 '$OutputPath' 已存在，是否覆蓋？(y/N)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host '❌ 操作已取消' -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "📝 輸出檔案：$OutputPath" -ForegroundColor Cyan
Write-Host ''

function Start-FFmpegConversion {
    param(
        [string]$ffmpegExe,
        [string]$inputFile,
        [string]$outputFile
    )
    
    $logDir = Join-Path (Split-Path $outputFile) 'ffmpeg-logs'
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null

    $base = [IO.Path]::GetFileNameWithoutExtension($outputFile)
    $safeBase = $base -replace '[^A-Za-z0-9\._-]', '_'
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outLog = Join-Path $logDir "${safeBase}_${timestamp}.out.txt"
    $errLog = Join-Path $logDir "${safeBase}_${timestamp}.err.txt"

    $ffArgs = @(
        '-y',
        '-i', $inputFile,
        '-vn',
        '-c:a', 'libmp3lame',
        '-b:a', '192k',
        $outputFile
    )

    try {
        Write-Host '⚙️  開始轉換...' -ForegroundColor Yellow
        Write-Host '   (這可能需要一些時間，請稍候)' -ForegroundColor DarkGray
        Write-Host ''
        
        $proc = Start-Process -FilePath $ffmpegExe `
            -ArgumentList $ffArgs `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -NoNewWindow -PassThru -Wait
        
        return $proc
    }
    catch {
        Write-Host "❌ FFmpeg 啟動失敗：$_" -ForegroundColor Red
        return $null
    }
}

$proc = Start-FFmpegConversion -ffmpegExe $ffmpegPath -inputFile $InputFile.FullName -outputFile $OutputPath

if ($null -eq $proc) {
    Write-Host '❌ 轉換程序無法啟動' -ForegroundColor Red
    exit 1
}

if ($proc.ExitCode -ne 0) {
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Red
    Write-Host "❌ 轉換失敗 (錯誤碼: $($proc.ExitCode))" -ForegroundColor Red
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Red
    Write-Host ''
    Write-Host '請查看日誌檔案以獲取詳細資訊：' -ForegroundColor Yellow
    $logDir = Join-Path (Split-Path $OutputPath) 'ffmpeg-logs'
    Write-Host "   $logDir" -ForegroundColor Gray
    Write-Host ''
    exit $proc.ExitCode
}
else {
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
    Write-Host '✅ 轉換成功！' -ForegroundColor Green
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
    Write-Host ''
    
    if (Test-Path $OutputPath) {
        $outputFile = Get-Item $OutputPath
        Write-Host "📁 輸出檔案：$($outputFile.FullName)" -ForegroundColor Cyan
        Write-Host "   大小：$([math]::Round($outputFile.Length / 1MB, 2)) MB" -ForegroundColor Gray
    }
    Write-Host ''
}
