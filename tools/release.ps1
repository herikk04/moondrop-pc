# Gera e publica uma release do MOONDROP PC no GitHub.
# Uso:  powershell -File tools\release.ps1 -Version 0.2.0 -Notes "o que mudou"
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$Notes = "",
  [string]$NotesFile = "",
  [switch]$NoPublish
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$app  = Join-Path $root "app"
$gh   = "C:\Program Files\GitHub CLI\gh.exe"
$env:PATH = (Join-Path $root "ferramentas\flutter\bin") + ";" + $env:PATH
$tag = "v$Version"

# 1) versao no pubspec (0.2.0+<numero>)
$pub = Join-Path $app "pubspec.yaml"
$txt = [IO.File]::ReadAllText($pub)
$build = ([regex]::Match($txt, '(?m)^version:\s*[\d.]+\+(\d+)')).Groups[1].Value
if (-not $build) { $build = "0" }
$newBuild = [int]$build + 1
$txt = [regex]::Replace($txt, '(?m)^version:.*$', "version: $Version+$newBuild")
[IO.File]::WriteAllText($pub, $txt, (New-Object Text.UTF8Encoding $false))

# 2) compila
Push-Location $app
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "flutter build falhou" }
Pop-Location

# 3) empacota (pasta portatil + zip); fecha o app se estiver aberto para liberar os arquivos
Stop-Process -Name moondrop_pc -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
$rel  = Join-Path $app "build\windows\x64\runner\Release"
$dist = Join-Path $root "dist"
$dir  = Join-Path $dist "MOONDROP_PC"
Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item "$rel\*" $dir -Recurse -Force
$zip = Join-Path $dist "MOONDROP_PC-$tag-windows.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$dir\*" -DestinationPath $zip
"zip: $zip ({0:N1} MB)" -f ((Get-Item $zip).Length / 1MB)

# 3b) instalador (Inno Setup)
$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "Inno Setup nao encontrado (winget install JRSoftware.InnoSetup)" }
$setup = Join-Path $dist "MOONDROP_PC-v$Version-Setup.exe"
Remove-Item $setup -Force -ErrorAction SilentlyContinue
& $iscc "/DVersion=$Version" (Join-Path $root "installer\moondrop.iss") | Select-Object -Last 3
if (-not (Test-Path $setup)) { throw "o instalador nao foi gerado" }
"instalador: $setup ({0:N1} MB)" -f ((Get-Item $setup).Length / 1MB)

# 3c) versao portatil de um arquivo so (extrai no temp, abre e apaga ao fechar)
$portable = Join-Path $dist "MOONDROP_PC-v$Version-Portable.exe"
Remove-Item $portable -Force -ErrorAction SilentlyContinue
& $iscc "/DVersion=$Version" (Join-Path $root "installer\portable.iss") | Select-Object -Last 3
if (-not (Test-Path $portable)) { throw "o portatil nao foi gerado" }
"portatil: $portable ({0:N1} MB)" -f ((Get-Item $portable).Length / 1MB)
if ($NoPublish) { return }

# 4) commit da versao, tag e release
Push-Location $root
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { git commit -q -m "Release $tag" }
git tag -a $tag -m "MOONDROP PC $tag"
git push -q origin main
git push -q origin $tag
if ($NotesFile -ne "" -and (Test-Path $NotesFile)) { $Notes = [IO.File]::ReadAllText($NotesFile, [Text.Encoding]::UTF8) }
if ($Notes -eq "") { $Notes = "MOONDROP PC $tag" }
$nf = Join-Path $env:TEMP "moondrop_release_notes.md"
[IO.File]::WriteAllText($nf, $Notes, (New-Object Text.UTF8Encoding $false))
& $gh release create $tag $setup $portable $zip --title "MOONDROP PC $tag" --notes-file $nf
Pop-Location
