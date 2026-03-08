import requests
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("openrouter_api_key")

def run(model_name):
    res = requests.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers={"Authorization": f"Bearer {api_key}"},
        json={"model": model_name, "messages": [{"role": "user", "content": "hi"}]}
    )
    print(model_name, res.status_code, res.text)

run("qwen/qwen-2.5-vl-7b-instruct")



