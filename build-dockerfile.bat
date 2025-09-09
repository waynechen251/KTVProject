@echo off
setlocal

set "REGISTRY=192.168.0.11:5000"
set "IMAGE_NAME=mini-ktv"
set "IMAGE=%REGISTRY%/mini-ktv/%IMAGE_NAME%:latest"

echo Building %IMAGE_NAME%...
docker build -f Dockerfile -t %IMAGE% .
if errorlevel 1 (
  echo [ERROR] %IMAGE_NAME% image build failed.
  exit /b 1
)

echo Pushing %IMAGE_NAME% image...
docker push %IMAGE%
if errorlevel 1 (
  echo [ERROR] %IMAGE_NAME% image push failed.
  exit /b 1
)

echo %IMAGE% built and pushed successfully.
exit /b 0
