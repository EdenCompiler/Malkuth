.PHONY: run svg analyze test smoke validate package clean help

help:
	@printf '%s\n' \
	  'make run       - abre a interface interativa' \
	  'make svg       - gera somente o SVG' \
	  'make analyze   - gera o pacote de relatórios sem interface' \
	  'make test      - executa a suíte automatizada' \
	  'make smoke     - executa um teste curto da interface SDL3' \
	  'make validate  - executa test, analyze e smoke' \
	  'make clean     - remove artefatos gerados' \
	  'make package   - cria malkuth-0.4.1.zip'

run:
	sbcl --script run.lisp

svg:
	sbcl --script render-svg.lisp

analyze:
	sbcl --script analyze.lisp

test:
	sbcl --script tests/run.lisp

smoke:
	xvfb-run -a env MALKUTH_MAX_FRAMES=12 sbcl --script run.lisp
	xvfb-run -a sbcl --script tests/text-input-smoke.lisp

validate: test analyze smoke

clean:
	rm -rf output build

package: clean
	cd .. && zip -r malkuth-0.4.1.zip malkuth-0.4.1 \
		-x 'malkuth-0.4.1/.git/*' 'malkuth-0.4.1/*.fasl' 'malkuth-0.4.1/*~'
