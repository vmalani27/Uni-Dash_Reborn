from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
import os
from threading import Lock
from typing import Any, Dict, Optional
from urllib.parse import urlparse

import requests
from ollama import Client


DEFAULT_OLLAMA_BASE_URL = "https://ollama.com"
DEFAULT_OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_PROBE_TIMEOUT = 8.0
DEFAULT_OLLAMA_SMALL_MODEL = "gpt-oss:20b-cloud"
DEFAULT_OLLAMA_LARGE_MODEL = "gpt-oss:120b-cloud"
DEFAULT_OPENROUTER_SMALL_MODEL = "google/gemma-4-31b-it:free"
DEFAULT_OPENROUTER_LARGE_MODEL = "google/gemma-4-26b-a4b-it:free"


class InferenceMode(str, Enum):
    OLLAMA_CLOUD = "ollama_cloud"
    OPENROUTER = "openrouter"
    UNAVAILABLE = "unavailable"


@dataclass
class InferenceRuntimeState:
    mode: InferenceMode = InferenceMode.UNAVAILABLE
    provider: str = "unavailable"
    base_url: str = ""
    headers: Dict[str, str] = field(default_factory=dict)
    initialized_at: Optional[datetime] = None
    probe_error: Optional[str] = None
    small_model: str = ""
    large_model: str = ""


_state = InferenceRuntimeState()
_lock = Lock()


def _normalize_base_url(value: Optional[str], fallback: str) -> str:
    raw_value = (value or "").strip()
    if not raw_value:
        return fallback.rstrip("/")

    if "://" not in raw_value:
        raw_value = f"https://{raw_value}"

    parsed = urlparse(raw_value)
    if not parsed.netloc:
        return fallback.rstrip("/")

    return f"{parsed.scheme}://{parsed.netloc}{parsed.path}".rstrip("/")


def _probe_ollama(base_url: str, headers: Dict[str, str], timeout: float = DEFAULT_PROBE_TIMEOUT) -> None:
    response = requests.get(f"{base_url.rstrip('/')}/api/tags", headers=headers, timeout=timeout)
    response.raise_for_status()


def _probe_openrouter(base_url: str, headers: Dict[str, str], timeout: float = DEFAULT_PROBE_TIMEOUT) -> None:
    response = requests.get(f"{base_url.rstrip('/')}/models", headers=headers, timeout=timeout)
    response.raise_for_status()


class _OpenRouterClientAdapter:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "HTTP-Referer": os.getenv("OPENROUTER_HTTP_REFERER", "http://localhost"),
            "X-Title": os.getenv("OPENROUTER_APP_TITLE", "UniDash Reborn"),
        }

    def generate(self, model: str, prompt: str, stream: bool = False, options: Optional[Dict[str, Any]] = None, **_: Any):
        payload: Dict[str, Any] = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False if not stream else stream,
        }

        options = options or {}
        if options.get("temperature") is not None:
            payload["temperature"] = options["temperature"]
        if options.get("top_p") is not None:
            payload["top_p"] = options["top_p"]
        if options.get("num_predict") is not None:
            payload["max_tokens"] = options["num_predict"]

        response = requests.post(
            f"{self.base_url}/chat/completions",
            headers=self.headers,
            json=payload,
            timeout=90,
        )
        response.raise_for_status()
        response_data = response.json()

        content = ""
        choices = response_data.get("choices") or []
        if choices:
            message = choices[0].get("message") or {}
            content = message.get("content") or ""

        return {"response": content, "raw": response_data}


