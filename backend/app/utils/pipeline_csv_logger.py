import csv
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List


_LOCK = threading.Lock()


def _base_log_dir() -> Path:
    root = Path(__file__).resolve().parents[2]
    log_dir = Path((Path.cwd() / "runtime_logs") if not root else (root / "runtime_logs"))
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def _stringify(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (str, int, float, bool)):
        return str(value)
    if isinstance(value, (list, tuple)):
        return "; ".join(_stringify(item) for item in value)
    if isinstance(value, dict):
        return str(value)
    return str(value)


def append_csv_row(filename: str, row: Dict[str, Any], fieldnames: Iterable[str]) -> Path:
    path = _base_log_dir() / filename
    headers: List[str] = list(fieldnames)
    normalized_row = {key: _stringify(row.get(key)) for key in headers}

    with _LOCK:
        file_exists = path.exists()
        with path.open("a", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=headers)
            if not file_exists:
                writer.writeheader()
            writer.writerow(normalized_row)

    return path

