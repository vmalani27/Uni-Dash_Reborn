import re
import unicodedata


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
# Final AI preprocessing pipeline
# ---------------------------
def preprocess_email_for_llm(subject: str, body: str, sender: str):
    raw_text = f"{subject or ''} {body or ''}"

    text = normalize_text(raw_text)
    text = remove_disclaimer(text)
    text = remove_signatures(text)
    text = mask_urls(text)
    text = text.lower()

    sender_email = extract_email(sender)
    sender_domain = extract_domain(sender_email)

    return {
        "clean_text": text,
        "sender_email": sender_email,
        "sender_domain": sender_domain,
    }
