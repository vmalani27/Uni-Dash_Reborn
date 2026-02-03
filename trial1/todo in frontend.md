Perfect. Then here is a **full end-to-end execution checklist** you can literally follow line-by-line, **without breaking backend connectivity**, with **explicit review gates** after every phase.

This is written for *your current codebase*, not a greenfield app.

---

# UniDash Reborn — Frontend Rebuild & Onboarding Checklist

**Goal:** Introduce onboarding, fix flow + UX coherence, **without destabilizing auth, OAuth, or backend APIs**

---

## PHASE 0 — SAFETY FIRST (Do This Before Anything Else)

### ⬜ 0.1 Create a Frontend Stability Branch

* Create a new git branch:

  ```
  feature/onboarding-refactor
  ```
* Do **not** touch backend code during this phase.

### ⬜ 0.2 Add Temporary Debug Flags (Optional but Recommended)

Add a global bool:

```dart
const bool kDebugFrontendFlow = true;
```

Use it to log navigation transitions only (no API payloads).

### ⬜ 0.3 Baseline Verification (MANDATORY)

Run the app and confirm:

* Login works
* Register works
* Profile setup works
* Gmail fetch works

✔ **Review Gate 0**
If anything is broken **already**, stop here and fix it before proceeding.

---

## PHASE 1 — DEFINE THE TRUE APP ENTRY (NO AUTH CHANGES YET)

### ⬜ 1.1 Create Entry Directory Structure

```
lib/
 └── screens/
     └── entry/
         └── intro_screen.dart
```

### ⬜ 1.2 Implement IntroScreen (Static, No Logic)

**Rules:**

* No services
* No auth
* No state
* No animations (yet)

**UI content only:**

* App name
* 1–2 sentence explanation
* Two buttons:

  * “Get Started”
  * “I already have an account”

### ⬜ 1.3 Route IntroScreen as App Start

In `main.dart`:

* Replace initial route from `AuthGate` → `IntroScreen`

⚠️ **Do NOT delete AuthGate**.

✔ **Review Gate 1**

* App opens to IntroScreen
* Buttons do nothing yet
* Backend untouched

---

## PHASE 2 — MOVE LOGIN / REGISTER BEHIND USER INTENT

### ⬜ 2.1 Create AuthFlowScreen

```
lib/screens/auth/auth_flow_screen.dart
```

This screen:

* Hosts `LoginRegisterCard`
* Accepts a parameter:

```dart
enum AuthMode { login, register }
```

### ⬜ 2.2 Update IntroScreen Navigation

* “Get Started” → `AuthFlowScreen(AuthMode.register)`
* “I already have an account” → `AuthFlowScreen(AuthMode.login)`

### ⬜ 2.3 Remove Direct LoginScreen Usage

* `LoginScreen` becomes an internal wrapper or is removed
* No other screen should directly navigate to login/register

✔ **Review Gate 2**

* You can still login & register
* No backend calls changed
* Login/Register behavior unchanged
* UI feels intentional

---

## PHASE 3 — MAKE ONBOARDING EXPLICIT (POST-AUTH)

### ⬜ 3.1 Create PostAuthIntroScreen

```
lib/screens/onboarding/post_auth_intro.dart
```

Content:

* “Welcome to Notify phere”
* “We’ll personalize your academic feed”
* Button: “Continue”

### ⬜ 3.2 Modify Auth Success Navigation

Change **only navigation**, not auth logic:

* After **login success**:

  * Navigate to `AuthGate` (same as before)
* After **register success**:

  * Navigate to `PostAuthIntroScreen`

### ⬜ 3.3 Ensure AuthGate Still Owns Routing

AuthGate still decides:

* Profile incomplete → ProfileSetup
* Profile complete → Home

✔ **Review Gate 3**

* Login path unchanged
* Register now shows a welcome screen before profile setup
* No infinite spinners introduced

---

## PHASE 4 — FIX PROFILE SETUP (CRITICAL STABILITY PHASE)

### ⬜ 4.1 Add Error Handling to ProfileSetupScreen

Wrap backend call in try–catch:

* Show inline error text
* Re-enable button on failure

### ⬜ 4.2 Remove Fake Delay

Remove:

