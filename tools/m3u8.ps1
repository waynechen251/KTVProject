<#
.SYNOPSIS
    批次轉換歌曲為 HLS 格式（m3u8）

.DESCRIPTION
    掃描 db/songs/ 目錄下的所有歌曲，將包含 mv.mp4、backing.m4a、vocal.m4a 的目錄
    轉換為 HLS 串流格式，輸出到 hls/ 子目錄

.PARAMETER Force
    強制重新轉換（即使 hls 目錄已存在）

.EXAMPLE
    pwsh m3u8.ps1
    # 掃描並轉換所有符合條件的歌曲
    
.EXAMPLE
    pwsh m3u8.ps1 -Force
    # 強制重新轉換所有歌曲
#>

[CmdletBinding()]
param(
    [switch]$Force
)

[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Stop'
$originalLocation = Get-Location

Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan
Write-Host '  HLS (m3u8) 批次轉換工具' -ForegroundColor Cyan
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan
Write-Host ''

try {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
    
    $ffmpegPath = Join-Path $projectRoot 'ffmpeg\bin\ffmpeg.exe'
    $ffprobePath = Join-Path $projectRoot 'ffmpeg\bin\ffprobe.exe'
    $songsBasePath = Join-Path $projectRoot 'db\songs'
    $logPath = Join-Path $PSScriptRoot 'm3u8.log'

    # 檢查 FFmpeg
    Write-Host '🔍 檢查必要工具...' -ForegroundColor Yellow
    if (-not (Test-Path $ffmpegPath)) {
        Write-Host '❌ 錯誤：找不到 ffmpeg.exe' -ForegroundColor Red
        Write-Host "   預期位置：$ffmpegPath" -ForegroundColor Gray
        Write-Host ''
        Write-Host '請將 FFmpeg 解壓縮到專案的 ffmpeg/ 目錄' -ForegroundColor Yellow
        exit 1
    }
    
    if (-not (Test-Path $ffprobePath)) {
        Write-Host '❌ 錯誤：找不到 ffprobe.exe' -ForegroundColor Red
        Write-Host "   預期位置：$ffprobePath" -ForegroundColor Gray
        exit 1
    }
    
    Write-Host '✅ FFmpeg 工具就緒' -ForegroundColor Green
    Write-Host ''

    # 初始化日誌
    if (Test-Path $logPath) {
        Remove-Item -Path $logPath -Force
    }
    Start-Transcript -Path $logPath -Append
    
    # 掃描歌曲目錄
    Write-Host "📂 掃描歌曲目錄：$songsBasePath" -ForegroundColor Yellow
    
    $songDirectories = Get-ChildItem -Path $songsBasePath -Recurse -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName 'mv.mp4')) -and
        (Test-Path (Join-Path $_.FullName 'backing.mp3')) -and
        (Test-Path (Join-Path $_.FullName 'vocal.mp3'))
    }
    
    if (-not $songDirectories) {
        Write-Host '⚠️  未找到符合條件的歌曲目錄' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '歌曲目錄必須包含以下檔案：' -ForegroundColor Gray
        Write-Host '  - mv.mp4       (含字幕的影片)' -ForegroundColor Gray
        Write-Host '  - backing.mp3  (伴奏音訊)' -ForegroundColor Gray
        Write-Host '  - vocal.mp3    (原唱音訊)' -ForegroundColor Gray
        Write-Host ''
        exit 0
    }
    
    # 過濾已轉換的歌曲（除非使用 -Force）
    if (-not $Force) {
        $pendingSongs = $songDirectories | Where-Object {
            -not (Test-Path (Join-Path $_.FullName 'hls\master.m3u8'))
        }
        
        $skippedCount = $songDirectories.Count - $pendingSongs.Count
        if ($skippedCount -gt 0) {
            Write-Host "ℹ️  跳過 $skippedCount 首已轉換的歌曲（使用 -Force 強制重新轉換）" -ForegroundColor Cyan
        }
        
        $songDirectories = $pendingSongs
    }
    
    if ($songDirectories.Count -eq 0) {
        Write-Host '✅ 所有歌曲都已轉換完成' -ForegroundColor Green
        exit 0
    }
    
    Write-Host "📝 找到 $($songDirectories.Count) 首待轉換的歌曲" -ForegroundColor Cyan
    Write-Host ''
    
    $currentSong = 0
    $totalSongs = $songDirectories.Count
    
    foreach ($songDir in $songDirectories) {
        $currentSong++
        $songName = "$($songDir.Parent.Name) / $($songDir.Name)"
        
        Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray
        Write-Host "🎵 [$currentSong/$totalSongs] $songName" -ForegroundColor Yellow
        Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor DarkGray
        
        Set-Location -Path $songDir.FullName
        
        # 取得影片時長
        Write-Host '  📊 檢測影片資訊...' -ForegroundColor Gray
        try {
            $durationOutput = & $ffprobePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 'mv.mp4' 2>&1
            
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($durationOutput)) {
                $duration = $durationOutput.ToString().Trim()
                if ([double]::TryParse($duration, [ref]$null)) {
                    $seconds = [math]::Round([double]$duration)
                    Write-Host "     時長：$seconds 秒" -ForegroundColor Cyan
                }
            }
        }
        catch {
            Write-Host '     ⚠️  無法取得時長資訊' -ForegroundColor Yellow
        }
        
        # 刪除舊的 HLS 目錄
        $hlsPath = Join-Path $songDir.FullName 'hls'
        if (Test-Path $hlsPath) {
            Write-Host '  🗑️  清除舊的 HLS 檔案...' -ForegroundColor Gray
            Remove-Item -Path $hlsPath -Recurse -Force
        }
        
        Write-Host '  ⚙️  開始轉換 HLS 格式...' -ForegroundColor Yellow
        Write-Host '     (這可能需要幾分鐘，請耐心等待)' -ForegroundColor DarkGray

        New-Item -ItemType Directory -Path $hlsPath | Out-Null
        
        $ffmpegArgs = @(
            '-i', 'mv.mp4',
            '-i', 'backing.mp3',
            '-i', 'vocal.mp3',
            '-map', '0:v:0', '-map', '1:a:0', '-map', '2:a:0',
            '-c:v', 'copy',
            '-c:a', 'aac', '-b:a', '192k',
            '-f', 'hls',
            '-hls_playlist_type', 'vod',
            '-hls_time', '10',
            '-hls_segment_filename', 'hls/segment_%v_%03d.ts',
            '-master_pl_name', 'master.m3u8',
            '-var_stream_map', 'v:0,agroup:audio a:0,agroup:audio,name:backing,default:yes a:1,agroup:audio,name:vocal',
            'hls/stream_%v.m3u8'
        )
        
        # 執行 FFmpeg（重定向標準錯誤到 null，因為 FFmpeg 將進度輸出到 stderr）
        $null = & $ffmpegPath $ffmpegArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ❌ 轉換失敗 (錯誤碼: $LASTEXITCODE)" -ForegroundColor Red
            Write-Host '     請查看 m3u8.log 取得詳細資訊' -ForegroundColor Yellow
            continue 
        }
        
        Write-Host '  ✅ HLS 轉換成功' -ForegroundColor Green
        
        # 驗證輸出
        $m3u8Files = Get-ChildItem -Path $hlsPath -Filter *.m3u8

        if ($m3u8Files) {
            Write-Host "  📄 已生成 $($m3u8Files.Count) 個 m3u8 檔案" -ForegroundColor Cyan
            
            # 只在詳細模式下顯示內容
            if ($VerbosePreference -eq 'Continue') {
                Write-Host '  ─────────────────────────────────────────' -ForegroundColor DarkGray
                foreach ($m3u8File in $m3u8Files) {
                    Write-Host "  📝 $($m3u8File.Name)" -ForegroundColor White
                    Get-Content $m3u8File.FullName | ForEach-Object { Write-Host "     $_" -ForegroundColor DarkGray }
                }
                Write-Host '  ─────────────────────────────────────────' -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host '  ⚠️  警告：未找到 m3u8 檔案' -ForegroundColor Yellow
        }
        
        Write-Host ''
    }
    
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
    Write-Host '✅ 批次轉換完成！' -ForegroundColor Green
    Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Green
    Write-Host ''
    Write-Host "📋 處理結果：已轉換 $totalSongs 首歌曲" -ForegroundColor Cyan
    Write-Host "📝 完整日誌已保存至：$logPath" -ForegroundColor Gray
    Write-Host ''
    Write-Host '📝 下一步：' -ForegroundColor Yellow
    Write-Host '   編輯 src/config/songs.json 新增歌曲資訊' -ForegroundColor Gray
    Write-Host ''
}
finally {
    Set-Location -Path $originalLocation
    Stop-Transcript
}