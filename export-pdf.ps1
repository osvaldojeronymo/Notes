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

$paginationScript = @'
<script>
(() => {
    const source = document.getElementById("pdf-source");
    const pagesRoot = document.getElementById("pdf-pages");
    const headerTemplate = document.getElementById("pdf-header-template");
    const footerTemplate = document.getElementById("pdf-footer-template");

    if (!source || !pagesRoot || !headerTemplate || !footerTemplate) {
        return;
    }

    source.querySelectorAll("h1.title").forEach((node) => node.remove());

    const sourceNodes = Array.from(source.children);

    function createPage() {
        const page = document.createElement("section");
        page.className = "print-page";
        const pageNumber = pagesRoot.children.length + 1;

        const inner = document.createElement("div");
        inner.className = "print-page-inner";

        const header = document.createElement("div");
        header.className = "print-page-header";
        header.appendChild(headerTemplate.content.firstElementChild.cloneNode(true));

        if (pageNumber === 1) {
            header.classList.add("print-page-header--cover");

            const coverTitle = document.createElement("h1");
            coverTitle.className = "print-page-cover-title";
            coverTitle.textContent = document.title || "Informe";

            const coverRule = document.createElement("div");
            coverRule.className = "print-page-cover-rule";

            const coverDate = document.createElement("p");
            coverDate.className = "print-page-cover-date";

            const formattedDate = new Intl.DateTimeFormat("pt-BR", {
                day: "2-digit",
                month: "long",
                year: "numeric"
            }).format(new Date());

            coverDate.textContent = `Curitiba, ${formattedDate}`;

            header.firstElementChild.appendChild(coverTitle);
            header.firstElementChild.appendChild(coverRule);
            header.firstElementChild.appendChild(coverDate);
        }

        const content = document.createElement("div");
        content.className = "print-page-content";

        if (pageNumber === 1) {
            content.classList.add("print-page-content--cover");
        }

        const footer = document.createElement("div");
        footer.className = "print-page-footer";
        footer.appendChild(footerTemplate.content.firstElementChild.cloneNode(true));

        const pageNumberLabel = document.createElement("div");
        pageNumberLabel.className = "print-page-number";
        pageNumberLabel.dataset.pageNumber = String(pageNumber);
        footer.appendChild(pageNumberLabel);

        inner.appendChild(header);
        inner.appendChild(content);
        inner.appendChild(footer);
        page.appendChild(inner);
        pagesRoot.appendChild(page);

        return content;
    }

    function overflows(element) {
        return element.scrollHeight > element.clientHeight + 1;
    }

    function cloneTableShell(table) {
        const clone = table.cloneNode(false);
        const thead = table.querySelector("thead");
        if (thead) {
            clone.appendChild(thead.cloneNode(true));
        }

        const tbody = document.createElement("tbody");
        clone.appendChild(tbody);
        return { table: clone, tbody };
    }

    function placeBlock(node, content) {
        content.appendChild(node);
        if (!overflows(content)) {
            return content;
        }

        content.removeChild(node);
        const nextContent = createPage();
        nextContent.appendChild(node);
        return nextContent;
    }

    function placeTable(table, content) {
        const rows = Array.from(table.querySelectorAll("tbody > tr"));
        if (rows.length === 0) {
            return placeBlock(table, content);
        }

        let shell = cloneTableShell(table);
        content.appendChild(shell.table);

        for (const row of rows) {
            shell.tbody.appendChild(row.cloneNode(true));

            if (!overflows(content)) {
                continue;
            }

            if (shell.tbody.children.length === 1) {
                continue;
            }

            shell.tbody.removeChild(shell.tbody.lastElementChild);
            content = createPage();
            shell = cloneTableShell(table);
            content.appendChild(shell.table);
            shell.tbody.appendChild(row.cloneNode(true));
        }

        return content;
    }

    function placeHeadingWithFollower(headingNode, followerNode, content) {
        const headingClone = headingNode.cloneNode(true);
        const followerClone = followerNode.cloneNode(true);

        content.appendChild(headingClone);
        content.appendChild(followerClone);

        if (!overflows(content)) {
            return { content, consumedFollower: true };
        }

        content.removeChild(headingClone);
        content.removeChild(followerClone);
        content = createPage();
        content.appendChild(headingClone);
        content.appendChild(followerClone);
        return { content, consumedFollower: true };
    }

    let content = createPage();

    for (let index = 0; index < sourceNodes.length; index += 1) {
        const node = sourceNodes[index];

        if (
            node.tagName === "H2" &&
            node.textContent &&
            node.textContent.trim().toUpperCase() === "PONTOS DE ATENÇÃO" &&
            content.childElementCount > 0
        ) {
            content = createPage();
        }

        if (/^H[1-6]$/.test(node.tagName || "")) {
            const followerNode = sourceNodes[index + 1];
            if (followerNode && ["OL", "UL", "P", "BLOCKQUOTE"].includes(followerNode.tagName)) {
                const result = placeHeadingWithFollower(node, followerNode, content);
                content = result.content;
                if (result.consumedFollower) {
                    index += 1;
                }
                continue;
            }
        }

        if (node.tagName === "TABLE") {
            content = placeTable(node.cloneNode(true), content);
            continue;
        }

        content = placeBlock(node.cloneNode(true), content);
    }

    const totalPages = pagesRoot.children.length;
    pagesRoot.querySelectorAll(".print-page-number").forEach((label, index) => {
        label.textContent = `Página ${index + 1} de ${totalPages}`;
    });
})();
</script>
'@

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
    <title>Informe</title>
    <link rel="stylesheet" href="$styleUri">
</head>
<body>
    <main id="pdf-source" class="pdf-body">
        $documentHtml
    </main>
    <div id="pdf-pages"></div>
    <template id="pdf-header-template">
        $headerHtml
    </template>
    <template id="pdf-footer-template">
        <div class="pdf-footer">
            <img src="assets/rodape-caixa.png" alt="Rodape CAIXA">
        </div>
    </template>
    $paginationScript
</body>
</html>
"@

        Set-Content -Path $internalHtmlPath -Value $fullHtml -Encoding UTF8
        if ($htmlOutputPath) {
            Set-Content -Path $htmlOutputPath -Value $fullHtml -Encoding UTF8
        }

    $htmlUri = [System.Uri]::new($internalHtmlPath).AbsoluteUri
    & $browser --headless --disable-gpu --allow-file-access-from-files --no-pdf-header-footer --print-to-pdf=$outputPath $htmlUri
}
finally {
    Pop-Location
}

Write-Output "PDF gerado em: $outputPath"
if ($htmlOutputPath) {
    Write-Output "HTML gerado em: $htmlOutputPath"
}