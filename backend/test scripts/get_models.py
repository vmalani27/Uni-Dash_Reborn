import requests
import json
res = requests.get("https://openrouter.ai/api/v1/models")
models = res.json()["data"]
free_models = [m["id"] for m in models if m["pricing"]["prompt"] == "0" and "gemini" in m["id"].lower()]
print("Free Gemini models:", free_models)
