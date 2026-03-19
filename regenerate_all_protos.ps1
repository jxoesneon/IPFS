# Regenerate all proto files for ipfs and dart_libp2p using relative paths

$protoc = "C:\Users\Eduardo\AppData\Local\Temp\protoc\bin\protoc.exe"
$protocPlugin = "C:\Users\Eduardo\AppData\Local\Pub\Cache\bin\protoc-gen-dart.bat"

Write-Host "=== Regenerating dart_libp2p Protos (from lib) ===" -ForegroundColor Cyan
$libp2pLib = (Resolve-Path "vendor/dart_libp2p/lib").Path
$protos = Get-ChildItem -Path $libp2pLib -Filter "*.proto" -Recurse
foreach ($proto in $protos) {
    $fullPath = $proto.FullName
    Write-Host "Generating $fullPath..."
    & $protoc --dart_out=$libp2pLib --proto_path=$libp2pLib $fullPath --plugin=protoc-gen-dart=$protocPlugin
}

Write-Host "`n=== Regenerating dart_libp2p Protos (from proto) ===" -ForegroundColor Cyan
$libp2pProto = (Resolve-Path "vendor/dart_libp2p/proto").Path
$libp2pOutBase = Join-Path (Resolve-Path "vendor/dart_libp2p/lib").Path "pb"
if (-not (Test-Path $libp2pOutBase)) { New-Item -ItemType Directory -Path $libp2pOutBase -Force }

$protos = Get-ChildItem -Path $libp2pProto -Filter "*.proto" -Recurse
foreach ($proto in $protos) {
    $fullPath = $proto.FullName
    Write-Host "Generating $fullPath..."
    & $protoc --dart_out=$libp2pOutBase --proto_path=$libp2pProto $fullPath --plugin=protoc-gen-dart=$protocPlugin
}

Write-Host "`n=== Regenerating ipfs Protos ===" -ForegroundColor Cyan
$ipfsProtoDir = (Resolve-Path "lib/src/proto").Path
$ipfsOutDir = (Resolve-Path "lib/src/proto/generated").Path
if (-not (Test-Path $ipfsOutDir)) { New-Item -ItemType Directory -Path $ipfsOutDir -Force }

$protos = Get-ChildItem -Path $ipfsProtoDir -Filter "*.proto" -Recurse
foreach ($proto in $protos) {
    if ($proto.FullName.Contains("\generated\")) { continue }
    $fullPath = $proto.FullName
    Write-Host "Generating $fullPath..."
    & $protoc --dart_out=grpc:$ipfsOutDir --proto_path=$ipfsProtoDir $fullPath --plugin=protoc-gen-dart=$protocPlugin
}

Write-Host "`nAll protos regenerated!" -ForegroundColor Green
