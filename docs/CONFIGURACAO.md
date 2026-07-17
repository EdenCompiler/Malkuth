# Configuração

| Variável | Padrão | Descrição |
|---|---:|---|
| `MALKUTH_WIDTH` | `1600` | Largura inicial; mínimo efetivo 1280 |
| `MALKUTH_HEIGHT` | `900` | Altura inicial; mínimo efetivo 760 |
| `MALKUTH_OUTPUT_DIR` | `output/` | Relatórios, favoritos, linha de base e histórico |
| `MALKUTH_SCOPE_PREFIXES` | ausente | Prefixos incluídos no instantâneo |
| `MALKUTH_USER_PREFIXES` | escopo | Prefixos tratados como projeto |
| `MALKUTH_INCLUDE_DEPENDENCIES` | `true` com escopo | Inclui dependências diretas de fronteira |
| `MALKUTH_INCLUDE_EMPTY` | `false` | Inclui pacotes sem símbolos próprios |
| `MALKUTH_AUTO_ORBIT` | `true` | Inicia órbita automática |
| `MALKUTH_RISK_THRESHOLD` | `20` | Limiar do filtro visual de risco, 0–100 |
| `MALKUTH_HISTORY_RETENTION` | `20` | Quantidade máxima de instantâneos no histórico interativo |
| `MALKUTH_INITIAL_PANEL` | `visao-geral` | Painel inicial: `visao-geral`, `diagnosticos` ou `evolucao` |
| `MALKUTH_MAX_FRAMES` | ausente | Limite de quadros para testes |
| `MALKUTH_MIN_HEALTH` | ausente | Saúde mínima para CI |
| `MALKUTH_FAIL_ON_CYCLES` | `false` | Falha política quando há ciclos |
| `MALKUTH_MAX_WARNINGS` | ausente | Máximo de avisos para CI |
| `MALKUTH_BASELINE_FILE` | ausente | Arquivo estrutural usado como linha de base no CI |
| `MALKUTH_UPDATE_BASELINE` | `false` | Atualiza a linha de base após análise aprovada |
| `MALKUTH_FAIL_ON_NEW_CYCLES` | `false` | Falha quando surgem ciclos inexistentes na base |
| `MALKUTH_MAX_HEALTH_REGRESSION` | ausente | Máxima queda permitida na saúde |
| `MALKUTH_MAX_RISK_INCREASES` | ausente | Máximo de pacotes com aumento de risco |
| `QUICKLISP_SETUP` | caminhos usuais | Caminho explícito do Quicklisp |

Valores verdadeiros aceitos: `1`, `true`, `yes`, `on`, `sim`, `verdadeiro`, `ligado`.

## Exemplos

```bash
MALKUTH_RISK_THRESHOLD=35 MALKUTH_AUTO_ORBIT=false sbcl --script run.lisp
```

```bash
MALKUTH_SCOPE_PREFIXES='EMPRESA.APP,EMPRESA.BIB' \
MALKUTH_OUTPUT_DIR="$PWD/build/arquitetura/" \
sbcl --script analyze.lisp
```

## Consulta inicial

`MALKUTH_INITIAL_SEARCH` abre a interface com a caixa de busca ativa e preenchida.

```bash
MALKUTH_INITIAL_SEARCH='MEU-APP.CORE' sbcl --script run.lisp
```

A consulta não altera o escopo carregado; ela apenas facilita a seleção inicial.

## Histórico interativo

```bash
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth/" \
MALKUTH_HISTORY_RETENTION=40 \
sbcl --script run.lisp
```
