@echo off
setlocal

set "REGISTRY=192.168.0.11:5000"
set "IMAGE_NAME=mini-ktv"
set "IMAGE=%REGISTRY%/mini-ktv/%IMAGE_NAME%:latest"

echo Stop and remove existing container if any...
docker rm -f %IMAGE_NAME% >nul 2>&1

echo Running %IMAGE_NAME%...
docker compose up -d
exit /b 0