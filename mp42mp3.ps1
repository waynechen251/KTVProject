param(
    [string]$FfmpegPath = 'D:/GitHub/YTDownload/ffmpeg/bin/ffmpeg.exe',
    [string]$InputPath = 'D:/GitHub/KTVProject/db/songs/Milena/why do we fall in love/Milena_why_do_we_fall_in_love[KTV字幕].mp4',
    [string]$OutputPath = 'D:/GitHub/KTVProject/db/songs/Milena/why do we fall in love/Milena_why_do_we_fall_in_love[KTV字幕].mp3'
)

function Start-FFmpegAsync([string]$inputFile, [string]$outputFile) {
    $logDir = Join-Path (Split-Path $outputFile) 'ffmpeg-logs'
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null

    $base = [IO.Path]::GetFileNameWithoutExtension($outputFile)
    $safeBase = $base -replace '[^A-Za-z0-9\._-]', '_'
    $outLog = Join-Path $logDir "$safeBase.out.txt"
    $errLog = Join-Path $logDir "$safeBase.err.txt"

    # 重要：對含空格路徑加引號
    $qIn = '"' + $inputFile + '"'
    $qOut = '"' + $outputFile + '"'

    $ffArgs = @(
        '-y',
        '-i', $qIn,
        '-vn',
        '-c:a', 'libmp3lame',
        '-b:a', '192k',
        $qOut
    )

    try {
        $proc = Start-Process -FilePath $FfmpegPath `
            -ArgumentList $ffArgs `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError $errLog `
            -NoNewWindow -PassThru
        return $proc
    }
    catch {
        Write-Error "Failed to start ffmpeg: $_"
        return $null
    }
}

$proc = Start-FFmpegAsync $InputPath $OutputPath
if ($proc -eq $null) { Write-Error 'ffmpeg process could not be started.'; exit 1 }

Write-Host "Started ffmpeg process: $($proc.Id). Waiting for completion..."
$proc.WaitForExit()

# 讀取 ExitCode 前，確保已退出
if (-not $proc.HasExited) { Start-Sleep -Milliseconds 200 }

if ($proc.ExitCode -ne 0) {
    Write-Error "ffmpeg exited with code: $($proc.ExitCode). Check the ffmpeg-logs folder."
    exit $proc.ExitCode
}
else {
    Write-Host 'Conversion completed successfully (exit code 0).'
}
