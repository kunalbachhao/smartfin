# SmartFin — Personal Finance Manager

SmartFin is a full-stack personal finance application built with **Flutter** (Android) and a **Node.js/Express** backend. It helps users track bank transactions, view spending analytics, and automatically detect bank SMS messages — all with INR (₹) formatting and Indian number grouping throughout.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Tech Stack](#tech-stack)
- [Installation](#installation)
- [Usage](#usage)
- [Features](#features)
- [API Endpoints](#api-endpoints)
- [Screenshots](#screenshots)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

---

## Project Overview

SmartFin solves a common problem for Indian users: fragmented financial data. It combines:

- A **Flutter mobile app** that reads incoming bank SMS messages, parses them into structured transactions, and displays them alongside manually added entries
- A **Node.js REST API** backed by MongoDB Atlas that handles authentication, transaction storage, account management, and analytics
- **Email OTP verification** for secure account creation via Gmail
- **Fully local SMS processing** — no SMS content is ever sent to the server

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile frontend | Flutter 3.x (Dart), Provider, sqflite |
| Backend API | Node.js, Express 5, MongoDB Atlas, Mongoose |
| Authentication | JWT (7-day expiry), bcryptjs, email OTP |
| SMS detection | Android BroadcastReceiver + Flutter EventChannel |
| Email | Nodemailer + Gmail App Password |

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
MONGO_URI=mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/
JWT_SECRET=your_long_random_secret_here
EMAIL_USER=your_gmail@gmail.com
EMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx
```

> **Getting a Gmail App Password:**
> 1. Go to [Google Account Security](https://myaccount.google.com/security)
> 2. Enable 2-Step Verification
> 3. Go to [App Passwords](https://myaccount.google.com/apppasswords)
> 4. Generate a password for "Mail" and paste it as `EMAIL_APP_PASSWORD`

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

Update the API base URL in `frontend/lib/services/api_client.dart` to point to your backend:

```dart
static const String _baseUrl = 'http://10.0.2.2:3000'; // Android emulator
// or
static const String _baseUrl = 'http://YOUR_LOCAL_IP:3000'; // Physical device
```

Connect an Android device or start an emulator, then run:

```bash
flutter run
```

> **SMS permissions:** On first launch the app will request `RECEIVE_SMS` permission. Grant it to enable automatic bank SMS detection.

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
flutter run                    # debug mode
flutter run --release          # release mode
flutter build apk              # build APK
```

### Running backend tests

```bash
cd backend
npm test
```

### Running Flutter tests

```bash
cd frontend
flutter test                                    # all tests
flutter test test/sms_classifier_test.dart      # SMS classifier only
flutter test test/sms_parser_test.dart          # SMS parser only
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
- Net worth, total income, total expenses, and growth percentage at a glance
- Recent transactions list (last 4 entries)
- Quick navigation to the full transactions screen

### Transactions
- Full paginated transaction list grouped by date
- Add new transactions (title, amount, type, category, date)
- Swipe-to-delete with confirmation dialog
- Pull-to-refresh syncs with the backend
- Tap any transaction to view the detail screen

### Analytics
- Total balance, net performance percentage, monthly usage ratio
- Spending breakdown by category with progress bars
- Legend entries for fixed costs vs lifestyle spending
- Date-range filtering (`from` / `to` query params)

### Accounts
- View all linked bank accounts with balance in ₹ (Indian grouping)
- Create new accounts

### Bank SMS Detection (Android)
- **Automatic detection** — listens for `SMS_RECEIVED` broadcasts via a manifest-registered `BroadcastReceiver`
- **Background reliability** — a foreground service with a headless Flutter engine keeps the pipeline alive when the app is killed
- **Classification** — sender ID patterns (HDFCBK, SBIINB, AXISBK, PAYTM, etc.) and body keywords (credited, debited, UPI, INR, txn, A/c) identify bank messages
- **Parsing** — extracts amount, credit/debit type, bank name, masked account number, counterparty (UPI ID or merchant), and timestamp
- **Local storage** — parsed transactions saved to on-device SQLite (`sqflite`); no SMS content is sent to the server
- **Live UI update** — new SMS transactions appear at the top of the transactions list instantly, without a network round-trip
- **Privacy** — non-bank messages are dropped immediately; SMS body is never logged

### Currency Formatting
- All amounts displayed in ₹ with correct Indian number grouping (e.g. ₹10,00,000.00)
- Consistent formatting across backend API responses and Flutter UI

---

## API Endpoints

All protected endpoints require the header:
```
Authorization: Bearer <jwt_token>
```

### Auth

#### `POST /signup-init`
Start registration — validates credentials and sends an OTP email.

**Request:**
```json
{ "email": "user@example.com", "password": "secret123" }
```
**Response `200`:**
```json
{ "success": true, "message": "Verification code sent to your email", "email": "user@example.com" }
```

---

#### `POST /verify-signup`
Complete registration by verifying the OTP.

**Request:**
```json
{ "email": "user@example.com", "code": "482910" }
```
**Response `201`:**
```json
{
  "success": true,
  "token": "<jwt>",
  "user": { "id": "...", "email": "user@example.com" }
}
```

---

#### `POST /resend-otp`
Regenerate and resend the OTP for a pending signup.

**Request:**
```json
{ "email": "user@example.com" }
```

---

#### `POST /login`
Authenticate an existing user.

**Request:**
```json
{ "email": "user@example.com", "password": "secret123" }
```
**Response `200`:**
```json
{
  "success": true,
  "token": "<jwt>",
  "user": { "id": "...", "email": "user@example.com" }
}
```

---

### Transactions 🔒

#### `GET /transactions?page=1&limit=100`
List all transactions for the authenticated user.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "title": "Groceries",
      "subtitle": "Swiggy Instamart",
      "amount": "-₹850.00",
      "amountValue": 850,
      "isIncome": false,
      "type": "expense",
      "category": "Food",
      "sectionLabel": "11 Apr 2026",
      "color": "red"
    }
  ]
}
```

#### `POST /transactions`
Create a new transaction.

**Request:**
```json
{
  "title": "Salary",
  "amount": 85000,
  "type": "income",
  "category": "Salary",
  "date": "2026-04-01T00:00:00.000Z"
}
```

#### `PUT /transactions/:id`
Update a transaction (partial update supported).

#### `DELETE /transactions/:id`
Delete a transaction by ID.

---

### Accounts 🔒

#### `GET /accounts`
List all accounts.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "...",
      "title": "HDFC Savings",
      "number": "XXXX1234",
      "balance": "₹9,45,200.00",
      "balanceValue": 945200
    }
  ]
}
```

#### `POST /accounts`
Create a new account.

**Request:**
```json
{ "name": "HDFC Savings", "number": "XXXX1234", "balance": 945200 }
```

---

### Analytics 🔒

#### `GET /analytics?from=2026-04-01&to=2026-04-30`
Computed financial analytics for the authenticated user.

**Response:**
```json
{
  "success": true,
  "data": {
    "totalBalance": "₹85,000.00",
    "netPerformance": "+62.4%",
    "monthlyUsageRatio": 0.376,
    "legendEntries": [
      { "title": "Fixed Costs", "amount": "₹32,000.00", "color": "blue" },
      { "title": "Lifestyle",   "amount": "₹85,000.00", "color": "teal" }
    ],
    "categories": [
      { "title": "Food", "amount": "₹12,500.00", "progress": 1.0, "color": "blue" }
    ],
    "summary": {
      "totalIncome": 85000,
      "totalExpenses": 32000,
      "netBalance": 53000,
      "transactionCount": 14
    }
  }
}
```

---

### Health

#### `GET /health`
Check server, database, and email service status.

```json
{
  "status": "OK",
  "services": { "mongodb": "connected", "email": "configured", "server": "running" }
}
```

---

## Screenshots

> Add screenshots here to showcase the app UI.

| Dashboard | Transactions | Analytics |
|---|---|---|
| ![Dashboard](screenshots/dashboard.png) | ![Transactions](screenshots/transactions.png) | ![Analytics](screenshots/analytics.png) |

| Login | OTP Verification | Transaction Detail |
|---|---|---|
| ![Login](screenshots/login.png) | ![OTP](screenshots/otp.png) | ![Detail](screenshots/detail.png) |

---

## Contributing

Contributions are welcome. Please follow these steps:

1. Fork the repository
2. Create a feature branch
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes and add tests where applicable
4. Ensure all tests pass
   ```bash
   # Backend
   cd backend && npm test
   # Flutter
   cd frontend && flutter test
   ```
5. Commit with a clear message
   ```bash
   git commit -m "feat: add spending category filter"
   ```
6. Push and open a Pull Request against `main`

### Code style
- **Dart:** follow the rules in `frontend/analysis_options.yaml` (`flutter_lints`)
- **JavaScript:** keep functions small and add JSDoc comments for new routes
- **Commits:** use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `refactor:`)

### Reporting issues
Open a GitHub Issue with:
- Steps to reproduce
- Expected vs actual behaviour
- Device/OS version and Flutter/Node version

---

## License

This project is licensed under the **ISC License**.

```
ISC License

Copyright (c) 2026 SmartFin

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

---

## Contact

For questions, bug reports, or feature requests:

- **Email:** smartfin.26@gmail.com
- **GitHub Issues:** [github.com/your-username/smartfin/issues](https://github.com/your-username/smartfin/issues)

> Replace `your-username` with your actual GitHub username before publishing.
