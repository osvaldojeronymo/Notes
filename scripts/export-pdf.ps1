param(
    [string]$InputFile,
    [string]$OutputFile,
    [string]$HtmlOutputFile = '',
    [string]$DocumentTitle = 'Informe Executivo',
    [string]$Subtitle = 'Produtos da Meta 2',
    [string]$ReportDate = (Get-Date).ToString(
        "dd 'de' MMMM 'de' yyyy",
        [System.Globalization.CultureInfo]::GetCultureInfo('pt-BR')
    ),
    [string]$FooterLeft = '#INTERNO.TODOS | META 2 - DIAGNÓSTICO',
    [string]$FooterCenter = 'Informe Executivo - Produtos da Meta 2',

    [AllowEmptyString()]
    [string]$FooterRight = '',

    [string]$TemplateFile = 'pdf-template.html',

    [int]$RenderWaitMs = 8000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Test-IsLinuxRuntime {
    if (Get-Variable -Name IsLinux -Scope Global -ErrorAction SilentlyContinue) {
        return [bool]$global:IsLinux
    }

    if ($PSVersionTable.PSEdition -eq 'Core' -and $env:OS -ne 'Windows_NT') {
        return $true
    }

    return $false
}

function Resolve-BrowserPath {
    $browserCandidates = @()

    if (Test-IsLinuxRuntime) {
        $browserCandidates += @(
            '/usr/bin/google-chrome',
            '/usr/bin/chromium',
            '/usr/bin/chromium-browser',
            '/snap/bin/chromium',
            '/usr/bin/microsoft-edge'
        )
    }
    else {
        $browserCandidates += @(
            'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
            'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
            'C:\Program Files\Google\Chrome\Application\chrome.exe',
            'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
        )
    }

    return $browserCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
}

function Read-TextFileRobust {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($bytes.Length -eq 0) {
        return ''
    }

    # BOM UTF-8
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }

    # BOM UTF-16 LE
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }

    # BOM UTF-16 BE
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
    }

    try {
        $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
        return $utf8Strict.GetString($bytes)
    }
    catch {
        $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
        return $cp1252.GetString($bytes)
    }
}

function Split-Lines {
    param([string]$Text)

    if ($null -eq $Text) {
        return @()
    }

    return ($Text -split "`r`n|`n|`r")
}

function Convert-InlineMarkdown {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)

    # Markdown inline básico
    $encoded = $encoded -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
    $encoded = $encoded -replace '_(.+?)_', '<em>$1</em>'
    $encoded = $encoded -replace '`(.+?)`', '<code>$1</code>'

    return $encoded
}

function Convert-MarkdownTableRow {
    param([string]$Line)

    $trimmed = $Line.Trim()

    if ($trimmed.StartsWith('|')) {
        $trimmed = $trimmed.Substring(1)
    }

    if ($trimmed.EndsWith('|')) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - 1)
    }

    return $trimmed.Split('|') | ForEach-Object { Convert-InlineMarkdown $_.Trim() }
}

function Test-MarkdownTableSeparator {
    param([string]$Line)

    $trimmed = $Line.Trim()

    if (-not $trimmed.StartsWith('|')) {
        return $false
    }

    if ($trimmed.StartsWith('|')) {
        $trimmed = $trimmed.Substring(1)
    }

    if ($trimmed.EndsWith('|')) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - 1)
    }

    $parts = $trimmed.Split('|') | ForEach-Object { $_.Trim() }

    if ($parts.Count -eq 0) {
        return $false
    }

    foreach ($part in $parts) {
        if ($part -notmatch '^:?-{3,}:?$') {
            return $false
        }
    }

    return $true
}

function Get-FrontMatterValue {
    param(
        [string[]]$Lines,
        [string]$Key
    )

    if ($Lines.Count -lt 3) {
        return $null
    }

    if ($Lines[0].Trim() -ne '---') {
        return $null
    }

    for ($i = 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i].Trim()

        if ($line -eq '---') {
            break
        }

        if ($line -match "^$Key\s*:\s*(.+)$") {
            return $matches[1].Trim().Trim('"').Trim("'")
        }
    }

    return $null
}

