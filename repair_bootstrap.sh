#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf "%s %s\n" "•" "$*"; }
die() { printf "✗ %s\n" "$*" >&2; exit 1; }

[ -n "${BASH_VERSION:-}" ] || die "Not running under bash. Use:  bash repair_bootstrap.sh"

log "Shell: $SHELL"
log "Using bash version: $BASH_VERSION"

# 1) Heredoc sanity test (if this fails, your shell/terminal paste is mangling heredocs)
tmp="$(mktemp)"
cat > "$tmp" <<'EOF'
heredoc_ok=1
EOF
grep -q 'heredoc_ok=1' "$tmp" || die "Heredoc test failed. Do NOT use 'source' or zsh; run: bash repair_bootstrap.sh"
rm -f "$tmp"
log "Heredoc test: OK"

# 2) Ensure Python 3.12 and Poetry exist (install via Homebrew if available)
if ! command -v python3.12 >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    log "Installing python@3.12 via Homebrew..."
    brew install python@3.12
  else
    die "python3.12 not found and Homebrew missing. Install Homebrew (https://brew.sh) and rerun."
  fi
fi
log "python3.12: $(python3.12 --version)"

if ! command -v poetry >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    log "Installing Poetry via Homebrew..."
    brew install poetry
  else
    die "Poetry not found and Homebrew missing. Install Poetry: https://python-poetry.org/docs/#installation"
  fi
fi
log "Poetry: $(poetry --version)"

# 3) Create project tree (idempotent)
PROJECT=fastform
if [ ! -d "$PROJECT" ]; then
  log "Creating project folder: $PROJECT/"
  mkdir -p "$PROJECT"
fi

cd "$PROJECT"
mkdir -p src/fastform/ai data tests
: > src/fastform/__init__.py
: > src/fastform/ai/__init__.py

write_if_missing() {
  local path="$1"; shift
  local label="$path"
  if [ -s "$path" ]; then
    log "Exists (skip): $label"
  else
    log "Writing: $label"
    # shellcheck disable=SC2129
    cat > "$path" <<"EOF"
$CONTENT
EOF
    # Replace placeholder marker with actual content passed in
    # (we can't pass heredoc content directly through functions; so we reroute)
    # This function expects caller to set CONTENT via a here-string
  fi
}

# --- pyproject.toml ---
if [ ! -s pyproject.toml ]; then
  log "Writing: pyproject.toml"
  cat > pyproject.toml <<'TOML'
[tool.poetry]
name = "fastform"
version = "0.1.0"
description = "Minimal drug-formulary rules engine (FastAPI + CSV + AI parsing + NN semantic search)"
authors = ["Jackson <you@example.com>"]
readme = "README.md"
packages = [{ include = "fastform", from = "src" }]

[tool.poetry.dependencies]
python = ">=3.12,<3.15"
fastapi = "^0.115.0"
uvicorn = { version = "^0.30.0", extras = ["standard"] }
pydantic-settings = "^2.4.0"
python-dotenv = "^1.0.1"
openai = "^1.51.0"
numpy = "^2.1.0"
scikit-learn = "^1.5.0"

[tool.poetry.group.dev.dependencies]
pytest = "^8.2.0"
httpx = "^0.27.0"
ruff = "^0.6.0"
mypy = "^1.10.0"
pre-commit = "^3.8.0"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
TOML
fi

# --- simple configs ---
[ -s .gitignore ] || cat > .gitignore <<'GIT'
__pycache__/
*.py[cod]
.venv/
.env
.DS_Store
.vscode/
GIT

[ -s ruff.toml ] || cat > ruff.toml <<'RUF'
line-length = 100
select = ["E","F","I","UP","B","SIM","N"]
ignore = ["E501"]
RUF

[ -s mypy.ini ] || cat > mypy.ini <<'INI'
[mypy]
python_version = 3.12
warn_unused_configs = True
strict = True
ignore_missing_imports = True
plugins = pydantic.mypy

[mypy-tests.*]
ignore_errors = True
INI

[ -s .pre-commit-config.yaml ] || cat > .pre-commit-config.yaml <<'YAML'
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: ["--fix"]
      - id: ruff-format
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.10.0
    hooks:
      - id: mypy
        additional_dependencies: ["pydantic>=2"]
YAML

[ -s Makefile ] || cat > Makefile <<'MAKE'
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
MAKE

# --- .env.example & README ---
if [ ! -s .env.example ]; then
  cat > .env.example <<'ENV'
FASTFORM_ENV=dev
FASTFORM_DATA_PATH=data/demo_rules.csv
DEFAULT_PLAN_ID=demo-plan

# AI provider config
AI_ENABLED=true
EMBEDDINGS_ENABLED=true
OPENAI_API_KEY=sk-REPLACE_ME
OPENAI_MODEL=gpt-4o-mini
OPENAI_EMBED_MODEL=text-embedding-3-small
ENV
  log "Wrote: .env.example"
fi

[ -s README.md ] || cat > README.md <<'MD'
# fastform

Tiny FastAPI service that answers: “given a drug query, what are the formulary rules for this plan?”
- Lexical search baseline
- AI parser for messy strings → `{drug_name,strength,route}`
- Semantic search via embeddings + scikit-learn NearestNeighbors

## Quickstart
```bash
poetry install
cp .env.example .env  # add your OPENAI_API_KEY
poetry run uvicorn fastform.main:app --reload

