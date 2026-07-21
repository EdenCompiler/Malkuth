# Configuração

## Interface e instantâneo

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
| `MALKUTH_IMPACT_THRESHOLD` | `5` | Mínimo de dependentes transitivos exibidos pelo filtro `9` |
| `MALKUTH_INITIAL_SEARCH` | ausente | Abre a busca com uma consulta inicial |
| `MALKUTH_INITIAL_PANEL` | `visao-geral` | `visao-geral`, `diagnosticos`, `evolucao` ou `politicas` |
| `MALKUTH_POLICY_FILE` | ausente | Arquivo de políticas arquiteturais |
| `MALKUTH_HISTORY_RETENTION` | `20` | Máximo de instantâneos no histórico interativo |
| `MALKUTH_MAX_FRAMES` | ausente | Limite de quadros para testes |

## Análise sem interface e CI

| Variável | Padrão | Descrição |
|---|---:|---|
| `MALKUTH_MIN_HEALTH` | ausente | Saúde mínima permitida |
| `MALKUTH_FAIL_ON_CYCLES` | `false` | Falha quando o estado corrente contém ciclos |
| `MALKUTH_MAX_WARNINGS` | ausente | Máximo de avisos permitidos |
| `MALKUTH_FAIL_ON_POLICY` | `true` quando há políticas | Falha diante de violações de severidade `:error` |
| `MALKUTH_BASELINE_FILE` | ausente | Arquivo estrutural usado como linha de base |
| `MALKUTH_UPDATE_BASELINE` | `false` | Atualiza a base após análise aprovada |
| `MALKUTH_FAIL_ON_NEW_CYCLES` | `false` | Falha quando surgem ciclos inexistentes na base |
| `MALKUTH_MAX_HEALTH_REGRESSION` | ausente | Máxima queda de saúde permitida |
| `MALKUTH_MAX_RISK_INCREASES` | ausente | Máximo de pacotes com aumento de risco |
| `MALKUTH_HISTORY_DIR` | `<saída>/historico/` | Diretório lido ou alimentado pela análise |
| `MALKUTH_SAVE_HISTORY` | `false` | Salva o instantâneo atual no histórico |
| `MALKUTH_EXPORT_TRENDS` | `true` quando há histórico | Exporta CSV, JSON e Markdown de tendências |
| `MALKUTH_TREND_LIMIT` | `100` | Máximo de pontos históricos usados |

## Monitor contínuo

| Variável | Padrão | Descrição |
|---|---:|---|
| `MALKUTH_BOOTSTRAP_FILE` | ausente | Arquivo que carrega a aplicação monitorada |
| `MALKUTH_WATCH_INTERVAL` | `5` | Segundos entre leituras |
| `MALKUTH_WATCH_ITERATIONS` | infinito | Quantidade máxima de verificações |
| `MALKUTH_EXPORT_ON_CHANGE` | `true` | Exporta relatórios quando a topologia muda |
| `MALKUTH_HISTORY_RETENTION` | `50` no monitor | Retenção do histórico do monitor |

## Inicialização do Lisp

| Variável | Padrão | Descrição |
|---|---:|---|
| `QUICKLISP_SETUP` | caminhos usuais | Caminho explícito de `quicklisp/setup.lisp` |

Valores verdadeiros aceitos: `1`, `true`, `yes`, `on`, `sim`, `verdadeiro`, `ligado`.

## Exemplos

Interface focada no projeto e com políticas:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
MALKUTH_INITIAL_PANEL=politicas \
sbcl --script run.lisp
```

Análise com histórico e tendências:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/arquitetura/" \
MALKUTH_SAVE_HISTORY=true \
MALKUTH_EXPORT_TRENDS=true \
sbcl --script analyze.lisp
```

Monitor de uma aplicação carregada por inicializador:

```bash
MALKUTH_BOOTSTRAP_FILE="$PWD/iniciar-meu-app.lisp" \
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_WATCH_INTERVAL=10 \
sbcl --script watch.lisp
```
