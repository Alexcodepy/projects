# CLAUDE.md

This file provides guidance for AI assistants working with this repository.

## Project Overview

A beginner Python learning project by Alejandro containing two standalone command-line scripts. No build system, no dependencies, no external services.

## Repository Structure

```
/
├── Calcualdora.py   # Multi-mode calculator (Spanish-language UI)
├── worlde.md        # Wordle-style word guessing game (Python code, misnamed as .md)
└── CLAUDE.md        # This file
```

## Files

### Calcualdora.py
A menu-driven calculator with 5 modes:
1. Quadratic equation solver (ax² + bx + c = 0)
2. Unit converter (km, cm, m)
3. Velocity calculator (linear and angular)
4. Simple arithmetic (add, subtract, multiply, divide)
5. Exit

Entry point: `python Calcualdora.py`

### worlde.md
A Wordle clone where users guess a 5-letter word ("paris") in up to 5 attempts. Uses emoji feedback: ✅ correct position, 🟡 wrong position, ❌ not in word.

Entry point: `python worlde.md` (note: file has `.md` extension but contains Python code)

## Language and Style Conventions

- **Primary language**: Spanish (UI text, variable names, comments)
- **Python version**: Python 3.x (uses f-strings)
- **Style**: Procedural single-file scripts, no classes or modules
- **Error handling**: `try/except ValueError` for invalid input; `while` loops for input validation
- **No external dependencies**: Standard library only

## Known Issues

- `Calcualdora.py` is a typo — should be `Calculadora.py`
- `worlde.md` should be `worlde.py` (it contains Python code)
- Line 128 in `Calcualdora.py`: variable `dsitancia` is a typo for `distancia`
- The word guessing game has a hardcoded answer ("paris")
- No test suite exists

## Development Notes

- No `requirements.txt`, `pyproject.toml`, or any dependency management
- No CI/CD pipelines
- No linters or formatters configured
- Scripts run directly: `python <filename>`
- Do not add external dependencies without discussion
- Do not convert to classes/modules unless explicitly requested
- Preserve the Spanish-language interface in existing scripts
