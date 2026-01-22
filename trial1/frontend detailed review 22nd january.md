# Frontend Detailed Review - 22nd January 2026

## Overview
This document provides a comprehensive analysis of the Uni-Dash Flutter frontend application. It details all implemented pages, services, UI/UX implementations, error handling mechanisms, and identifies current issues and limitations.

---

## SERVICES LAYER

### 1. AppConfig Service ([config.dart](lib/config.dart))

**Purpose**: Global configuration management for dynamic backend URL selection

**Current State**: Minimal implementation
```dart
class AppConfig {
  static late String backendUrl;
  static void initialize(String url) {
    backendUrl = url;
  }
}
```

**Functionality**:
- Stores backend URL globally
- Initialized in main.dart based on device type
- Accessed by BackendService via getter

**Error Handling**: 
- None (static initialization, value already validated in main.dart)

**Issues/Limitations**:
- Very simple, only handles one configuration value
- Could be extended to handle other config like API timeouts, feature flags, etc.
- No validation on initialization

---

### 2. AuthService ([authentication_service.dart](lib/services/authentication_service.dart))

**Purpose**: Handle Firebase authentication operations for login/registration

**Current State**: Fully implemented for email/password auth; Google Sign-In partially commented out

**Implemented Operations**:

| Operation | Method | Returns | Status |
|-----------|--------|---------|--------|
| Login | `signInWithEmail(email, password)` | Future<User?> | ✅ Active |
| Register | `registerWithEmail(email, password)` | Future<User?> | ✅ Active |
| Sign Out | `signOut()` | Future<void> | ✅ Active |
| Auth Stream | `authStateChanges` | Stream<User?> | ✅ Active |
| Current User | `currentUser` | User? | ✅ Active |
| Google Sign-In | `signInWithGoogle()` | Future<UserCredential?> | ⏸️ Commented Out |

**Error Handling Details**:

The service uses Firebase error code mapping:
```dart
String _handleAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No user found with that email.';
    case 'wrong-password':
      return 'Incorrect password.';
    case 'invalid-email':
      return 'Invalid email format.';
    case 'email-already-in-use':
      return 'This email is already registered.';
    case 'weak-password':
      return 'Password is too weak.';
    default:
      return e.message ?? 'Authentication failed.';
  }
}
```

**Exception Flow**:
- Catches `FirebaseAuthException`
- Converts specific error codes to user-friendly messages
- Rethrows as generic Exception with formatted message
- Callers receive and display error message

**Limitations**:
- ❌ No rate limiting on login attempts
- ❌ No account lockout after failed attempts
- ❌ No session timeout handling
- ❌ Google Sign-In not implemented (code commented out)
- ❌ No two-factor authentication
- ⚠️ Sign out error caught but not propagated to UI (just logs to console)

---

### 3. BackendService ([services/api_services.dart](lib/services/api_services.dart))

**Purpose**: HTTP communication layer with Python backend

**Configuration**:
```dart
static String get baseUrl => AppConfig.backendUrl;  // Dynamic from AppConfig
static final String webClientId = dotenv.env['oauth2_client_id_web']!;
```

**Implemented Endpoints**:

#### Gmail Notifications
| Endpoint | Method | Purpose | Parameters | Response |
|----------|--------|---------|------------|----------|
| `/notifications/gmail/list-all` | GET | Fetch preview list | None | List<GmailNotification> |
| `/notifications/gmail/get-mail/{id}` | GET | Fetch full message | gmailId | GmailMessageDetail |

**Example Implementation**:
```dart
static Future<List<dynamic>> fetchGmailNotificationPreviews() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception("No Firebase user");
  final idToken = await user.getIdToken();
  final response = await http.get(
    Uri.parse("$baseUrl/notifications/gmail/list-all"),
    headers: {"Authorization": "Bearer $idToken"},
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['notifications'] as List<dynamic>;
  } else {
    throw Exception("Failed to fetch Gmail notification previews: ${response.body}");
  }
}
```

#### User Profile
| Endpoint | Method | Purpose | Parameters | Response |
|----------|--------|---------|------------|----------|
| `/user/profile` | GET | Fetch profile | None | UserProfile JSON |
| `/user/profile-setup` | POST | Create/update profile | {name, branch, semester, sid} | {status: success} |

**User Profile Fetch - Special Error Handling**:
```dart
static Future<Map<String, dynamic>> fetchUserProfile() async {
  // ... auth setup ...
  try {
    final response = await http.get(
      Uri.parse("$baseUrl/user/profile"),
      headers: {"Authorization": "Bearer $idToken"},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception("Unauthorized. Please log in again.");
    } else {
      throw Exception("Backend error: ${response.statusCode} ${response.body}");
    }
  } on TimeoutException {
    throw Exception("Request timed out.");
  }
}
```

#### OAuth Integration
| Endpoint | Method | Purpose | Parameters | Response |
|----------|--------|---------|------------|----------|
| `/auth/google/url` | GET | Get OAuth URL | None | {auth_url: string} |
| `/auth/google/exchange` | POST | Exchange code for token | {code: string} | {status: success} |

