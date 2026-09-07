---
name: python-engineering
description: Modern Python engineering practices — pyproject.toml, uv, ruff, mypy, pytest, packaging, type hints, async patterns, and project structure. Use this skill whenever the user is starting a new Python project, refactoring existing Python code, adding dependencies, setting up tooling, writing tests, adding type hints, or wants a code review of Python code for idiomatic patterns and modern conventions. Also use when converting from requirements.txt/setup.py to pyproject.toml, or when the user asks about the "right way" to structure a Python codebase.
---

# Python Engineering

## Core stack — use these, not the legacy alternatives

| Purpose | Use | Not |
|---|---|---|
| Package/venv manager | `uv` | pip/pipenv/poetry/conda |
| Project config | `pyproject.toml` | setup.py / requirements.txt |
| Formatter | `ruff format` | black |
| Linter | `ruff check` | flake8/pylint/isort |
| Type checker | `mypy` (or `pyright`) | none |
| Test runner | `pytest` | unittest |
| Task runner | `just` or `uv run` | make |

`uv` replaces pip, pip-tools, pipx, pyenv, poetry, and virtualenv. One tool. 10–100× faster.

## Project skeleton

```
my-project/
├── pyproject.toml
├── README.md
├── .python-version          # uv reads this to pin Python version
├── src/
│   └── my_package/
│       ├── __init__.py
│       └── core.py
├── tests/
│   └── test_core.py
└── .gitignore
```

Use **src layout** (`src/my_package/`) not flat layout. Src layout forces you to install your own package for tests to import it, which catches packaging bugs before your users do.

## pyproject.toml template

```toml
[project]
name = "my-package"
version = "0.1.0"
description = "One-line description"
requires-python = ">=3.11"
dependencies = [
    "pandas>=2.0",
    "numpy>=1.26",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-cov",
    "mypy>=1.8",
    "ruff>=0.5",
]

[project.scripts]
my-cli = "my_package.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM", "RUF"]
ignore = ["E501"]

[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
warn_unused_ignores = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-ra --strict-markers"
```

## Standard commands

```bash
uv init my-project              # scaffold new project
uv add pandas                   # add a dep (updates pyproject + lockfile)
uv add --dev pytest             # dev dep
uv sync                         # install everything from lockfile
uv run pytest                   # run in the project's venv
uv run ruff check --fix .       # lint + autofix
uv run ruff format .            # format
uv run mypy src/                # typecheck
uv lock --upgrade               # upgrade pinned versions
uv build                        # build wheel + sdist
```

## Type hints — the rules I actually follow

Modern typing (Python 3.10+):

```python
# Yes
def process(items: list[str], config: dict[str, int] | None = None) -> pd.DataFrame:
    ...

# No — the old typing module aliases are unnecessary now
from typing import List, Dict, Optional  # don't
def process(items: List[str], config: Optional[Dict[str, int]] = None) -> pd.DataFrame:
    ...
```

Use `TypeAlias` (or `type` statement in 3.12+) for repeated compound types:

```python
type Prices = pd.Series  # readable in error messages
type StrategyConfig = dict[str, float | int | str]
```

For public APIs, always annotate. For internal helpers, annotate when it clarifies intent — don't type-annotate a 3-line function whose types are obvious.

## Async — when to reach for it

Use `async` when:
- You're doing I/O-bound work (HTTP, DB, disk) and want concurrency
- You're integrating with an async framework (FastAPI, aiohttp)

Do NOT use `async` when:
- Work is CPU-bound (use `multiprocessing` or `concurrent.futures.ProcessPoolExecutor`)
- You're calling one blocking library — asyncifying one call in a sync flow adds complexity without benefit

Pattern for concurrent HTTP:

```python
import asyncio, httpx

async def fetch_all(urls: list[str]) -> list[dict]:
    async with httpx.AsyncClient() as client:
        tasks = [client.get(u) for u in urls]
        responses = await asyncio.gather(*tasks, return_exceptions=True)
    return [r.json() for r in responses if not isinstance(r, Exception)]
```

## Testing

- One test file per module: `tests/test_<module>.py`.
- Use `pytest` fixtures for setup, not `setUp`/`tearDown`.
- Parametrize instead of loops:
  ```python
  @pytest.mark.parametrize("input_val,expected", [(1, 2), (3, 4)])
  def test_double(input_val, expected):
      assert double(input_val) == expected
  ```
- Coverage target: 80%+ for library code. For scripts / one-shots, coverage is less useful than integration tests.
- Property-based tests (`hypothesis`) are worth the extra effort for anything with numerical edge cases (backtests, financial calcs).

## Data & math code — specific patterns for the Financial Terminal

- Always type-annotate DataFrame columns in docstrings — mypy can't see them.
- Use `pandera` or `pydantic` for schema validation at data boundaries (CSV imports, API responses).
- Prefer `polars` over `pandas` for anything > 1M rows or heavy groupby work. `pandas` is fine for exploration.
- Never `import *`. Never mutate a DataFrame in place unless you own the reference (return copies).
- For numerical code, prefer `numpy` operations over Python loops — 100× faster and cleaner.

## Error handling

- Raise specific exception types (`ValueError`, `KeyError`, custom subclass) — never bare `Exception`.
- Do NOT catch and swallow. `except Exception: pass` is almost always a bug.
- For long-running scripts, wrap the top-level with logging and a non-zero exit on failure:
  ```python
  def main() -> int:
      try:
          run()
          return 0
      except Exception:
          logger.exception("fatal error")
          return 1
  ```

## Common anti-patterns I flag on review

- `requirements.txt` in 2026 — should be `pyproject.toml` + `uv.lock`.
- `os.path.join` — should be `pathlib.Path`.
- String formatting with `%` or `.format` — should be f-strings.
- `time.sleep` in async code — should be `asyncio.sleep`.
- Global mutable state — refactor to dependency injection or dataclasses.
- No `if __name__ == "__main__":` guard in modules meant to be importable.
- `print()` for logging — use the `logging` module (or `structlog`/`loguru` for structured output).
