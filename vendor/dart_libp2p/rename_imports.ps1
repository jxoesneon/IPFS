
$files = Get-ChildItem -Path . -Recurse -Include *.dart,*.yaml,*.md
foreach ($file in $files) {
    if ($file.FullName -match "\\.git\\" -or $file.FullName -match "\\.dart_tool\\" -or $file.FullName -match "\\build\\") { continue }
    
    $content = Get-Content -Path $file.FullName -Raw
    if ($content -match "package:dart_libp2p") {
        $newContent = $content -replace "package:dart_libp2p", "package:ipfs_libp2p"
        Set-Content -Path $file.FullName -Value $newContent -NoNewline -Encoding utf8
        Write-Host "Updated imports in $($file.Name)"
    }
}