function Convert-MarkdownToHtml {
    param([string[]]$Lines)

    $html = New-Object System.Collections.Generic.List[string]
    $paragraph = New-Object System.Collections.Generic.List[string]
    $orderedList = New-Object System.Collections.Generic.List[string]
    $unorderedList = New-Object System.Collections.Generic.List[string]
    $blockquoteLines = New-Object System.Collections.Generic.List[string]
    $tableBuffer = New-Object System.Collections.Generic.List[string]

    $inFrontMatter = $false
    $frontMatterProcessed = $false

    function Flush-Paragraph {
        if ($paragraph.Count -gt 0) {
            $text = ($paragraph -join ' ').Trim()
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $html.Add("<p>$(Convert-InlineMarkdown $text)</p>")
            }
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

    function Flush-UnorderedList {
        if ($unorderedList.Count -gt 0) {
            $items = $unorderedList | ForEach-Object { "<li>$(Convert-InlineMarkdown $_)</li>" }
            $html.Add("<ul>$($items -join '')</ul>")
            $unorderedList.Clear()
        }
    }

    function Flush-Blockquote {
        if ($blockquoteLines.Count -gt 0) {
            $text = ($blockquoteLines -join ' ').Trim()
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $html.Add("<blockquote><p>$(Convert-InlineMarkdown $text)</p></blockquote>")
            }
            $blockquoteLines.Clear()
        }
    }

    function Flush-Table {
        if ($tableBuffer.Count -lt 2) {
            foreach ($row in $tableBuffer) {
                if (-not [string]::IsNullOrWhiteSpace($row)) {
                    $paragraph.Add($row.Trim())
                }
            }
            $tableBuffer.Clear()
            return
        }

        $headerLine = $tableBuffer[0]
        $separatorLine = $tableBuffer[1]

        if (-not (Test-MarkdownTableSeparator $separatorLine)) {
            foreach ($row in $tableBuffer) {
                if (-not [string]::IsNullOrWhiteSpace($row)) {
                    $paragraph.Add($row.Trim())
                }
            }
            $tableBuffer.Clear()
            return
        }

        $headerCells = Convert-MarkdownTableRow $headerLine
        $theadCellsHtml = ($headerCells | ForEach-Object { "<th>$_</th>" }) -join ''
        $theadHtml = "<thead><tr>$theadCellsHtml</tr></thead>"

        $bodyRows = New-Object System.Collections.Generic.List[string]

        for ($i = 2; $i -lt $tableBuffer.Count; $i++) {
            $row = $tableBuffer[$i]

            if ([string]::IsNullOrWhiteSpace($row)) {
                continue
            }

            if (Test-MarkdownTableSeparator $row) {
                continue
            }

            $cells = Convert-MarkdownTableRow $row
            $tds = ($cells | ForEach-Object { "<td>$_</td>" }) -join ''
            $bodyRows.Add("<tr>$tds</tr>")
        }

        $tbodyHtml = ''
        if ($bodyRows.Count -gt 0) {
            $tbodyHtml = "<tbody>$($bodyRows -join '')</tbody>"
        }

        $html.Add("<table>$theadHtml$tbodyHtml</table>")
        $tableBuffer.Clear()
    }

    foreach ($rawLine in $Lines) {
        $line = $rawLine.TrimEnd()

        # Ignora front matter YAML
        if (-not $frontMatterProcessed) {
            if ($line -eq '---' -and -not $inFrontMatter) {
                $inFrontMatter = $true
                continue
            }
            elseif ($line -eq '---' -and $inFrontMatter) {
                $inFrontMatter = $false
                $frontMatterProcessed = $true
                continue
            }
        }

        if ($inFrontMatter) {
            continue
        }

        # Preserva HTML bruto quando vier em linha própria
        if ($line.TrimStart().StartsWith('<') -and $line.TrimEnd().EndsWith('>')) {
            Flush-Paragraph
            Flush-OrderedList
            Flush-UnorderedList
            Flush-Blockquote
            if ($tableBuffer.Count -gt 0) {
                Flush-Table
            }
            $html.Add($line.Trim())
            continue
        }

        if ($line -match '^\|') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-UnorderedList
            Flush-Blockquote
            $tableBuffer.Add($line)
            continue
        }

        if ($tableBuffer.Count -gt 0) {
            Flush-Table
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            Flush-Paragraph
            Flush-OrderedList
            Flush-UnorderedList
            Flush-Blockquote
            continue
        }

        if ($line -match '^###\s+(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-UnorderedList
            Flush-Blockquote
            $html.Add("<h3>$(Convert-InlineMarkdown $matches[1])</h3>")
            continue
        }

        if ($line -match '^##\s+(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-UnorderedList
            Flush-Blockquote
            $html.Add("<h2>$(Convert-InlineMarkdown $matches[1])</h2>")
            continue
        }

        if ($line -match '^#\s+(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-UnorderedList
            Flush-Blockquote
            $html.Add("<h1>$(Convert-InlineMarkdown $matches[1])</h1>")
            continue
        }

        if ($line -match '^>\s*(.+)$') {
            Flush-Paragraph
            Flush-OrderedList
            Flush-UnorderedList
            $blockquoteLines.Add($matches[1])
            continue
        }

        if ($line -match '^\d+\.\s+(.+)$') {
            Flush-Paragraph
            Flush-Blockquote
            Flush-UnorderedList
            $orderedList.Add($matches[1])
            continue
        }

        if ($line -match '^[-*]\s+(.+)$') {
            Flush-Paragraph
            Flush-Blockquote
            Flush-OrderedList
            $unorderedList.Add($matches[1])
            continue
        }

        Flush-OrderedList
        Flush-UnorderedList
        Flush-Blockquote
        $paragraph.Add($line.Trim())
    }

    if ($tableBuffer.Count -gt 0) {
        Flush-Table
    }

    Flush-Paragraph
    Flush-OrderedList
    Flush-UnorderedList
    Flush-Blockquote

    return ($html -join [Environment]::NewLine)
}

