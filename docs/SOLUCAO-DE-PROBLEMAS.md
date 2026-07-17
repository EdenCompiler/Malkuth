# Solução de problemas

## “Component cffi not found”

O CFFI pode estar instalado pelo Quicklisp, mas invisível em `sbcl --script`, que ignora `~/.sbclrc`.

```bash
QUICKLISP_SETUP="$HOME/quicklisp/setup.lisp" \
sbcl --script run.lisp
```

Localize o arquivo:

```bash
find "$HOME" -path '*/quicklisp/setup.lisp' -print 2>/dev/null
```

Também é possível instalar o pacote da distribuição:

```bash
sudo apt install cl-cffi
```

## SDL3 não encontrada

Verifique:

```bash
pkg-config --modversion sdl3
ldconfig -p | grep SDL3
```

Instale os pacotes de tempo de execução e desenvolvimento. O comando `analyze.lisp` continua disponível sem SDL3.

## A janela não abre em servidor ou contêiner

Use o modo sem interface:

```bash
sbcl --script analyze.lisp
```

Para teste automatizado, use um servidor X virtual:

```bash
xvfb-run -a env MALKUTH_MAX_FRAMES=12 sbcl --script run.lisp
```

## O escopo não encontrou pacotes

A aplicação precisa estar carregada na mesma imagem antes da construção do instantâneo. Confira nomes reais:

```lisp
(mapcar #'package-name (list-all-packages))
```

Depois ajuste `MALKUTH_SCOPE_PREFIXES`.

## O relatório inclui pacotes demais

Defina escopo e prefixos de usuário:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
sbcl --script analyze.lisp
```

Desative dependências de fronteira somente quando não precisar do contexto:

```bash
MALKUTH_INCLUDE_DEPENDENCIES=false
```

## A pontuação parece injusta

A pontuação é deliberadamente heurística. Revise ciclos, pacotes isolados e avisos individuais. Use políticas de CI somente depois de estabelecer uma linha de base adequada à arquitetura do projeto.

## Arquivo parcial ou temporário permaneceu

Exportações finais usam substituição atômica. Um processo encerrado à força pode deixar um arquivo oculto terminado em `.tmp`; ele pode ser removido com segurança quando nenhuma exportação estiver em execução.

## Texto com acento aparece sem marca gráfica na interface

A fonte vetorial 5x7 normaliza letras acentuadas para seus glifos-base. O texto continua legível, mas o acento visual pode ser omitido. Relatórios SVG e Markdown preservam os acentos completos.
