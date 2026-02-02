# Regenerate proto files for dart-libp2p

param(
    [string]$ProtocPath = "$env:TEMP\protoc\bin\protoc.exe",
    [string]$OutputDir = "lib/src/generated"
)

Write-Host "=== dart-libp2p Proto Regeneration ===" -ForegroundColor Cyan

# Check protoc exists
if (-not (Test-Path $ProtocPath)) {
    Write-Host "Error: protoc not found at $ProtocPath" -ForegroundColor Red
    Write-Host "Please install protoc 28.0 or later" -ForegroundColor Yellow
    exit 1
}

Write-Host "Using protoc: $ProtocPath" -ForegroundColor Green

# Add pub cache to PATH for protoc_plugin
$pubCache = "C:\Users\Eduardo\AppData\Local\Pub\Cache\bin"
$env:PATH = "$pubCache;$env:PATH"

# Clean output directory
if (Test-Path $OutputDir) {
    Write-Host "Cleaning output directory: $OutputDir" -ForegroundColor Yellow
    Remove-Item -Path $OutputDir -Recurse -Force
}

# Create output directory
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# List of proto files to generate
$protoFiles = @(
    "lib/core/crypto/pb/crypto.proto",
    "lib/core/peer/pb/peer_record.proto",
    "lib/core/record/pb/envelope.proto",
    "lib/core/sec/insecure/pb/plaintext.proto",
    "lib/p2p/crypto/pb/crypto.proto",
    "lib/p2p/host/autonat/pb/autonat.proto",
    "lib/p2p/protocol/autonatv2/pb/autonatv2.proto",
    "lib/p2p/protocol/circuitv2/pb/circuit.proto",
    "lib/p2p/protocol/circuitv2/pb/voucher.proto",
    "lib/p2p/protocol/holepunch/pb/holepunch.proto",
    "lib/p2p/protocol/identify/pb/identify.proto"
)

Write-Host "`nGenerating $($protoFiles.Count) proto files..." -ForegroundColor Cyan

$successCount = 0
$failedFiles = @()

foreach ($file in $protoFiles) {
    Write-Host "  Generating $file..." -NoNewline
    
    # Run protoc with --proto_path=lib
    & $ProtocPath --dart_out=$OutputDir --proto_path=lib $file 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host " ✓" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host " ✗" -ForegroundColor Red
        $failedFiles += $file
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Successfully generated: $successCount out of $($protoFiles.Count) files" -ForegroundColor Green

if ($failedFiles.Count -gt 0) {
    Write-Host "Failed files:" -ForegroundColor Red
    foreach ($file in $failedFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`nAll proto files regenerated successfully!" -ForegroundColor Green
Write-Host "Output directory: $OutputDir" -ForegroundColor Green

# Show generated files
Write-Host "`nGenerated files:" -ForegroundColor Cyan
Get-ChildItem -Path $OutputDir -Filter "*.pb.dart" -Recurse | ForEach-Object {
    Write-Host "  - $($_.FullName.Substring((Get-Location).Path.Length + 1))"
}