**OAuth Flow**:
```dart
// 1. Get authorization URL from backend
static Future<void> startGoogleOAuth() async {
  final response = await http.get(
    Uri.parse("$baseUrl/auth/google/url"),
    headers: {"Authorization": "Bearer $idToken"},
  );
  if (response.statusCode != 200) {
    throw Exception("Failed to get Google OAuth URL");
  }
  final data = jsonDecode(response.body);
  final authUrl = data["auth_url"];
  
  // 2. Launch in external browser
  final uri = Uri.parse(authUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception("Could not launch Google OAuth");
  }
}

// 3. Exchange auth code (called from deep link)
static Future<void> exchangeAuthCode(String code) async {
  final response = await http.post(
    Uri.parse("$baseUrl/auth/google/exchange"),
    headers: {
      "Authorization": "Bearer $idToken",
      "Content-Type": "application/json",
    },
    body: jsonEncode({"code": code}),
  );
  if (response.statusCode == 200) {
    debugPrint("Google OAuth connected successfully");
  } else {
    debugPrint("OAuth exchange failed: ${response.body}");
  }
}
```

**Authentication Method**:
- All requests include Firebase ID token in Authorization header: `"Bearer $idToken"`
- Backend validates token server-side

**Error Handling**:
- Status code checking (200, 401, other)
- Response body included in error message
- Timeout handling (10s) for profile fetch only
- OAuth exchange only logs to debug console (⚠️ not propagated to UI)

**Limitations/Issues**:
- ❌ No retry logic for failed requests
- ❌ No handling for network connectivity checks
- ❌ OAuth exchange doesn't show errors to user (only debug logs)
- ❌ Inconsistent timeout: only profile fetch has 10s timeout, others unlimited
- ❌ All errors thrown as generic Exception, not typed
- ❌ No request interceptors for token refresh
- ⚠️ No exponential backoff for retries
- ⚠️ No request queuing if app goes offline
- ⚠️ Hard-coded values (timeout duration) should be in AppConfig

---

## PAGE COMPONENTS

### 1. AuthGate (Route Guardian) ([services/authorisation_service.dart](lib/services/authorisation_service.dart))

**Purpose**: Smart routing based on authentication and profile state

**Visual State**: Not visible to user (behind-the-scenes router component)

**Current Implementation**:
```dart
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Step 1: Wait for Firebase state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Step 2: Check if user logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        
        // Step 3: Fetch backend profile
        return FutureBuilder(
          future: BackendService.fetchUserProfile(),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final profile = profileSnapshot.data!;
            final completed = profile["profile_completed"] ?? false;
            
            if (!completed) {
              return const ProfileSetupScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}
```

**Routing Decision Tree**:
```
┌─ Firebase Loading? → Show Spinner
├─ No Firebase user? → LoginScreen
├─ Backend Loading? → Show Spinner
├─ Profile incomplete? → ProfileSetupScreen
└─ Profile complete? → HomeScreen
```

**Error Handling**:
- ✅ Loading spinner while Firebase initializes
- ✅ Loading spinner while backend fetches profile
- ❌ **No error handling** if backend call fails
- ❌ **No timeout** on FutureBuilder
- ❌ **No 401 detection** - if token invalid, will hang forever

**UI/UX Issues**:
- ⚠️ Infinite spinner if backend is unreachable
- ⚠️ Infinite spinner if user's token expires
- ⚠️ No error screen to inform user of connection problems
- ⚠️ No retry mechanism if initial profile fetch fails

**Recommended Fixes**:
1. Add timeout to FutureBuilder
2. Handle backend errors and show error screen with retry button
3. Detect 401 errors and redirect to LoginScreen
4. Add connection timeout with user-friendly message

---

### 2. LoginScreen ([login_screen.dart](lib/screens/login_screen.dart))

**Purpose**: Entry point for unauthenticated users

**Current State**: Simple wrapper/container component

**Layout**:
```
┌─────────────────────────────────┐
│ AppBar: "Uni-Dash" (Hero anime) │
├─────────────────────────────────┤
│                                 │
│   [LoginRegisterCard Widget]    │
│   (All logic delegated here)    │
│                                 │
└─────────────────────────────────┘
```

**Components**:
- **AppBar**: 
  - Title: "Uni-Dash" with Hero animation
  - Logo adaptive to system theme (light/dark)
  - Background color matches theme
  
- **Body**: 
  - Centers LoginRegisterCard widget
  - Responsive padding

**Error Handling**: None (all delegated to LoginRegisterCard)

**UI/UX Features**:
- ✅ System brightness detection for logo selection
- ✅ Hero animation for smooth title transition
- ✅ Clean, minimal design
- ✅ Responsive layout

**Asset Usage**:
```dart
final logoPath = brightness == Brightness.dark
    ? "assets/university/dark_mode.png"
    : "assets/university/light_mode.png";
```

---

### 3. LoginRegisterCard Widget ([widgets/login_card.dart](lib/widgets/login_card.dart))

