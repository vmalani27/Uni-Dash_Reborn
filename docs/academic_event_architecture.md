# AcademicEvent Architecture — Integration Guide

## Overview

This is a well-architected data transformation layer that converts low-level Gmail notifications into high-level **academic events** for dashboard prioritization. The transformation is **purely in the Flutter data layer** — no backend changes needed yet.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ Backend AI Service                                           │
│ (existing: Gmail sync → NLP classification → DB scoring)    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ GmailNotificationPreview (existing model)                   │
│ - gmailId, subject, sender, snippet                         │
│ - normalizedTopic (ASSIGNMENT, EXAM, ACADEMIC_ADMIN, etc.)  │
│ - academicScore (0-100)                                     │
│ - deadlineIso (nullable)                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
      ┌──────────────────┴──────────────────┐
      │                                     │
      ▼ (mapNotificationToEvent)            ▼ (existing)
┌─────────────────────────────────────────┐
│ AcademicEvent (new unified model)       │
│ - id, type, title, course               │
│ - deadline, urgency, academicScore      │
│ - sourceEmailId (for detail lookup)     │
└────────────────┬────────────────────────┘
                 │
      ┌──────────┴──────────┐
      │                     │
      ▼                     ▼
┌──────────────────────┐  ┌──────────────────────┐
│ AcademicDashboard    │  │ AcademicEventCard    │
│ (new: organized view)│  │ (new: single event)  │
└──────────────────────┘  └──────────────────────┘
```

## Files Added

### 1. **lib/models/academic_event.dart** (58 lines)
- **AcademicEventType** enum: `assignment`, `exam`, `academic`, `opportunity`, `information`, `other`
- **AcademicEvent** class: Unified event representation with:
  - `sortKey` computed property (urgency × weight + academicScore) for consistent ordering
  - `isActive` property to check if deadline is still actionable
  - Constructor validates all required fields

### 2. **lib/services/event_mapper.dart** (126 lines)
- **mapNotificationToEvent()**: Single notification → AcademicEvent
- **mapNotificationsToEvents()**: List transformation with stable 3-level sorting:
  1. urgency + academicScore (combined sort key)
  2. deadline (nearest first)
  3. recency (newest first)
- **groupEventsByType()**: Organize events into typed buckets
- **typeDisplayOrder**: Constant for consistent UI ordering
- **_topicToType()**: Enum conversion
- **_extractCourse()**: Regex parsing for course codes (CS101, MATH-201, etc.)

### 3. **lib/widgets/academic_event_card.dart** (246 lines)
- **AcademicEventCard**: Dashboard card displaying single event
  - Type badge (colored, icon-ready)
  - Urgency badge (Critical/High/Medium/Low/None)
  - Deadline countdown ("Due in 3 days", "Overdue", etc.)
  - Academic score progress bar (0-100)
  - Optional course code display
- Sub-widgets: `_TypeBadge`, `_UrgencyBadge`, `_DeadlineText`, `_ScoreIndicator`

### 4. **lib/widgets/academic_dashboard.dart** (344 lines)
- **AcademicDashboard**: Main organized view widget
  - Loads events via `mapNotificationsToEvents()`
  - Groups by type with `groupEventsByType()`
  - Summary stats bar (Total / Active / Critical counts)
  - Type sections with type emoji + event cards
  - Pull-to-refresh + auto-refresh (30s interval)
  - Error/empty states
  - Lifecycle handling (pause/resume)

---

## How to Integrate

### Option A: Replace GmailNotificationsList (Full Dashboard Mode)

In **lib/screens/home_screen.dart**, replace the notification list widget:

```dart
// OLD:
if (_profile != null && _profile!.oauthConnected) {
  return const GmailNotificationsList();
}

// NEW:
if (_profile != null && _profile!.oauthConnected) {
  return const AcademicDashboard();
}
```

Then add the import:
```dart
import 'package:trial1/widgets/academic_dashboard.dart';
```

### Option B: Keep Both (Hybrid Mode)

Add a view toggle and show either the old list view or new dashboard:

```dart
class HomeScreen extends StatefulWidget {
  // ...
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDashboardView = true; // Toggle preference
  
  // In _buildBody():
  if (_profile != null && _profile!.oauthConnected) {
    return _isDashboardView
        ? const AcademicDashboard()
        : const GmailNotificationsList();
  }
  
  // Add toggle button in header
}
```

---

## Data Flow Example

### Input (from backend via GmailSyncService):
```dart
GmailNotificationPreview(
  id: 1,
  gmailId: 'msg_abc123',
  subject: 'CS101 Assignment 3 Due Friday',
  snippet: 'Please submit your ...',
  normalizedTopic: 'ASSIGNMENT',
  academicScore: 87.5,
  deadlineIso: DateTime.parse('2026-03-21T23:59:59Z'),
  sender: 'prof@university.edu',
  internalDate: DateTime.parse('2026-03-15T10:30:00Z'),
)
```

### Transformation:
```dart
final event = mapNotificationToEvent(notification);
// ↓
AcademicEvent(
  id: 'msg_abc123',
  type: AcademicEventType.assignment,
  title: 'CS101 Assignment 3 Due Friday',
  course: 'CS101',  // ← extracted from subject
  deadline: DateTime.parse('2026-03-21T23:59:59Z'),
  urgency: 'Medium',  // ← default (can be enriched from AI)
  academicScore: 87.5,
  sourceEmailId: 'msg_abc123',
  summary: 'Please submit your ...',
  sender: 'prof@university.edu',
  receivedAt: DateTime.parse('2026-03-15T10:30:00Z'),
)
```

### Dashboard Display:
- Card appears in **"📝 Assignments"** section
- Type badge shows "Assignment" (blue)
- Title: "CS101 Assignment 3 Due Friday"
- Course code: "CS101" (blue, small)
- Deadline: "Due in 6 days"
- Score bar: 87 (yellow, 87% filled)
- Urgency badge: "Medium" (yellow)

---

## Sorting & Prioritization

### Sort Key Formula:
```
sortKey = urgencyWeight + academicScore

