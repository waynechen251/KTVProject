@echo off
setlocal

set "REGISTRY=192.168.0.11:5000"
set "IMAGE_NAME=mini-ktv"
set "IMAGE=%REGISTRY%/mini-ktv/%IMAGE_NAME%:latest"

echo Pushing %IMAGE_NAME% image...
cd src
docker push %IMAGE%
if errorlevel 1 (
  echo [ERROR] %IMAGE_NAME% image push failed.
  cd ..
  exit /b 1
)

echo %IMAGE% pushed successfully.
cd ..
exit /b 0
