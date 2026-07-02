# CSS modular para PDFs A4

Copie todos os arquivos da pasta `styles/` para a pasta `styles/` do projeto `Notes`.

O arquivo principal continua sendo:

```text
styles/a4.css
```

Ele apenas importa os módulos:

```text
styles/a4-base.css
styles/a4-header-footer.css
styles/a4-typography.css
styles/a4-tables.css
styles/a4-executive.css
styles/a4-caderno.css
styles/a4-dashboard.css
styles/a4-print.css
```

## Ordem dos módulos

A ordem dos `@import` importa. Evite mover os módulos sem necessidade.

styles/
├── a4.css ← arquivo principal (importa os módulos)
├── a4-base.css ← variáveis, reset, página A4
├── a4-header-footer.css ← cabeçalho e rodapé
├── a4-typography.css ← tipografia geral
├── a4-tables.css ← tabelas genéricas
├── a4-executive.css ← componentes executivos
├── a4-caderno.css ← páginas do Caderno Executivo
├── a4-dashboard.css ← gráficos e dashboards
└── a4-print.css ← ajustes de impressão

## Observação

O bloco `body::before/body::after` foi removido. O cabeçalho e o rodapé devem vir do template HTML (`caderno-template.html` ou `pdf-template.html`).
