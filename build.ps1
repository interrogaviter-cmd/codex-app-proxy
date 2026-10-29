param(
  [ValidateSet('Debug', 'Release')]
  [string]$Config = 'Release',
  [ValidateSet('MSVC', 'MinGW')]
  [string]$Toolchain = 'MSVC',
  [string]$GccBin = '',
  [switch]$Clean,
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).Path
$buildRoot = Join-Path $root 'build'
$output = Join-Path $root ('out\{0}-{1}' -f $Toolchain.ToLowerInvariant(), $Config.ToLowerInvariant())

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

function Assert-LocalBuildRoot {
  if (Test-Path -LiteralPath $buildRoot) {
    $item = Get-Item -LiteralPath $buildRoot -Force
    $resolved = (Resolve-Path -LiteralPath $buildRoot).Path
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        (Split-Path -Parent $resolved) -ne $root) {
      throw "Build root is not a normal directory inside the repository: $buildRoot"
    }
  }
}

function Remove-LocalBuildDir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Assert-LocalBuildRoot
  $item = Get-Item -LiteralPath $Path -Force
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $resolvedRoot = (Resolve-Path -LiteralPath $buildRoot).Path
  if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
      (Split-Path -Parent $resolved) -ne $resolvedRoot) {
    throw "Refusing to remove a directory outside the build root: $Path"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}

$previousPath = $env:PATH
try {
Assert-LocalBuildRoot
if ($Toolchain -eq 'MinGW') {
  if (-not $GccBin) {
    if (-not $env:CONDA_PREFIX) { throw 'Pass -GccBin or activate the Conda GCC environment first.' }
    $GccBin = Join-Path $env:CONDA_PREFIX 'Library\bin'
  }
  $GccBin = (Resolve-Path -LiteralPath $GccBin).Path
  foreach ($tool in @('cmake.exe', 'ctest.exe', 'ninja.exe', 'g++.exe', 'x86_64-w64-mingw32-ar.exe', 'x86_64-w64-mingw32-ranlib.exe', 'x86_64-w64-mingw32-windres.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $GccBin $tool) -PathType Leaf)) { throw "Missing tool: $(Join-Path $GccBin $tool)" }
  }
  $env:PATH = "$GccBin;$env:PATH"
  $cmake = Join-Path $GccBin 'cmake.exe'
  $ctest = Join-Path $GccBin 'ctest.exe'
  $gccCmakeBin = $GccBin.Replace('\', '/')
  $commonArgs = @('-G', 'Ninja', "-DCMAKE_MAKE_PROGRAM=$gccCmakeBin/ninja.exe", "-DCMAKE_CXX_COMPILER=$gccCmakeBin/g++.exe", "-DCMAKE_AR=$gccCmakeBin/x86_64-w64-mingw32-ar.exe", "-DCMAKE_RANLIB=$gccCmakeBin/x86_64-w64-mingw32-ranlib.exe", "-DCMAKE_RC_COMPILER=$gccCmakeBin/x86_64-w64-mingw32-windres.exe")
  $debugDir = Join-Path $buildRoot 'mingw-debug'
  $build = Join-Path $buildRoot ('mingw-' + $Config.ToLowerInvariant())
} else {
  $cmake = 'cmake'
  $ctest = 'ctest'
  $commonArgs = @('-G', 'Visual Studio 17 2022', '-A', 'x64')
  $build = Join-Path $buildRoot 'vs2022'
  $debugDir = $build
}

if ($Clean) {
  Remove-LocalBuildDir $build
  if (-not $SkipTests -and $debugDir -ne $build) { Remove-LocalBuildDir $debugDir }
}

if (-not $SkipTests) {
  $debugArgs = @('-S', $root, '-B', $debugDir) + $commonArgs
  if ($Toolchain -eq 'MinGW') { $debugArgs += '-DCMAKE_BUILD_TYPE=Debug' }
  $debugArgs += '-DCODEX_PROXY_BUILD_TESTS=ON'
  Invoke-Checked $cmake $debugArgs
  Invoke-Checked $cmake @('--build', $debugDir, '--config', 'Debug')
  Invoke-Checked $ctest @('--test-dir', $debugDir, '-C', 'Debug', '--output-on-failure')
  Invoke-Checked 'node' @((Join-Path $root 'tests\verify-start-here.mjs'), (Join-Path $root 'resources\START-HERE.html'), (Join-Path $root 'resources\default_config.json'))
}

if ($Config -ne 'Debug' -or $SkipTests) {
  $configArgs = @('-S', $root, '-B', $build) + $commonArgs
  if ($Toolchain -eq 'MinGW') { $configArgs += "-DCMAKE_BUILD_TYPE=$Config" }
  Invoke-Checked $cmake $configArgs
  Invoke-Checked $cmake @('--build', $build, '--config', $Config)
}

$exe = if ($Toolchain -eq 'MinGW') { Join-Path $build 'CodexProxyLauncher.exe' } else { Join-Path $build "$Config\CodexProxyLauncher.exe" }
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Built executable not found: $exe" }

# Verify a fresh package before updating the output; preserve any existing configuration and logs.
$stage = Join-Path $buildRoot ('.package-check-' + [Guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $stage | Out-Null
  Copy-Item -LiteralPath $exe -Destination $stage
  Copy-Item -LiteralPath (Join-Path $root 'resources\START-HERE.html') -Destination $stage
  Copy-Item -LiteralPath (Join-Path $root 'resources\default_config.json') -Destination (Join-Path $stage 'config.json')
  Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $stage
  & (Join-Path $root 'tests\verify-package.ps1') -Path $stage
  New-Item -ItemType Directory -Force -Path $output | Out-Null
  foreach ($name in @('CodexProxyLauncher.exe', 'START-HERE.html', 'README.md')) {
    Copy-Item -LiteralPath (Join-Path $stage $name) -Destination (Join-Path $output $name) -Force
  }
  if (-not (Test-Path -LiteralPath (Join-Path $output 'config.json'))) {
    Copy-Item -LiteralPath (Join-Path $stage 'config.json') -Destination (Join-Path $output 'config.json')
  }
} finally {
  Remove-LocalBuildDir $stage
}

Write-Host "Output written to $output"
} finally {
  $env:PATH = $previousPath
}
