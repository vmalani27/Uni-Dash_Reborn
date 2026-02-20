"""
Timezone utilities for converting UTC to IST
"""
import datetime
from typing import Optional

# IST is UTC+5:30
IST_OFFSET = datetime.timedelta(hours=5, minutes=30)

def utc_to_ist(utc_datetime: Optional[datetime.datetime]) -> Optional[datetime.datetime]:
    """Convert UTC datetime to IST (Indian Standard Time)"""
    if utc_datetime is None:
        return None
    
    # If the datetime is naive (no timezone info), assume it's UTC
    if utc_datetime.tzinfo is None:
        return utc_datetime + IST_OFFSET
    
    # If it has timezone info, convert to UTC first then add IST offset
    utc_datetime = utc_datetime.replace(tzinfo=None)
    return utc_datetime + IST_OFFSET




def format_ist_datetime(utc_datetime: Optional[datetime.datetime]) -> Optional[str]:
    """Convert UTC datetime to IST and return ISO format string"""
    ist_datetime = utc_to_ist(utc_datetime)
    if ist_datetime is None:
        return None
    return ist_datetime.isoformat()
