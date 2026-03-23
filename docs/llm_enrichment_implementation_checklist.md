# Implementation Checklist — LLM Enrichment Integration

## Backend Setup

- [ ] **Install Ollama dependency**
  ```bash
  cd backend
  pip install ollama
  ```

- [ ] **Add enriched notification endpoint**
  - Copy `backend/app/routers/enriched_notifications.py` (done)
  - Wire into main FastAPI app:
    ```python
    # backend/app/main.py
    from app.routers import enriched_notifications
    app.include_router(enriched_notifications.router)
    ```

- [ ] **Update notification fetching to include enrichment**
  - Option A: Modify `GmailSyncService.loadNotificationsInstant()` to call enrichment endpoint
  - Option B: Keep separate, add `enrich_with_llm` param to request

- [ ] **Set up Ollama** (local or Docker)
  ```bash
  ollama serve &
  ollama pull gemma:7b-instruct
  ```

---

## Flutter Updates

- [ ] **Models updated** ✅
  - `StructuredInsights` (new)
  - `GmailNotificationPreview` (extended with `structuredInsights?`)
  - `AcademicEvent` (extended with `insights?`)

- [ ] **Event mapper updated** ✅
  - Now passes `structuredInsights` through to `AcademicEvent`

- [ ] **AcademicEventCard updated** ✅
  - Shows `_InsightsSection` when insights available
  - Displays instructor, actions, submission format
  - Shows "AI enriched" badge

- [ ] **Test cold compile**
  ```bash
  cd trial1
  flutter pub get
  flutter analyze
  ```

---

## Integration Points

### Option 1: Update GmailSyncService (Recommended)

**File:** `lib/services/gmail_sync_service.dart`

```dart
// OLD
Future<List<GmailNotificationPreview>> loadNotificationsInstant() async {
  final response = await http.get(Uri.parse('$baseUrl/emails/preview'));
  final data = json.decode(response.body) as List;
  return data.map((e) => GmailNotificationPreview.fromJson(e)).toList();
}

// NEW
Future<List<GmailNotificationPreview>> loadNotificationsInstant({
  bool enrichWithLlm = false,
  int enrichCount = 5,
}) async {
  final endpoint = enrichWithLlm
      ? '$baseUrl/notifications/dashboard/high-priority?enrich_with_llm=true&enrich_count=$enrichCount'
      : '$baseUrl/emails/preview';
  
  final response = await http.get(Uri.parse(endpoint));
  final data = json.decode(response.body);
  
  // Check if response includes 'notifications' (enriched endpoint) or direct list
  final list = data is Map ? data['notifications'] as List : data as List;
  return list.map((e) => GmailNotificationPreview.fromJson(e)).toList();
}
```

Then update `AcademicDashboard` call:
```dart
Future<void> _loadEvents() async {
  try {
    final result = await GmailSyncService.loadNotificationsInstant(
      enrichWithLlm: true,
      enrichCount: 5,  // Top 5 get LLM enrichment
    );
    // ... rest of method
  }
}
```

### Option 2: Dual Endpoints (Keep Flexibility)

Create separate service method:
```dart
Future<List<GmailNotificationPreview>> loadEnrichedNotifications() async {
  final response = await http.get(
    Uri.parse('$baseUrl/notifications/dashboard/high-priority?enrich_with_llm=true'),
  );
  final data = json.decode(response.body)['notifications'] as List;
  return data.map((e) => GmailNotificationPreview.fromJson(e)).toList();
}
```

---

## Testing Checklist

### Backend Tests

- [ ] Test pattern extraction
  ```bash
  python -m pytest backend/tests/test_academic_context.py::test_extract_course_code -v
  ```

- [ ] Test LLM extraction (requires Ollama running)
  ```bash
  python -m pytest backend/tests/test_academic_context.py::test_llm_extraction -v
  ```

- [ ] Test API endpoints
  ```bash
  curl http://localhost:8000/api/notifications/dashboard/high-priority?limit=5&enrich_with_llm=false
  curl http://localhost:8000/api/notifications/dashboard/high-priority?limit=5&enrich_with_llm=true&enrich_count=3
  ```

### Flutter Tests

- [ ] Compile with no errors
  ```bash
  flutter analyze
  flutter pub get
  ```

- [ ] AcademicEventCard displays insights
  ```bash
  flutter test test/widgets/academic_event_card_test.dart
  ```