def initialize_ollama_runtime(force: bool = False) -> InferenceRuntimeState:
    global _state

    with _lock:
        if _state.initialized_at is not None and not force:
            return _state

        ollama_key = (os.getenv("OLLAMA_API_KEY") or "").strip()
        ollama_base_url = _normalize_base_url(os.getenv("OLLAMA_BASE_URL"), DEFAULT_OLLAMA_BASE_URL)
        openrouter_key = (os.getenv("OPENROUTER_API_KEY") or os.getenv("openrouter_api_key") or "").strip()
        openrouter_base_url = _normalize_base_url(os.getenv("OPENROUTER_BASE_URL"), DEFAULT_OPENROUTER_BASE_URL)

        ollama_headers = {"Authorization": f"Bearer {ollama_key}"} if ollama_key else {}
        openrouter_headers = {
            "Authorization": f"Bearer {openrouter_key}",
            "HTTP-Referer": os.getenv("OPENROUTER_HTTP_REFERER", "http://localhost"),
            "X-Title": os.getenv("OPENROUTER_APP_TITLE", "UniDash Reborn"),
        } if openrouter_key else {}

        ollama_error: Optional[Exception] = None
        openrouter_error: Optional[Exception] = None

        if ollama_key:
            try:
                _probe_ollama(ollama_base_url, ollama_headers)
            except Exception as exc:
                ollama_error = exc
            else:
                _state = InferenceRuntimeState(
                    mode=InferenceMode.OLLAMA_CLOUD,
                    provider="ollama",
                    base_url=ollama_base_url,
                    headers=ollama_headers,
                    initialized_at=datetime.now(timezone.utc),
                    small_model=os.getenv("OLLAMA_MODEL_20B", DEFAULT_OLLAMA_SMALL_MODEL),
                    large_model=os.getenv("OLLAMA_MODEL_120B", DEFAULT_OLLAMA_LARGE_MODEL),
                )
                return _state

        if openrouter_key:
            try:
                _probe_openrouter(openrouter_base_url, openrouter_headers)
            except Exception as exc:
                openrouter_error = exc
            else:
                _state = InferenceRuntimeState(
                    mode=InferenceMode.OPENROUTER,
                    provider="openrouter",
                    base_url=openrouter_base_url,
                    headers=openrouter_headers,
                    initialized_at=datetime.now(timezone.utc),
                    small_model=os.getenv("OPENROUTER_MODEL_20B", DEFAULT_OPENROUTER_SMALL_MODEL),
                    large_model=os.getenv("OPENROUTER_MODEL_120B", DEFAULT_OPENROUTER_LARGE_MODEL),
                )
                return _state

        if ollama_error or openrouter_error:
            _state = InferenceRuntimeState(
                mode=InferenceMode.UNAVAILABLE,
                provider="unavailable",
                base_url="",
                headers={},
                initialized_at=datetime.now(timezone.utc),
                probe_error=f"ollama={ollama_error}; openrouter={openrouter_error}",
            )
            return _state

        _state = InferenceRuntimeState(
            mode=InferenceMode.UNAVAILABLE,
            provider="unavailable",
            base_url="",
            headers={},
            initialized_at=datetime.now(timezone.utc),
            probe_error="Both OLLAMA_API_KEY and OPENROUTER_API_KEY are missing",
        )
        return _state


def get_ollama_runtime_state() -> InferenceRuntimeState:
    if _state.initialized_at is None:
        return initialize_ollama_runtime()
    return _state


def get_ollama_client() -> Any:
    state = get_ollama_runtime_state()
    if state.mode == InferenceMode.UNAVAILABLE:
        raise RuntimeError(f"[OLLAMA] Backend unavailable: {state.probe_error or 'startup probe failed'}")

    if state.mode == InferenceMode.OLLAMA_CLOUD:
        return Client(host=state.base_url, headers=state.headers)

    return _OpenRouterClientAdapter(state.base_url, state.headers["Authorization"].split(" ", 1)[1])


def get_inference_client() -> Any:
    return get_ollama_client()


def get_inference_model(kind: str) -> str:
    state = get_ollama_runtime_state()
    if kind not in {"small", "large"}:
        raise ValueError(f"Unknown inference model kind: {kind}")

    if kind == "small":
        return state.small_model
    return state.large_model


def get_inference_mode() -> InferenceMode:
    return get_ollama_runtime_state().mode