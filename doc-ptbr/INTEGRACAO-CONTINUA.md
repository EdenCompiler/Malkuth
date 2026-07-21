# Integração contínua

## Execução básica

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth/" \
sbcl --script analyze.lisp
```

Armazene o diretório de saída como artefato do job. Ele contém SVG, Markdown, JSON, DOT, manifesto e tabelas CSV.

## Políticas absolutas

```bash
MALKUTH_MIN_HEALTH=80
MALKUTH_FAIL_ON_CYCLES=true
MALKUTH_MAX_WARNINGS=5
```

Essas regras avaliam somente o estado corrente.

## Políticas declarativas versionadas

```bash
MALKUTH_POLICY_FILE="$PWD/ci/malkuth-politicas.sexp" \
MALKUTH_FAIL_ON_POLICY=true \
sbcl --script analyze.lisp
```

Use essas regras para expressar camadas, dependências proibidas ou obrigatórias e limites específicos por padrão de pacote. Somente violações `:error` reprovam a execução; avisos continuam nos relatórios.

## Linha de base e políticas de regressão

Crie inicialmente uma linha de base versionada ou preservada como artefato:

```bash
MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp" \
MALKUTH_UPDATE_BASELINE=true \
sbcl --script analyze.lisp
```

Depois compare cada execução:

```bash
MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp" \
MALKUTH_FAIL_ON_NEW_CYCLES=true \
MALKUTH_MAX_HEALTH_REGRESSION=5 \
MALKUTH_MAX_RISK_INCREASES=3 \
sbcl --script analyze.lisp
```

Quando a base existe, o Malkuth também gera `malkuth-comparacao.md` e `malkuth-comparacao.json`.

## Histórico e tendências no CI

```bash
MALKUTH_HISTORY_DIR="$PWD/build/historico/" \
MALKUTH_SAVE_HISTORY=true \
MALKUTH_EXPORT_TRENDS=true \
MALKUTH_TREND_LIMIT=100 \
sbcl --script analyze.lisp
```

Preserve o histórico entre jobs para acompanhar a trajetória do projeto. O pacote de tendências é apropriado para gráficos externos, painéis e auditorias de longo prazo.

## Atualização controlada

`MALKUTH_UPDATE_BASELINE=true` substitui o arquivo somente depois que todas as políticas foram aprovadas. Não o habilite permanentemente no mesmo job que deveria detectar regressões, pois isso aceitaria automaticamente o estado atual.

## Adoção gradual

1. Execute sem políticas bloqueantes.
2. Revise ciclos, riscos e avisos existentes.
3. Capture uma linha de base conhecida.
4. Adicione políticas declarativas inicialmente como `:warning`.
5. Ative `MALKUTH_FAIL_ON_NEW_CYCLES`.
6. Observe tendências durante várias mudanças.
7. Promova regras estáveis para `:error`.
8. Atualize a base apenas em uma mudança arquitetural aprovada.


## SARIF e code scanning

Todo pacote completo grava `malkuth.sarif`. O arquivo segue SARIF 2.1.0 e representa avisos arquiteturais e violações opcionais de políticas como localizações lógicas de pacotes. Assim, o CI pode arquivá-lo ou enviá-lo para interfaces de code scanning.

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
sbcl --script analyze.lisp
# envie output/malkuth.sarif com a ação SARIF do provedor de CI
```

## Códigos de saída

- `0`: análise e políticas aprovadas;
- `1`: falha operacional, configuração inválida ou arquivo corrompido;
- `2`: política arquitetural violada.

Os relatórios são gerados antes da verificação das políticas para facilitar o diagnóstico de falhas.

## Exemplo de job genérico

```bash
set -eu

export MALKUTH_SCOPE_PREFIXES='MEU-APP'
export MALKUTH_USER_PREFIXES='MEU-APP'
export MALKUTH_OUTPUT_DIR="$PWD/build/malkuth/"
export MALKUTH_POLICY_FILE="$PWD/ci/malkuth-politicas.sexp"
export MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp"
export MALKUTH_MIN_HEALTH=75
export MALKUTH_FAIL_ON_POLICY=true
export MALKUTH_FAIL_ON_NEW_CYCLES=true
export MALKUTH_MAX_HEALTH_REGRESSION=4
export MALKUTH_SAVE_HISTORY=true
export MALKUTH_EXPORT_TRENDS=true

sbcl --script analyze.lisp
```

## Privacidade

Relatórios, linhas de base e históricos contêm nomes de pacotes e símbolos. Trate-os como documentação de código-fonte e aplique escopo antes de publicá-los.