**Purpose**: Combined login and registration UI with progressive disclosure

**Current State**: Fully implemented with complex state management

**Screen Size**: Fixed width 340px, wrapping in animated size container

**Design**:
- Card background: #C8C8C8
- Border radius: 22px
- Shadow: soft with 0.15 opacity

**Dual Mode Implementation**:

#### LOGIN FLOW:
```
┌──────────────────────┐
│ "Welcome Back!"      │ (title)
├──────────────────────┤
│ [Login] [Register]   │ (tabs)
├──────────────────────┤
│ Email field          │
│ Password field       │
│ [Login Button]       │
│ (error text if any)  │
└──────────────────────┘
```

#### REGISTRATION FLOW (Progressive):
```
Step 1: Email only
┌──────────────────────┐
│ "Create an Account"  │
├──────────────────────┤
│ [Login] [Register]   │
├──────────────────────┤
│ Email field          │
│ [Register Button]    │ (disabled)
└──────────────────────┘

Step 2: Add Password (if email valid)
┌──────────────────────┐
│ "Set a secure pwd"   │
├──────────────────────┤
│ Email field          │
│ Password field       │
│ ✓ 8+ chars          │ (rules)
│ ✓ Uppercase         │
│ ✗ Number            │
│ ✗ Symbol            │
│ [Register Button]    │ (disabled)
└──────────────────────┘

Step 3: Confirm Password (if pwd valid & rules met)
┌──────────────────────┐
│ "Confirm Password"   │
├──────────────────────┤
│ Email field          │
│ Password field       │
│ Confirm field        │
│ [Register Button]    │ (enabled if match)
└──────────────────────┘
```

**State Management**:
```dart
// Mode control
bool isLogin = true;

// Form inputs
TextEditingController emailController;
TextEditingController passwordController;
TextEditingController confirmPasswordController;

// Registration progress
bool showPasswordField = false;
bool showConfirmField = false;
bool passwordValid = false;
bool confirmValid = false;

// Submission
bool _isLoading = false;
String? _errorTextMsg;

// Animation
late AnimationController titleController;
late Animation<double> titleFade;
String lastTitle = "";
```

**Field Validation**:

```dart
// Email validation (regex-based)
RegExp _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');

// Password rules
1. At least 8 characters: pass.length >= 8
2. One uppercase letter: pass.contains(RegExp(r'[A-Z]'))
3. One number: pass.contains(RegExp(r'[0-9]'))
4. One special symbol: pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))

// All must pass for valid password
bool validatePassword(String pass) {
  return pass.length >= 8 &&
      pass.contains(RegExp(r'[A-Z]')) &&
      pass.contains(RegExp(r'[0-9]')) &&
      pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
}
```

**Password Rules Display**:
```
✓ At least 8 characters (green when met)
✓ One uppercase letter
✗ One number (red when not met)
✗ One symbol
```

