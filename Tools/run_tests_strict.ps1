param(
    [switch]$NoExitCodeFailure,
    [string]$StdoutPath = "",
    [string]$StderrPath = "",
    [int]$GodotExitCode = 0
)

$ErrorActionPreference = "Continue"

if ($StdoutPath -eq "" -and $StderrPath -eq "") {
    if ($env:GODOT_DISABLE_CRASH_HANDLER -ne "1") {
        Write-Output "STRICT FAILED: set GODOT_DISABLE_CRASH_HANDLER=1 before running Godot headless tests on this machine."
        Write-Output 'Example: $env:GODOT_DISABLE_CRASH_HANDLER="1"; powershell -ExecutionPolicy Bypass -File "F:/GreedySnake/Tools/run_tests_strict.ps1"'
        exit 2
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $envPath = Join-Path $repoRoot "EnvPath.json"
    $envConfig = Get-Content -Raw -Encoding UTF8 $envPath | ConvertFrom-Json

    $godot = $envConfig.godot.console
    $project = $envConfig.project.godot_project
    $scene = "Test/test_runner.tscn"
    $StdoutPath = Join-Path $repoRoot ".tmp_godot_test_stdout.log"
    $StderrPath = Join-Path $repoRoot ".tmp_godot_test_stderr.log"
    Remove-Item -LiteralPath $StdoutPath, $StderrPath -ErrorAction SilentlyContinue

    # 先重建 import/全局类缓存：headless 下全局 class_name 解析依赖该缓存，
    # 缓存过期曾导致整批测试解析失败。导入器输出不进严格扫描，只看退出码。
    $importStdout = Join-Path $repoRoot ".tmp_godot_test_import_stdout.log"
    $importStderr = Join-Path $repoRoot ".tmp_godot_test_import_stderr.log"
    & $godot --headless --import --path $project 1> $importStdout 2> $importStderr
    if ($LASTEXITCODE -ne 0) {
        Write-Output "STRICT FAILED: godot --import exited with code $LASTEXITCODE (see $importStderr)."
        exit $LASTEXITCODE
    }

    & $godot --headless --path $project $scene 1> $StdoutPath 2> $StderrPath
    $GodotExitCode = $LASTEXITCODE
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$exitCode = $GodotExitCode
$output = @()
if (Test-Path -LiteralPath $StdoutPath) {
    $output += Get-Content -LiteralPath $StdoutPath -Encoding UTF8
}
if (Test-Path -LiteralPath $StderrPath) {
    $output += Get-Content -LiteralPath $StderrPath -Encoding UTF8
}
$output = $output | Where-Object { $_ -ne "" } | ForEach-Object { $_.ToString() }
$output | ForEach-Object { Write-Output $_ }

$allowedErrorPatterns = @(
    "^ERROR: AtomRegistry: unknown atom 'nonexistent_atom'$",
    "^ERROR: Lambda capture at index \d+ was freed\. Passed `"null`" instead\.$",
    "^ERROR: \d+ RID allocations of type '.+' were leaked at exit\.$",
    "^ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.$"
)

$violations = New-Object System.Collections.Generic.List[string]
foreach ($line in $output) {
    $text = [string]$line
    $isViolation = $false

    if ($text -match "SCRIPT ERROR") {
        $isViolation = $true
    } elseif ($text -match "FAILED:") {
        $isViolation = $true
    } elseif ($text -match "^ERROR:") {
        $allowed = $false
        foreach ($pattern in $allowedErrorPatterns) {
            if ($text -match $pattern) {
                $allowed = $true
                break
            }
        }
        if (-not $allowed) {
            $isViolation = $true
        }
    }

    if ($isViolation) {
        $violations.Add($text)
    }
}

if ($exitCode -ne 0) {
    Write-Output "STRICT FAILED: Godot test process exited with code $exitCode."
    if (-not $NoExitCodeFailure) {
        exit $exitCode
    }
}

if ($violations.Count -gt 0) {
    Write-Output ("STRICT FAILED: found {0} unallowed error line(s)." -f $violations.Count)
    $violations | Select-Object -First 40 | ForEach-Object { Write-Output $_ }
    exit 1
}

Write-Output "STRICT PASSED: no unallowed Godot error output detected."
exit 0
