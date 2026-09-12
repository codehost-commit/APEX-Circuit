param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [ValidateSet('basics', 'rules', 'flow', 'lap', 'field', 'fieldquick', 'race', 'race_full', 'presentation')]
    [string[]]$Cases = @('basics', 'rules', 'flow', 'lap', 'field', 'race', 'presentation')
)
$ErrorActionPreference = 'Stop'
$apexProject = Split-Path -Parent $PSScriptRoot
foreach ($apexCase in $Cases) {
    $apexLog = Join-Path $PSScriptRoot ('artifacts/' + $apexCase + '.log')
    $apexScene = if ($apexCase -eq 'presentation') { 'tests/presentation_checks.tscn' } else { 'tests/drive_checks.tscn' }
    & $Godot --headless --path $apexProject --fixed-fps 120 --log-file $apexLog $apexScene -- ('--case=' + $apexCase)
    if ($LASTEXITCODE -ne 0) { throw "APEX check failed: $apexCase (see $apexLog)" }
    if (Select-String -LiteralPath $apexLog -Pattern 'SCRIPT ERROR|SHADER ERROR' -Quiet) {
        throw "Runtime error in $apexLog"
    }
}
