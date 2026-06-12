# Notes

Repositório de documentos em Markdown, estilos de renderização e automação local para geração de PDFs institucionais.

## Objetivo

Este repositório concentra o conteúdo-fonte e os artefatos de estilo usados para transformar documentos em Markdown em relatórios PDF com identidade visual institucional.

O foco atual é a produção do documento `matriz_produto_unb_gelos_corrigido.md` com exportação automatizada por PowerShell e integração com tarefas do VS Code.

## Estrutura

- `matriz_produto_unb_gelos_corrigido.md`: documento-fonte principal.
- `styles/`: CSS e fragmentos HTML usados na composição visual do PDF.
- `assets/`: imagens institucionais usadas no layout.
- `export-pdf.ps1`: script de exportação para PDF.
- `.vscode/tasks.json`: tarefa padrão para geração do PDF com `Ctrl+Shift+B`.
- `pdf/`: diretório de saída e arquivos de referência local.

## Como gerar o PDF

No VS Code:

- use `Ctrl+Shift+B` para executar a tarefa `Gerar PDF CAIXA`.

No terminal:

```powershell
.\export-pdf.ps1 -OutputFile "pdf\matriz_produto_unb_gelos_corrigido.pdf"
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
