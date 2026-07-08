---
title: Relatório Analítico
subtitle: Arquitetura de Dados para Governança Arquivística Digital da CAIXA
date: auto
footer_left: "#PUBLICO | Convênio CAIXA-UnB"
footer_center: "Relatório Analítico - Arquitetura de Dados"
---

# Relatório Analítico

Este relatório consolida os resultados da entrega _Arquitetura de Dados_ elaborada por intermédio do convênio CAIXA-UnB.

## Apresentação

A cadeia analítica adotada: Problema -> Metodologia -> Produtos -> Benefícios -> Próximos passos.

<p class="abnt-table-title">Quadro 1 - Escopo do relatório</p>

| Pergunta de gestão                 | Resposta do relatório                                                            |
| :--------------------------------- | :------------------------------------------------------------------------------- |
| Qual problema a entrega resolve?   | Fragmentação documental e baixa integração arquivística                          |
| Como a solução foi construída?     | Arquitetura de dados orientada por princípios arquivísticos e interoperabilidade |
| O que foi efetivamente entregue?   | Catálogo, modelo de dados, regras e pacote de intercâmbio                        |
| Qual valor institucional esperado? | Governança, conformidade, rastreabilidade e eficiência operacional               |
| O que precisa ser decidido agora?  | Priorização, governança de implantação e cronograma faseado                      |

<p class="abnt-table-source">Fonte: Elaboração própria.</p>

<div class="newpage"></div>

## 1. Objetivo da entrega

O documento foi estruturado para dar uma resposta ao problema de lacuna institucional de governança documental em ambiente digital.

### 1.1 Qual problema motivou esta entrega?

A entrega foi motivada por um desafio institucional de integração e governança documental em ambiente digital. Em termos práticos, a CAIXA convive com produção e armazenamento de documentos em múltiplos sistemas e repositórios, com diferentes graus de padronização e interoperabilidade.

A consequência desse cenário é a fragmentação do ciclo de vida documental, com impactos diretos em:

- qualidade e consistência da informação arquivística;
- rastreabilidade da cadeia de custódia;
- confiabilidade para auditoria, controle e prova institucional;
- capacidade de aplicar classificação, temporalidade e destinação de forma uniforme;
- maturidade para evolução de SIGAD e preservação digital de longo prazo.

### 1.2 Formulação do problema

Antes da proposta:

- sistemas corporativos produzem e mantêm documentos de forma distribuída;
- integrações não asseguram, por si só, coerência arquivística ponta a ponta;
- classificação e temporalidade nem sempre estão estruturadas no contexto funcional do documento;
- metadados essenciais de governança podem ficar incompletos, heterogêneos ou não reconciliados;
- a cadeia de custódia torna-se suscetível a rupturas operacionais e semânticas.

A questão central, portanto, não é apenas tecnológica; é de governança da informação arquivística em escala corporativa.

<div class="newpage"></div>

## 2. Escopo

Os sistemas corporativos da CAIXA que se utilizam da Gestão Eletrônica de Documentos (GED) CAIXA.

### 2.1 O que foi analisado?

A entrega abrangeu a definição de uma arquitetura de dados para suportar integração documental, classificação arquivística, temporalidade, conformidade e preparo para configuração no SIGAD.

O escopo considerou:

- conceitos arquivísticos necessários para modelagem de dados;
- estrutura de metadados e contexto funcional;
- instrumentos de classificação e temporalidade (CCD e TTD);
- critérios de conformidade LGPD/LAI;
- estratégia de normalização de bases legadas e coletas novas;
- camadas de integração e formato de exportação para intercâmbio.

### 2.2 Limites do escopo

Não faz parte desta entrega:

- executar implantação tecnológica completa dos conectores;
- substituir decisões institucionais de governança por desenho técnico;
- encerrar, por si só, a agenda de SIGAD e RDC-Arq.

A arquitetura entregue constitui base de referência para decisões e implantação faseada.

<p class="abnt-table-title">Quadro 2 - Delimitação de escopo</p>

| Inclui                                         | Não inclui                                |
| :--------------------------------------------- | :---------------------------------------- |
| Modelo de dados e integração                   | Implantação tecnológica completa          |
| Regras de classificação e temporalidade        | Substituição de deliberação institucional |
| Critérios de conformidade e interoperabilidade | Encerramento da agenda SIGAD/RDC-Arq      |

<p class="abnt-table-source">Fonte: Elaboração própria.</p>

<div class="newpage"></div>

## 3. Fundamentação Técnica

A proposta foi construída com base em princípios e referenciais arquivísticos e de interoperabilidade já consolidados no contexto público brasileiro.

### 3.1 Referências estruturantes

