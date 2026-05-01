#!/usr/bin/env python3
"""
Diagnostic script for Ollama/LLM inference issues.
Helps identify model availability, response issues, and configuration problems.
"""

import os
import sys
import json
import time
import requests
from typing import Optional, Dict, Any

# Add parent directory to path
sys.path.insert(0, os.path.dirname(__file__))

from app.services.ollama_runtime import (
    get_ollama_runtime_state,
    initialize_ollama_runtime,
    get_inference_model,
    get_inference_mode,
    get_ollama_client,
)

def check_ollama_server(base_url: str = "http://localhost:11434", timeout: float = 5.0) -> Dict[str, Any]:
    """Check if Ollama server is running and responding."""
    print(f"\n[CHECK] Checking Ollama Server: {base_url}")
    print("-" * 60)
    
    result = {
        "reachable": False,
        "models": [],
        "error": None,
    }
    
    try:
        # Check if server is alive
        response = requests.get(f"{base_url}/api/tags", timeout=timeout)
        response.raise_for_status()
        
        data = response.json()
        models = data.get("models", [])
        
        result["reachable"] = True
        result["models"] = [m.get("name") for m in models]
        
        print(f"[OK] Server is running")
        print(f"[OK] Found {len(result['models'])} models")
        if result["models"]:
            for model in result["models"]:
                print(f"  - {model}")
        else:
            print("  [WARNING] No models available!")
        
        return result
        
    except requests.ConnectionError as e:
        result["error"] = f"Connection refused: {e}"
        print(f"[ERROR] Server is not reachable")
        print(f"  Error: {e}")
        return result
    except requests.Timeout as e:
        result["error"] = f"Server timeout: {e}"
        print(f"[ERROR] Server timed out")
        print(f"  Error: {e}")
        return result
    except Exception as e:
        result["error"] = str(e)
        print(f"[ERROR] Unexpected error: {e}")
        return result


def check_runtime_state() -> Optional[Dict[str, Any]]:
    """Check the current inference runtime state."""
    print(f"\n[CONFIG] Checking Runtime Configuration")
    print("-" * 60)
    
    try:
        state = initialize_ollama_runtime(force=True)
        
        print(f"Mode: {state.mode.value}")
        print(f"Provider: {state.provider}")
        print(f"Base URL: {state.base_url}")
        print(f"Small Model: {state.small_model}")
        print(f"Large Model: {state.large_model}")
        print(f"Initialized: {state.initialized_at}")
        
        if state.probe_error:
            print(f"[WARNING] Probe Error: {state.probe_error}")
        
        return {
            "mode": state.mode.value,
            "provider": state.provider,
            "base_url": state.base_url,
            "small_model": state.small_model,
            "large_model": state.large_model,
            "error": state.probe_error,
        }
    except Exception as e:
        print(f"[ERROR] Error initializing runtime: {e}")
        return None


def test_model_inference(model: str, prompt: str = "Say hello in JSON format: {\"greeting\": \"hello\"}", timeout: float = 30.0) -> Optional[str]:
    """Test if a model can produce valid output."""
    print(f"\n[TEST] Testing Model: {model}")
    print("-" * 60)
    
    try:
        client = get_ollama_client()
        
        print(f"Calling {model}...")
        start_time = time.time()
        
        result = client.generate(
            model=model,
            prompt=prompt,
            options={
                "temperature": 0.0,
                "top_p": 0.1,
                "num_predict": 500,
            },
        )
        
        elapsed = time.time() - start_time
        response = result.get("response", "")
        
        print(f"[OK] Inference completed in {elapsed:.2f}s")
        print(f"Response length: {len(response)} chars")
        
        if not response or not response.strip():
            print("[ERROR] Model returned EMPTY response!")
            return None
        
        print(f"Response preview: {response[:200]}...")
        
        # Try to parse as JSON
        try:
            parsed = json.loads(response)
            print(f"[OK] Response is valid JSON")
            return response
        except json.JSONDecodeError:
            print(f"[WARNING] Response is not valid JSON (may not be required)")
            return response
        
    except requests.Timeout:
        print(f"[ERROR] Model timed out after {timeout}s")
        return None
    except Exception as e:
        print(f"[ERROR] Error: {type(e).__name__}: {e}")
        return None


