PY ?= python

.PHONY: validate trust run grade results report screens all demo test

validate:
	$(PY) -m assay validate
trust:
	$(PY) -m assay trust
run:
	$(PY) -m assay run
grade:
	$(PY) -m assay.grade --force
results:
	$(PY) -m assay results
report:
	$(PY) -m assay report
screens:
	$(PY) -m assay screens
all:
	$(PY) -m assay all
demo:
	$(PY) -m assay demo
test:
	$(PY) -m pytest -q tests
