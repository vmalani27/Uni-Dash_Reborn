from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]


def _sanitize_label(label: str) -> str:
    cleaned = label.strip()
    if not cleaned:
        raise ValueError("Migration label cannot be empty")

    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned


def _run_alembic(args: list[str]) -> None:
    command = [sys.executable, "-m", "alembic", *args]
    result = subprocess.run(command, cwd=BACKEND_DIR)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Autogenerate an Alembic migration from model changes and upgrade the database."
    )
    parser.add_argument(
        "label",
        help="Short description for the migration, e.g. 'add academic consolidation fields'",
    )
    parser.add_argument(
        "--no-upgrade",
        action="store_true",
        help="Only generate the migration file, do not run upgrade head.",
    )
    args = parser.parse_args()

    label = _sanitize_label(args.label)

    # Alembic requires the database to be at the current head before autogenerate.
    # This keeps the helper usable even when the local DB is one or more revisions behind.
    _run_alembic(["upgrade", "head"])
    _run_alembic(["revision", "--autogenerate", "-m", label])

    if not args.no_upgrade:
        _run_alembic(["upgrade", "head"])


if __name__ == "__main__":
    main()
