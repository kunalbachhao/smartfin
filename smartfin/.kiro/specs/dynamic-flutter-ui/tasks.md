# Dynamic Flutter UI Bugfix Tasks

## Tasks

- [x] 1. Create model classes
  - [x] 1.1 Create `frontend/lib/models/app_models.dart` with all typed model classes: `AccountModel`, `TransactionModel`, `LegendEntry`, `SpendingCategory`, `DashboardData`, `AnalyticsData`, `WelcomeContent`, `OtpScreenContent`, `LoginContent`, `SocialProvider`, `SignupContent`
  - [x] 1.2 Verify the file compiles with no errors

- [x] 2. Create dummy data
  - [x] 2.1 Create `frontend/lib/data/dummy_data.dart` exporting a populated instance of each model using the exact values currently hardcoded in each screen
  - [x] 2.2 Verify the file compiles and all field values match the original hardcoded literals

- [x] 3. Refactor dashboard_screen.dart
  - [x] 3.1 Add `final DashboardData data` required constructor parameter to `DashboardScreen`
  - [x] 3.2 Replace hardcoded `"\$124,592.40"` and `"↗ 2.4%"` literals with `data.netWorth` and `data.growthPercent`
  - [x] 3.3 Replace inline `AccountCard(...)` constructors with list-driven rendering from `data.accounts`
  - [x] 3.4 Replace inline `TransactionTile(...)` constructors with list-driven rendering from `data.recentTransactions`
  - [x] 3.5 Verify screen compiles and renders identically when supplied with dummy data

- [x] 4. Refactor transactions_screen.dart
  - [x] 4.1 Add `final List<TransactionModel> transactions` required constructor parameter to `SmartFinScreen`
  - [x] 4.2 Replace all inline `SectionTitle` and `TransactionTile` constructors with list-driven rendering grouped by `sectionLabel`
  - [x] 4.3 Verify screen compiles and renders identically when supplied with dummy data

- [x] 5. Refactor analytics_screen.dart
  - [x] 5.1 Add `final AnalyticsData data` required constructor parameter to `AnalyticsScreen`
  - [x] 5.2 Replace hardcoded `"\$14,250.00"`, `"+12.4%"`, and `0.68` literals with model fields
  - [x] 5.3 Replace inline `_legend(...)` calls in `OverviewCard` with list-driven rendering from `data.legendEntries`
  - [x] 5.4 Replace inline `CategoryBar(...)` constructors in `SpendingCard` with list-driven rendering from `data.categories`
  - [x] 5.5 Verify screen compiles and renders identically when supplied with dummy data

- [x] 6. Refactor welcome_screen.dart
  - [x] 6.1 Add `final WelcomeContent content` required constructor parameter to `SmartFinScreen`
  - [x] 6.2 Replace hardcoded headline and subtitle string literals with `content.headline` and `content.subtitle`
  - [x] 6.3 Verify screen compiles and renders identically when supplied with dummy data

- [x] 7. Refactor otp_verify_screen.dart
  - [x] 7.1 Add `final OtpScreenContent content` required constructor parameter to `VerifyScreen`
  - [x] 7.2 Replace `"Code expires in 02:59"` and `"Join 40k+ verified investors"` literals with `content.expiryLabel` and `content.socialProof`
  - [x] 7.3 Verify screen compiles and renders identically when supplied with dummy data

- [x] 8. Refactor login_screen.dart
  - [x] 8.1 Add `final LoginContent content` required constructor parameter to `LoginScreen`
  - [x] 8.2 Replace `"Precision finance for the modern architect."` and `"name@atelier.com"` literals with `content.tagline` and `content.emailHint`
  - [x] 8.3 Verify screen compiles and renders identically when supplied with dummy data

- [x] 9. Refactor signup_screen.dart
  - [x] 9.1 Add `final SignupContent content` required constructor parameter to `SmartFinSignUp`
  - [x] 9.2 Replace `'John Doe'` and `'name@company.com'` hint literals with `content.namePlaceholder` and `content.emailPlaceholder`
  - [x] 9.3 Replace inline `_socialButton(label: 'Google', iconUrl: '...')` calls with list-driven rendering from `content.socialProviders`
  - [x] 9.4 Verify screen compiles and renders identically when supplied with dummy data

- [x] 10. Update main.dart call sites
  - [x] 10.1 Import `dummy_data.dart` in `main.dart`
  - [x] 10.2 Update every screen instantiation to pass the corresponding dummy data instance
  - [x] 10.3 Verify the full app compiles and runs without errors

- [x] 11. Write exploratory tests (bug condition checking)
  - [x] 11.1 Create `frontend/test/bugfix_exploration_test.dart`
  - [x] 11.2 Write a test that pumps `DashboardScreen` with a distinct `netWorth` value and asserts the widget tree reflects it (run on unfixed code to confirm failure, then on fixed code to confirm pass)
  - [x] 11.3 Write a test that pumps `SmartFinScreen` (transactions) with a 2-item list and asserts exactly 2 `TransactionTile` widgets are found
  - [x] 11.4 Write a test that pumps `AnalyticsScreen` with a distinct `totalBalance` and asserts it appears in the widget tree

- [x] 12. Write fix-checking tests
  - [x] 12.1 Create `frontend/test/bugfix_fix_test.dart`
  - [x] 12.2 For each of the 7 screens, write a widget test that pumps the screen with dummy data and asserts key display values appear in the widget tree
  - [x] 12.3 Assert that old hardcoded literals (e.g., `"\$124,592.40"`) do NOT appear when a different value is supplied

- [x] 13. Write preservation tests
  - [x] 13.1 Create `frontend/test/bugfix_preservation_test.dart`
  - [x] 13.2 Write a property-based test: generate random `List<TransactionModel>` (length 1–20) and verify `TransactionsScreen` renders exactly that many `TransactionTile` widgets
  - [x] 13.3 Write a property-based test: generate random `List<AccountModel>` (length 1–5) and verify `DashboardScreen` renders exactly that many `AccountCard` widgets
  - [x] 13.4 Write a property-based test: generate random `List<SpendingCategory>` and verify `SpendingCard` renders exactly that many `CategoryBar` widgets
  - [x] 13.5 Write a widget test asserting `VerifyScreen` always renders exactly 6 OTP input boxes regardless of `OtpScreenContent` values
  - [x] 13.6 Write a widget test asserting `_SmartFinSignUpState` password visibility toggle still functions after refactor
