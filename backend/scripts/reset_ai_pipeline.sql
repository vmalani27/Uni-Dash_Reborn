-- Reset SQL for re-running the AI pipeline
-- This clears AI-generated data but preserves the synced emails

-- 1. Clear Projected Academic Items (DANGER: This removes dashboard objects)
DELETE FROM academic_items;

-- 2. Reset GmailMessage AI state to trigger re-processing
UPDATE gmail_messages
SET 
    ai_status = 'pending',
    ai_processed = false,
    ai_summary = NULL,
    ai_label_topic = NULL,
    ai_label_urgency = NULL,
    ai_label_source = NULL,
    ai_extra = NULL,
    academic_score = 0,
    deadline_iso = NULL,
    deadline_confidence = NULL,
    retry_count = 0,
    last_error = NULL,
    next_retry_at = NULL;
