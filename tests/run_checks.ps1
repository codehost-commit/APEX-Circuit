param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [ValidateSet('basics', 'rules', 'flow', 'lap', 'field', 'fieldquick', 'race', 'race_full')]
    [string[]]$Cases = @('basics', 'rules', 'flow', 'lap', 'field', 'race')
)
$ErrorActionPreference = 'Stop'
$apexProject = Split-Path -Parent $PSScriptRoot
foreach ($apexCase in $Cases) {
    $apexLog = Join-Path $PSScriptRoot ('artifacts/' + $apexCase + '.log')
    & $Godot --headless --path $apexProject --fixed-fps 120 --log-file $apexLog 'tests/drive_checks.tscn' -- ('--case=' + $apexCase)
    if ($LASTEXITCODE -ne 0) { throw "APEX check failed: $apexCase (see $apexLog)" }
    if (Select-String -LiteralPath $apexLog -Pattern 'SCRIPT ERROR|SHADER ERROR' -Quiet) {
        throw "Runtime error in $apexLog"
    }
}
