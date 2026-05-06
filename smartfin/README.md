# SmartFin — Personal Finance Manager

SmartFin is a full-stack personal finance application built with **Flutter** (Android) and a **Node.js/Express** backend. It automatically reads bank SMS messages, parses them into structured transactions, detects bank accounts, tracks spending against a monthly budget, and syncs everything to MongoDB Atlas — all with ₹ (INR) formatting and Indian number grouping throughout.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Usage](#usage)
- [Features](#features)
- [API Endpoints](#api-endpoints)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

---

## Project Overview

SmartFin solves a common problem for Indian users: fragmented financial data. It combines:

- A **Flutter mobile app** that reads incoming and historical bank SMS messages, parses them into structured transactions, auto-detects bank accounts, and displays everything alongside manually added entries
- A **Node.js REST API** backed by MongoDB Atlas for authentication, transaction storage, account management, analytics, and budget settings
- **Email OTP verification** for secure account creation via Gmail
- **Fully local SMS processing** — no SMS content is ever sent to the server
- **Smart filtering** — promotional and telecom service messages are automatically skipped

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile frontend | Flutter 3.x (Dart 3.10+), Provider, sqflite |
| Backend API | Node.js, Express 5, MongoDB Atlas, Mongoose |
| Authentication | JWT (7-day expiry), bcryptjs, email OTP |
| SMS detection (real-time) | Android BroadcastReceiver + Flutter EventChannel (`another_telephony`) |
| SMS detection (historical) | `another_telephony` inbox query + cooldown guard |
| Local storage | sqflite (transactions), SharedPreferences (sync state, budget) |
| Permissions | `permission_handler` |
| Email | Nodemailer + Gmail App Password |

---

## Project Structure

```
smartfin/
├── backend/                    # Node.js/Express API
│   ├── index.js                # App entry, auth routes, budget routes
│   ├── middleware/
│   │   └── auth.js             # JWT middleware
│   ├── models/
│   │   ├── Account.js          # Account schema (userId, name, number, balance)
│   │   └── Transaction.js      # Transaction schema (userId, title, amount, type, category, date)
│   └── routes/
│       ├── accounts.js         # CRUD for accounts
│       ├── analytics.js        # Aggregated analytics
│       └── transactions.js     # CRUD for transactions
│
└── frontend/                   # Flutter app
    ├── android/
    │   └── app/src/main/kotlin/com/example/smartfin/
    │       ├── MainActivity.kt         # EventChannel setup
    │       ├── SmsReceiver.kt          # BroadcastReceiver for incoming SMS
    │       ├── SmsEventSink.kt         # Process-wide sink bridge
    │       └── SmsForegroundService.kt # Headless engine for background SMS
    ├── assets/
    │   └── telecom_keywords.txt        # Editable keyword list for telecom filtering
    └── lib/
        ├── main.dart                   # App entry, provider wiring, lifecycle observer
        ├── data/
        │   └── dummy_data.dart         # Static fallback content
        ├── models/
        │   ├── app_models.dart         # AccountModel, TransactionModel, AnalyticsData
        │   ├── bank_sms_record.dart    # SQLite storage model
        │   └── sms_transaction.dart    # Parsed SMS domain model
        ├── providers/
        │   ├── auth_provider.dart      # Login, signup, session restore
        │   └── finance_provider.dart   # Transactions, accounts, analytics, budget
        ├── screens/
        │   ├── analytics_screen.dart
        │   ├── dashboard_screen.dart
        │   ├── login_screen.dart
        │   ├── main_shell.dart
        │   ├── otp_verify_screen.dart
        │   ├── profile_screen.dart
        │   ├── signup_screen.dart
        │   ├── sms_sync_screen.dart    # SMS sync status + manual refresh
        │   ├── transaction_detail_screen.dart
        │   ├── transactions_screen.dart
        │   └── welcome_screen.dart
        └── services/
            ├── api_client.dart         # HTTP client with retry
            ├── auth_service.dart       # Auth API calls
            ├── finance_service.dart    # Transactions, accounts, analytics, budget API
            ├── sms_classifier.dart     # Promotional + telecom keyword + bank classification
            ├── sms_database.dart       # SQLite CRUD for parsed SMS transactions
            ├── sms_parser.dart         # Extracts amount, type, bank, account, counterparty
            ├── sms_pipeline.dart       # Real-time SMS → classify → parse → save
            ├── sms_service.dart        # EventChannel stream wrapper
            ├── sms_storage_helper.dart # SharedPreferences: lastSyncTime, processedIds
            ├── sms_sync_service.dart   # Historical inbox backfill with cooldown
            └── token_storage.dart      # Secure JWT storage
```

---

## Installation

### Prerequisites

- [Node.js](https://nodejs.org/) v18+
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x (Dart SDK ^3.10.4)
- [Android Studio](https://developer.android.com/studio) with an Android emulator or physical device (API 26+)
- A MongoDB Atlas account and cluster
- A Gmail account with [App Password](https://myaccount.google.com/apppasswords) enabled

---

### 1. Clone the repository

```bash
git clone https://github.com/your-username/smartfin.git
cd smartfin
```

### 2. Backend setup

```bash
cd backend
npm install
```

Create a `.env` file in the `backend/` directory:

```env
PORT=3000
MONGO_URI=mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/smartfin
JWT_SECRET=your_long_random_secret_here
EMAIL_USER=your_gmail@gmail.com
EMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx
```

Start the backend:

```bash
node index.js
```

You should see:
```
✅ Connected to MongoDB Atlas
✅ Gmail is ready to send emails
🚀 OTP Authentication Server Started on port 3000
```

### 3. Frontend setup

```bash
cd frontend
flutter pub get
```

Update the API base URL in `frontend/lib/services/api_client.dart`:

```dart
static String get baseUrl => 'http://10.0.2.2:3000'; // Android emulator
// or
static String get baseUrl => 'http://YOUR_LOCAL_IP:3000'; // Physical device
// or use ngrok for a public URL
```

Connect an Android device or start an emulator, then run:

```bash
flutter run
```

> **SMS permissions:** On first launch the app requests `READ_SMS` and `RECEIVE_SMS`. Grant both to enable automatic bank SMS detection and historical inbox sync.

---

## Usage

### Running the backend

```bash
cd backend
node index.js
```

### Running the Flutter app

```bash
cd frontend
flutter run          # debug mode
flutter run --release
flutter build apk    # build APK
```

### Cleaning build artifacts

```bash
cd frontend
flutter clean
flutter pub get
```

---

## Features

### Authentication
- **Email + password signup** with 6-digit OTP verification sent via Gmail
- **OTP expiry** — codes expire after 10 minutes; max 3 attempts before lockout
- **Resend OTP** — users can request a new code without restarting signup
- **JWT login** — tokens valid for 7 days, stored securely on-device via `flutter_secure_storage`
- **Session restore** — app restores the previous session on cold start without re-login

### Dashboard
- Net worth, total income, total expenses, and growth percentage
- Gradient account cards showing bank name, masked account number (`•••• 8045`), balance, and ACTIVE status
- Recent transactions list (last 4 entries)
- Skeleton loading UI while data loads
- Empty state for accounts with helpful message

### Transactions
- Full transaction list grouped by date section labels
- Merge of API transactions and local SMS transactions with deduplication
- Swipe-to-delete with confirmation dialog — removes from SQLite and adds tombstone to prevent re-sync
- Pull-to-refresh
- Tap any transaction to view the detail screen with SMS breakdown fields

### Analytics
- Total balance, net performance %, monthly usage ratio (circular progress)
- Spending breakdown by category with animated progress bars
- Week / Month / Year segmented control with date-range filtering
- Falls back to locally computed values when API is unavailable

### My Accounts
- Gradient cards per bank (HDFC navy, SBI blue, ICICI red, Axis purple, Kotak orange, default navy)
- Account number displayed as `•••• XXXX` regardless of stored format
- **Auto-detection from SMS** — when a new bank account number is parsed from an SMS, the account is automatically created in "My Accounts" if it doesn't already exist
- Duplicate prevention via last-4-digit suffix matching (no API call if already known)
- Empty state placeholder when no accounts exist yet

### Bank SMS Detection — Real-time
- Listens for `SMS_RECEIVED` broadcasts via a manifest-registered `SmsReceiver`
- A foreground service with a headless Flutter engine keeps the pipeline alive when the app is killed
- Single `classify()` call per message covers all filter gates

### Bank SMS Detection — Historical Inbox Sync
- Reads up to 100 most recent inbox messages on app open and resume
- 5-minute cooldown prevents redundant reads on rapid foreground/background cycles
- Incremental sync — only processes messages newer than `lastSyncTime`
- Processed-ID set persisted in SharedPreferences prevents duplicate inserts across restarts
- Manual refresh available from the SMS Sync screen (Profile → SMS Transaction Sync)

### SMS Filtering Pipeline

Every SMS passes through these gates in order before being parsed or stored:

| Gate | Filter | Action |
|---|---|---|
| 0 | Promotional sender (TRAI DLT `-P` suffix, e.g. `AD-60022-P`) | Drop |
| 1 | Telecom keyword match (`assets/telecom_keywords.txt`) | Drop |
| 1† | Financial safety guard (`debited`/`credited`/`UPI`/`INR X debited` in body) | Override — always pass |
| 2 | Bank/payment sender pattern (HDFC, SBIN, ICICI, PAYTM, etc.) | Pass |
| 3 | Body keyword scan (credited, debited, UPI, INR, txn, payment, etc.) | Pass |
| 4 | Transaction keyword check (sync service only) | Pass |
| 5 | Timestamp after `lastSyncTime` (sync service only) | Pass |
| 6 | Not in processed-ID set (sync service only) | Pass |

#### Telecom keyword file

Telecom filtering is driven by a plain-text keyword list at:

```
frontend/assets/telecom_keywords.txt
```

- One keyword per line, case-insensitive
- Lines starting with `#` are comments
- **No code changes needed** — edit the file to add or remove keywords
- Loaded once at app startup via `SmsClassifier.loadKeywords()`
- Covers 90+ keywords across: recharge, data pack/plan, validity, SIM service, low balance alerts, carrier offers, and carrier-specific phrases

Example entries:
```
recharge
data pack
validity expires
SIM activated
welcome to jio
low balance
plan expiring
```

### SMS Parsing
- **Amount** — matches `INR 5,000`, `Rs.500`, `₹200.00`
- **Transaction type** — credit / debit / OTP / unknown
- **Bank name** — inferred from sender ID (25+ banks mapped)
- **Account number** — 5-pattern extraction: label+mask, "ending", mask-only, debit/credit context
- **Counterparty** — UPI VPA, merchant name, or generic to/from pattern

### Monthly Budget
- Default budget: **₹10,000/month**
- User-specific — keyed by `userId` in SharedPreferences
- Synced to MongoDB (`monthlyBudget` field on User document)
- `budgetUsageRatio`, `budgetRemaining`, `isBudgetExceeded` computed getters in `FinanceProvider`
- Loads from backend on login; falls back to local cache when offline

### Privacy
- Non-bank messages dropped immediately after classification
- SMS body never logged in debug output
- Bank messages stored locally only — no SMS content sent to server
- Tombstone system prevents deleted transactions from being re-inserted by sync

---

## API Endpoints

All protected endpoints require:
```
Authorization: Bearer <jwt_token>
```

### Auth

| Method | Path | Description |
|---|---|---|
| `POST` | `/signup-init` | Start registration, send OTP email |
| `POST` | `/verify-signup` | Verify OTP, create account, return JWT |
| `POST` | `/resend-otp` | Regenerate and resend OTP |
| `POST` | `/login` | Authenticate, return JWT |
| `GET` | `/health` | Server, DB, and email status |

### Transactions 🔒

| Method | Path | Description |
|---|---|---|
| `GET` | `/transactions?page=1&limit=100` | List transactions (paginated, filterable) |
| `POST` | `/transactions` | Create transaction |
| `PUT` | `/transactions/:id` | Partial update |
| `DELETE` | `/transactions/:id` | Delete |

**Query filters:** `category`, `type` (`income`/`expense`), `from` (ISO date), `to` (ISO date)

### Accounts 🔒

| Method | Path | Description |
|---|---|---|
| `GET` | `/accounts` | List all accounts |
| `POST` | `/accounts` | Create account |
| `PUT` | `/accounts/:id` | Update account |
| `DELETE` | `/accounts/:id` | Delete account |

### Analytics 🔒

| Method | Path | Description |
|---|---|---|
| `GET` | `/analytics?from=&to=` | Aggregated analytics for date range |

**Response includes:** `totalBalance`, `netPerformance`, `monthlyUsageRatio`, `legendEntries`, `categories`, `summary`

### Budget 🔒

| Method | Path | Description |
|---|---|---|
| `GET` | `/budget` | Get user's monthly budget (default ₹10,000) |
| `PUT` | `/budget` | Update monthly budget |

**PUT body:** `{ "monthlyBudget": 15000 }`

---

## Architecture

### SMS Pipeline (real-time)

```
SmsReceiver.kt (BroadcastReceiver)
  → SmsEventSink (process-wide bridge)
    → SmsService (EventChannel stream)
      → SmsPipeline._process()
          → SmsClassifier.classify()   ← promotional / telecom / bank gates
          → SmsParser.parse()          ← amount, type, bank, account, counterparty
          → SmsDatabase.saveTransaction()  ← SQLite with ConflictAlgorithm.ignore
          → onTransaction callback     → FinanceProvider.prependSmsTransaction()
          → onAccountDetected callback → FinanceProvider.ensureAccountExists()
```

### SMS Sync (historical inbox)

```
AppLifecycleState.resumed / initState
  → SmsSyncService.autoSync()   ← 5-min cooldown guard
    → SmsSyncService.syncSms()
        → Permission.sms.request()
        → Telephony.getInboxSms()  ← up to 100 messages, newest first
        → [filter pipeline]
        → SmsParser.parse()
        → SmsDatabase.saveTransaction()
        → SmsStorageHelper.addProcessedIds()
        → SmsStorageHelper.setLastSyncTime()
        → onTransaction / onAccountDetected callbacks
```

### State Management

`FinanceProvider` (single `ChangeNotifier`) manages:
- `_accounts` — loaded from `GET /accounts`
- `_transactions` — merged from `GET /transactions` + `SmsDatabase.getAllTransactions()`
- `_analyticsData` — loaded from `GET /analytics`
- `_monthlyBudget` — loaded from `GET /budget`, cached in SharedPreferences

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make changes and commit: `git commit -m "feat: description"`
4. Push and open a Pull Request against `main`

### Code style
- **Dart:** `flutter_lints` rules in `analysis_options.yaml`
- **JavaScript:** JSDoc comments for new routes
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `refactor:`)

---

## License

ISC License — Copyright (c) 2026 SmartFin

---

## Contact

- **Email:** smartfin.26@gmail.com
- **GitHub Issues:** [github.com/your-username/smartfin/issues](https://github.com/your-username/smartfin/issues)

> Replace `your-username` with your actual GitHub username before publishing.
