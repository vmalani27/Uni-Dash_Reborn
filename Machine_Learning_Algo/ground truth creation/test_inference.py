import requests
import json
import re

def extract_json(text):
    try:
        return json.loads(text)
    except:
        pass
    match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except:
            pass
    return None

# Quick test of requests call
print("Testing inference via requests...") 
response = requests.post(
    'http://127.0.0.1:11434/api/generate',
    json={
        'model': 'gemini-3-flash-preview',
        'prompt': 'Respond with ONLY this JSON: {"test": true}',
        'stream': False,
        'options': {'temperature': 0, 'top_p': 0.1}
    },
    timeout=30
)

print(f"Response status: {response.status_code}")
print(f"Response body: {response.text[:200]}")

raw = response.json().get('response', '').strip()
print(f"\nRaw response: {repr(raw[:150])}")

parsed = extract_json(raw)
print(f"Parsed result: {parsed}")
