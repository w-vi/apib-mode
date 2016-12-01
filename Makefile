EMACS ?= emacs

all: update compile test

update:
	$(EMACS) -batch -l install-deps.el

compile:
	$(EMACS) -batch -l load-deps.el . --eval '(setq byte-compile-error-on-warn t)' \
	-f batch-byte-compile apib-mode.el
test:
	${EMACS} -batch -l load-deps.el -l apib-mode-test.el -f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc

.PHONY: all compile test clean
