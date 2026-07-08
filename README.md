# Notes

Repositório de documentos em Markdown, estilos de renderização e automação local para geração de PDFs institucionais.

## Objetivo

Este repositório concentra o conteúdo-fonte e os artefatos de estilo usados para transformar documentos em Markdown em relatórios PDF com identidade visual institucional.

## Estrutura

- `styles/`: CSS e fragmentos HTML usados na composição visual do PDF.
- `assets/`: imagens institucionais usadas no layout.
- `export-pdf.ps1`: script de exportação para PDF.
- `.vscode/tasks.json`: tarefa padrão para geração do PDF com `Ctrl+Shift+B`.
- `pdf/`: diretório de saída e arquivos de referência local.

Os entregáveis finais gerados para publicação ficam na raiz do repositório, como `caderno-de-visao-geral.html`, `caderno-de-visao-geral.pdf` e `entrega-de-materiais.pdf`, e são versionados quando o conteúdo é aprovado.

## Como gerar o PDF

No VS Code:

- use `Ctrl+Shift+B` para executar a tarefa `Gerar PDF CAIXA`.

No terminal:

```powershell
.\export-pdf.ps1 -OutputFile "pdf\matriz_produto_unb_gelos_corrigido.pdf"
```

Para geração automática em lote pelo script Python:

```bash
python3 scripts/build_pdf.py arquitetura-dados
python3 scripts/build_pdf.py todos
```

Alvos relevantes para arquitetura de dados:

- `arq-msg`: mensagem executiva
- `arq-rel`: relatório analítico
- `arq-ref`: referência técnica
- `arq-apr`: apresentação executiva
- `arq-apr-dir`: apresentação diretoria (fala do apresentador)

Alvo adicional:

- `an-onepage`: resumo de reunião CAIXA + Arquivo Nacional

## Mermaid no build (mmdc)

O script `scripts/build_pdf.py` agora compila blocos Mermaid (`mermaid ... ` ) automaticamente com `mmdc` antes de chamar o `pandoc`.

Pré-requisito:

```bash
npm install -g @mermaid-js/mermaid-cli
```

Se houver bloco Mermaid no Markdown e o `mmdc` não estiver no `PATH`, o build interrompe com mensagem de instalação.

No Linux, uma alternativa validada localmente e sem depender do script PowerShell e gerar o HTML intermediario com titulo explicito para evitar avisos do `pandoc`:

```bash
mkdir -p pdf && pandoc "informe_12_de_junho_de_2026.md" -f gfm -t html5 -s --css "styles/a4.css" --include-before-body="styles/pdf-before-body.html" --include-after-body="styles/pdf-after-body.html" -o ".pdf-export-source.html" && google-chrome --headless --disable-gpu --allow-file-access-from-files --no-pdf-header-footer --print-to-pdf="$PWD/pdf/informe_12_de_junho_de_2026.pdf" "file://$PWD/.pdf-export-source.html"
```

Para gerar também uma prévia HTML:

```powershell
.\export-pdf.ps1 -OutputFile "pdf\matriz_produto_unb_gelos_corrigido.pdf" -HtmlOutputFile "pdf\matriz_produto_unb_gelos_corrigido.preview.html"
```

## Arquivos versionados

Entram no repositório:

- conteúdo-fonte em Markdown
- estilos e templates em `styles/`
- imagens necessárias à identidade visual em `assets/`
- scripts e configuração do fluxo de geração
- entregáveis finais gerados para publicação em HTML e PDF

Não entram no repositório:

- arquivos internos temporários de exportação
- prévias HTML de inspeção
- PDFs de debug
- arquivos-modelo usados apenas como referência visual

## Decisão sobre PDF-modelo

O arquivo `pdf/relatorio-sustentabilidade-2024.pdf` foi tratado como referência visual local e não como insumo do processo de geração.

Como ele não é lido pelo script, não é dependência do build e pode trazer peso ou dúvida de licenciamento para o repositório, a recomendação é não versioná-lo no novo repositório `Notes`.

## Observações

- `.pdf-export-source.html` é um arquivo interno de apoio à impressão e está ignorado no Git.
- arquivos `*.preview.html` e exports de debug estão ignorados no Git.
- se um PDF de referência precisar permanecer no projeto, o ideal é documentar a finalidade e a origem do arquivo antes de versioná-lo.

## Estratégia de commits

Para manter o histórico legível, a prática recomendada é separar:

- um commit para alterações de fonte, templates, estilos e scripts;
- um commit seguinte para os entregáveis regenerados em HTML e PDF.

Assim fica claro quando houve mudança de conteúdo e quando o repositório só refletiu a nova saída publicada.
