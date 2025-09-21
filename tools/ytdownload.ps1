#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)][string]$Url,
    [string]$OutputDir = '.'
)

$ErrorActionPreference = 'Stop'

if (-not $Url) {
    $Url = Read-Host -Prompt '請輸入影片網址'
    if (-not $Url) { throw '未提供網址。' }
}

$yt = (Get-Command yt-dlp -ErrorAction SilentlyContinue).Source
if (-not $yt) { throw 'yt-dlp.exe 未安裝或未加入 PATH。' }

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# 獲取影片標題作為基礎檔名
$baseNameTemplate = [IO.Path]::Combine($OutputDir, '%(title)s')
$titleArgs = @($Url, '--get-filename', '-o', $baseNameTemplate)
$baseFilePath = (& $yt @titleArgs | Select-Object -First 1).Trim()

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
Write-Host '正在下載最高品質的無聲影片...'
& $yt @ytDlpVideoArgs

# 2. 下載最高品質的純音訊
$audioPath = $baseFilePath + '_audio.m4a'
$ytDlpAudioArgs = @(
    $Url
    '-f', 'bestaudio[ext=m4a]/bestaudio' # 優先下載 m4a 格式的純音訊
    '-o', $audioPath
    '--no-mtime'
    '--restrict-filenames'
)
Write-Host '正在下載最高品質的音訊...'
& $yt @ytDlpAudioArgs

$finalVideoFile = Get-ChildItem -Path $videoPath -ErrorAction SilentlyContinue
$finalAudioFile = Get-ChildItem -Path $audioPath -ErrorAction SilentlyContinue

if (-not $finalVideoFile) {
    throw '無聲影片下載失敗。'
}
if (-not $finalAudioFile) {
    throw '音訊檔案下載失敗。'
}

Write-Host '--- 操作完成 ---'
Write-Output "無聲影片檔案: $($finalVideoFile.FullName)"
Write-Output "純音訊檔案:   $($finalAudioFile.FullName)"