- e-ARQ Brasil (requisitos para sistemas informatizados de gestão arquivística);
- diretrizes de gestão arquivística e preservação digital aplicáveis à evolução SIGAD/RDC-Arq;
- princípios de autenticidade, integridade, rastreabilidade e contexto de produção documental;
- padrões de interoperabilidade e formatos abertos para intercâmbio de dados.

### 3.2 Princípios aplicados na modelagem

- Classificação funcional: o documento deve ser compreendido no contexto da atividade que o gerou.
- Temporalidade vinculada ao contexto: prazos e destinação decorrem do enquadramento arquivístico, não apenas do nome do documento.
- Separação entre camada operacional e camada de exportação: evita contaminação do contrato formal de dados por inconsistências de coleta.
- Evidência e auditabilidade: os dados devem ser entregues de forma verificável e rastreável para uso institucional.

<div class="newpage"></div>

## 4. Solução Proposta

Foi elaborada uma arquitetura de integração documental baseada em camadas lógicas e em instrumentos arquivísticos de referência, com foco em interoperabilidade e qualidade dos dados para configuração no SIGAD.

### 4.1 Síntese da arquitetura

Em síntese, a solução:

- organiza o fluxo de transformação de dados, da coleta ao pacote de entrega;
- estabiliza a semântica arquivística por meio de conceitos e relacionamentos explícitos;
- associa tipos documentais a classificação (CCD), temporalidade (TTD) e conformidade (LGPD/LAI);
- disponibiliza saída em formato de intercâmbio para integração sistêmica.

### 4.2 Lógica de transformação do ativo técnico

A página técnica descreve o funcionamento detalhado do modelo. O relatório analítico, por sua vez, responde ao nível decisório:

- qual problema institucional está sendo endereçado;
- por que esta abordagem foi escolhida;
- quais capacidades a CAIXA passa a ter;
- quais decisões ainda precisam ser tomadas para implementação.

<p class="abnt-table-title">Quadro 3 - Síntese da solução</p>

| Eixo                    | Síntese                                                                |
| :---------------------- | :--------------------------------------------------------------------- |
| Arquitetura             | Integração em camadas para estabilizar qualidade e semântica dos dados |
| Governança arquivística | Vinculação entre tipo documental, CCD, TTD e contexto funcional        |
| Conformidade            | Parametrização LGPD/LAI no nível de metadados documentais              |
| Implementação           | Pacote de intercâmbio em formato aberto para configuração no SIGAD     |

<p class="abnt-table-source">Fonte: Elaboração própria.</p>

<div class="newpage"></div>

## 5. Componentes da Solução

Esta seção consolida os elementos efetivamente produzidos e demonstrados na arquitetura.

### 5.1 Produto final orientador

- Catálogo Institucional de Tipos Documentais, preparado para configuração no SIGAD.

### 5.2 Componentes estruturantes

- Arquitetura lógica de integração por camadas (coleta, integração, exportação).
- Modelo de dados consolidado (tabelas, campos, relacionamentos e mapeamentos SIGAD).
- Estrutura de tipos documentais com base em espécie, atividade e contexto de negócio.
- Mecanismos de distinção entre objeto arquivístico e variante operacional.
- Regras para documento simples, documento composto e unidade de arquivamento.

### 5.3 Instrumentos arquivísticos incorporados

- Código de Classificação de Documentos (CCD).
- Tabela de Temporalidade e Destinação (TTD).
- Vinculação de classificação e temporalidade ao contexto funcional.

### 5.4 Componentes de conformidade e segurança

- Parâmetros LGPD/LAI por tipo/variante quando aplicável.
- Definição de metadados de acesso e tratamento de dados pessoais.

### 5.5 Componentes de implementação

- Estratégia de normalização para legado e coleta nova.
- Formato de exportação em padrões abertos.
- Pacote de intercâmbio com artefatos de conferência e integridade.

### 5.6 Conteúdo de apoio para equipes técnicas

- Guia conceitual para implementação (ponte entre teoria arquivística e modelagem de sistemas).
- Referência técnica em perguntas e respostas para reduzir ambiguidades de execução.

<div class="newpage"></div>

## 6. Benefícios esperados

A arquitetura proposta habilita capacidades institucionais que extrapolam a dimensão de uma página técnica.

### 6.1 O que isso permite à CAIXA?

Benefícios diretos:

- manutenção de autenticidade e integridade documental;
- fortalecimento da cadeia de custódia digital;
- padronização de classificação e temporalidade no contexto funcional;
- redução de duplicidades e inconsistências entre sistemas;
- melhoria de recuperação da informação e rastreabilidade para auditoria;
- preparação estruturada para evolução SIGAD e preservação digital (RDC-Arq).

Benefícios gerenciais:

- base objetiva para priorização de investimentos em integração;
- aumento da previsibilidade de implantação por fases;
- redução de risco regulatório e operacional associado a documentos digitais.

