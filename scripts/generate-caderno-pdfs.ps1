$ErrorActionPreference = 'Stop'

Set-StrictMode -Version Latest

function Resolve-Python {
    $candidates = @()

    if ($env:CODEX_PYTHON) {
        $candidates += $env:CODEX_PYTHON
    }

    $homeDir = [Environment]::GetFolderPath('UserProfile')
    if (-not $homeDir) {
        $homeDir = $HOME
    }

    if ($homeDir) {
        $candidates += @(
            (Join-Path $homeDir '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'),
            (Join-Path $homeDir '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python'),
            (Join-Path $homeDir '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3')
        )
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    foreach ($commandName in @('python3', 'python', 'py')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    throw "Python não encontrado. Instale Python 3 ou defina a variável CODEX_PYTHON apontando para o executável."
}

function Invoke-Python {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonPath,

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    if ((Split-Path -Leaf $PythonPath) -eq 'py.exe' -or (Split-Path -Leaf $PythonPath) -eq 'py') {
        & $PythonPath -3 $ScriptPath
    }
    else {
        & $PythonPath $ScriptPath
    }
}

$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$generator = Join-Path $scriptDir 'generate-caderno-pdfs.py'
if (-not (Test-Path -LiteralPath $generator)) {
    throw "Gerador não encontrado: $generator"
}

$python = Resolve-Python
Write-Host "Python: $python"
Invoke-Python -PythonPath $python -ScriptPath $generator
