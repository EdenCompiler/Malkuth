# Integração contínua

## Execução básica

```bash
MALKUTH_SCOPE_PREFIXES='ACME.APP' \
MALKUTH_USER_PREFIXES='ACME.APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth/" \
sbcl --script analyze.lisp
```

Armazene o diretório de saída como artefato do job. Assim, uma falha arquitetural permanece explicável por SVG, Markdown e JSON.

## Políticas

```bash
MALKUTH_MIN_HEALTH=80
MALKUTH_FAIL_ON_CYCLES=true
MALKUTH_MAX_WARNINGS=5
```

A política é verificada depois da geração dos relatórios. Mesmo quando o código de saída é `2`, os artefatos devem estar disponíveis.

## Adoção gradual

1. Execute sem políticas.
2. Revise ciclos e avisos existentes.
3. Diferencie decisões intencionais de dívida técnica.
4. Armazene uma linha de base.
5. Comece com limites permissivos.
6. Aperte os limites somente quando houver processo de correção.

Não use uma pontuação arbitrária para bloquear imediatamente um projeto maduro.

## Exemplo de job genérico

```bash
set -eu

export MALKUTH_SCOPE_PREFIXES='ACME.APP'
export MALKUTH_USER_PREFIXES='ACME.APP'
export MALKUTH_OUTPUT_DIR="$PWD/build/malkuth/"
export MALKUTH_MIN_HEALTH=75
export MALKUTH_FAIL_ON_CYCLES=true

sbcl --script analyze.lisp
```

## Comparação histórica

O Malkuth não mantém histórico automaticamente. Para acompanhar evolução:

- arquive `malkuth.json` por compilação;
- registre a impressão digital;
- compare contagens, ciclos e avisos;
- gere tendências em ferramenta externa.

## Privacidade

Relatórios contêm nomes de pacotes e símbolos. Trate-os como documentação de código-fonte e aplique escopo antes de publicá-los.
