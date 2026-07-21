# Análise de impacto e integrações de produção

## Alcance transitivo

O Malkuth agora percorre o grafo de `USE-PACKAGE` além dos vizinhos diretos. Para qualquer pacote, a API retorna todas as dependências alcançáveis e todos os pacotes que dependem dele, opcionalmente com limite de profundidade.

```lisp
(malkuth.model:node-transitive-dependencies instantaneo "MEU-APP.CORE")
(malkuth.model:node-transitive-dependents instantaneo "MEU-APP.CORE")
(malkuth.model:reachable-node-ids instantaneo "MEU-APP.CORE"
                                  :direction :outgoing :max-depth 2)
```

## Raio de impacto

`node-metrics-blast-radius` é a quantidade de dependentes transitivos. Um pacote com raio alto fica a montante de muitos outros pacotes; alterações em seus contratos merecem testes de regressão e revisão mais amplos.

O filtro `9` mostra pacotes no limiar configurado por `MALKUTH_IMPACT_THRESHOLD`:

```bash
MALKUTH_IMPACT_THRESHOLD=10 sbcl --script run.lisp
```

O padrão é `5`.

## Instabilidade

O Malkuth calcula a instabilidade estrutural como:

```text
fan-out / (fan-in + fan-out) × 100
```

Valor próximo de 100 indica um pacote que depende principalmente de outros; próximo de 0 indica um pacote do qual muitos dependem. É uma heurística estrutural, não uma nota de qualidade isolada.

## SARIF 2.1.0

`malkuth.sarif` contém avisos da análise e, quando fornecidas ao exportador, violações das políticas declarativas. Como o Malkuth analisa a imagem viva em vez de linhas de código, os resultados usam localizações lógicas SARIF nomeadas pelos pacotes.

```lisp
(malkuth.export:export-sarif instantaneo #P"build/malkuth/malkuth.sarif"
                              :analysis analise
                              :policy-report relatorio-politicas)
```

## Prometheus

`malkuth.prom` expõe gauges globais e por pacote: saúde, quantidade de pacotes/dependências, ciclos, avisos, risco local, raio de impacto e instabilidade. O arquivo pode ser publicado por um textfile collector ou transformado pelo pipeline de observabilidade.

## Mermaid

`malkuth.mmd` é um `flowchart LR` adequado a documentação Markdown. Os nós exibem risco e impacto e recebem classes para projeto, runtime, ferramentas e bibliotecas.

## Relatório de impacto

`malkuth-impacto.md` ordena os pacotes por dependentes transitivos, instabilidade e risco local. Ele ajuda a identificar contratos que merecem testes, revisão de compatibilidade e estratégias de rollout mais cautelosas.

## Esquema JSON e colunas CSV

O esquema de instantâneo `1.2` acrescenta:

- `transitiveDependencies`;
- `transitiveDependents`;
- `blastRadius`;
- `instability`.

O CSV de pacotes contém colunas equivalentes. Os campos anteriores continuam disponíveis.