**UI/UX Features**:
- ✅ Animated title with fade transition on mode change
- ✅ Tab switching between Login/Register
- ✅ Progressive field disclosure in register mode
- ✅ Real-time validation feedback
- ✅ Password strength indicator with visual rules
- ✅ Loading spinner on submit button during auth
- ✅ Disabled submit button until valid
- ✅ Field validation icons (green check / red X)
- ✅ Custom styled input fields (dark background, rounded)
- ✅ Tab underline indicator (orange #E59A23)

**Event Listeners**:
```dart
emailController.addListener(() {
  // Show/hide password field if email valid/invalid
  // Disable password field when register tab
});

passwordController.addListener(() {
  // Track password validity
  // Show/hide confirm field
});

confirmPasswordController.addListener(() {
  // Track if password matches confirm
});
```

**Submission Logic**:

```dart
Future<void> _handleAuth() async {
  setState(() {
    _isLoading = true;
    _errorTextMsg = null;
  });
  
  final email = emailController.text.trim();
  final password = passwordController.text;
  
  try {
    if (isLogin) {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      // Validation
      if (!validateEmail(email)) {
        setState(() {
          _errorTextMsg = "Please enter a valid email.";
        });
        return;
      }
      if (password != confirmPasswordController.text) {
        setState(() {
          _errorTextMsg = "Passwords do not match.";
        });
        return;
      }
      
      // Register
      final user = await _authService.registerWithEmail(email, password);
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    }
  } catch (e) {
    setState(() {
      _errorTextMsg = e.toString().replaceFirst('Exception: ', '');
    });
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Error Handling**:
- ✅ Catches all exceptions from AuthService
- ✅ Strips "Exception: " prefix for display
- ✅ Shows error in red text below button
- ✅ Disables button during submission
- ❌ Error doesn't auto-dismiss
- ❌ Error persists until user modifies fields
- ❌ Password strength validated client-only (no server-side check)
- ⚠️ Email regex might reject some valid emails (e.g., with + sign)

**Limitations**:
- ⚠️ No rate limiting display for repeated failed attempts
- ⚠️ Confirms password match client-side, but backend doesn't re-validate
- ⚠️ No "Forgot Password" flow
- ⚠️ No email verification step
- ⚠️ No clear on-screen indication of why button is disabled

---

### 4. ProfileSetupScreen ([profile_setup_screen.dart](lib/screens/profile_setup_screen.dart))

**Purpose**: Collect student profile information after registration

**Current State**: Fully implemented form with validation

**Trigger**: Shows after successful registration (when `profile_completed == false`)

**Layout**:
```
┌──────────────────────────┐
│ AppBar: "Profile Setup"  │
├──────────────────────────┤
│ "Step 1 of 2"            │
│                          │
│ [Full Name]              │
│ [Branch/Program]         │
│ [Semester/Year]          │
│ [Roll Number]            │
│                          │
│ [Continue Button]        │
└──────────────────────────┘
```

**Form Fields**:

| Field | Type | Validation | Rules |
|-------|------|-----------|-------|
| Full Name | TextFormField | Required, String only | No numbers allowed |
| Branch/Program | TextFormField | Required, String only | No numbers allowed |
| Semester/Year | TextFormField | Required | Any non-empty value |
| Roll Number | TextFormField | Required, String only | No numbers allowed |

**Validation Logic**:
```dart
TextFormField(
  controller: nameController,
  decoration: const InputDecoration(
    labelText: 'Full Name',
    border: OutlineInputBorder(),
  ),
  validator: (v) {
    if (v == null || v.trim().isEmpty) 
      return 'Enter your name';
    if (int.tryParse(v.trim()) != null) 
      return 'Name must be a string';
    return null;
  },
)
```

**Form Validation**:
- Uses `GlobalKey<FormState>` for form validation
- All fields required
- String fields reject pure-number inputs
- Validation runs on submit, not real-time

**Submission Flow**:
```dart
if (_formKey.currentState?.validate() ?? false) {
  setState(() => _isLoading = true);
  
  await BackendService.createUserProfile(
    name: nameController.text,
    branch: branchController.text,
    semester: semesterController.text,
    sid: rollController.text,
  );
  
  await Future.delayed(const Duration(seconds: 1));
  
  if (mounted) {
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
```

**UI/UX Features**:
- ✅ "Step 1 of 2" indicator
- ✅ Centered, scrollable on small screens
- ✅ Consistent OutlineInputBorder styling
- ✅ Loading spinner on submit button
- ✅ Button disabled during submission
- ✅ Proper form validation before submission
- ✅ Clean layout with spacing

**Error Handling**:
- ✅ Form field validators
- ❌ **Critical Issue**: No try-catch for backend errors!
- ❌ If `createUserProfile()` fails, setState triggers but nothing displays
- ❌ No error message shown to user
- ❌ App state becomes inconsistent (button shows spinner but nothing happens)

**Issues/Limitations**:
- ❌ **No error display** if backend fails
- ⚠️ "Step 1 of 2" implies more steps but there are none
- ⚠️ No loading state description (what's happening during 1s delay?)
- ⚠️ Hard-coded 1s delay before navigation is artificial/confusing
- ⚠️ No back button to return to login
- ⚠️ Roll Number validation rejects pure numbers but what if it contains letters? (e.g., "24CE001")

**Recommended Fixes**:
```dart
// Should add try-catch
try {
  await BackendService.createUserProfile(...);
  // Success - navigate
} catch (e) {
  setState(() {
    _errorTextMsg = e.toString().replaceFirst('Exception: ', '');
    _isLoading = false;
  });
  // Don't navigate, show error
}
```

---

### 5. HomeScreen ([home_screen.dart](lib/screens/home_screen.dart))

**Purpose**: Main dashboard after full authentication

**Current State**: Minimal implementation, serves as entry point for main app

**Trigger**: Shows after login/registration when `profile_completed == true`

**Layout**:
```
┌──────────────────────────┐
│ AppBar: "Uni-Dash"       │
│ [Profile Icon Button]    │
├──────────────────────────┤
│                          │
│  If Loading:             │
│    [Spinner]             │
│                          │
│  If Error:               │
│    [Error text in red]   │
│                          │
│  If Success:             │
│    "Welcome to          │
│     Uni-Dash Home!"      │
│                          │
│    [Gmail Notifications] │ (if OAuth)
│                          │
└──────────────────────────┘
```

**State Management**:
```dart
class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BackendService.fetchUserProfile();
      setState(() {
        _profile = UserProfile.fromJson(data);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
}
```

**Features**:
- ✅ Fetches user profile on mount
- ✅ Profile button in AppBar navigates to ProfileScreen
- ✅ Refetches profile when returning from ProfileScreen
- ✅ Conditionally shows Gmail button only if `profile.oauthConnected == true`

**App Navigation**:
```dart
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ProfileScreen()),
  ).then((_) => _fetchProfile());  // Refresh after returning
}
```

**Conditional Gmail Widget**:
```dart
if (_profile != null && _profile!.oauthConnected)
  const GmailNotificationsButton(),
```

**Error Handling**:
- ✅ Catches backend exceptions
- ✅ Shows spinner during loading
- ✅ Shows error message in red
- ❌ Error shown as full exception string (not user-friendly)
- ❌ No retry button
- ❌ No timeout on profile fetch

**UI/UX Issues**:
- ⚠️ Very minimal dashboard (just welcome text)
- ⚠️ No other content or features visible
- ⚠️ Gmail button only shows if OAuth already connected

**Limitations**:
- ⚠️ No main dashboard content/features
- ⚠️ No notification badges or counters
- ⚠️ No quick actions or shortcuts
- ⚠️ Very sparse implementation

---

### 6. ProfileScreen ([profile_screen.dart](lib/screens/profile_screen.dart))

**Purpose**: Display user information and manage OAuth connection

**Current State**: Fully implemented read-only profile display with OAuth management

**Trigger**: Navigated to from HomeScreen via Profile button

**Layout**:
```
┌──────────────────────────┐
│ AppBar: "Profile"        │
├──────────────────────────┤
│ [👤 Avatar: First init]  │
│                          │
│ Name: John Doe           │
│ Email: john@uni.edu      │
│ Branch: CSE              │
│ Semester: 4              │
│ Roll Number: 23CE001     │
│                          │
│ Profile Completed: ✓     │
│                          │
│ [Connect Google Acct]    │ (if not connected)
│       OR                 │
│ ✓ Google Connected       │ (if connected)
│                          │
└──────────────────────────┘
```

**Avatar**:
```dart
CircleAvatar(
  radius: 38,
  child: Text(
    profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
  ),
)
```

**Profile Fields Display**:
```dart
Widget _profileField(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value.isNotEmpty ? value : '-'),
        ),
      ],
    ),
  );
}
```

**Data Loading**:
```dart
FutureBuilder<UserProfile>(
  future: _profileFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Failed to load profile:\n${snapshot.error}',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (!snapshot.hasData) {
      return const Center(child: Text('No profile data found.'));
    }
    final profile = snapshot.data!;
    // Build profile UI
  }
)
```

**OAuth Integration**:

When OAuth not connected:
```dart
if (!profile.oauthConnected)
  ElevatedButton(
    onPressed: () async {
      await BackendService.startGoogleOAuth();
      setState(() {
        _profileFuture = _fetchProfile();
      });
    },
    child: const Text('Connect Google Account'),
  ),
