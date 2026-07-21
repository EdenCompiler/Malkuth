# Installation

## 1. Available components

Malkuth is split into a portable core and an optional SDL3 interface.

- `malkuth/core`: reflection, analysis, policies, history, monitoring and exports. It does not require SDL3 or CFFI.
- `malkuth`: interactive interface. It depends on CFFI and SDL3.
- `malkuth/tests`: automated regression suite.

The command-line entry points are `run.lisp`, `analyze.lisp`, `watch.lisp` and `render-svg.lisp`.

## 2. Linux dependencies

On Debian/Ubuntu-like systems:

```bash
sudo apt update
sudo apt install sbcl cl-cffi libsdl3-0 libsdl3-dev graphviz xvfb jq unzip
```

Package names can differ across distributions. The graphical interface needs an SDL3 runtime library; headless analysis does not.

## 3. CFFI through Quicklisp

When CFFI is installed through Quicklisp, remember that `sbcl --script` does not load the normal SBCL user initialization file. `run.lisp` therefore tries to discover Quicklisp automatically.

You may provide an explicit setup path:

```bash
QUICKLISP_SETUP="$HOME/quicklisp/setup.lisp" sbcl --script run.lisp
```

Or install CFFI through the operating system so ASDF can discover it directly.

## 4. First run

```bash
unzip malkuth-0.7.0.zip
cd malkuth-0.7.0
sbcl --script run.lisp
```

Headless analysis:

```bash
sbcl --script analyze.lisp
```

SVG only:

```bash
sbcl --script render-svg.lisp
```

## 5. Loading from the REPL

Add the project directory to ASDF or place it in a known ASDF source registry, then:

```lisp
(asdf:load-system "malkuth/core")
(asdf:load-system "malkuth")
(malkuth.app:run)
```

To inspect an application, load that application in the same Lisp image before building the Malkuth snapshot.

## 6. Installing in an ASDF-known location

A common development layout is:

```text
~/common-lisp/malkuth/
```

ASDF commonly scans `~/common-lisp/`. A custom source registry is also supported by ASDF.

## 7. Platforms

Linux is the primary validation platform. The portable core should work on other conforming Common Lisp implementations where the required implementation-specific reflection is available, while the interactive layer also requires a compatible SDL3 shared library and CFFI.
