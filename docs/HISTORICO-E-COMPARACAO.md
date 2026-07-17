# Histórico e comparação arquitetural

## Linha de base interativa

A linha de base é uma fotografia estrutural usada como referência para avaliar mudanças posteriores.

1. Carregue a aplicação no mesmo processo Lisp do Malkuth.
2. Pressione `B` para capturar o estado atual.
3. Modifique ou recarregue a aplicação.
4. Pressione `F5` para reconstruir o instantâneo.
5. Pressione `T` para abrir o painel de evolução.

O arquivo persistido é:

```text
output/malkuth-linha-de-base.sexp
```

A leitura usa `*READ-EVAL*` desativado e valida IDs, arestas e contagens antes de aceitar o documento.

## Painel de evolução

O painel apresenta:

- variação da pontuação de saúde;
- variação da quantidade de avisos;
- pacotes adicionados, removidos e alterados;
- ciclos novos e ciclos resolvidos;
- maiores aumentos de risco local.

Pressione `6` para mostrar no mapa somente pacotes adicionados ou alterados. Esses pacotes recebem um anel magenta mesmo em outros filtros.

## Histórico rotativo

Antes de cada atualização por `F5`, o instantâneo anterior é gravado em:

```text
output/historico/snapshot-<tempo>-<impressao-digital>.sexp
```

A quantidade de arquivos é limitada por:

```bash
MALKUTH_HISTORY_RETENTION=50 sbcl --script run.lisp
```

O padrão é 20. O histórico guarda a topologia e as contagens, não funções executáveis, valores de variáveis ou todo o heap Lisp.

## Exportação da comparação

Pressione `Y` para gerar:

```text
malkuth-comparacao.md
malkuth-comparacao.json
```

API equivalente:

```lisp
(defparameter *base*
  (malkuth.history:load-snapshot-file
   #P"output/malkuth-linha-de-base.sexp"))

(defparameter *atual*
  (malkuth.model:build-snapshot))

(defparameter *diferenca*
  (malkuth.analysis:compare-architectures *base* *atual*))

(malkuth.export:export-comparison-bundle
 *base* *atual* #P"output/" :diff *diferenca*)
```

## Uso em integração contínua

Na primeira execução, crie ou atualize a linha de base:

```bash
MALKUTH_BASELINE_FILE="$PWD/build/malkuth-baseline.sexp" \
MALKUTH_UPDATE_BASELINE=true \
sbcl --script analyze.lisp
```

Em execuções posteriores, compare sem atualizar automaticamente:

```bash
MALKUTH_BASELINE_FILE="$PWD/build/malkuth-baseline.sexp" \
MALKUTH_FAIL_ON_NEW_CYCLES=true \
MALKUTH_MAX_HEALTH_REGRESSION=5 \
MALKUTH_MAX_RISK_INCREASES=3 \
sbcl --script analyze.lisp
```

Atualize a linha de base somente depois de revisar e aceitar conscientemente as mudanças arquiteturais.
