.PHONY: install run test lint format check hooks
install:
	poetry install
	poetry run pre-commit install
run:
	poetry run uvicorn fastform.main:app --reload
test:
	poetry run pytest -q
lint:
	poetry run ruff check src tests
format:
	poetry run ruff format src tests
check: lint
	poetry run mypy src
hooks:
	poetry run pre-commit install
