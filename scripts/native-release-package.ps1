Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "release-output-scope.ps1")

function Convert-ToNativeReleaseWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Invoke-NativeReleasePackaging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$RepositoryRoot,
        [Parameter(Mandatory)] [ValidatePattern('^\d+\.\d+\.\d+$')] [string]$Version,
        [Parameter(Mandatory)] [string]$OutputRoot,
        [Parameter(Mandatory)] [string]$WindowsStage3Path,
        [Parameter(Mandatory)] [string]$LinuxStage3Path,
        [switch]$DryRun
    )

    $RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $OutputRoot = Assert-SafeReleaseOutputRoot $OutputRoot $RepositoryRoot
    $WindowsStage3Path = [System.IO.Path]::GetFullPath($WindowsStage3Path)
    $LinuxStage3Path = [System.IO.Path]::GetFullPath($LinuxStage3Path)
    $systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($DryRun -and -not $OutputRoot.StartsWith(
        $systemTemporaryRoot,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Native release dry-run output must stay under the OS temporary directory: $OutputRoot"
    }

    $stagingRoot = Join-Path $OutputRoot "staging"
    $versionParts = $Version.Split('.')
    $nativeOnly = [int]$versionParts[0] -gt 0 -or [int]$versionParts[1] -ge 4
    $project = Join-Path $RepositoryRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"

    function New-ReleasePackage {
        param(
            [Parameter(Mandatory)] [string]$Runtime,
            [Parameter(Mandatory)] [string]$PlatformName
        )

        $packageName = "sollang-$Version-$PlatformName"
        $packageRoot = Join-Path $stagingRoot $packageName
        $executableName = if ($Runtime -eq "win-x64") { "sollang.exe" } else { "sollang" }
        $stage3Source = if ($Runtime -eq "win-x64") { $WindowsStage3Path } else { $LinuxStage3Path }

        if ($nativeOnly) {
            Write-Host "[release $PlatformName 1/5] Stage fixed-point native compiler."
            if (-not (Test-Path -LiteralPath $stage3Source -PathType Leaf)) {
                throw "verified native compiler is missing: $stage3Source"
            }
            if (-not $DryRun) {
                $stage3Platform = if ($Runtime -eq "win-x64") { "windows" } else { "linux" }
                & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
                    -Platform $stage3Platform `
                    -Stage3Path $stage3Source `
                    -RepositoryRoot $RepositoryRoot
            }
            New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
            Copy-Item -LiteralPath $stage3Source -Destination (Join-Path $packageRoot $executableName)
        } else {
            if ($DryRun) {
                throw "Native release dry-run requires a native-only release version"
            }
            Write-Host "[release $PlatformName 1/3] Publish self-contained compiler."
            dotnet publish $project -c Release -r $Runtime --self-contained true `
                -p:PublishSingleFile=true `
                -p:DebugType=None `
                -p:DebugSymbols=false `
                -p:AssemblyName=sollang `
                -p:PackageVersion=$Version `
                -p:InformationalVersion=$Version `
                -o $packageRoot | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $Runtime" }
        }

        Copy-Item (Join-Path $RepositoryRoot "stdlib") (Join-Path $packageRoot "stdlib") -Recurse
        Copy-Item (Join-Path $RepositoryRoot "README.md") $packageRoot
        Copy-Item (Join-Path $RepositoryRoot "LICENSE") $packageRoot
        if (-not $nativeOnly) {
            Copy-Item (Join-Path $RepositoryRoot "Sollang.slnx") $packageRoot
            $packageDocs = Join-Path $packageRoot "docs"
            New-Item -ItemType Directory -Path $packageDocs -Force | Out-Null
            Copy-Item (Join-Path $RepositoryRoot "docs\STAGE3_COMPILER.md") $packageDocs
            $stage3Name = if ($Runtime -eq "win-x64") { "sollangc-stage3.exe" } else { "sollangc-stage3" }
            if (-not (Test-Path -LiteralPath $stage3Source -PathType Leaf)) {
                throw "verified Stage 3 compiler is missing: $stage3Source"
            }
            Copy-Item -LiteralPath $stage3Source -Destination (Join-Path $packageRoot $stage3Name)
        }

        $verifyStep = if ($nativeOnly) { "2/5" } else { "2/3" }
        Write-Host "[release $PlatformName $verifyStep] Verify package contents."
        $required = @(
            (Join-Path $packageRoot $executableName),
            (Join-Path $packageRoot "stdlib\sys\io.slg"),
            (Join-Path $packageRoot "README.md"),
            (Join-Path $packageRoot "LICENSE")
        )
        foreach ($path in $required) {
            if (-not (Test-Path -LiteralPath $path)) { throw "release package is missing $path" }
        }

        if (-not $nativeOnly) {
            foreach ($path in @(
                (Join-Path $packageRoot "Sollang.slnx"),
                (Join-Path $packageRoot "docs\STAGE3_COMPILER.md"),
                (Join-Path $packageRoot $stage3Name)
            )) {
                if (-not (Test-Path -LiteralPath $path)) { throw "release package is missing $path" }
            }
        }

        if ($nativeOnly) {
            $forbidden = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object {
                $_.Name -match '\.(dll|deps\.json|runtimeconfig\.json|pdb)$' -or
                $_.Name -like 'sollangc-stage*'
            }
            if ($forbidden) {
                throw "0.4 native-only package contains forbidden bootstrap artifacts: $($forbidden.FullName -join ', ')"
            }
            $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $stage3Source).Hash
            $packageHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packageRoot $executableName)).Hash
            if ($sourceHash -ne $packageHash) {
                throw "packaged compiler hash differs from the verified native compiler"
            }
        }

        if ($nativeOnly -and -not $DryRun) {
            $parityProof = Join-Path $RepositoryRoot "artifacts\native-cli-full-parity\$Runtime-$sourceHash.verified"
            if (-not (Test-Path -LiteralPath $parityProof -PathType Leaf)) {
                throw "0.4 release is blocked: full native CLI parity proof is missing for $Runtime compiler hash $sourceHash"
            }
            $parityVersion = [IO.File]::ReadAllText($parityProof).Trim()
            if ($parityVersion -ne "Sollang $Version") {
                throw "native CLI parity proof targets '$parityVersion', expected 'Sollang $Version'"
            }

            Write-Host "[release $PlatformName 3/5] Verify native CLI version contract."
            if ($Runtime -eq "win-x64") {
                $versionOutput = & (Join-Path $packageRoot $executableName) --version
            } else {
                $wslExecutable = Convert-ToNativeReleaseWslPath (Join-Path $packageRoot $executableName)
                $versionOutput = & wsl.exe -- $wslExecutable --version
            }
            if ($LASTEXITCODE -ne 0 -or ($versionOutput -join "`n").Trim() -ne "Sollang $Version") {
                throw "native compiler does not preserve `sollang --version`: expected 'Sollang $Version'"
            }

            Write-Host "[release $PlatformName 4/5] Build and run with the packaged compiler and standard library."
            $smokeRoot = Join-Path $OutputRoot "smoke-$PlatformName"
            New-Item -ItemType Directory -Path $smokeRoot -Force | Out-Null
            $smokeSource = Join-Path $RepositoryRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-single-smoke.slg"
            if ($Runtime -eq "win-x64") {
                $smokeExecutable = Join-Path $smokeRoot "smoke.exe"
                & (Join-Path $packageRoot $executableName) build $smokeSource -o $smokeExecutable --target windows-x64 --stdlib (Join-Path $packageRoot "stdlib") --llvm (Join-Path $RepositoryRoot ".tools\llvm-22.1.8") -O1 | Out-Host
                if ($LASTEXITCODE -ne 0) { throw "packaged Windows compiler failed the build smoke test" }
                $smokeOutput = & $smokeExecutable
            } else {
                $wslCompiler = Convert-ToNativeReleaseWslPath (Join-Path $packageRoot $executableName)
                $wslSource = Convert-ToNativeReleaseWslPath $smokeSource
                $wslExecutable = Convert-ToNativeReleaseWslPath (Join-Path $smokeRoot "smoke")
                $wslStdlib = Convert-ToNativeReleaseWslPath (Join-Path $packageRoot "stdlib")
                $wslLlvm = Convert-ToNativeReleaseWslPath (Join-Path $RepositoryRoot "scripts\linux-cross-llvm")
                & wsl.exe -- $wslCompiler build $wslSource -o $wslExecutable --target linux-x64 --stdlib $wslStdlib --llvm $wslLlvm -O1 | Out-Host
                if ($LASTEXITCODE -ne 0) { throw "packaged Linux compiler failed the build smoke test" }
                $smokeOutput = & wsl.exe -- $wslExecutable
            }
            if ($LASTEXITCODE -ne 0 -or ($smokeOutput -join "`n").Trim() -ne "stage2-single-ok") {
                throw "packaged compiler build/run smoke output mismatch"
            }
        }

        $archiveStep = if ($nativeOnly) { "5/5" } else { "3/3" }
        Write-Host "[release $PlatformName $archiveStep] Archive package."
        if ($Runtime -eq "win-x64") {
            $archive = Join-Path $OutputRoot "$packageName.zip"
            Compress-Archive -Path $packageRoot -DestinationPath $archive -CompressionLevel Optimal
        } else {
            $archive = Join-Path $OutputRoot "$packageName.tar.gz"
            tar -C $stagingRoot -czf $archive $packageName
            if ($LASTEXITCODE -ne 0) { throw "tar failed for $packageName" }
        }
        $archive
    }

    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    foreach ($ownedPath in @(
        $stagingRoot,
        (Join-Path $OutputRoot "smoke-windows-x64"),
        (Join-Path $OutputRoot "smoke-linux-x64"),
        (Join-Path $OutputRoot "sollang-$Version-windows-x64.zip"),
        (Join-Path $OutputRoot "sollang-$Version-linux-x64.tar.gz"),
        (Join-Path $OutputRoot "SHA256SUMS.txt")
    )) {
        Remove-OwnedReleasePath $OutputRoot $ownedPath
    }
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    $windowsArchive = New-ReleasePackage -Runtime "win-x64" -PlatformName "windows-x64"
    $linuxArchive = New-ReleasePackage -Runtime "linux-x64" -PlatformName "linux-x64"
    $checksumPath = Join-Path $OutputRoot "SHA256SUMS.txt"
    @($windowsArchive, $linuxArchive) | ForEach-Object {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash.ToLowerInvariant()
        "$hash  $([System.IO.Path]::GetFileName($_))"
    } | Set-Content -LiteralPath $checksumPath -Encoding utf8NoBOM

    [pscustomobject]@{
        WindowsArchive = $windowsArchive
        LinuxArchive = $linuxArchive
        ChecksumPath = $checksumPath
    }
}
