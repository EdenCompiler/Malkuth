# Instalação

## 1. Componentes disponíveis

O projeto possui dois sistemas ASDF:

- `malkuth/core`: reflexão, análise, políticas, histórico, monitor, arranjo, SVG e exportações; não depende de SDL3 ou CFFI;
- `malkuth`: acrescenta fonte vetorial, ponte CFFI, SDL3 e interface interativa.

Use somente o núcleo em servidores, contêineres ou pipelines sem ambiente gráfico.

## 2. Dependências no Linux

Em Debian, Ubuntu e derivados:

```bash
sudo apt update
sudo apt install sbcl cl-cffi libsdl3-0 libsdl3-dev
```

Verifique:

```bash
sbcl --version
pkg-config --modversion sdl3
```

## 3. CFFI pelo Quicklisp

Dentro do REPL:

```lisp
(ql:quickload :cffi)
```

Ao usar `sbcl --script`, o SBCL não carrega `~/.sbclrc`. Por isso, `run.lisp` procura automaticamente:

```text
~/quicklisp/setup.lisp
~/.quicklisp/setup.lisp
~/.roswell/lisp/quicklisp/setup.lisp
```

Também é possível definir o caminho explicitamente:

```bash
QUICKLISP_SETUP="$HOME/meu-quicklisp/setup.lisp" \
sbcl --script run.lisp
```

## 4. Primeira execução

Interface:

```bash
sbcl --script run.lisp
```

Núcleo sem interface:

```bash
sbcl --script analyze.lisp
```

Monitor cooperativo:

```bash
MALKUTH_WATCH_ITERATIONS=1 sbcl --script watch.lisp
```

## 5. Carregamento pelo REPL

No diretório do projeto:

```lisp
(require :asdf)
(asdf:load-asd #P"malkuth.asd")
(asdf:load-system "malkuth")
(malkuth.app:run)
```

Somente o núcleo:

```lisp
(asdf:load-system "malkuth/core")
```

## 6. Instalação em localização ASDF conhecida

É possível criar uma ligação simbólica para o registro local do ASDF:

```bash
mkdir -p ~/.local/share/common-lisp/source
ln -s "$PWD" ~/.local/share/common-lisp/source/malkuth
```

Depois disso:

```lisp
(asdf:load-system "malkuth")
```

## 7. Plataformas

A versão atual é validada principalmente no Linux. A ponte SDL3 contém nomes usuais de biblioteca para macOS e Windows, mas essas plataformas precisam de validação independente.
