.PHONY: run svg analyze watch test smoke watch-smoke validate package clean help

VERSAO := 0.6.0
PACOTE := malkuth-$(VERSAO)

help:
	@printf '%s\n' \
	  'make run         - abre a interface interativa' \
	  'make svg         - gera somente o SVG' \
	  'make analyze     - gera o pacote de relatórios sem interface' \
	  'make watch       - inicia o monitor cooperativo' \
	  'make test        - executa a suíte automatizada' \
	  'make smoke       - executa testes curtos da interface SDL3' \
	  'make watch-smoke - executa uma iteração do monitor' \
	  'make validate    - executa test, analyze, watch-smoke e smoke' \
	  'make clean       - remove artefatos gerados' \
	  'make package     - cria malkuth-0.6.0.zip'

run:
	sbcl --script run.lisp

svg:
	sbcl --script render-svg.lisp

analyze:
	sbcl --script analyze.lisp

watch:
	sbcl --script watch.lisp

test:
	sbcl --script tests/run.lisp

smoke:
	xvfb-run -a env MALKUTH_MAX_FRAMES=12 sbcl --script run.lisp
	xvfb-run -a sbcl --script tests/text-input-smoke.lisp

watch-smoke:
	env MALKUTH_WATCH_ITERATIONS=1 MALKUTH_EXPORT_ON_CHANGE=false sbcl --script watch.lisp

validate: test analyze watch-smoke smoke

clean:
	rm -rf output build

package: clean
	cd .. && zip -r $(PACOTE).zip $(PACOTE) \
		-x '$(PACOTE)/.git/*' '$(PACOTE)/*.fasl' '$(PACOTE)/*~'
