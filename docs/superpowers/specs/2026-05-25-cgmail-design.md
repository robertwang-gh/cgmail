# CGmail — macOS Gmail Client Design Spec

**Date:** 2026-05-25  
**Status:** Approved  
**Product:** CGmail — native macOS Gmail client

---

## 1. Overview

CGmail is a native macOS Gmail client built with SwiftUI. It supports multiple Gmail accounts, label-based navigation, and core email operations (read, compose, reply, forward, search, star, archive, delete). V1 targets core reading and writing experience, matching Gmail web UI closely.

**Key decisions:**
- Native SwiftUI + Swift 6 (Xcode 26)
- Gmail REST API with custom Swift wrapper (OAuth 2.0)
- Local SQLite cache via GRDB for fast startup and offline browsing
- Clean Architecture + MVVM

---

## 2. Architecture

### Layer Overview

```
┌─────────────────────────────────────────────────────┐
│  Presentation Layer (SwiftUI)                        │
│  MainWindowView, SidebarView, MailListView,          │
│  MailDetailView, ComposeView                         │
│  └── ViewModels (@Observable) hold Use Cases         │
├─────────────────────────────────────────────────────┤
│  Domain Layer (Use Cases + Models)                   │
│  FetchMailsUseCase, SendMailUseCase,                 │
│  SyncAccountUseCase, SearchMailsUseCase              │
│  └── Pure Swift, no framework dependencies           │
├─────────────────────────────────────────────────────┤
│  Data Layer (Repository implementations)             │
│  MailRepository  ←→  GmailAPIClient (REST)           │
│                  ←→  LocalDatabase (GRDB/SQLite)     │
│  AccountRepository ←→ Keychain (OAuth token storage) │
└─────────────────────────────────────────────────────┘
```

### Key Design Decisions

- `MailRepository` uses cache-first strategy: returns local data immediately, syncs API in background, pushes updates via `AsyncStream`
- Each Gmail account has an independent `AccountSession` (token + API client instance)
- All network calls isolated in Swift `actor` to prevent data races

---

## 3. Project Structure

```
CGmail/
├── App/
│   ├── CGmailApp.swift                  # @main, WindowGroup
│   └── AppDependencyContainer.swift     # Dependency injection root
│
├── Presentation/
│   ├── Main/
│   │   ├── MainWindowView.swift         # NavigationSplitView 3-pane root
│   │   └── MainViewModel.swift
│   ├── Sidebar/
│   │   ├── SidebarView.swift            # Account switcher + label list
│   │   └── SidebarViewModel.swift
│   ├── MailList/
│   │   ├── MailListView.swift           # Email list + search bar
│   │   └── MailListViewModel.swift
│   ├── MailDetail/
│   │   ├── MailDetailView.swift         # Email body reading
│   │   └── MailDetailViewModel.swift
│   └── Compose/
│       ├── ComposeView.swift            # Compose / reply / forward
│       └── ComposeViewModel.swift
│
├── Domain/
│   ├── Models/
│   │   ├── Mail.swift
│   │   ├── Label.swift
│   │   └── Account.swift
│   ├── UseCases/
│   │   ├── FetchMailsUseCase.swift
│   │   ├── SendMailUseCase.swift
│   │   ├── SyncAccountUseCase.swift
│   │   └── SearchMailsUseCase.swift
│   └── Repositories/                    # Protocols only
│       ├── MailRepositoryProtocol.swift
│       └── AccountRepositoryProtocol.swift
│
├── Data/
│   ├── Network/
│   │   ├── GmailAPIClient.swift         # URLSession actor
│   │   ├── GmailAuthService.swift       # OAuth 2.0 flow
│   │   └── DTOs/                        # API response decodable structs
│   ├── Database/
│   │   ├── LocalDatabase.swift          # GRDB setup
│   │   └── DatabaseMigrations.swift
│   └── Repositories/
│       ├── MailRepository.swift         # Cache-first implementation
│       └── AccountRepository.swift      # Keychain storage
│
└── CGmailTests/
    ├── UseCases/
    └── Repositories/
```

### External Dependencies (Swift Package Manager)

| Package | Purpose |
|---------|---------|
| `GRDB.swift` | SQLite ORM, Swift 6 compatible |
| `GoogleSignIn-iOS` | OAuth 2.0, supports macOS |

---

## 4. Data Models

### Domain Models

```swift
struct Mail: Identifiable, Hashable {
    let id: String              // Gmail message ID
    let threadId: String
    let accountId: String       // owning account
    let from: EmailAddress
    let to: [EmailAddress]
    let subject: String
    let snippet: String         // list preview text
    let body: String?           // loaded on demand
    let date: Date
    let labels: [String]        // ["INBOX", "UNREAD", "Label_xxx"]
    let isRead: Bool
    let isStarred: Bool
    var hasAttachment: Bool
}

struct Label: Identifiable {
    let id: String              // Gmail label ID
    let name: String
    let type: LabelType         // .system / .user
    let unreadCount: Int
    let color: LabelColor?
}

struct Account: Identifiable {
    let id: String              // Google user ID
    let email: String
    let displayName: String
    var accessToken: String     // Keychain only, never persisted to DB
    var tokenExpiry: Date
}
```

### Local Database Schema (SQLite via GRDB)

