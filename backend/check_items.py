

import os
from dotenv import load_dotenv


# Load dotenv file by name if provided, otherwise fall back to ../.env
dotenv_file = os.path.join(os.path.dirname(__file__), '.env.dev')

# replace dev with prod based on branch, for feature branch stay on env.dev, 
from pathlib import Path
_dotenv_path = Path(dotenv_file)
if _dotenv_path.exists():
    load_dotenv(str(_dotenv_path))
    print("file loaded sucessfully")
else:
    # Fall back to default load (no-op if no .env present)
    load_dotenv()
    print("cant find file")



from app.core.database import SupabaseSessionLocal
from app.models.academic_objects import AcademicItem





db = SupabaseSessionLocal()
try:
    count = db.query(AcademicItem).count()
    print(f"Academic Items created: {count}")
    if count > 0:
        item = db.query(AcademicItem).first()
        print(f"item info {item}")
finally:
    db.close()
