[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Stop'
$originalLocation = Get-Location

try {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $projectRoot = (Resolve-Path "$PSScriptRoot\..").Path
    
    $ffmpegPath = Join-Path $projectRoot 'ffmpeg\bin\ffmpeg.exe'
    $ffprobePath = Join-Path $projectRoot 'ffmpeg\bin\ffprobe.exe'
    $songsBasePath = Join-Path $projectRoot 'db\songs'
    $logPath = Join-Path $PSScriptRoot 'm3u8.log'

    if (Test-Path $logPath) {
        Remove-Item -Path $logPath -Force
    }
    Start-Transcript -Path $logPath -Append
    
    if (-not (Test-Path $ffmpegPath)) {
        Write-Host 'Error: ffmpeg.exe not found at the specified path. Please check if the path is correct.' -ForegroundColor Red
        Write-Host "Expected path: $ffmpegPath"
        exit 1
    }
    
    if (-not (Test-Path $ffprobePath)) {
        Write-Host 'Error: ffprobe.exe not found at the specified path. Please check if the path is correct.' -ForegroundColor Red
        Write-Host "Expected path: $ffprobePath"
        exit 1
    }
    
    $songDirectories = Get-ChildItem -Path $songsBasePath -Recurse -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName 'mv.mp4')) -and
        (Test-Path (Join-Path $_.FullName 'backing.m4a')) -and
        (Test-Path (Join-Path $_.FullName 'vocal.m4a'))
    }
    
    if (-not $songDirectories) {
        Write-Host "No song directories containing mv.mp4, backing.m4a, and vocal.m4a were found in '$songsBasePath'." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($songDirectories.Count) songs. Starting HLS conversion..." -ForegroundColor Cyan
    
    foreach ($songDir in $songDirectories) {
        $songName = "$($songDir.Parent.Name) / $($songDir.Name)"
        Write-Host '------------------------------------------------------------'
        Write-Host "Processing: $songName" -ForegroundColor Yellow
        
        Set-Location -Path $songDir.FullName
        
        Write-Host '  - Extracting duration for reference...'
        try {
            $durationOutput = & $ffprobePath -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 'mv.mp4' 2>&1
            
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($durationOutput)) {
                $duration = $durationOutput.ToString().Trim()
                if ([double]::TryParse($duration, [ref]$null)) {
                    $seconds = [math]::Round([double]$duration)
                    Write-Host "  - Duration: $seconds seconds" -ForegroundColor Cyan
                }
                else {
                    Write-Host "  - Duration: Could not parse '$duration'" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host '  - Duration: Could not extract (ffprobe failed)' -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  - Duration: Error - $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        $hlsPath = Join-Path $songDir.FullName 'hls'
        if (Test-Path $hlsPath) {
            Write-Host '  - Deleting old hls directory...'
            Remove-Item -Path $hlsPath -Recurse -Force
        }
        
        Write-Host '  - Generating HLS stream files...'

        New-Item -ItemType Directory -Path $hlsPath | Out-Null
        
        $ffmpegArgs = @(
            '-i', 'mv.mp4',
            '-i', 'backing.m4a',
            '-i', 'vocal.m4a',
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
        & $ffmpegPath $ffmpegArgs

        if ($LASTEXITCODE -ne 0) {
            Write-Error "FFmpeg failed to process '$songName', exit code: $LASTEXITCODE. Please check m3u8.log for details."
            continue 
        }
        
        Write-Host '  - HLS generation successful.' -ForegroundColor Green
        
        $m3u8Files = Get-ChildItem -Path $hlsPath -Filter *.m3u8

        if ($m3u8Files) {
            Write-Host '  - Verifying m3u8 contents:' -ForegroundColor Cyan
            Write-Host '----------------- m3u8 content start -----------------'
            foreach ($m3u8File in $m3u8Files) {
                Write-Host "--- $($m3u8File.Name) ---" -ForegroundColor White
                Get-Content $m3u8File.FullName | Write-Host
                Write-Host ''
            }
            Write-Host '------------------ m3u8 content end ------------------'
        }
        else {
            Write-Host "  - Warning: No .m3u8 files found in '$hlsPath'" -ForegroundColor Yellow
        }
    }
    
    Write-Host '------------------------------------------------------------'
    Write-Host '✅ All HLS conversions completed! Detailed log saved to m3u8.log' -ForegroundColor Cyan
}
finally {
    Write-Host "Returning to original directory: $($originalLocation.Path)"
    Set-Location -Path $originalLocation
}