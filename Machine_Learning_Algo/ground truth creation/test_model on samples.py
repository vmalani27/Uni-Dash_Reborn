import requests
import json
import re
import time

def extract_json(text):
    """Robustly extract JSON from text that may contain surrounding content."""
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

# System prompt
SYSTEM_PROMPT = """You are an academic email classification assistant.

You will receive:
- SOURCE TRUST LEVEL
- EMAIL SUBJECT
- EMAIL BODY

Your task:
1. Classify the email into ONE topic
2. Generate a short student-facing summary

--------------------------------------------------
CRITICAL RULES (MUST FOLLOW)

1. TOPIC = PRIMARY INTENT (NOT KEYWORDS)
- Ignore secondary elements like "fees", "forms", or "links"
- Classify based on the main purpose of the email

Examples:
- Paying semester fees → Administrative
- Paying for a certification course → Certification / Courses
- Joining Google Classroom → Administrative (setup)
- Assignment submission → Assignment or Submission

2. IMPORTANT ANNOUNCEMENTS RULE
- Use ONLY if no action is required
- If action is required → NEVER use this category

3. HANDLE NOISY EMAILS
- If content is partially noisy (HTML etc.) but intent is clear → classify normally
- If content is completely missing or meaningless → treat as General Information / Misc

--------------------------------------------------

Allowed topic labels:
["Timetable / Schedule Update", "Exam Notifications", "Assignment or Submission", "Certification / Courses", "Internship / Placement Opportunities", "Events / Hackathons", "Important Announcements", "Administrative / Fees / Counselling", "General Information / Misc"]

--------------------------------------------------

RETURN INSTRUCTIONS (CRITICAL):
- Return ONLY valid JSON in this exact format - NO other text
- Do NOT include any text before or after the JSON
- Do NOT use markdown formatting or code blocks
- Output must be pure JSON only

{
  "summary": "<one-line student-facing summary>",
  "label_topic": "<one topic label>"
}
"""

# Sample email from dataset
sample_email = {
    "label_source": "External / Misc",
    "subject": "Exclusive Education Pricing Just for You!",
    "clean_text": "exclusive education pricing just for you! read ai for $5 per month hi 23dcs023, as a read user with a .edu email, we're thrilled to offer you exclusive education pricing..."
}

prompt = f"""
SOURCE TRUST LEVEL: {sample_email['label_source']}
SUBJECT: {sample_email['subject']}

EMAIL CONTENT:
{sample_email['clean_text']}
"""

print("="*80)
print("Testing deepseek-r1:7b Model Inference")
print("="*80)
print(f"\nSample Email:")
print(f"  Source: {sample_email['label_source']}")
print(f"  Subject: {sample_email['subject']}")
print(f"  Text: {sample_email['clean_text'][:100]}...\n")

print("Sending inference request...")
start = time.time()

try:
    response = requests.post(
        'http://127.0.0.1:11434/api/generate',
        json={
            'model': 'gemini-3-flash-preview',
            'prompt': SYSTEM_PROMPT + "\n" + prompt,
            'stream': False,
            'options': {'temperature': 0, 'top_p': 0.1}
        },
        timeout=90
    )
    
    latency_ms = round((time.time() - start) * 1000)
    
    print(f"Response Status: {response.status_code}")
    print(f"Latency: {latency_ms}ms")
    
    if response.status_code == 200:
        raw = response.json().get('response', '').strip()
        print(f"\nRaw Response (first 300 chars):")
        print(f"{raw[:300]}")
        
        parsed = extract_json(raw)
        
        print(f"\n" + "="*80)
        if parsed:
            print(f"Parsing Result: [OK]")
            print(f"  Topic: {parsed.get('label_topic', 'N/A')}")
            print(f"  Summary: {parsed.get('summary', 'N/A')}")
        else:
            print(f"Parsing Result: [WARNING] - Could not extract valid JSON")
            print(f"Raw output saved for inspection")
    else:
        print(f"Error: HTTP {response.status_code}")
        print(response.text)
        
except requests.exceptions.Timeout:
    print("Error: Request timed out (90s)")
except Exception as e:
    print(f"Error: {str(e)}")

print("="*80)