```

When OAuth connected:
```dart
if (profile.oauthConnected)
  Row(
    children: [
      const Icon(Icons.verified, color: Colors.blue),
      const SizedBox(width: 8),
      const Text('Google Account Connected', 
        style: TextStyle(fontWeight: FontWeight.w600)),
    ],
  ),
```

**Error Handling**:
- ✅ FutureBuilder handles loading, error, and no-data states
- ✅ Shows spinner while loading
- ✅ Shows error message on failure
- ❌ Error message shows full exception string
- ❌ No retry mechanism
- ❌ No timeout on profile fetch

**OAuth Flow Issues**:
- ⚠️ Calls `startGoogleOAuth()` which opens browser
- ⚠️ **Critical**: Immediately refreshes profile without waiting for OAuth completion
- ⚠️ OAuth happens in external browser, not in-app
- ⚠️ No loading indicator shown during OAuth flow
- ⚠️ Profile refresh happens immediately, should wait for deep link callback
- ⚠️ No error handling if OAuth launch fails
- ⚠️ User can't see if OAuth actually completed

**Expected OAuth Flow**:
```
1. User taps "Connect Google Account"
2. Backend generates OAuth URL
3. App opens Google OAuth in browser
4. User authorizes in browser
5. Google redirects to deep link (app_links)
6. App captures auth code
7. App sends code to backend (exchangeAuthCode)
8. Backend stores tokens
9. Profile refresh shows connected status
```

**Current Flow**:
```
1. User taps button
2. Opens browser (maybe)
3. Immediately refreshes profile (doesn't wait!)
4. Profile shows same status (not connected)
```

**Recommended Fix**:
Need to properly handle deep link callbacks and wait for OAuth completion before refreshing.

---

### 7. GmailNotifications Widget ([widgets/gmail_notifications_button.dart](lib/widgets/gmail_notifications_button.dart))

**Purpose**: Display and manage Gmail notifications

**Current State**: Fully implemented with list and detail views

**Trigger**: Shows on HomeScreen only if `profile.oauthConnected == true`

**Data Models**:

```dart
class GmailNotificationPreview {
  final int id;
  final String gmailId;
  final String sender;
  final String subject;
  final String snippet;
  final DateTime? internalDate;
  // ... fromJson factory
}

class GmailMessageDetail {
  final int id;
  final String gmailId;
  final String? threadId;
  final String sender;
  final String subject;
  final String bodyHtml;
  final String bodyText;
  final DateTime? internalDate;
  // ... fromJson factory
}
```

**UI Layout**:
```
┌──────────────────────────┐
│ [📧 Fetch Gmail Notif]   │ (button)
├──────────────────────────┤
│                          │
│ [Spinner]  (if loading)  │
│ [Error]    (if error)    │
│                          │
│ [Notification Cards]     │ (if loaded)
│ ├─ Subject               │
│ ├─ Sender                │
│ ├─ Snippet (2 lines)     │
│ └─ Time [HH:mm]          │
│                          │
│ ├─ Subject               │
│ ├─ Sender                │
│ ├─ Snippet               │
│ └─ Time [DD/MM/YYYY]     │
│                          │
│ ... (scrollable)         │
└──────────────────────────┘
```

**Fetch Button**:
```dart
ElevatedButton.icon(
  icon: const Icon(Icons.mail, size: 20),
  label: const Text('Fetch Gmail Notifications'),
  onPressed: _loading ? null : _fetchNotifications,
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFE59A23),  // Orange
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    elevation: 2,
  ),
)
```

**Notification List**:
```dart
ListView.separated(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  itemCount: _notifications!.length,
  separatorBuilder: (_, __) => const SizedBox(height: 10),
  itemBuilder: (context, index) {
    final n = _notifications![index];
    return Material(
      color: const Color(0xFFC8C8C8),  // Card background
      borderRadius: BorderRadius.circular(22),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showMailDetail(n.gmailId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.subject, 
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(n.sender,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(n.snippet,
                      style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (n.internalDate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text(_formatTime(n.internalDate!),
                    style: const TextStyle(
                      fontSize: 12, color: Colors.black54)),
                ),
            ],
          ),
        ),
      ),
    );
  },
)
```

**Detail Modal Dialog**:
```dart
void _showMailDetail(String gmailId) async {
  showDialog(
    context: context,
    builder: (context) {
      return FutureBuilder<Map<String, dynamic>>(
        future: BackendService.fetchGmailMessageDetail(gmailId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              backgroundColor: const Color(0xFFC8C8C8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
              content: const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError) {
            return AlertDialog(
              backgroundColor: const Color(0xFFC8C8C8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
              title: const Text('Error', style: TextStyle(color: Colors.red)),
              content: Text(snapshot.error.toString()),
            );
          }
          
          final mail = GmailMessageDetail.fromJson(snapshot.data!);
          return AlertDialog(
            backgroundColor: const Color(0xFFC8C8C8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
            title: Text(mail.subject,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From: ${mail.sender}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  if (mail.internalDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      child: Text(_formatTime(mail.internalDate!)),
                    ),
                  if (mail.bodyText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(mail.bodyText),
                    ),
                  if (mail.bodyHtml.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('[HTML body available]'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFE59A23),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('Close',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
```

**Time Formatting**:
```dart
String _formatTime(DateTime dt) {
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    // Today: HH:mm
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  } else {
    // Other days: DD/MM/YYYY
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}
```

**Error Handling**:

Fetch errors:
```dart
try {
  final rawList = await BackendService.fetchGmailNotificationPreviews();
  final notifications = rawList.map<GmailNotificationPreview>((n) {
    try {
      final notif = GmailNotificationPreview.fromJson(n as Map<String, dynamic>);
      debugPrint('[GMAIL DEBUG] Parsed notification: $notif');
      return notif;
    } catch (err) {
      debugPrint('[GMAIL DEBUG] Error parsing notification: $err, data: $n');
      rethrow;
    }
  }).toList();
  setState(() {
    _notifications = notifications;
  });
} catch (e, stack) {
  debugPrint('[GMAIL DEBUG] Error: $e');
  debugPrint(stack.toString());
  setState(() {
    _error = e.toString();
  });
}
```

- ✅ Catches parsing errors
- ✅ Shows error message to user
- ❌ Error shown as full exception string
- ❌ No retry button
- ⚠️ Debug logging left in production code

Detail errors:
```dart
if (snapshot.hasError) {
  debugPrint('[GMAIL DEBUG] Error fetching mail detail: ${snapshot.error}');
  return AlertDialog(
    // ... error dialog
  );
}
```

- ✅ Shows error in modal
- ❌ No retry mechanism in modal
- ⚠️ Still debug logging in production

**State Variables**:
```dart
bool _loading = false;
String? _error;
List<GmailNotificationPreview>? _notifications;
```

**UI/UX Features**:
- ✅ Button has mail icon
- ✅ Consistent styling with login card theme
- ✅ Scrollable notification list
- ✅ Notification cards with rounded corners
- ✅ Tap card → detail modal
- ✅ InkWell tap feedback
- ✅ Time formatting (today: HH:mm, other: DD/MM/YYYY)
- ✅ Loading spinner during fetch
- ✅ Modal loading spinner for detail
- ✅ Clean modal design

**Issues/Limitations**:
- ❌ Raw exception strings shown to users
- ❌ No retry button on error
- ❌ Debug logging in production code
- ❌ HTML body not rendered (just shows "[HTML body available]")
- ❌ No pagination/lazy loading for large lists
- ❌ No unread badge or notification count
- ❌ No refresh on returning to screen
- ⚠️ Android back button doesn't close modal (needs manual tap of Close)
- ⚠️ Tapping notification doesn't prevent multiple simultaneous fetches

---

## REUSABLE WIDGETS

### UsernameField ([Username_field.dart](lib/widgets/Username_field.dart))

**Purpose**: Custom email/username input field

**Props**:
```dart
required TextEditingController controller
required String hint
ValueChanged<String>? onChanged
bool? isValid (ternary: true=green, false=red, null=none)
```

**Features**:
- Dark background color: #3A3A3A
- White text color
- Validation icon indicator:
  - Green checkmark if isValid == true
  - Red X if isValid == false
  - No icon if isValid == null or field empty
- Rounded corners: 30px
- Focus border: white 2px
- Enabled border: none

**Example Usage**:
```dart
UsernameField(
  controller: emailController,
  hint: "Email",
  isValid: emailController.text.isEmpty
      ? null
      : validateEmail(emailController.text),
  onChanged: (value) => setState(() {}),
)
```

---

### PasswordField ([Password_field.dart](lib/widgets/Password_field.dart))

**Purpose**: Custom password input field with visibility toggle

**Props**:
```dart
required TextEditingController controller
required String hint
ValueChanged<String>? onChanged (optional)
```

**Features**:
- Text obscured by default
- Eye icon button to toggle visibility
- Same dark styling as UsernameField (#3A3A3A)
- White text
- Rounded corners: 30px
- Icon color: white70

**Example Usage**:
```dart
PasswordField(
  controller: passwordController,
  hint: "Password",
  onChanged: (value) => validatePassword(value),
)
```

---

## DATA MODELS

### UserProfile ([UserProfile.dart](lib/models/UserProfile.dart))

**Purpose**: Type-safe user data representation

**Fields**:
```dart
final String uid;
final String email;
final String name;
final String branch;
final int semester;
final String sid;
final bool profileCompleted;
final bool oauthConnected;
```

**Serialization**:
```dart
factory UserProfile.fromJson(Map<String, dynamic> json) {
  int parseSemester(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  return UserProfile(
    uid: json['uid'] as String? ?? '',
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
    branch: json['branch'] as String? ?? '',
    semester: parseSemester(json['semester']),
    sid: json['sid'] as String? ?? '',
    profileCompleted: json['profile_completed'] == true || 
                      json['profile_completed'] == 1,
    oauthConnected: json['oauth_connected'] == true || 
                    json['oauth_connected'] == 1,
  );
}

Map<String, dynamic> toJson() {
  return {
    'uid': uid,
    'email': email,
    'name': name,
    'branch': branch,
    'semester': semester,
    'sid': sid,
    'profile_completed': profileCompleted,
    'oauth_connected': oauthConnected,
  };
}
```

**Features**:
- ✅ Defensive parsing with type handling
- ✅ Default values for missing fields
- ✅ Handles both boolean true/false and numeric 1/0 from backend
- ✅ Semester conversion string → int

---

## ERROR HANDLING SUMMARY

### By Component

| Component | Loading UI | Error Display | Recovery | Issues |
|-----------|-----------|----------------|----------|--------|
| **AuthGate** | ✅ Spinner | ❌ None | ❌ Hangs | No timeout, no 401 detection |
| **AuthService** | N/A | ✅ Error codes mapped | N/A | No rate limiting |
| **BackendService** | N/A | ✅ Exceptions thrown | N/A | No retries, inconsistent timeouts |
| **LoginCard** | ✅ Spinner | ✅ Red text | ✅ User can retry | Error doesn't dismiss |
| **ProfileSetupScreen** | ✅ Spinner | ❌ None | ❌ Manual reload | Critical: backend errors not shown |
| **HomeScreen** | ✅ Spinner | ✅ Red text | ❌ No retry | Shows full exception |
| **ProfileScreen** | ✅ Spinner | ✅ Modal text | ❌ No retry | Shows full exception |
| **Gmail List** | ✅ Spinner | ✅ Red text | ✅ Retry button | Exception strings, debug logs |
| **Gmail Detail** | ✅ Spinner | ✅ Modal | ❌ No retry | Exception strings |

### Error Message Quality

**Current**: All services throw generic Exceptions with messages
```dart
throw Exception("Failed to fetch Gmail notification previews: ${response.body}");
```

**Issues**:
- Full exception object printed with "Exception: " prefix
- Response bodies included (may be HTML error pages, not JSON)
- No user-friendly categorization

**Example Bad Messages**:
- "Exception: Failed to fetch Gmail notification previews: <html>...</html>"
- "Exception: Backend error: 500 Internal Server Error"
- "Exception: Request timed out."

---

## CONFIGURATION

### Environment Variables ([.env](../trial1/.env))

```
oauth2_client_id_web=551724754459-jfr5qel37k6b1pemdg6hgme5upjeljr6
ANDROID_GOOGLE_CLIENT_ID=551724754459-qa0mnvf692mj8s9gkmu6n7otjfslbtuo
BACKEND_URL=http://192.168.31.4:8000
```

**Currently Missing**:
- `EMULATOR_BACKEND_URL` - Needed for Android emulator testing

**Recommended Addition**:
```
EMULATOR_BACKEND_URL=http://10.0.2.2:8000
```

### Firebase Configuration ([firebase_options.dart](lib/firebase_options.dart))

**Currently Configured**: Android only
**Missing**: iOS, Web configurations

**Android Credentials**:
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyBvGs5AAZ-MkuJzzwKT-WJLZlQ3tx6pkE8',
  appId: '1:551724754459:android:a786e54635a8e8695d7abe',
  messagingSenderId: '551724754459',
  projectId: 'f-r-i-d-a-y-vlelfh',
  databaseURL: 'https://f-r-i-d-a-y-vlelfh.firebaseio.com',
  storageBucket: 'f-r-i-d-a-y-vlelfh.firebasestorage.app',
);
```

---

## THEME SYSTEM

### Light Theme

```dart
final ThemeData uniDashLightTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
  ),
);
```

### Dark Theme

```dart
final ThemeData uniDashDarkTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
  ),
);
```

**Theme Mode**: System (follows device settings)

---

## KEY ISSUES & RECOMMENDATIONS

### CRITICAL ISSUES

1. **ProfileSetupScreen Silent Failure**
   - Backend errors not displayed to user
   - **Fix**: Wrap createUserProfile in try-catch, show error message

2. **AuthGate Infinite Spinner**
   - No timeout or error state if backend unreachable
   - **Fix**: Add timeout to FutureBuilder, handle errors with retry screen

3. **OAuth Completion Not Detected**
   - Profile refreshes immediately without waiting for OAuth
   - **Fix**: Implement deep link handling, wait for OAuth completion

### HIGH PRIORITY

4. **User-Unfriendly Error Messages**
   - All errors show full exception strings
   - **Fix**: Create error categorization, map to user-friendly messages

5. **No Retry Mechanisms**
   - Users stuck if any operation fails
   - **Fix**: Add retry buttons on error screens

6. **Debug Logs in Production**
   - Gmail component has debug logging
   - **Fix**: Remove or guard with debug-only flag

### MEDIUM PRIORITY

7. **Inconsistent Error Handling**
   - Some screens show errors, some don't
   - **Fix**: Standardize error display across app

8. **No Network Resilience**
   - No retry logic, no offline handling
   - **Fix**: Add exponential backoff retry, offline queue

9. **No Rate Limiting Feedback**
   - No indication if account locked after failed attempts
   - **Fix**: Show rate limit warnings

### LOW PRIORITY

10. **HTML Body Not Rendered**
    - Gmail detail shows "[HTML body available]" but doesn't render
    - **Fix**: Use html rendering package or parse HTML

11. **Modal Back Button**
    - Android back button doesn't close Gmail detail modal
    - **Fix**: Use WillPopScope or handle back button

12. **"Step 1 of 2" Confusion**
    - ProfileSetupScreen shows Step 1 of 2 but only 1 step exists
    - **Fix**: Remove "of 2" or implement step 2

---

## ARCHITECTURE OBSERVATIONS

### Strengths

✅ Clean separation of concerns (Services, Screens, Widgets, Models)
✅ Proper use of StreamBuilder for auth state
✅ FutureBuilder pattern for data loading
✅ Reusable custom widgets
✅ Theme system with light/dark support
✅ Type-safe data models with JSON serialization
✅ Firebase authentication integration
✅ Progressive disclosure in registration

### Weaknesses

❌ No centralized error handling
❌ No typed exceptions (all generic Exception)
❌ No request interceptors for auth/retry
❌ Limited state management (only setState)
❌ No architecture pattern (could use Provider, Riverpod, BLoC)
❌ No logging framework
❌ Mixed concerns (UI logic in widgets)
❌ No dependency injection

### Recommended Improvements

1. **Create Error Hierarchy**
   ```dart
   abstract class AppException implements Exception {
     final String message;
     AppException(this.message);
   }
   
   class NetworkException extends AppException {}
   class AuthException extends AppException {}
   class ValidationException extends AppException {}
   ```

2. **Implement State Management**
   - Consider Provider or Riverpod for shared state
   - Currently only using setState

3. **Add Request Interceptor**
   - Centralize auth header addition
   - Handle token refresh
   - Implement retry logic

4. **Create Error Handler Service**
   - Map exceptions to user messages
   - Log errors consistently
   - Track error metrics

5. **Add Logging**
   - Use logger package
   - Log all API calls and responses
   - Track user actions for analytics

---

## CONCLUSION

The frontend application is **functional but has several critical issues**:

1. **Silent failures** on profile setup could leave users stuck
2. **Infinite spinners** if backend is unreachable
3. **OAuth integration incomplete** - doesn't wait for actual completion
4. **Error messages** are technical, not user-friendly
5. **No retry mechanisms** for failed operations

**Priority actions**:
1. Fix ProfileSetupScreen error handling (critical)
2. Add timeout + error state to AuthGate (critical)
3. Implement proper OAuth flow with deep link handling (high)
4. Create user-friendly error messages (high)
5. Add error recovery/retry options (high)

The app would benefit from a more structured architecture and centralized error handling to improve reliability and user experience.
