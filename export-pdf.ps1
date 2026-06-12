param(
    [string]$InputFile = "matriz_produto_unb_gelos_corrigido.md",
    [string]$OutputFile = "pdf\matriz_produto_unb_gelos_corrigido.pdf",
    [string]$HtmlOutputFile = ""
)

$ErrorActionPreference = "Stop"

function Convert-InlineMarkdown {
    param([string]$Text)

    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)
    $encoded = $encoded -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
    $encoded = $encoded -replace '`(.+?)`', '<code>$1</code>'
    return $encoded
}

function Convert-MarkdownTableRow {
    param([string]$Line)

    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
    if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }

    return $trimmed.Split('|') | ForEach-Object { Convert-InlineMarkdown $_.Trim() }
}

function Convert-MarkdownToHtml {
    param([string[]]$Lines)

    $html = New-Object System.Collections.Generic.List[string]
    $paragraph = New-Object System.Collections.Generic.List[string]
    $orderedList = New-Object System.Collections.Generic.List[string]
    $tableBuffer = @()
    $inBlockquote = $false
    $blockquoteLines = New-Object System.Collections.Generic.List[string]

    function Flush-Paragraph {
        if ($paragraph.Count -gt 0) {
            $html.Add("<p>$(Convert-InlineMarkdown (($paragraph -join ' ').Trim()))</p>")
            $paragraph.Clear()
        }
    }

    function Flush-OrderedList {
        if ($orderedList.Count -gt 0) {
            $items = $orderedList | ForEach-Object { "<li>$(Convert-InlineMarkdown $_)</li>" }
            $html.Add("<ol>$($items -join '')</ol>")
            $orderedList.Clear()
        }
    }

    function Flush-Blockquote {
        if ($blockquoteLines.Count -gt 0) {
            $html.Add("<blockquote><p>$(Convert-InlineMarkdown (($blockquoteLines -join ' ').Trim()))</p></blockquote>")
            $blockquoteLines.Clear()
        }
    }

    function Flush-Table {
        if ($tableBuffer.Count -ge 2) {
            $headerCells = Convert-MarkdownTableRow $tableBuffer[0]
            $bodyRows = @()
            foreach ($row in $tableBuffer[2..($tableBuffer.Count - 1)]) {
                $cells = Convert-MarkdownTableRow $row
                $bodyRows += "<tr>$((@($cells | ForEach-Object { "<td>$_</td>" }) -join ''))</tr>"
            }

            $thead = "<thead><tr>$((@($headerCells | ForEach-Object { "<th>$_</th>" }) -join ''))</tr></thead>"
            $tbody = if ($bodyRows.Count -gt 0) { "<tbody>$($bodyRows -join '')</tbody>" } else { "" }
            $html.Add("<table>$thead$tbody</table>")
        }
        $script:tableBuffer = @()
    }

    foreach ($rawLine in $Lines) {
        $line = $rawLine.TrimEnd()

        if ($line -match '^\|') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-Blockquote
            $tableBuffer += $line
            continue
        }

        if ($tableBuffer.Count -gt 0) {
            Flush-Table
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            Flush-Paragraph
            Flush-OrderedList
            Flush-Blockquote
            continue
        }

        if ($line -match '^###\s+(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-Blockquote
            $html.Add("<h3>$(Convert-InlineMarkdown $matches[1])</h3>")
            continue
        }

        if ($line -match '^##\s+(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-Blockquote
            $html.Add("<h2>$(Convert-InlineMarkdown $matches[1])</h2>")
            continue
        }

        if ($line -match '^#\s+(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-Blockquote
            $html.Add("<h1>$(Convert-InlineMarkdown $matches[1])</h1>")
            continue
        }

        if ($line -match '^>\s*(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            $blockquoteLines.Add($matches[1])
            continue
        }

        if ($line -match '^\d+\.\s+(.+)$') {
            Flush-Paragraph
            Flush-Blockquote
            $orderedList.Add($matches[1])
            continue
        }

        Flush-OrderedList
        Flush-Blockquote
        $paragraph.Add($line.Trim())
    }

    if ($tableBuffer.Count -gt 0) { Flush-Table }
    Flush-Paragraph
    Flush-OrderedList
    Flush-Blockquote

    return ($html -join [Environment]::NewLine)
}

function Convert-AssetPathsToFileUris {
    param(
        [string]$Html,
        [string]$RootPath
    )

    return [System.Text.RegularExpressions.Regex]::Replace(
        $Html,
        'src="([^"]+)"',
        {
            param($match)

            $source = $match.Groups[1].Value
            if ($source -match '^(https?:|file:|data:)') {
                return $match.Value
            }

            $absolutePath = Join-Path $RootPath $source.Replace('/', '\\')
            $fileUri = [System.Uri]::new($absolutePath).AbsoluteUri
            return 'src="' + $fileUri + '"'
        }
    )
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputPath = Join-Path $root $InputFile
$outputPath = Join-Path $root $OutputFile
$htmlOutputPath = if ([string]::IsNullOrWhiteSpace($HtmlOutputFile)) { $null } else { Join-Path $root $HtmlOutputFile }
$internalHtmlPath = Join-Path $root ".pdf-export-source.html"

if (-not (Test-Path $inputPath)) {
    throw "Arquivo de entrada nao encontrado: $inputPath"
}

$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

if ($htmlOutputPath) {
    $htmlOutputDir = Split-Path -Parent $htmlOutputPath
    if (-not (Test-Path $htmlOutputDir)) {
        New-Item -ItemType Directory -Path $htmlOutputDir | Out-Null
    }
}

if (Test-Path $outputPath) {
    try {
        Remove-Item $outputPath -Force
    }
    catch {
        throw "Nao foi possivel substituir o PDF existente. Feche o arquivo se ele estiver aberto em algum visualizador e tente novamente: $outputPath"
    }
}

$edgeCandidates = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
)

$browser = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) {
    throw "Nenhum navegador compativel encontrado para imprimir o PDF."
}

Push-Location $root
try {
        $markdownLines = Get-Content -Path $inputPath -Encoding UTF8
        $documentHtml = Convert-MarkdownToHtml -Lines $markdownLines
        $headerHtml = Get-Content -Path (Join-Path $root "styles\header.html") -Raw -Encoding UTF8

        $headerHtml = Convert-AssetPathsToFileUris -Html $headerHtml -RootPath $root
        $styleUri = [System.Uri]::new((Join-Path $root "styles\a4.css")).AbsoluteUri

        $fullHtml = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Matriz de conversao do produto UnB em capacidade operacional GELOS</title>
    <link rel="stylesheet" href="$styleUri">
</head>
<body>
    $headerHtml
    <main class="pdf-body">
        $documentHtml
    </main>
</body>
</html>
"@

        Set-Content -Path $internalHtmlPath -Value $fullHtml -Encoding UTF8
        if ($htmlOutputPath) {
            Set-Content -Path $htmlOutputPath -Value $fullHtml -Encoding UTF8
        }

    $htmlUri = [System.Uri]::new($internalHtmlPath).AbsoluteUri
    & $browser --headless --disable-gpu --allow-file-access-from-files --print-to-pdf-no-header --print-to-pdf=$outputPath $htmlUri
}
finally {
    Pop-Location
}

Write-Output "PDF gerado em: $outputPath"
if ($htmlOutputPath) {
    Write-Output "HTML gerado em: $htmlOutputPath"
}