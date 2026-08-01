param(
    [int]$Port = 8775,
    [switch]$NoOpen
)

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $repositoryRoot "Tools\functional_test_server.py"
$serverArguments = @($serverPath, "--port", $Port)

if ($NoOpen) {
    $serverArguments += "--no-open"
}

$pythonCommand = Get-Command python -CommandType Application -ErrorAction SilentlyContinue
if ($null -ne $pythonCommand) {
    & $pythonCommand.Source @serverArguments
    exit $LASTEXITCODE
}

$pythonLauncher = Get-Command py -CommandType Application -ErrorAction SilentlyContinue
if ($null -ne $pythonLauncher) {
    & $pythonLauncher.Source -3 @serverArguments
    exit $LASTEXITCODE
}

throw "Python 3 was not found. Install it or add python.exe/py.exe to PATH."
