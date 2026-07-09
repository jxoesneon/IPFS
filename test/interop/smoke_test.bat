@echo off
REM Smoke test for the interop infrastructure (Windows version)
REM This script verifies that all services are running and can communicate

setlocal enabledelayedexpansion

echo === Interop Infrastructure Smoke Test ===
echo.

REM Check if docker-compose is running
echo 1. Checking docker-compose status...
cd /d "%~dp0"
docker-compose ps | findstr "Up" >nul
if errorlevel 1 (
    echo ERROR: docker-compose services are not running
    echo Run: docker-compose up -d
    exit /b 1
)
echo docker-compose services are running
echo.

REM Check dart_ipfs health
echo 2. Checking dart_ipfs health...
docker-compose exec -T dart_ipfs curl -f http://localhost:8080/health >nul 2>&1
if errorlevel 1 (
    echo dart_ipfs health check failed
    docker-compose logs dart_ipfs
    exit /b 1
)
echo dart_ipfs is healthy
echo.

REM Check kubo health
echo 3. Checking kubo health...
docker-compose exec -T kubo ipfs id >nul 2>&1
if errorlevel 1 (
    echo kubo health check failed
    docker-compose logs kubo
    exit /b 1
)
echo kubo is healthy
echo.

REM Check helia health
echo 4. Checking helia health...
docker-compose exec -T helia curl -f http://localhost:5001/health >nul 2>&1
if errorlevel 1 (
    echo helia health check failed
    docker-compose logs helia
    exit /b 1
)
echo helia is healthy
echo.

REM Test network connectivity
echo 5. Testing network connectivity...
docker-compose exec -T test-runner ping -c 1 dart_ipfs >nul 2>&1
if errorlevel 1 (
    echo test-runner cannot reach dart_ipfs
    exit /b 1
)
echo test-runner can reach dart_ipfs

docker-compose exec -T test-runner ping -c 1 kubo >nul 2>&1
if errorlevel 1 (
    echo test-runner cannot reach kubo
    exit /b 1
)
echo test-runner can reach kubo

docker-compose exec -T test-runner ping -c 1 helia >nul 2>&1
if errorlevel 1 (
    echo test-runner cannot reach helia
    exit /b 1
)
echo test-runner can reach helia
echo.

REM Test API endpoints
echo 6. Testing API endpoints...
docker-compose exec -T test-runner curl -f http://kubo:5001/api/v0/version >nul 2>&1
if errorlevel 1 (
    echo Kubo API is not accessible
    exit /b 1
)
echo Kubo API is accessible

docker-compose exec -T test-runner curl -f http://helia:5001/api/v0/version >nul 2>&1
if errorlevel 1 (
    echo Helia API is not accessible
    exit /b 1
)
echo Helia API is accessible

docker-compose exec -T test-runner curl -f http://dart_ipfs:5001/api/v0/version >nul 2>&1
if errorlevel 1 (
    echo dart_ipfs API is not accessible
    exit /b 1
)
echo dart_ipfs API is accessible
echo.

REM Test Helia add/cat
echo 7. Testing Helia add/cat functionality...
set TEST_DATA=smoke-test-%random%
set ADD_RESULT=
for /f "delims=" %%i in ('docker-compose exec -T helia curl -s -X POST -d "!TEST_DATA!" http://localhost:5001/api/v0/add') do set ADD_RESULT=%%i

echo ADD_RESULT: !ADD_RESULT!

REM Extract CID from JSON response (simplified - assumes format)
for /f "tokens=2 delims=:," %%a in ("%ADD_RESULT%") do set CID=%%a
set CID=%CID:"=%

if defined CID (
    echo Helia added data with CID: %CID%
    
    set RETRIEVED=
    for /f "delims=" %%i in ('docker-compose exec -T helia curl -s "http://localhost:5001/api/v0/cat?arg=%CID%"') do set RETRIEVED=%%i
    
    if "!RETRIEVED!"=="!TEST_DATA!" (
        echo Helia retrieved data successfully
    ) else (
        echo Helia retrieved data mismatch
        echo Expected: !TEST_DATA!
        echo Got: !RETRIEVED!
        exit /b 1
    )
) else (
    echo Helia add failed
    echo Response: !ADD_RESULT!
    exit /b 1
)
echo.

echo === All Smoke Tests Passed ===
echo.
echo The interop infrastructure is ready for testing.
echo Run the Dart tests with:
echo   docker-compose exec test-runner dart test test/interop/test/
