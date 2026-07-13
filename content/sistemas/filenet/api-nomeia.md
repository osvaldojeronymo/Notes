---
title: Informe Executivo
subtitle: Proposta para Meta 2 e Meta 7
footer_left: "#PUBLICO | Proposta de API"
footer_center: Informe Executivo - Proposta para Meta 2 e Meta 7
---

# Contexto

A Gerência Nacional Infraestrutura (GEINF) possui documentos técnicos armazenados no _SharePoint_. Esses documentos precisam deixar de ser apenas _arquivos guardados_ e passar a ser **ativos informacionais**.

## Como são os documentos produzidos pela GEINF

A Gerência Nacional Infraestrutura (GEINF) criou o 'Nomeia', um aplicativo de geração de nomenclatura técnica. Esse aplicativo foi desenvolvido na plataforma Microsoft Power Apps.

No 'Nomeia', o usuário seleciona:

- Classe de edificação: existente, mudança de endereço, nova unidade ou unidade lotérica;
- Unidade desejada;
- Tipo do documento: Projeto, Procedimento, Planilha, ART/RRT, Fiscalização ou GRS;
- Especialidade;
- OES;

A proposta é transformar os arquivos técnicos oriundos do 'Nomeia' em **ativos informacionais**. Para isso, será utilizada uma _API_ para inserir uma camada arquivística no arquivo e armazená-lo no _FileNet_ (IBM), no contexto do Gerenciamento Eletrônico de Documentos (GED) da **CAIXA**.

Assim, a API atuará como instrumento para resolver um problema de governança documental: transformar arquivos técnicos dispersos em documentos contextualizados, rastreáveis e gerenciáveis.

# Proposta de valor

A proposta é transformar esses documentos em ativos informacionais por meio de uma API que aplique uma camada arquivística aos arquivos, associando metadados, contexto de produção, classificação, versionamento, temporalidade e relações documentais, para posterior armazenamento e gestão no GED.

# Funções que a API deve realizar

- Extrair metadados do arquivo;
- Receber metadados informados por sistemas ou usuários;
- Validar metadados mínimos;
- Relacionar o documento a contrato, empreendimento, processo, unidade, versão e tipo documental;
- Registrar essas informações no GED;
- Criar uma trilha de rastreabilidade entre SharePoint, API e GED.

# Entregas

- Modelo conceitual da API arquivística;
- Glossário e requisitos arquivísticos;
- Desenho do fluxo SharePoint → API → GED;
- Modelo de metadados mínimos;
- Protótipo de especificação OpenAPI;
- Prova de conceito com alguns tipos documentais.

# Exemplo ilustrativo

A imagem a seguir mostra o tipo de nomenclatura dos arquivos que serão recebidos pela API.

<div class="newpage"></div>

<p class="abnt-figure-title">Figura 1 - Exemplo ilustrativo do padrão de nomenclatura dos arquivos recebidos pela API</p>

<figure class="illustrative-figure">
<img src="file:///home/osvaldo/%C3%81rea%20de%20Trabalho/CAIXA/Notes/assets/nomeia.png" alt="Exemplo ilustrativo do padrão de nomenclatura dos arquivos recebidos pela API">
</figure>

<p class="abnt-figure-source">Fonte: Extraído do site do app 'Nomeia'.</p>