def test_model_json_output(model: str, timeout: float = 30.0) -> bool:
    """Test if a model can produce valid JSON output."""
    print(f"\n[TEST-JSON] Testing JSON Output for: {model}")
    print("-" * 60)
    
    json_prompt = """
    You MUST respond with ONLY valid JSON. No markdown, no extra text.
    Extract information from this text and return as JSON:
    
    "I have a math assignment due tomorrow with an urgency of high"
    
    Required JSON format:
    {
        "summary": "brief summary",
        "item_type": "ASSIGNMENT",
        "urgency": "high"
    }
    """
    
    try:
        client = get_ollama_client()
        
        print(f"Calling {model} with JSON prompt...")
        start_time = time.time()
        
        result = client.generate(
            model=model,
            prompt=json_prompt,
            options={
                "temperature": 0.0,
                "top_p": 0.1,
                "num_predict": 1000,
            },
        )
        
        elapsed = time.time() - start_time
        response = result.get("response", "")
        
        print(f"Response time: {elapsed:.2f}s")
        print(f"Response length: {len(response)} chars")
        
        if not response or not response.strip():
            print("[ERROR] Model returned EMPTY response!")
            return False
        
        # Try to parse as JSON
        try:
            parsed = json.loads(response)
            print(f"[OK] Response is valid JSON")
            print(f"Parsed: {json.dumps(parsed, indent=2)}")
            return True
        except json.JSONDecodeError as e:
            print(f"[ERROR] Response is NOT valid JSON: {e}")
            print(f"Response: {response}")
            return False
        
    except requests.Timeout:
        print(f"[ERROR] Model timed out after {timeout}s")
        return False
    except Exception as e:
        print(f"[ERROR] Error: {type(e).__name__}: {e}")
        return False


def main():
    """Run all diagnostics."""
    print("=" * 60)
    print("OLLAMA DIAGNOSTIC TOOL")
    print("=" * 60)
    
    # Check server
    server_status = check_ollama_server()
    
    if not server_status["reachable"]:
        print("\n[FATAL] OLLAMA SERVER IS NOT RUNNING!")
        print("\nTo start Ollama:")
        print("  - On Windows: Run 'ollama serve' or use Ollama application")
        print("  - On Mac/Linux: Run 'ollama serve'")
        return
    
    # Check runtime
    runtime = check_runtime_state()
    if not runtime:
        print("\n[FATAL] Could not initialize runtime")
        return
    
    # Test models
    if runtime["small_model"]:
        print(f"\n" + "=" * 60)
        print("TESTING SMALL MODEL")
        print("=" * 60)
        response = test_model_inference(runtime["small_model"])
        if not response:
            print(f"\n[WARNING] Small model ({runtime['small_model']}) is not responding properly!")
    
    if runtime["large_model"]:
        print(f"\n" + "=" * 60)
        print("TESTING LARGE MODEL")
        print("=" * 60)
        response = test_model_inference(runtime["large_model"])
        if not response:
            print(f"\n[WARNING] Large model ({runtime['large_model']}) is not responding properly!")
        else:
            # Test JSON specifically
            json_ok = test_model_json_output(runtime["large_model"])
            if not json_ok:
                print(f"\n[WARNING] Large model ({runtime['large_model']}) cannot produce valid JSON!")
    
    # Summary
    print(f"\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    def model_exists(model_name: str, available_models: list) -> bool:
        """Check if model exists, accounting for tags like llama3:latest."""
        model_base = model_name.split(":")[0]  # Get base name without tag
        return any(m.startswith(model_base) for m in available_models)
    
    issues = []
    
    if not server_status["reachable"]:
        issues.append("[ERROR] Ollama server is not running")
    
    if not server_status["models"]:
        issues.append("[ERROR] No models are available in Ollama")
    elif not model_exists(runtime["small_model"], server_status["models"]):
        issues.append(f"[ERROR] Small model '{runtime['small_model']}' not found in Ollama")
    elif not model_exists(runtime["large_model"], server_status["models"]):
        issues.append(f"[ERROR] Large model '{runtime['large_model']}' not found in Ollama")
    
    if issues:
        print("\n[ISSUES] ISSUES FOUND:\n")
        for issue in issues:
            print(f"  {issue}")
        print("\n[FIXES] Recommended fixes:")
        print("  1. Ensure Ollama server is running")
        print("  2. Install missing models:")
        print(f"     - ollama pull {runtime['small_model']}")
        print(f"     - ollama pull {runtime['large_model']}")
        print("  3. Check Ollama logs for errors")
        print("  4. Verify system resources (RAM, disk space)")
    else:
        print("\n[SUCCESS] All systems operational!")
    
    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
