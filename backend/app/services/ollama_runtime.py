from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
import os
from threading import Lock
from typing import Any, Dict, Optional

import requests


DEFAULT_OLLAMA_CLOUD_BASE_URL = "https://ollama.com/api"
DEFAULT_OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_OLLAMA_SMALL_MODEL = "mistral:7b"
DEFAULT_OLLAMA_LARGE_MODEL = "llama3"
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


class _OpenRouterClientAdapter:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
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


class _OllamaCloudClientAdapter:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

    def generate(self, model: str, prompt: str, stream: bool = False, options: Optional[Dict[str, Any]] = None, **_: Any):
        payload: Dict[str, Any] = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False if not stream else stream,
        }

        options = options or {}
        if options.get("temperature") is not None:
            payload["options"] = payload.get("options", {})
            payload["options"]["temperature"] = options["temperature"]
        if options.get("top_p") is not None:
            payload["options"] = payload.get("options", {})
            payload["options"]["top_p"] = options["top_p"]
        if options.get("num_predict") is not None:
            payload["options"] = payload.get("options", {})
            payload["options"]["num_predict"] = options["num_predict"]

        response = requests.post(
            f"{self.base_url}/chat",
            headers=self.headers,
            json=payload,
            timeout=90,
        )
        response.raise_for_status()
        response_data = response.json()

        content = ""
        message = response_data.get("message") or {}
        content = message.get("content") or ""

        return {"response": content, "raw": response_data}


def initialize_ollama_runtime(force: bool = False) -> InferenceRuntimeState:
    global _state

    with _lock:
        if _state.initialized_at is not None and not force:
            return _state

        provider = (os.getenv("AI_PROVIDER") or "openrouter").strip().lower()

        if provider == "ollama_cloud":
            api_key = (os.getenv("OLLAMA_API_KEY") or "").strip()
            if not api_key:
                raise RuntimeError("OLLAMA_API_KEY is required for ollama_cloud")
            small_model = (os.getenv("OLLAMA_MODEL_20B") or "").strip()
            large_model = (os.getenv("OLLAMA_MODEL_120B") or "").strip()
            if not small_model:
                raise RuntimeError("OLLAMA_MODEL_20B is required for ollama_cloud")
            if not large_model:
                raise RuntimeError("OLLAMA_MODEL_120B is required for ollama_cloud")

            _state = InferenceRuntimeState(
                mode=InferenceMode.OLLAMA_CLOUD,
                provider="ollama_cloud",
                base_url=(os.getenv("OLLAMA_CLOUD_BASE_URL") or DEFAULT_OLLAMA_CLOUD_BASE_URL).rstrip("/"),
                headers={"Authorization": f"Bearer {api_key}"},
                initialized_at=datetime.now(timezone.utc),
                small_model=small_model,
                large_model=large_model,
            )
            return _state

        if provider == "openrouter":
            api_key = (os.getenv("OPENROUTER_API_KEY") or os.getenv("openrouter_api_key") or "").strip()
            if not api_key:
                raise RuntimeError("OPENROUTER_API_KEY is required for openrouter")
            small_model = (os.getenv("OPENROUTER_MODEL_20B") or "").strip()
            large_model = (os.getenv("OPENROUTER_MODEL_120B") or "").strip()
            if not small_model:
                raise RuntimeError("OPENROUTER_MODEL_20B is required for openrouter")
            if not large_model:
                raise RuntimeError("OPENROUTER_MODEL_120B is required for openrouter")

            _state = InferenceRuntimeState(
                mode=InferenceMode.OPENROUTER,
                provider="openrouter",
                base_url=(os.getenv("OPENROUTER_BASE_URL") or DEFAULT_OPENROUTER_BASE_URL).rstrip("/"),
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                initialized_at=datetime.now(timezone.utc),
                small_model=small_model,
                large_model=large_model,
            )
            return _state

        raise RuntimeError(f"Invalid AI_PROVIDER: {provider}. Use ollama_cloud or openrouter.")


def get_ollama_runtime_state() -> InferenceRuntimeState:
    if _state.initialized_at is None:
        return initialize_ollama_runtime()
    return _state


def get_ollama_client() -> Any:
    state = get_ollama_runtime_state()
    if state.mode == InferenceMode.UNAVAILABLE:
        raise RuntimeError(f"[OLLAMA] Backend unavailable: {state.probe_error or 'startup probe failed'}")

    if state.provider == "ollama_cloud":
        return _OllamaCloudClientAdapter(state.base_url, state.headers["Authorization"].split(" ", 1)[1])
    if state.provider == "openrouter":
        return _OpenRouterClientAdapter(state.base_url, state.headers["Authorization"].split(" ", 1)[1])

    raise RuntimeError(f"[OLLAMA] Unsupported provider: {state.provider}")


def get_inference_client() -> Any:
    return get_ollama_client()


def get_inference_model(kind: str) -> str:
    state = get_ollama_runtime_state()
    if kind not in {"small", "large"}:
        raise ValueError(f"Unknown inference model kind: {kind}")

    model = ""
    if kind == "small":
        model = state.small_model
    else:
        model = state.large_model

    if not model:
        raise RuntimeError(f"{kind.upper()} model is not configured for provider {state.provider}")

    return model


def get_inference_mode() -> InferenceMode:
    return get_ollama_runtime_state().mode
