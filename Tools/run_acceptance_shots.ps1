# Layer C 截图装置启动器（spec 002 T035，presentation_design.md §12.2）
# 带窗运行 AcceptanceShots 自承载场景（headless 下 dummy driver 截图全黑，必须带窗），
# 在本机短暂弹出 1280x720 窗口属预期行为。路径一律读 EnvPath.json。
# 输出: AgentOps/acceptance_shots/<date>/*.png + manifest.json；
# findings.md 由 AI 读图评审后归档（§12.2 清单），不在本脚本内生成。

$ErrorActionPreference = "Continue"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot "EnvPath.json"
$envConfig = Get-Content -Raw -Encoding UTF8 $envPath | ConvertFrom-Json

$godot = $envConfig.godot.console
$project = $envConfig.project.godot_project
$scene = "res://AcceptanceShots/acceptance_shots.tscn"
$stdoutPath = Join-Path $repoRoot ".tmp_acceptance_shots_stdout.log"
$stderrPath = Join-Path $repoRoot ".tmp_acceptance_shots_stderr.log"
Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

& $godot --path $project --resolution 1280x720 $scene 1> $stdoutPath 2> $stderrPath
$exitCode = $LASTEXITCODE

if (Test-Path -LiteralPath $stdoutPath) {
    Get-Content -LiteralPath $stdoutPath -Encoding UTF8 |
        Where-Object { $_ -match "SHOTS" } |
        ForEach-Object { Write-Output $_ }
}

if ($exitCode -ne 0) {
    Write-Output "ACCEPTANCE SHOTS FAILED: Godot exited with code $exitCode (see $stderrPath)."
    exit $exitCode
}

Write-Output "ACCEPTANCE SHOTS DONE"
exit 0
