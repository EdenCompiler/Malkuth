# Histórico de alterações

## 0.7.0 — Impacto transitivo e integrações de produção

- Consultas de dependências e dependentes transitivos com limite opcional de profundidade.
- Métricas de raio de impacto e instabilidade para cada pacote.
- Filtro visual `9` com `MALKUTH_IMPACT_THRESHOLD`.
- Exportação SARIF 2.1.0 com avisos arquiteturais e violações de políticas.
- Métricas no formato de exposição do Prometheus para monitoramento global e por pacote.
- Exportação Mermaid do grafo de dependências para documentação Markdown.
- Relatório dedicado de ranking de impacto transitivo.
- Esquema JSON 1.2 e novas colunas CSV de impacto transitivo.

## 0.6.1 — Documentação bilíngue e limpeza

- Documentação reorganizada em `doc-ptbr/` e `doc-en/`.
- Árvore completa de documentação em português do Brasil e inglês.
- README dividido em duas metades completas: inglês e pt-BR.
- Imagem da interface movida para `assets/` para evitar duplicação entre idiomas.
- Auditoria dos comentários do código-fonte, mantidos em pt-BR.
- Remoção da árvore obsoleta `docs/` e do teste SDL duplicado não utilizado.
- Atualização dos links, versão ASDF e empacotamento para 0.6.1.

## 0.6.0 — Políticas, caminhos e monitoramento

- Motor de políticas arquiteturais declarativas em S-expression segura.
- Regras para dependências proibidas ou obrigatórias, limites, ciclos e camadas.
- Painel de políticas, filtro `7` e anéis de violação no mapa.
- Menor caminho entre pacotes com direções `:outgoing`, `:incoming` e `:either`.
- Painel de rota, filtro `8`, destaque de arestas e exportação Markdown/DOT.
- Análise de tendências a partir do histórico persistido.
- Exportação de tendências em CSV, JSON e Markdown.
- Monitor cooperativo `malkuth.monitor` e inicializador `watch.lisp`.
- Integração de políticas e tendências com `analyze.lisp` e o pacote completo.
- Novos testes de políticas, caminhos, tendências, monitor e exportações.

## 0.5.0 — Linha de base, histórico e regressões

- Persistência segura de instantâneos estruturais e histórico rotativo.
- Linha de base interativa capturada por `B`.
- Painel de evolução por `T` com saúde, ciclos, avisos e risco.
- Filtro `6` e marcação visual de pacotes alterados.
- Exportação de comparação em Markdown e JSON por `Y`.
- Tabelas CSV de pacotes e dependências no pacote completo.
- Políticas de CI para ciclos novos, regressão de saúde e aumentos de risco.
- API pública `malkuth.history` e `compare-architectures`.
- Testes de round-trip, comparação, CSV e artefatos de regressão.

## 0.4.1 — Busca textual de pacotes

- Caixa de busca sempre visível, ativada por clique, `/` ou `Ctrl+F`.
- Entrada Unicode através de `SDL_EVENT_TEXT_INPUT` e posicionamento do IME.
- Resultados em tempo real com classificação por relevância.
- Navegação por setas, `Tab`, `Enter`, `Backspace` e `Esc`.
- API pública `search-nodes` no núcleo portátil.
- Consulta inicial opcional por `MALKUTH_INITIAL_SEARCH`.
- Testes de regressão para busca exata, prefixo, segmento e ausência de resultados.

## 0.4.0 — Filtros, favoritos e investigação focada

- Filtros visuais para todos, projeto, risco, favoritos e vizinhança.
- Favoritos persistentes em S-expression validada com `*READ-EVAL*` desativado.
- Aba de dependências no inspetor, com relações de entrada e saída.
- Dossiê focado por pacote em Markdown e Graphviz DOT.
- Consultas públicas de dependências, dependentes e vizinhos.
- Limiar visual de risco configurável por `MALKUTH_RISK_THRESHOLD`.
- Comentários, docstrings, testes e documentação ampliados em pt-BR.
- Esquema de instantâneo atualizado para `1.1`.

## 0.3.1 — Documentação e localização pt-BR

- Reescrita completa do README e da documentação em português do Brasil.
- Tradução dos comentários, docstrings, mensagens operacionais, relatórios e interface.
- Manutenção dos nomes públicos da API, variáveis de ambiente e chaves JSON para preservar compatibilidade.
- Suporte da fonte vetorial a letras acentuadas por normalização para glifos-base.
- Remoção de capturas, relatórios gerados, guia de migração obsoleto e executores de teste duplicados.
- Inclusão de `.gitignore` para FASLs, relatórios, compilações e arquivos temporários.
- Organização da documentação por instalação, uso, arquitetura, configuração, exportações, CI, desenvolvimento e solução de problemas.

## 0.3.0 — Análise orientada a produção

- Metadados de esquema, validação e impressão digital determinística para instantâneos.
- Métricas de entrada, saída, grau total, centros de conectividade, pacotes isolados, ciclos, riscos e saúde heurística.
- Detecção de componentes fortemente conexos pelo algoritmo de Tarjan.
- Comparação de instantâneos para atualização da imagem ativa.
- Atalhos `F5`, `G`, `X` e navegação paginada de símbolos.
- Escopo por prefixos e inclusão opcional de dependências diretas de fronteira.
- Exportações atômicas SVG, JSON, Graphviz DOT, Markdown e manifesto.
- Executor `analyze.lisp` para CI, com políticas configuráveis e códigos de saída distintos.
- Testes integrados ao ASDF e teste de fumaça da interface SDL3.

## 0.2.1 — Legibilidade

- Escala mínima da fonte vetorial.
- Ajuste de texto por largura real.
- Recorte de painéis e rótulos responsivos.

## 0.2.0 — Malkuth

- Renomeação completa do projeto para Malkuth.
- Introdução da interface em três regiões: visão geral, mapa e inspetor.
