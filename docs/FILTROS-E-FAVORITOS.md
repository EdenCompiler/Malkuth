# Filtros, foco e favoritos

## Filtros visuais

Os filtros alteram somente o que é desenhado e percorrido pela navegação. O instantâneo e a análise continuam completos.

| Tecla | Filtro | Regra |
|---|---|---|
| `1` | Todos | Exibe todos os nós do instantâneo |
| `2` | Projeto | Exibe pacotes classificados como código do projeto |
| `3` | Risco | Exibe pacotes cujo risco local alcança o limiar configurado |
| `4` | Favoritos | Exibe pacotes marcados pelo usuário |
| `5` | Vizinhança | Exibe seleção, dependências e dependentes diretos |

O pacote selecionado permanece visível mesmo quando não satisfaz o filtro. Isso impede a perda de contexto durante a troca de modos.

## Foco de vizinhança

`V` alterna rapidamente entre o filtro de vizinhança e a visão completa. Esse modo é útil para responder:

- o que este pacote usa diretamente;
- quem depende dele;
- quais relações existem entre seus vizinhos imediatos.

## Favoritos persistentes

`F` alterna o pacote selecionado na lista de favoritos. A lista é gravada como uma S-expression simples em:

```text
<diretório-de-saída>/malkuth-favoritos.sexp
```

O carregamento desativa `*READ-EVAL*` e aceita somente uma lista de strings. Um arquivo inválido é ignorado com aviso, sem impedir a abertura da interface.

## Limiar de risco

O filtro `3` usa `MALKUTH_RISK_THRESHOLD`, com padrão `20` e intervalo aceito de 0 a 100.

```bash
MALKUTH_RISK_THRESHOLD=40 sbcl --script run.lisp
```

Esse valor não modifica a pontuação global de saúde nem as regras do analisador; ele serve apenas para navegação visual.

## Alterados desde a linha de base

Pressione `6` para mostrar pacotes adicionados ou com contagens alteradas desde a linha de base. É necessário capturar a base com `B` ou possuir `malkuth-linha-de-base.sexp` no diretório de saída. Pacotes alterados recebem um anel magenta. Pacotes removidos aparecem no painel `T`, mas não podem ser desenhados porque já não existem no instantâneo atual.