### 6.2 Valor institucional

A entrega transforma conhecimento técnico disperso em referência corporativa de decisão. Isso permite que áreas de negócio, tecnologia e governança documental atuem sobre um mesmo contrato informacional.

<p class="abnt-table-title">Quadro 4 - Benefícios institucionais esperados</p>

| Dimensão   | Benefício para a CAIXA                                     |
| :--------- | :--------------------------------------------------------- |
| Governança | Padronização de critérios e maior coerência institucional  |
| Operação   | Ganho de eficiência e redução de retrabalho                |
| Controle   | Rastreabilidade qualificada para auditoria e conformidade  |
| Estratégia | Base técnica para implantação progressiva de SIGAD/RDC-Arq |

<p class="abnt-table-source">Fonte: Elaboração própria.</p>

<div class="newpage"></div>

## 7. Riscos e premissas

Riscos identificados e as premissas elecandas à partir da entrega _Arquitetura de Dados_ elaborada por intermédio do convênio CAIXA-UnB.

### 7.1 Riscos de não implantação

- permanência de fragmentação documental entre sistemas;
- manutenção de heterogeneidade semântica e de metadados;
- aumento de esforço manual para reconciliação e conferência;
- atraso na maturidade institucional para SIGAD/RDC-Arq;
- maior exposição a inconsistências em auditorias e controles.

### 7.2 Riscos de implantação parcial

- adotar apenas integração técnica sem governança de dados arquivísticos;
- tratar classificação e temporalidade como etapa acessória, e não estruturante;
- executar conectores sem critérios de qualidade e validação institucional.

### 7.3 Premissas críticas

- patrocínio institucional e governança transversal (negócio, TI, arquivo, jurídico/compliance);
- definição formal de papéis e responsabilidades;
- priorização por criticidade documental e impacto de negócio;
- capacidade de validação contínua dos metadados e regras de negócio.

<p class="abnt-table-title">Quadro 5 - Matriz executiva de riscos</p>

| Risco               | Efeito principal                               | Mitigação recomendada                           |
| :------------------ | :--------------------------------------------- | :---------------------------------------------- |
| Não implantação     | Persistência da fragmentação documental        | Institucionalizar priorização e cronograma      |
| Implantação parcial | Integração técnica sem governança arquivística | Vincular TI a critérios de curadoria documental |
| Governança difusa   | Baixa accountability                           | Definir instância decisória formal              |

<p class="abnt-table-source">Fonte: Elaboração própria.</p>

<div class="newpage"></div>

## 8. Sugestões

As sugestões descritas a seguir buscam resolver um problema real de fragmentação, oferecer método para superá-lo, entregar produtos aplicáveis e abrir caminho estruturado para implantação institucional.

### 8.1 Próximos passos de curto prazo

1. Instituir a arquitetura de dados como referência oficial para decisões de integração documental.
2. Definir governança de implantação com comitê e rito de validação.
3. Selecionar casos prioritários para implantação piloto por criticidade.
4. Especificar conectores, contratos de dados e critérios de qualidade.
5. Formalizar plano de transição para operação assistida.

### 8.2 Próximos passos de médio prazo

1. Expandir implantação para novos sistemas conforme priorização.
2. Implantar indicadores de maturidade arquivística e conformidade.
3. Consolidar trilha de evolução para SIGAD e estratégia RDC-Arq.
4. Institucionalizar ciclo de revisão contínua de catálogo, CCD e TTD.

### 8.3 Governança recomendada

- Patrocinador executivo para priorização e desbloqueio de decisões.
- Coordenação técnica de dados/integridade da integração.
- Curadoria arquivística para classificação, temporalidade e contexto funcional.
- Instância de conformidade para LGPD/LAI e evidência regulatória.

<div class="newpage"></div>

## 9. Conclusão

A entrega de Arquitetura de Dados demonstra que a CAIXA já dispõe de base metodológica consistente para enfrentar seu principal desafio: transformar produção documental distribuída em governança arquivística integrada.

O ponto central é reconhecer a capacidade institucional criada:

- um modelo comum para classificar, contextualizar e integrar documentos;
- um contrato de dados auditável para interoperabilidade com SIGAD;
- uma trilha concreta para reduzir risco e aumentar confiabilidade documental.

<div class="newpage"></div>

## 10. Anexos

A página técnica elaborada pelos pesquisadores da UnB, relatório e resumo executivo elaborado pelos representantes da CAIXA no convênio CAIXA-UnB.

### Anexo A - Referência técnica primária

- Página de Arquitetura de Dados da plataforma de Governança Arquivística: https://governancaarquivistica.org/arquitetura-dados

### Anexo B - Função do anexo no processo decisório

Fluxo de derivação recomendado: Página Técnica -> Relatório Analítico -> Resumo Executivo.