- [ ] AcademicDashboard loads and renders
  ```bash
  flutter test test/widgets/academic_dashboard_test.dart
  ```

- [ ] Hot reload with real data
  - Run app
  - Tap dashboard
  - Check enriched cards show instructor, actions, etc.

---

## Debugging

### "structured_insights is null"
→ Backend not returning enrichment. Check:
1. API endpoint is wired correctly
2. Use `enrich_with_llm=true` in request?
3. Backend logs for errors

### "No errors but no actions displayed"
→ Insights populated but empty. Check:
1. Email body has action keywords?
2. Try with `enrich_with_llm=true` (pattern extraction may be too conservative)

### "Ollama not found" error
→ Expected if running without Ollama. System should degrade gracefully.
Check backend logs; should fallback to pattern extraction.

### "LLM inference taking >1s"
→ Normal for first request (model load). Subsequent requests faster.
- If persistent, try smaller model: `phi:instruct`
- Or disable LLM on all but top N items

---

## Rollout Strategy

### Phase 1: Shadow Deploy (Week 1)
- [ ] Deploy pattern-based extraction
- [ ] No UI changes yet — just log metrics
- [ ] Measure accuracy: course code, action items
- [ ] **Success criteria:** >90% course code extraction accuracy

### Phase 2: UI Integration (Week 2)
- [ ] Show insights in AcademicEventCard
- [ ] Deploy Ollama locally
- [ ] Enrich only top 5 items (cost-aware)
- [ ] **Success criteria:** Insights displayed, no performance regression

### Phase 3: Production (Week 3)
- [ ] Enable LLM enrichment for all high-priority emails
- [ ] Add feedback mechanism ("Action was wrong")
- [ ] Cache enrichments (24h)
- [ ] Monitor Ollama latency

### Phase 4: Optimization (Week 4+)
- [ ] Fine-tune model on your email corpus
- [ ] Improve prompt
- [ ] Add user-facing filtering by action type
- [ ] A/B test different models (gemma vs. mistral)

---

## Monitoring

### Metrics to Track

1. **Pattern Extraction**
   - Course code detection rate (target: >90%)
   - Action item detection rate (target: >75%)
   - False positive rate (target: <10%)

2. **LLM Enrichment**
   - Inference latency per email (target: <500ms)
   - Confidence score distribution
   - Semantic accuracy (manual spot-checks)

3. **Dashboard Performance**
   - Page load time (should not increase >100ms)
   - Network request size (enrichment overhead)
   - Cache hit rate (if caching enrichments)

### Dashboard Queries

```python
# Backend: Count enriched vs. pattern emails
SELECT 
  COUNT(*) as total,
  SUM(CASE WHEN enriched_by_llm THEN 1 ELSE 0 END) as llm_enriched,
  COUNT(*) - SUM(CASE WHEN enriched_by_llm THEN 1 ELSE 0 END) as pattern_only
FROM notifications WHERE DATE = TODAY();

# Backend: Avg confidence by method
SELECT 
  enriched_by_llm,
  AVG(confidence) as avg_confidence,
  COUNT(*) as count
FROM structured_insights
GROUP BY enriched_by_llm;
```

---

## Common Pitfalls

1. **Calling LLM for every email**
   - Cost: ~500ms × 1000 emails = 8 min
   - **Fix:** Limit to top N (enrich_count=5)

2. **Assuming LLM always better**
   - Sometimes wrong! (hallucination)
   - **Fix:** Keep pattern-based as fallback, show confidence score

3. **Not handling Ollama offline**
   - App crashes if Ollama unavailable
   - **Fix:** Graceful degradation to patterns (already implemented)

4. **Stale enrichments**
   - Email replied to, but old insights still shown
   - **Fix:** Add `enriched_at` timestamp, cache TTL

5. **Prompt too specific**
   - Works on your emails but fails on variations
   - **Fix:** Make prompt more generic, test on diverse samples

---

## Resources

- [Ollama Docs](https://ollama.ai)
- [Gemma Model Card](https://huggingface.co/google/gemma-7b-it)
- [Mistral 7B](https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.1)
- [LLM Prompting Best Practices](https://github.com/openai/openai-cookbook)

---

## Next Action

**Immediate (this sprint):**
1. Add enriched notification endpoint to FastAPI
2. Test pattern extraction on 100 real emails
3. Verify course code detection accuracy

**Next sprint:**
1. Deploy Ollama
2. Integrate with Flutter
3. A/B test enriched vs. non-enriched dashboard
