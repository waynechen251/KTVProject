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
    $workspacePath = Join-Path $projectRoot 'workspace'
    $dbSongsPath = Join-Path $projectRoot 'db\songs'
    $logPath = Join-Path $PSScriptRoot 'm3u8.log'

    # 檢查 FFmpeg 是否存在
    Write-Host '🔍 檢查必要工具...' -ForegroundColor Yellow
    if (-not (Test-Path $ffmpegPath)) {
        Write-Host '❌ 錯誤：找不到 ffmpeg.exe' -ForegroundColor Red
        Write-Host "   預期位置：$ffmpegPath" -ForegroundColor Gray
        Write-Host ''
        Write-Host 'FFmpeg 需解壓縮到專案的 ffmpeg/ 目錄' -ForegroundColor Yellow
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
    
    # 掃描包含必要檔案的歌曲目錄
    Write-Host "📂 掃描 workspace 目錄：$workspacePath" -ForegroundColor Yellow
    
    if (-not (Test-Path $workspacePath)) {
        Write-Host '❌ 錯誤：找不到 workspace 目錄' -ForegroundColor Red
        Write-Host "   預期位置：$workspacePath" -ForegroundColor Gray
        exit 1
    }
    
    $songDirectories = Get-ChildItem -Path $workspacePath -Recurse -Directory | Where-Object {
        $hasVideo = (Test-Path (Join-Path $_.FullName 'mv.mp4'))
        $hasBacking = (Test-Path (Join-Path $_.FullName 'backing.mp3')) -or (Test-Path (Join-Path $_.FullName 'backing.m4a'))
        $hasVocal = (Test-Path (Join-Path $_.FullName 'vocal.mp3')) -or (Test-Path (Join-Path $_.FullName 'vocal.m4a'))
        
        $hasVideo -and $hasBacking -and $hasVocal
    }
    
    if (-not $songDirectories) {
        Write-Host '⚠️  未找到符合條件的歌曲目錄' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '歌曲目錄必須包含以下檔案：' -ForegroundColor Gray
        Write-Host '  - mv.mp4                        (含字幕的影片)' -ForegroundColor Gray
        Write-Host '  - backing.mp3 或 backing.m4a    (伴奏音訊)' -ForegroundColor Gray
        Write-Host '  - vocal.mp3 或 vocal.m4a        (原唱音訊)' -ForegroundColor Gray
        Write-Host ''
        exit 0
    }
    
    # 根據 -Force 參數決定是否過濾已轉換的歌曲
    if (-not $Force) {
        $pendingSongs = $songDirectories | Where-Object {
            # 取得相對於 workspace 的路徑
            $relativePath = $_.FullName.Substring($workspacePath.Length).TrimStart('\')
            $dbOutputPath = Join-Path $dbSongsPath $relativePath
            $hlsPath = Join-Path $dbOutputPath 'hls\master.m3u8'
            
            -not (Test-Path $hlsPath)
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
        
        # 計算輸入和輸出路徑
        $relativePath = $songDir.FullName.Substring($workspacePath.Length).TrimStart('\')
        $dbOutputDir = Join-Path $dbSongsPath $relativePath
        
        # 確保輸出目錄存在
        if (-not (Test-Path $dbOutputDir)) {
            Write-Host "  📁 建立輸出目錄：$relativePath" -ForegroundColor Gray
            New-Item -ItemType Directory -Path $dbOutputDir -Force | Out-Null
        }
        
        # 輸入檔案（workspace）
        $inputVideo = Join-Path $songDir.FullName 'mv.mp4'
        
        # 檢查音訊檔案格式（支援 .mp3 和 .m4a）
        $backingMp3 = Join-Path $songDir.FullName 'backing.mp3'
        $backingM4a = Join-Path $songDir.FullName 'backing.m4a'
        $inputBacking = if (Test-Path $backingMp3) { $backingMp3 } else { $backingM4a }
        
        $vocalMp3 = Join-Path $songDir.FullName 'vocal.mp3'
        $vocalM4a = Join-Path $songDir.FullName 'vocal.m4a'
        $inputVocal = if (Test-Path $vocalMp3) { $vocalMp3 } else { $vocalM4a }
        
        # 輸出路徑（db/songs）
        $hlsPath = Join-Path $dbOutputDir 'hls'
        
        Set-Location -Path $songDir.FullName
        
        # 使用 ffprobe 取得影片時長
        Write-Host '  📊 檢測影片資訊...' -ForegroundColor Gray
        try {
            $durationOutput = & $ffprobePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputVideo 2>&1
            
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
        
        # 如果存在舊的 HLS 目錄則刪除
        if (Test-Path $hlsPath) {
            Write-Host '  🗑️  清除舊的 HLS 檔案...' -ForegroundColor Gray
            Remove-Item -Path $hlsPath -Recurse -Force
        }
        
        Write-Host '  ⚙️  開始轉換 HLS 格式...' -ForegroundColor Yellow
        Write-Host "     來源：workspace\$relativePath" -ForegroundColor DarkGray
        Write-Host "     目標：db\songs\$relativePath\hls\" -ForegroundColor DarkGray
        Write-Host '     (轉換過程可能需要數分鐘)' -ForegroundColor DarkGray

        New-Item -ItemType Directory -Path $hlsPath | Out-Null
        
        $ffmpegArgs = @(
            '-i', $inputVideo,
            '-i', $inputBacking,
            '-i', $inputVocal,
            '-map', '0:v:0', '-map', '1:a:0', '-map', '2:a:0',
            '-c:v', 'copy',
            '-c:a', 'aac', '-b:a', '192k',
            '-f', 'hls',
            '-hls_playlist_type', 'vod',
            '-hls_time', '10',
            '-hls_segment_filename', (Join-Path $hlsPath 'segment_%v_%03d.ts'),
            '-master_pl_name', 'master.m3u8',
            '-var_stream_map', 'v:0,agroup:audio a:0,agroup:audio,name:backing,default:yes a:1,agroup:audio,name:vocal',
            (Join-Path $hlsPath 'stream_%v.m3u8')
        )
        
        # 臨時調整錯誤處理，因為 FFmpeg 將進度資訊輸出到 stderr
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        
        & $ffmpegPath $ffmpegArgs 2>&1 | Out-Null
        $ffmpegExitCode = $LASTEXITCODE
        
        $ErrorActionPreference = $previousErrorAction
        
        if ($ffmpegExitCode -ne 0) {
            Write-Host "  ❌ 轉換失敗 (錯誤碼: $ffmpegExitCode)" -ForegroundColor Red
            Write-Host '     詳細錯誤資訊已記錄於 m3u8.log' -ForegroundColor Yellow
            continue 
        }
        
        Write-Host '  ✅ HLS 轉換成功' -ForegroundColor Green
        
        # 列出生成的 m3u8 檔案
        $m3u8Files = Get-ChildItem -Path $hlsPath -Filter *.m3u8

        if ($m3u8Files) {
            Write-Host "  📄 已生成 $($m3u8Files.Count) 個 m3u8 檔案" -ForegroundColor Cyan
            
            # 在詳細模式下顯示檔案內容
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
    Write-Host '後續步驟：' -ForegroundColor Yellow
    Write-Host '   編輯 src/config/songs.json 以新增歌曲資訊' -ForegroundColor Gray
    Write-Host ''
}
finally {
    Set-Location -Path $originalLocation
    Stop-Transcript
}