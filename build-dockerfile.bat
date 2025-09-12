@echo off
setlocal

set "REGISTRY=192.168.0.11:5000"
set "IMAGE_NAME=mini-ktv"
set "IMAGE=%REGISTRY%/mini-ktv/%IMAGE_NAME%:latest"

echo Building %IMAGE_NAME%...
cd src
docker build -f Dockerfile -t %IMAGE% .
if errorlevel 1 (
  echo [ERROR] %IMAGE_NAME% image build failed.
  cd ..
  exit /b 1
)

echo Pushing %IMAGE_NAME% image...
docker push %IMAGE%
if errorlevel 1 (
  echo [ERROR] %IMAGE_NAME% image push failed.
  cd ..
  exit /b 1
)

echo %IMAGE% built and pushed successfully.
cd ..
exit /b 0