| Table | Contents |
|-------|---------|
| `mails` | Mail metadata (id, subject, snippet, date, labels, flags) |
| `mail_bodies` | Email body stored separately (lazy load, avoids reading large fields in list queries) |
| `labels` | Label list per account |
| `accounts` | Account info (no tokens — those are in Keychain) |
| `sync_state` | Per-account `historyId` for incremental sync |

---

## 5. UI Layout

**3-pane layout** (Gmail web standard):

```
┌──────────────┬───────────────────┬──────────────────────────┐
│   Sidebar    │   Email List      │   Email Reading Pane      │
│              │                   │                           │
│ [Account     │ 🔍 Search bar     │ Subject                   │
│  switcher]   │                   │ From · Date               │
│              │ ● GitHub  10:23am │                           │
│ ✏️ Compose   │   Your PR merged  │ Body content...           │
│              │   Congratulations │                           │
│ 📥 Inbox 24  │                   │ [Reply] [Forward]         │
│ ⭐ Starred   │ ○ Notion  9:15am  │                           │
│ 📤 Sent      │   Weekly digest   │                           │
│ 📝 Drafts    │                   │                           │
│ 🗑️ Trash     │ ○ Canva  Yesterday│                           │
│              │   Design review   │                           │
│ Labels       │                   │                           │
│ ● Work       │                   │                           │
│ ● Personal   │                   │                           │
└──────────────┴───────────────────┴──────────────────────────┘
```

- Sidebar: 200pt fixed width, collapsible
- Mail list: 280pt default width, resizable
- Reading pane: fills remaining width
- Built with `NavigationSplitView` (native macOS multi-column)

---

## 6. Authentication Flow

```
User clicks "Add Account"
    ↓
GmailAuthService opens system browser
(Google Sign-In, scope: gmail.modify)
    ↓
Google callback → obtain access_token + refresh_token
    ↓
refresh_token → Keychain (permanent)
access_token → memory cache (auto-refresh on expiry)
    ↓
AccountRepository saves account info
    ↓
Trigger initial full sync (latest 100 emails)
```

**OAuth scopes required:** `https://www.googleapis.com/auth/gmail.modify`

**Google Cloud Console setup (required before first run):**
1. Create project at console.cloud.google.com
2. Enable Gmail API
3. Create OAuth 2.0 credentials (Desktop app type)
4. Add bundle ID `com.cgmail.app` as authorized redirect URI
5. Download credentials and add Client ID to `Info.plist`

---

## 7. Cache & Sync Strategy

```
App launch / account switch
    ↓
1. Read SQLite immediately → render list (< 50ms)
    ↓
2. Background: call Gmail API users.history.list(startHistoryId)
    ↓
3. Parse incremental changes (add / delete / read status)
    ↓
4. Update SQLite → push via AsyncStream → ViewModel → UI refresh
    ↓
5. Save new historyId to sync_state table
```

- **First sync** (no historyId): full fetch of latest 100 emails + all labels
- **Foreground sync interval:** every 60 seconds
- **Background sync:** `BackgroundTasks` framework
- **Token expiry:** auto-refresh on failure, transparent retry once; after 3 consecutive failures prompt re-auth

---

## 8. Error Handling

```swift
enum CGmailError: Error {
    case networkUnavailable
    case authExpired
    case rateLimited(retryAfter: TimeInterval)
    case apiError(code: Int, message: String)
    case databaseError(underlying: Error)
}
```

| Error | Behavior |
|-------|---------|
| Network unavailable | Show banner, cached content remains browsable |
| Auth expired | Silent refresh; re-auth dialog after 3 failures |
| Send failure | Auto-save to Drafts, notify user to retry |
| Rate limited (429) | Exponential backoff, max 3 retries |

---

## 9. Testing Strategy

| Layer | Type | Coverage |
|-------|------|---------|
| Domain Use Cases | Unit tests | Business logic with mock Repositories |
| Repository | Integration tests | Cache-first logic with in-memory DB |
| GmailAPIClient | Unit tests | Request construction, response parsing, mock URLSession |
| ViewModels | Unit tests | State transitions with mock Use Cases |
| UI | Manual | Main flows: add account, read/send email |

- No automated UI tests (Xcode UI Testing has limited macOS support)
- Target: ≥ 70% line coverage on Domain + Data layers

---

## 10. V1 Feature Scope

**In scope:**
- Multiple Gmail account support with sidebar switching
- Inbox, Starred, Sent, Drafts, Trash system labels
- User-defined label display and filtering
- Email list with sender, subject, snippet, date, unread indicator
- Full email body reading (HTML rendered in WKWebView)
- Compose new email
- Reply / Reply all / Forward
- Search (via Gmail API search)
- Star / unstar
- Archive
- Delete (move to Trash)
- Local SQLite cache with incremental sync
- OAuth 2.0 authentication per account

**Out of scope for V1:**
- Thread conversation view (flat list only)
- Attachments (attachment indicator shown, but no download or preview)
- Calendar integration
- Keyboard shortcuts
- Notification badges
- Offline compose (compose requires network)
- Spam management
- Settings/preferences UI

---

## 11. GitHub & Development Workflow

- **Repository:** Create new public repo `cgmail` under user's GitHub account
- **Branches:** `main` (stable) and `develop` (active development)
- **Workflow:** Develop and test on `develop`, merge to both `develop` and `main` when tests pass
- **Initial commit:** Project scaffold + this spec
