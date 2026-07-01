param(
    [string]$MiniZinc = "minizinc",
    [string[]]$Suites = @(),
    [string[]]$Sizes = @(),
    [string[]]$Models = @(),
    [string[]]$Solvers = @("Chuffed"),
    [int]$Parallel = 0,
    [string]$BackendFlags = "",
    [int]$OptimizationLevel = -1,
    [int]$TimeLimitMs = 60000,
    [int]$MaxRuns = 0,
    [string]$ResultsDir = "benchmark_results",
    [switch]$FullOutput,
    [switch]$FallbackOnNoResponse
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Manifest = Join-Path $Root "data\benchmarks_organized\manifest.csv"
$ModelDir = Join-Path $Root "models"
$OutDir = Join-Path $Root $ResultsDir
$RawDir = Join-Path $OutDir "raw"
$TempModelDir = Join-Path $OutDir "temp_models"
$Summary = Join-Path $OutDir "summary.csv"

if (-not (Test-Path $Manifest)) {
    throw "Manifest not found: $Manifest. Run python tools\generate_benchmark_data.py first."
}

function Expand-CommaList {
    param([string[]]$Values)
    $expanded = @()
    foreach ($value in $Values) {
        if ($null -eq $value) {
            continue
        }
        $expanded += $value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }
    return $expanded
}

$Suites = Expand-CommaList $Suites
$Sizes = Expand-CommaList $Sizes
$Models = Expand-CommaList $Models
$Solvers = Expand-CommaList $Solvers

New-Item -ItemType Directory -Force -Path $RawDir | Out-Null
New-Item -ItemType Directory -Force -Path $TempModelDir | Out-Null

$PreviousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$probe = & $MiniZinc --version 2>&1
$probeExitCode = $LASTEXITCODE
$ErrorActionPreference = $PreviousErrorActionPreference
if ($probeExitCode -ne 0) {
    throw "MiniZinc is not available through '$MiniZinc'. Add it to PATH or pass -MiniZinc 'C:\path\to\minizinc.exe'."
}

$rows = Import-Csv $Manifest
if ($Suites.Count -gt 0) {
    $rows = $rows | Where-Object { $Suites -contains $_.suite }
}
if ($Sizes.Count -gt 0) {
    $rows = $rows | Where-Object { $Sizes -contains $_.size }
}

$summaryRows = New-Object System.Collections.Generic.List[object]
$runCount = 0
$stopRuns = $false

function Save-Summary {
    if ($summaryRows.Count -gt 0) {
        $summaryRows | Export-Csv -NoTypeInformation -Encoding utf8 -Path $Summary
    } else {
        "" | Out-File -FilePath $Summary -Encoding utf8
    }
}

foreach ($row in $rows) {
    if ($stopRuns) {
        break
    }

    $compatibleModels = $row.compatible_models -split "\|"
    if ($Models.Count -gt 0) {
        $compatibleModels = $Models | Where-Object {
            ($compatibleModels -contains $_) -or
            ($row.suite -eq "epsilon_free" -and $_ -like "*epsilon_consensus_free*") -or
            ($row.suite -eq "epsilon_directed" -and $_ -like "*epsilon_consensus_directed*") -or
            ($row.suite -eq "consensus_free" -and $_ -like "*consensus_free*") -or
            ($row.suite -eq "consensus_directed" -and $_ -like "*consensus_directed*")
        }
    }

    foreach ($modelName in $compatibleModels) {
        if ($stopRuns) {
            break
        }

        $modelPath = Join-Path $ModelDir $modelName
        $dataPath = Join-Path $Root $row.file

        if (-not (Test-Path $modelPath)) {
            Write-Warning "Skipping missing model: $modelPath"
            continue
        }

        $runModelPath = $modelPath
        if ($FullOutput) {
            $modelSupportsFullOutput = Select-String -Path $modelPath -Pattern "bool\s*:\s*full_output\s*=\s*false\s*;" -Quiet
            if ($modelSupportsFullOutput) {
                $modelText = Get-Content -Path $modelPath -Raw
                $modelText = $modelText -replace "bool\s*:\s*full_output\s*=\s*false\s*;", "bool: full_output = true;"
                $runModelPath = Join-Path $TempModelDir ([IO.Path]::GetFileName($modelPath))
                [IO.File]::WriteAllText($runModelPath, $modelText, [Text.Encoding]::ASCII)
            }
        }

        foreach ($solver in $Solvers) {
            if ($MaxRuns -gt 0 -and $runCount -ge $MaxRuns) {
                $stopRuns = $true
                break
            }

            $runCount += 1
            $safeSolver = ($solver -replace "[^A-Za-z0-9_-]", "_")
            $hashInput = "{0}|{1}|{2}|{3}" -f $row.suite, $row.file, $modelName, $solver
            $hashBytes = [Text.Encoding]::UTF8.GetBytes($hashInput)
            $sha = [Security.Cryptography.SHA1]::Create()
            $hash = ([BitConverter]::ToString($sha.ComputeHash($hashBytes))).Replace("-", "").Substring(0, 10).ToLower()
            $baseName = "{0:D4}__{1}__{2}__{3}" -f $runCount, $row.suite, $safeSolver, $hash
            $logPath = Join-Path $RawDir "$baseName.log"

            Write-Host "[$runCount] $solver | $modelName | $($row.file)"

            $sw = [Diagnostics.Stopwatch]::StartNew()
            $PreviousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $minizincArgs = @("--solver", $solver, "--time-limit", $TimeLimitMs, "--statistics", "-I", $ModelDir)
            if ($OptimizationLevel -ge 0) {
                $minizincArgs += "-O$OptimizationLevel"
            }
            if ($Parallel -gt 0) {
                $minizincArgs += @("--parallel", $Parallel)
            }
            if ($BackendFlags.Trim() -ne "") {
                $minizincArgs += @("--fzn-flags", $BackendFlags)
            }
            $minizincArgs += @($runModelPath, $dataPath)

            $output = & $MiniZinc @minizincArgs 2>&1
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = $PreviousErrorActionPreference
            $sw.Stop()

            $output | Out-File -FilePath $logPath -Encoding utf8

            $status = "unknown"
            $joined = $output -join "`n"
            if ($joined -match "=====UNSATISFIABLE=====") {
                $status = "unsat"
            } elseif ($joined -match "=====UNKNOWN=====") {
                $status = "unknown"
            } elseif ($joined -match "==========") {
                $status = "optimal_or_complete"
            } elseif ($joined -match "----------") {
                $status = "solution_or_timeout"
            } elseif ($exitCode -ne 0) {
                $status = "error"
            }

            $summaryRows.Add([pscustomobject]@{
                suite = $row.suite
                data = $row.file
                size = $row.size
                A = $row.A
                C = $row.C
                Iend = $row.Iend
                scenario = $row.scenario
                model = $modelName
                solver = $solver
                parallel = $Parallel
                backend_flags = $BackendFlags
                optimization_level = $OptimizationLevel
                time_limit_ms = $TimeLimitMs
                wall_time_ms = [int]$sw.ElapsedMilliseconds
                exit_code = $exitCode
                status = $status
                log = $logPath
            })
            Save-Summary

            if ($FallbackOnNoResponse -and $status -notin @("unknown", "error")) {
                break
            }
        }
    }
}

Save-Summary
Write-Host "Summary written to $Summary"
Write-Host "Raw logs written to $RawDir"
