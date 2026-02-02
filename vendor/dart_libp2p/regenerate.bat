@echo off
setlocal

REM Set paths
set PROTOC=C:\Users\Eduardo\AppData\Local\Temp\protoc\bin\protoc.exe
set PUB_CACHE=C:\Users\Eduardo\AppData\Local\Pub\Cache\bin

echo Using protoc from: %PROTOC%
echo Adding pub cache to PATH

set PATH=%PUB_CACHE%;%PATH%

REM Clean output
if exist "lib\src\generated" (
    echo Cleaning output directory...
    rmdir /s /q "lib\src\generated"
)
mkdir "lib\src\generated"

REM Change to project root
cd /d "%~dp0"

echo Generating proto files...

REM Generate each proto file with appropriate proto paths
REM 1. crypto.proto (core)
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/core/crypto/pb --proto_path=. lib/core/crypto/pb/crypto.proto

REM 2. peer_record.proto
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/core/peer/pb --proto_path=. lib/core/peer/pb/peer_record.proto

REM 3. envelope.proto (needs crypto.proto)
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/core/crypto/pb --proto_path=lib/core/record/pb --proto_path=. lib/core/record/pb/envelope.proto

REM 4. plaintext.proto
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/core/sec/insecure/pb --proto_path=. lib/core/sec/insecure/pb/plaintext.proto

REM 5. crypto.proto (p2p)
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/p2p/crypto/pb --proto_path=. lib/p2p/crypto/pb/crypto.proto

REM 6. autonat.proto
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/p2p/host/autonat/pb --proto_path=. lib/p2p/host/autonat/pb/autonat.proto

REM 7. autonatv2.proto
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/p2p/protocol/autonatv2/pb --proto_path=. lib/p2p/protocol/autonatv2/pb/autonatv2.proto

REM 8. circuit.proto and voucher.proto
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/p2p/protocol/circuitv2/pb --proto_path=. lib/p2p/protocol/circuitv2/pb/circuit.proto lib/p2p/protocol/circuitv2/pb/voucher.proto

REM 9. holepunch.proto
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/p2p/protocol/holepunch/pb --proto_path=. lib/p2p/protocol/holepunch/pb/holepunch.proto

REM 10. identify.proto
"%PROTOC%" --dart_out=lib/src/generated --proto_path=lib/p2p/protocol/identify/pb --proto_path=. lib/p2p/protocol/identify/pb/identify.proto

echo.
echo Successfully regenerated proto files!
echo Output: lib\src\generated

endlocal