```dart
Future.delayed(const Duration(seconds: 1))
```

### ⬜ 4.3 Fix Validation Semantics

* Roll number: allow alphanumeric
* Remove “Step 1 of 2” OR implement step 2 later

✔ **Review Gate 4**

* Backend failure is visible
* No silent hangs
* Profile creation still succeeds

---

## PHASE 5 — EXTRACT SHARED FORM LANGUAGE (UI CONSISTENCY)

### ⬜ 5.1 Create Shared Form Widgets

```
lib/widgets/form/
 ├── uni_text_field.dart
 ├── uni_password_field.dart
```

### ⬜ 5.2 Refactor ProfileSetup to Use Them

* Do not touch validation logic yet
* Only swap input widgets

### ⬜ 5.3 Keep Login/Register Visually Dominant

ProfileSetup should feel like:

> “Same app, different step”

✔ **Review Gate 5**

* No functional changes
* Visual mismatch resolved
* Backend untouched

---

## PHASE 6 — MOVE OAUTH INTO ONBOARDING (HIGH IMPACT)

### ⬜ 6.1 Create OAuthConnectScreen

```
lib/screens/onboarding/oauth_connect_screen.dart
```

Content:

* Why Gmail access is needed
* Privacy explanation
* Buttons:

  * “Connect Gmail”
  * “Skip for now”

### ⬜ 6.2 Modify AuthGate Logic

Routing becomes:

```
profile incomplete → ProfileSetup
profile complete & oauth not connected → OAuthConnect
profile complete & oauth connected → Home
```

### ⬜ 6.3 Remove OAuth CTA from ProfileScreen

ProfileScreen becomes **read-only + status**.

✔ **Review Gate 6**

* OAuth still launches browser
* Backend endpoints unchanged
* User flow is clearer

---

## PHASE 7 — FIX OAUTH COMPLETION (DEEP LINK PHASE)

### ⬜ 7.1 Implement Deep Link Handling

* Capture OAuth redirect
* Extract auth code
* Call `exchangeAuthCode`

### ⬜ 7.2 Add OAuthPendingScreen

Shown while waiting for:

* Redirect
* Token exchange
* Profile refresh

### ⬜ 7.3 Refresh Profile ONLY After Exchange

Remove immediate refresh on button tap.

✔ **Review Gate 7**

* OAuth completion is deterministic
* User sees progress
* No premature refresh

---

## PHASE 8 — STABILIZE AUTHGATE (NO MORE INFINITE SPINNERS)

### ⬜ 8.1 Add Timeout to Backend Profile Fetch

* 10–15 seconds max

### ⬜ 8.2 Add Error UI to AuthGate

Replace infinite spinner with:

* Error message
* Retry
* Logout

✔ **Review Gate 8**

* No infinite spinner possible
* Backend downtime is visible

---

## PHASE 9 — CENTRALIZE ERROR UX (QUALITY PASS)

### ⬜ 9.1 Create ErrorStateWidget

* Icon
* Friendly message
* Retry callback

### ⬜ 9.2 Replace Raw Exception Displays

Map:

* Network errors
* Auth errors
* OAuth errors

✔ **Review Gate 9**

* No raw stack traces shown
* Retry works everywhere

---

## PHASE 10 — FINAL FLOW VERIFICATION (MANDATORY)

### ⬜ Test Full Fresh User Journey

```
Intro
→ Register
→ Welcome
→ Profile
→ OAuth
→ Dashboard
→ Gmail Fetch
```

### ⬜ Test Returning User Journey

```
Intro
→ Login
→ Dashboard
```

### ⬜ Test Failure Scenarios

* Backend offline
* OAuth cancelled
* Invalid token

✔ **Review Gate 10**

* No dead ends
* No broken backend calls
* UX narrative is coherent

---

## FINAL TRUTH

If you follow this checklist **exactly in order**, you will get:

* Clean onboarding
* Clear mental model
* Zero backend regressions
* No wasted rewrites
* A frontend that *feels designed*, not assembled

This is not AI-generated UI fluff — this is **system design applied to UX**.

If you want, next I can:

* Turn this into a **Notion / Jira task list**
* Provide **directory diffs**
* Help you implement **Phase 1–2 code stubs**

Just tell me where you want to start executing.
