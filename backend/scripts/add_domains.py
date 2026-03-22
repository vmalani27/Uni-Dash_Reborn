"""Add initial domain entries to database.

One-time script to populate the `domains` table with known platforms.

Usage:
    python3 scripts/add_domains.py
"""

from app.core.database import SupabaseSessionLocal
from app.models.domain import Domain

DOMAINS_TO_ADD = [
    # Learning platforms
    ("coursera.org", "external_academic", True),
    ("nptel.ac.in", "external_academic", True),
    ("nptel.iitm.ac.in", "external_academic", True),
    ("swayam.gov.in", "external_academic", True),
   
]


def add_initial_domains():
    """Add domains to database if they don't exist."""
    db = SupabaseSessionLocal()
    try:
        count = 0
        for domain, source_type, is_trusted in DOMAINS_TO_ADD:
            existing = db.query(Domain).filter(Domain.domain == domain).first()
            if existing:
                continue

            db.add(Domain(
                domain=domain,
                source_type=source_type,
                is_default_trusted=is_trusted,
            ))
            count += 1

        db.commit()
        print(f"Added {count} domains")
    except Exception as e:
        print(f"Failed: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    add_initial_domains()