urgencyWeights = {
  'Critical': 400.0,
  'High': 300.0,
  'Medium': 200.0,
  'Low': 100.0,
  'None': 0.0,
}
```

**Example ordering:**
1. Critical exam (score 92) → sortKey = 400 + 92 = 492
2. High assignment (score 85) → sortKey = 300 + 85 = 385
3. Medium assignment (score 79) → sortKey = 200 + 79 = 279
4. Low info (score 50) → sortKey = 100 + 50 = 150

Same urgency? Break ties by deadline (soonest first), then by recency (newest first).

---

## Urgency Enrichment (Future)

Currently, **urgency defaults to 'Medium'** as a placeholder. To wire up actual AI urgency:

### Step 1: Extend GmailNotificationPreview
```dart
// In lib/models/gmail_models.dart
class GmailNotificationPreview {
  // ... existing fields
  final String? urgency;  // ← ADD THIS
}
```

### Step 2: Update mapper
```dart
// In lib/services/event_mapper.dart
urgency: notification.urgency ?? 'Medium',  // Use if available
```

### Step 3: Backend provides urgency
Your AI service already classifies urgency (see `GmailMessageDetail.aiLabelUrgency`). Expose it in the notification preview endpoint.

---

## Extension Points

### 1. Add More Event Metadata
```dart
class AcademicEvent {
  // ... existing
  final List<String>? tags;  // e.g., ['overdue', 'submitted']
  final String? actionItem;  // e.g., 'Review feedback'
}
```

### 2. Implement Detail View
```dart
// Replace the stub in AcademicDashboard._navigateToDetail():
void _navigateToDetail(AcademicEvent event) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EmailDetailScreen(gmailId: event.sourceEmailId),
    ),
  );
}
```

### 3. Add Filtering
```dart
// In AcademicDashboard:
List<AcademicEvent> get _filteredEvents {
  return _events
      .where((e) => selectedTypes.contains(e.type))
      .where((e) => selectedUrgencies.contains(e.urgency))
      .toList();
}
```

### 4. Batch Actions
```dart
// Mark as read, snooze, etc.
void _snoozeEvent(AcademicEvent event, Duration duration) {
  // Implement via backend API
}
```

---

## Testing

### Unit Tests (lib/services/event_mapper_test.dart)
```dart
void main() {
  test('mapNotificationToEvent extracts course code', () {
    final notif = GmailNotificationPreview(
      // ...
      subject: 'CS101 Assignment 3',
      // ...
    );
    final event = mapNotificationToEvent(notif);
    expect(event.course, 'CS101');
  });

  test('mapNotificationsToEvents sorts by sort key descending', () {
    // Create multiple notifications with varying urgency + score
    // Verify order matches expected sort key calculation
  });
}
```

### Widget Tests (lib/widgets/academic_event_card_test.dart)
```dart
void main() {
  testWidgets('AcademicEventCard displays course if provided', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AcademicEventCard(
      event: AcademicEvent(
        // ...
        course: 'CS101',
      ),
    )));
    expect(find.text('CS101'), findsOneWidget);
  });
}
```

---

## Migration Path

**Phase 1 (Now):** AcademicEvent layer + AcademicDashboard widget (no backend changes)  
**Phase 2 (Next sprint):** Wire up urgency field from AI service  
**Phase 3 (Future):** Create dedicated `/events` backend endpoint optimized for dashboard query  
**Phase 4 (Later):** Add filtering, saved searches, batch actions at UI layer

---

## Design Principles

1. **No backend changes yet** — prototype with existing data shape
2. **Single source of truth** — GmailNotificationPreview from backend, AcademicEvent in Flutter
3. **Stable sorting** — consistent multi-level ordering for predictable UX
4. **Computed properties** — `sortKey` and `isActive` derived from data, not stored
5. **Clear naming** — "AcademicEvent" clearly indicates problem domain (not generic notification)
6. **Compose over inherit** — small widgets (`_TypeBadge`, `_ScoreIndicator`) compose into cards/dashboard

---

## Next Steps

1. ✅ Create AcademicEvent model (done)
2. ✅ Create event mapper with sorting logic (done)
3. ✅ Create AcademicEventCard widget (done)
4. ✅ Create AcademicDashboard view (done)
5. ⏳ Integrate into HomeScreen (Option A or B above)
6. ⏳ Test with real Gmail data
7. ⏳ Add email detail view navigation
8. ⏳ Wire up urgency field from backend
9. ⏳ Add filtering/search UI
10. ⏳ Create backend `/events` endpoint (Phase 3)
