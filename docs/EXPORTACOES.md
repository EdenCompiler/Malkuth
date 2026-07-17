# Exportações

## Pacote completo

`malkuth.export:export-bundle` e `X` produzem os artefatos centrais:

```text
malkuth.svg
malkuth.json
malkuth.dot
malkuth-report.md
malkuth-manifest.txt
malkuth-pacotes.csv
malkuth-dependencias.csv
```

Quando há dados disponíveis, `X` também acrescenta:

```text
malkuth-politicas.md
malkuth-politicas.json
malkuth-tendencia.csv
malkuth-tendencia.json
malkuth-tendencia.md
```

## Comparação contra linha de base

`Y` e `malkuth.export:export-comparison-bundle` produzem:

```text
malkuth-comparacao.md
malkuth-comparacao.json
```

O relatório registra variação de saúde, pacotes adicionados, removidos e alterados, ciclos novos ou resolvidos e mudanças de risco.

## Políticas arquiteturais

`malkuth.export:export-policy-bundle` produz:

```text
malkuth-politicas.md
malkuth-politicas.json
```

Os arquivos contêm identificação da regra, tipo, severidade, pacotes envolvidos, mensagem e estado global de aprovação.

## Caminho entre pacotes

`U` e `malkuth.export:export-path-bundle` produzem:

```text
malkuth-caminho.md
malkuth-caminho.dot
```

O Markdown explica a sequência. O DOT representa somente os nós e arestas relevantes, preservando a direção real de `USE-PACKAGE`.

## Tendência histórica

`malkuth.export:export-trend-bundle` produz:

```text
malkuth-tendencia.csv
malkuth-tendencia.json
malkuth-tendencia.md
```

Cada ponto registra data, impressão digital, saúde, pacotes, dependências, símbolos, ciclos e avisos. Arquivos históricos inválidos são ignorados e contabilizados no relatório.

## Dossiê do pacote

`malkuth.export:export-package-bundle` e `C` produzem:

```text
pacote-<nome>.md
pacote-<nome>.dot
```

O Markdown reúne conteúdo, métricas, risco, participação em ciclos, dependências, dependentes e até 200 símbolos próprios. O DOT contém somente a seleção e sua vizinhança direta.

## CSV

`malkuth-pacotes.csv` contém uma linha por pacote com contagens, fan-in, fan-out, grau e risco. `malkuth-dependencias.csv` contém origem, destino e peso de cada relação `USE-PACKAGE`. Os campos são protegidos por aspas e podem ser abertos em planilhas ou ferramentas de BI.

## JSON

O esquema do instantâneo continua em `1.1`. Relatórios de política, caminho, comparação e tendência possuem seus próprios esquemas versionados.

As chaves permanecem em inglês para compatibilidade com automações.

## Escrita atômica

Artefatos são escritos em arquivos temporários vizinhos e depois substituem o destino. Isso reduz o risco de consumidores lerem resultados incompletos.

## API

```lisp
(malkuth.export:export-bundle instantaneo #P"build/malkuth/")
(malkuth.export:export-csv-bundle instantaneo #P"build/malkuth/")
(malkuth.export:export-package-bundle
 instantaneo pacote #P"build/malkuth/" :analysis analise)
(malkuth.export:export-policy-bundle relatorio-politicas #P"build/malkuth/")
(malkuth.export:export-path-bundle
 instantaneo caminho #P"build/malkuth/" :direction :either)
(malkuth.export:export-trend-bundle relatorio-tendencia #P"build/malkuth/")
```
