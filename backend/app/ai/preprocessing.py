import re
import unicodedata

# Maximum characters to send to LLM to reduce token usage
TRUNCATE_LIMIT = 800

# Keywords for "Level 0" cheap filtering (bypass LLM)
# NOTE: Disabled aggressive filtering - letting LLM classify all emails
# The scoring system will naturally deprioritize low-value emails
TRIVIAL_KEYWORDS = [
    # Disabled - too many false positives with legitimate academic emails
]


# ---------------------------
# Basic normalization
# ---------------------------
def normalize_text(text: str) -> str:
    if not text:
        return ""

    text = str(text)
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"[\u200b\u200c\u200d\ufeff]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


# ---------------------------
# Remove institutional disclaimers
# ---------------------------
def remove_disclaimer(text: str) -> str:
    pattern = r"(?is)disclaimer[:].*"
    return re.sub(pattern, "", text)


# ---------------------------
# Remove generic signature endings
# ---------------------------
def remove_signatures(text: str) -> str:
    text = re.sub(
        r"(?is)(thanks[,.]?$|regards[,.]?$|warm regards[,.]?$|best wishes[,.]?$)",
        "",
        text
    )
    text = re.sub(r"(?is)(thanks|regards)[\s\S]{0,200}$", "", text)
    return text


# ---------------------------
# Replace URLs
# ---------------------------
def mask_urls(text: str) -> str:
    return re.sub(r"http\S+|www\.\S+", " <URL> ", text)


# ---------------------------
# Extract sender email
# ---------------------------
def extract_email(text: str) -> str:
    match = re.search(r'[\w\.-]+@[\w\.-]+', str(text))
    return match.group(0).lower() if match else ""


def extract_domain(email: str) -> str:
    return email.split('@')[-1] if "@" in email else ""


# ---------------------------
# Level 0: Cheap filter for trivial emails
# ---------------------------
def is_trivial_email(subject: str, body: str) -> bool:
    """
    Returns True if the email is likely a generic notification, 
    newsletter, or automated message that doesn't need AI extraction.
    """
    content = f"{subject or ''} {body or ''}".lower()
    
    # Check for trivial keywords
    for kw in TRIVIAL_KEYWORDS:
        if kw in content:
            return True
            
    return False


# ---------------------------
# Final AI preprocessing pipeline
# ---------------------------
def preprocess_email_for_llm(subject: str, body: str, sender: str):
    raw_text = f"{subject or ''} {body or ''}"

    text = normalize_text(raw_text)
    text = remove_disclaimer(text)
    text = remove_signatures(text)
    text = mask_urls(text)
    text = text.lower()
    
    # Aggressive truncation for LLM efficiency
    if len(text) > TRUNCATE_LIMIT:
        text = text[:TRUNCATE_LIMIT] + "..."

    sender_email = extract_email(sender)
    sender_domain = extract_domain(sender_email)

    return {
        "clean_text": text,
        "sender_email": sender_email,
        "sender_domain": sender_domain,
    }