function Convert-AssetPathsToFileUris {
    param(
        [string]$Html,
        [string]$RootPath
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return $Html
    }

    return [System.Text.RegularExpressions.Regex]::Replace(
        $Html,
        '(src|href)="([^"]+)"',
        {
            param($match)

            $attr = $match.Groups[1].Value
            $source = $match.Groups[2].Value

            if ($source -match '^(https?:|file:|data:|#|mailto:|tel:|javascript:)') {
                return $match.Value
            }

            $absolutePath = Join-Path $RootPath ($source.Replace('/', '\\'))
            $fileUri = [System.Uri]::new($absolutePath).AbsoluteUri
            return "$attr=`"$fileUri`""
        }
    )
}

function Resolve-PandocConditional {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Template,

        [Parameter(Mandatory = $true)]
        [string]$VariableName,

        [string]$Value = ''
    )

    $escapedVar = [System.Text.RegularExpressions.Regex]::Escape($VariableName)

    $patternWithElse = '(?s)\$if\(' + $escapedVar + '\)\$(.*?)\$else\$(.*?)\$endif\$'
    $patternWithoutElse = '(?s)\$if\(' + $escapedVar + '\)\$(.*?)\$endif\$'

    if ([string]::IsNullOrWhiteSpace($Value)) {
        $Template = [System.Text.RegularExpressions.Regex]::Replace($Template, $patternWithElse, '$2')
        $Template = [System.Text.RegularExpressions.Regex]::Replace($Template, $patternWithoutElse, '')
    }
    else {
        $Template = [System.Text.RegularExpressions.Regex]::Replace($Template, $patternWithElse, '$1')
        $Template = [System.Text.RegularExpressions.Regex]::Replace($Template, $patternWithoutElse, '$1')
    }

    return $Template
}

function Build-HtmlFromTemplate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [string]$DocumentTitle,

        [Parameter(Mandatory = $true)]
        [string]$Subtitle,

        [Parameter(Mandatory = $true)]
        [string]$ReportDate,

        [Parameter(Mandatory = $true)]
        [string]$FooterLeft,

        [Parameter(Mandatory = $true)]
        [string]$FooterCenter,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$FooterRight = '',

        [Parameter(Mandatory = $true)]
        [string]$DocumentHtml,

        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    if (-not (Test-Path $TemplatePath)) {
        throw "Template não encontrado: $TemplatePath"
    }

    $templateHtml = Read-TextFileRobust -Path $TemplatePath

    $safeTitle = [System.Net.WebUtility]::HtmlEncode($DocumentTitle)
    $safeSubtitle = [System.Net.WebUtility]::HtmlEncode($Subtitle)
    $safeReportDate = [System.Net.WebUtility]::HtmlEncode($ReportDate)
    $safeFooterLeft = [System.Net.WebUtility]::HtmlEncode($FooterLeft)
    $safeFooterCenter = [System.Net.WebUtility]::HtmlEncode($FooterCenter)
    $safeFooterRight = [System.Net.WebUtility]::HtmlEncode($FooterRight)

    # 1) Resolve condicionais estilo Pandoc
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'title' -Value $DocumentTitle
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'subtitle' -Value $Subtitle
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'REPORT_DATE' -Value $ReportDate
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'report_date' -Value $ReportDate
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'date' -Value $ReportDate
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'FOOTER_LEFT' -Value $FooterLeft
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'footer_left' -Value $FooterLeft
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'FOOTER_CENTER' -Value $FooterCenter
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'footer_center' -Value $FooterCenter
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'FOOTER_RIGHT' -Value $FooterRight
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'footer_right' -Value $FooterRight
    $templateHtml = Resolve-PandocConditional -Template $templateHtml -VariableName 'body' -Value 'x'

    # 2) Resolve placeholders simples
    $replacements = @(
        @{ k = '$title$'; v = $safeTitle },
        @{ k = '$subtitle$'; v = $safeSubtitle },
        @{ k = '$REPORT_DATE$'; v = $safeReportDate },
        @{ k = '$report_date$'; v = $safeReportDate },
        @{ k = '$date$'; v = $safeReportDate },
        @{ k = '$FOOTER_LEFT$'; v = $safeFooterLeft },
        @{ k = '$footer_left$'; v = $safeFooterLeft },
        @{ k = '$FOOTER_CENTER$'; v = $safeFooterCenter },
        @{ k = '$footer_center$'; v = $safeFooterCenter },
        @{ k = '$FOOTER_RIGHT$'; v = $safeFooterRight },
        @{ k = '$footer_right$'; v = $safeFooterRight },
        @{ k = '$body$'; v = $DocumentHtml }
    )

    foreach ($item in $replacements) {
        $templateHtml = $templateHtml.Replace([string]$item.k, [string]$item.v)
    }

    # 3) Fallback para <title>
    $templateHtml = [System.Text.RegularExpressions.Regex]::Replace(
        $templateHtml,
        '(?is)<title>.*?</title>',
        ('<title>{0}</title>' -f $safeTitle)
    )

    # 4) Fallback para <main id="pdf-source" class="pdf-body"></main>
    $templateHtml = [System.Text.RegularExpressions.Regex]::Replace(
        $templateHtml,
        '(?is)<main\s+id="pdf-source"\s+class="pdf-body">\s*</main>',
        ('<main id="pdf-source" class="pdf-body">{0}</main>' -f $DocumentHtml)
    )

    # 5) Limpeza residual de marcadores Pandoc
    $templateHtml = [System.Text.RegularExpressions.Regex]::Replace($templateHtml, '\$if\([^)]+\)\$', '')
    $templateHtml = $templateHtml.Replace('$else$', '')
    $templateHtml = $templateHtml.Replace('$endif$', '')
    $templateHtml = [System.Text.RegularExpressions.Regex]::Replace(
        $templateHtml,
        '\$(title|subtitle|REPORT_DATE|report_date|date|FOOTER_LEFT|footer_left|FOOTER_CENTER|footer_center|FOOTER_RIGHT|footer_right|body)\$',
        ''
    )

    # 6) Converte caminhos relativos para file:///
    $templateHtml = Convert-AssetPathsToFileUris -Html $templateHtml -RootPath $RootPath

    return $templateHtml
}

function Wait-ForPdfReady {
    param(
        [string]$Path,
        [int]$TimeoutSeconds = 120,
        [int]$PollMilliseconds = 500
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastLength = -1
    $stableHits = 0

    while ((Get-Date) -lt $deadline) {
        if (Test-Path $Path) {
            try {
                $currentLength = (Get-Item $Path -ErrorAction Stop).Length

                if ($currentLength -gt 0 -and $currentLength -eq $lastLength) {
                    $stableHits++
                }
                else {
                    $stableHits = 0
                }

                $lastLength = $currentLength

                if ($stableHits -ge 3) {
                    return $true
                }
            }
            catch {
                # continua tentando
            }
        }

        Start-Sleep -Milliseconds $PollMilliseconds
    }

    if (Test-Path $Path) {
        return ((Get-Item $Path).Length -gt 0)
    }

    return $false
}

# =========================================================
# RESOLUÇÃO DE CAMINHOS DO PROJETO
# =========================================================
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$contentDir = Join-Path $root 'content'
$templatePath = Join-Path $root (Join-Path 'templates' $TemplateFile)

if (-not (Test-Path $contentDir)) {
    throw "Pasta de conteúdo não encontrada: $contentDir"
}

if (-not (Test-Path $templatePath)) {
    throw "Template principal não encontrado: $templatePath"
}

# =========================================================
# SELEÇÃO AUTOMÁTICA DO .MD MAIS RECENTE
# =========================================================
if (-not $InputFile) {
    $mdFiles = @(
        Get-ChildItem -Path $contentDir -Filter *.md -File -Recurse |
        Sort-Object LastWriteTime -Descending
    )

    if ($mdFiles.Count -eq 0) {
        throw "Nenhum arquivo .md encontrado na pasta ou subpastas: $contentDir"
    }

    $selectedFile = $mdFiles[0]

    $InputFile = $selectedFile.FullName

    $relativeInputFile = $selectedFile.FullName.Substring($contentDir.Length).TrimStart('\', '/')

    Write-Output "Arquivo selecionado automaticamente: $relativeInputFile"
}
else {
    if ([System.IO.Path]::IsPathRooted($InputFile)) {
        $selectedFile = Get-Item -Path $InputFile -ErrorAction Stop
        $InputFile = $selectedFile.FullName
        $relativeInputFile = $selectedFile.FullName.Substring($contentDir.Length).TrimStart('\', '/')
    }
    else {
        $inputCandidate = Join-Path $contentDir $InputFile

        if (Test-Path $inputCandidate) {
            $selectedFile = Get-Item -Path $inputCandidate -ErrorAction Stop
            $InputFile = $selectedFile.FullName
            $relativeInputFile = $selectedFile.FullName.Substring($contentDir.Length).TrimStart('\', '/')
        }
        else {
            $matches = @(
                Get-ChildItem -Path $contentDir -Filter ([System.IO.Path]::GetFileName($InputFile)) -File -Recurse
            )

            if ($matches.Count -eq 0) {
                throw "Arquivo de entrada não encontrado em content ou subpastas: $InputFile"
            }

            if ($matches.Count -gt 1) {
                $lista = ($matches | ForEach-Object {
                        $_.FullName.Substring($contentDir.Length).TrimStart('\', '/')
                    }) -join [Environment]::NewLine

                throw "Mais de um arquivo com o nome '$InputFile' foi encontrado. Informe o caminho relativo completo. Opções encontradas:$([Environment]::NewLine)$lista"
            }

            $selectedFile = $matches[0]
            $InputFile = $selectedFile.FullName
            $relativeInputFile = $selectedFile.FullName.Substring($contentDir.Length).TrimStart('\', '/')
        }
    }
}

$inputPath = $InputFile

if (-not (Test-Path $inputPath)) {
    throw "Arquivo de entrada não encontrado: $inputPath"
}

if (-not $OutputFile) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
    $OutputFile = "pdf\$baseName.pdf"
}

$outputPath = Join-Path $root $OutputFile

if ([string]::IsNullOrWhiteSpace($HtmlOutputFile)) {
    $htmlOutputPath = $null
}
else {
    $htmlOutputPath = Join-Path $root $HtmlOutputFile
}

$internalHtmlPath = Join-Path $root '.pdf-export-source.html'

$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if ($htmlOutputPath) {
    $htmlOutputDir = Split-Path -Parent $htmlOutputPath
    if (-not (Test-Path $htmlOutputDir)) {
        New-Item -ItemType Directory -Path $htmlOutputDir -Force | Out-Null
    }
}

if (Test-Path $outputPath) {
    try {
        Remove-Item $outputPath -Force
    }
    catch {
        throw "Não foi possível substituir o PDF existente. Feche o arquivo e tente novamente: $outputPath"
    }
}

$browser = Resolve-BrowserPath
if (-not $browser) {
    throw 'Nenhum navegador compatível (Edge/Chrome) encontrado para gerar o PDF.'
}

Push-Location $root
try {
    # Leitura robusta do markdown
    $markdownText = Read-TextFileRobust -Path $inputPath
    $markdownLines = Split-Lines -Text $markdownText

    $titleFromFrontMatter = Get-FrontMatterValue -Lines $markdownLines -Key 'title'
    $subtitleFromFrontMatter = Get-FrontMatterValue -Lines $markdownLines -Key 'subtitle'
    $reportDateFromFrontMatter = Get-FrontMatterValue -Lines $markdownLines -Key 'report_date'
    $footerLeftFromFrontMatter = Get-FrontMatterValue -Lines $markdownLines -Key 'footer_left'
    $footerCenterFromFrontMatter = Get-FrontMatterValue -Lines $markdownLines -Key 'footer_center'

    if (-not [string]::IsNullOrWhiteSpace($titleFromFrontMatter)) {
        $DocumentTitle = $titleFromFrontMatter
    }

    if (-not [string]::IsNullOrWhiteSpace($subtitleFromFrontMatter)) {
        $Subtitle = $subtitleFromFrontMatter
    }

    if (-not [string]::IsNullOrWhiteSpace($reportDateFromFrontMatter)) {
        $ReportDate = $reportDateFromFrontMatter
    }

    if (-not [string]::IsNullOrWhiteSpace($footerLeftFromFrontMatter)) {
        $FooterLeft = $footerLeftFromFrontMatter
    }

    if (-not [string]::IsNullOrWhiteSpace($footerCenterFromFrontMatter)) {
        $FooterCenter = $footerCenterFromFrontMatter
    }
 
    # Conversão markdown -> HTML
    $documentHtml = Convert-MarkdownToHtml -Lines $markdownLines

    # Monta HTML final a partir do template único
    $fullHtml = Build-HtmlFromTemplate `
        -TemplatePath $templatePath `
        -DocumentTitle $DocumentTitle `
        -Subtitle $Subtitle `
        -ReportDate $ReportDate `
        -FooterLeft $FooterLeft `
        -FooterCenter $FooterCenter `
        -FooterRight $FooterRight `
        -DocumentHtml $documentHtml `
        -RootPath $root

    # UTF-8 sem BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($internalHtmlPath, $fullHtml, $utf8NoBom)

    if ($htmlOutputPath) {
        [System.IO.File]::WriteAllText($htmlOutputPath, $fullHtml, $utf8NoBom)
    }

    $htmlUri = [System.Uri]::new($internalHtmlPath).AbsoluteUri

    # Perfil temporário do navegador
    $tempProfileDir = Join-Path ([System.IO.Path]::GetTempPath()) ('pdf-headless-' + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempProfileDir -Force | Out-Null

    # Gera primeiro em TEMP e depois move (mais robusto em OneDrive corporativo)
    $tempPdfPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetFileName($outputPath))
    if (Test-Path $tempPdfPath) {
        Remove-Item $tempPdfPath -Force -ErrorAction SilentlyContinue
    }

    try {
        $browserArgs = @(
            '--headless',
            '--disable-gpu',
            '--no-sandbox',
            "--virtual-time-budget=$RenderWaitMs",
            '--default-encoding=utf-8',
            '--run-all-compositor-stages-before-draw',
            '--no-first-run',
            '--no-default-browser-check',
            '--allow-file-access-from-files',
            '--disable-web-security',
            '--disable-extensions',
            '--no-pdf-header-footer',
            "--user-data-dir=$tempProfileDir",
            "--print-to-pdf=$tempPdfPath",
            $htmlUri
        )

        Write-Output "Navegador: $browser"
        Write-Output "HTML fonte: $htmlUri"
        Write-Output "PDF temporário: $tempPdfPath"
        Write-Output "PDF destino: $outputPath"

        & $browser @browserArgs

        $pdfReady = Wait-ForPdfReady -Path $tempPdfPath -TimeoutSeconds 30 -PollMilliseconds 500

        if (-not $pdfReady) {
            throw "O navegador não gerou o PDF esperado em: $tempPdfPath"
        }

        Move-Item -Path $tempPdfPath -Destination $outputPath -Force

        if (-not (Test-Path $outputPath)) {
            throw "O PDF foi gerado em TEMP, mas não foi possível movê-lo para: $outputPath"
        }

        Write-Output "PDF gerado com sucesso: $outputPath"
    }
    finally {
        if (Test-Path $tempProfileDir) {
            try {
                Remove-Item -Path $tempProfileDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                # ignora limpeza
            }
        }

        if (Test-Path $tempPdfPath) {
            try {
                Remove-Item -Path $tempPdfPath -Force -ErrorAction SilentlyContinue
            }
            catch {
                # ignora limpeza
            }
        }
    }
}
finally {
    Pop-Location
}

Write-Output "PDF gerado em: $outputPath"
if ($htmlOutputPath) {
    Write-Output "HTML gerado em: $htmlOutputPath"
}
