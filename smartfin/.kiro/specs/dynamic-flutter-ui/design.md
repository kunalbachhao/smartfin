# Dynamic Flutter UI Bugfix Design

## Overview

All 7 SmartFin screens currently embed display data as string/numeric literals directly inside widget constructors. This prevents the UI from being driven by any data source and makes the screens untestable in isolation. The fix introduces typed Dart model classes and a centralized `dummy_data.dart` file. Each screen is refactored to accept its model as a constructor parameter and render values from that model. The dummy data file supplies the same values that are currently hardcoded, so the visual output remains pixel-identical.

## Glossary

- **Bug_Condition (C)**: A screen widget that reads display data from hardcoded string/numeric literals embedded in its widget tree rather than from a typed model parameter
- **Property (P)**: The desired behavior — a screen widget that reads all display data from a typed model passed as a constructor parameter, with no hardcoded display strings or numbers in the widget tree
- **Preservation**: All layout, spacing, colors, fonts, icons, interaction behaviors, and widget structure that must remain visually and functionally identical after the refactor
- **dummy_data.dart**: The single file at `frontend/lib/data/dummy_data.dart` that exports pre-populated instances of every model, supplying the same values currently hardcoded in each screen
- **DashboardData**: Model carrying `netWorth`, `growthPercent`, `accounts` (List\<AccountModel\>), `recentTransactions` (List\<TransactionModel\>)
- **TransactionModel**: Model carrying `title`, `subtitle`, `amount`, `isIncome`, `icon`, `color`, `sectionLabel`
- **AnalyticsData**: Model carrying `totalBalance`, `netPerformance`, `monthlyUsageRatio`, `legendEntries` (List\<LegendEntry\>), `categories` (List\<SpendingCategory\>)
- **WelcomeContent**: Model carrying `headline` and `subtitle` strings
- **OtpScreenContent**: Model carrying `expiryLabel` and `socialProof` strings
- **LoginContent**: Model carrying `tagline` and `emailHint` strings
- **SignupContent**: Model carrying `namePlaceholder`, `emailPlaceholder`, and `socialProviders` (List\<SocialProvider\>)

## Bug Details

### Bug Condition

The bug manifests when any of the 7 screen widgets render display data that is hardcoded as string or numeric literals inside the widget tree. The widget has no constructor parameter for its data, so it is impossible to supply different values without editing the widget source.

**Formal Specification:**
```
FUNCTION isBugCondition(screen)
  INPUT: screen — a Flutter widget class
  OUTPUT: boolean

  RETURN screen.constructorParameters DOES NOT CONTAIN a typed data model
         AND screen.widgetTree CONTAINS one or more hardcoded display strings
             OR hardcoded numeric display values
END FUNCTION
```

### Examples

- `DashboardScreen` renders `"\$124,592.40"` and `"↗ 2.4%"` as `const Text` literals — **bug condition holds**; expected: values read from `DashboardData.netWorth` and `DashboardData.growthPercent`
- `TransactionsScreen` constructs `TransactionTile(title: "Whole Foods Market", ...)` inline — **bug condition holds**; expected: tiles built by iterating `List<TransactionModel>` from `dummy_data.dart`
- `AnalyticsScreen` passes `value: 0.68` and `"Net performance: +12.4%"` as literals — **bug condition holds**; expected: values from `AnalyticsData.monthlyUsageRatio` and `AnalyticsData.netPerformance`
- `WelcomeScreen` has `'Smart finance for\nyour future.'` as a `TextSpan` literal — **bug condition holds**; expected: value from `WelcomeContent.headline`
- `OtpVerifyScreen` has `"Code expires in 02:59"` and `"Join 40k+ verified investors"` as `const Text` literals — **bug condition holds**; expected: values from `OtpScreenContent`
- `LoginScreen` has `"Precision finance for the modern architect."` as a `const Text` literal — **bug condition holds**; expected: value from `LoginContent.tagline`
- `SignupScreen` has `'John Doe'` and `'name@company.com'` as hint strings and hardcoded SVG URLs — **bug condition holds**; expected: values from `SignupContent`

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Dashboard account cards render in a horizontally scrollable row with the same card dimensions, typography, and white card decoration
- Transaction tiles group under section headers (`TODAY`, `YESTERDAY`, `JULY 2024`) with the same icon badge, color, title, subtitle, and amount styling
- Analytics overview card shows the circular progress indicator and legend rows with the same visual proportions and colors
- Analytics spending card shows labeled linear progress bars per category with the same bar height (8px), border radius (10), and color scheme
- OTP verify screen shows six individual input boxes with the same focus-advance behavior, numeric keyboard type, and layout
- Signup screen shows the terms checkbox, password visibility toggles, and social sign-in buttons with the same interaction behavior
- All screens compile without errors; existing widget classes remain in their original screen files

**Scope:**
All inputs that do NOT involve hardcoded display data (i.e., layout parameters, color constants, icon references, widget structure, interaction callbacks) must be completely unaffected by this fix. This includes:
- `BoxDecoration`, `BorderRadius`, `EdgeInsets`, and all styling constants
- `onPressed` / `onTap` callbacks (currently no-ops, must remain no-ops)
- `BottomNavigationBar` structure and active index
- OTP box focus-advance logic in `_VerifyScreenState`
- Password visibility toggle logic in `_SmartFinSignUpState`

## Hypothesized Root Cause

1. **No Data Layer Exists**: The project has no `models/` or `data/` directory. Screens were built as self-contained UI prototypes with no intent to separate data from presentation.

2. **Widget Constructors Accept No Data Parameters**: Every screen class (`DashboardScreen`, `TransactionsScreen`, etc.) has a `const` constructor with zero parameters, making it structurally impossible to inject data without modifying the widget tree.

3. **Inline Widget Construction**: Data-bearing widgets like `TransactionTile` and `AccountCard` are constructed inline with literal arguments rather than being built from a list, so there is no single place to swap data.

4. **No Shared Model Types**: `TransactionTile` in `dashboard_screen.dart` and `TransactionTile` in `transactions_screen.dart` are separate classes with different signatures, preventing reuse of a single `TransactionModel`.

## Correctness Properties

Property 1: Bug Condition — Screen Reads Data from Model Parameter

_For any_ screen widget where the bug condition holds (isBugCondition returns true), the fixed screen class SHALL accept a typed data model as a required constructor parameter and render all display strings and numeric values by reading fields from that model, with zero hardcoded display literals remaining in the widget tree.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7**

Property 2: Preservation — Visual and Behavioral Output Unchanged

_For any_ screen widget where the bug condition does NOT hold (layout constants, colors, icons, interaction callbacks, widget structure), the fixed screen SHALL produce output that is visually and behaviorally identical to the original screen when supplied with the dummy data values that match the previously hardcoded literals.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

## Fix Implementation

### Changes Required

**New File**: `frontend/lib/models/app_models.dart`
- Define `AccountModel(title, number, balance)`
- Define `TransactionModel(title, subtitle, amount, isIncome, icon, color, sectionLabel)`
- Define `LegendEntry(title, amount, color)`
- Define `SpendingCategory(title, amount, progress, color)`
- Define `DashboardData(netWorth, growthPercent, accounts, recentTransactions)`
- Define `AnalyticsData(totalBalance, netPerformance, monthlyUsageRatio, legendEntries, categories)`
- Define `WelcomeContent(headline, subtitle)`
- Define `OtpScreenContent(expiryLabel, socialProof)`
- Define `LoginContent(tagline, emailHint)`
- Define `SocialProvider(label, iconUrl)`
- Define `SignupContent(namePlaceholder, emailPlaceholder, socialProviders)`

**New File**: `frontend/lib/data/dummy_data.dart`
- Export a `const` or `final` instance of each model populated with the exact values currently hardcoded in each screen

**File**: `frontend/lib/screens/dashboard_screen.dart`
- Add `final DashboardData data` required parameter to `DashboardScreen`
- Replace `"\$124,592.40"` literal with `data.netWorth`
- Replace `"↗ 2.4%"` literal with `data.growthPercent`
- Replace inline `AccountCard(...)` constructors with `...data.accounts.map((a) => AccountCard(title: a.title, number: a.number, balance: a.balance))`
- Replace inline `TransactionTile(...)` constructors with `...data.recentTransactions.map((t) => TransactionTile(...))`

**File**: `frontend/lib/screens/transactions_screen.dart`
- Add `final List<TransactionModel> transactions` required parameter to `SmartFinScreen`
- Replace inline `TransactionTile(...)` constructors and `SectionTitle(...)` constructors with list-driven rendering grouped by `sectionLabel`

**File**: `frontend/lib/screens/analytics_screen.dart`
- Add `final AnalyticsData data` required parameter to `AnalyticsScreen`
- Replace `0.68` literal with `data.monthlyUsageRatio`
- Replace `"+12.4%"` and `"\$14,250.00"` literals with `data.netPerformance` and `data.totalBalance`
- Replace inline `_legend(...)` calls with `data.legendEntries.map(...)`
- Replace inline `CategoryBar(...)` constructors with `data.categories.map(...)`

**File**: `frontend/lib/screens/welcome_screen.dart`
- Add `final WelcomeContent content` required parameter to `SmartFinScreen`
- Replace headline and subtitle `TextSpan`/`Text` literals with `content.headline` and `content.subtitle`

**File**: `frontend/lib/screens/otp_verify_screen.dart`
- Add `final OtpScreenContent content` required parameter to `VerifyScreen`
- Replace `"Code expires in 02:59"` with `content.expiryLabel`
- Replace `"Join 40k+ verified investors"` with `content.socialProof`

**File**: `frontend/lib/screens/login_screen.dart`
- Add `final LoginContent content` required parameter to `LoginScreen`
- Replace `"Precision finance for the modern architect."` with `content.tagline`
- Replace `"name@atelier.com"` hint with `content.emailHint`

**File**: `frontend/lib/screens/signup_screen.dart`
- Add `final SignupContent content` required parameter to `SmartFinSignUp`
- Replace `'John Doe'` and `'name@company.com'` hints with `content.namePlaceholder` and `content.emailPlaceholder`
- Replace inline `_socialButton(label: 'Google', iconUrl: '...')` calls with `content.socialProviders.map(...)`

**File**: `frontend/lib/main.dart`
- Update all screen instantiation call sites to pass the corresponding dummy data instance

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm that screens contain hardcoded literals and have no data parameter.

**Test Plan**: Write widget tests that pump each screen with a modified data value and assert the widget tree reflects the change. Run these tests on the UNFIXED code to observe failures (the widget will still show the old hardcoded value).

**Test Cases**:
1. **Dashboard Net Worth Test**: Pump `DashboardScreen` with a `DashboardData` where `netWorth = "\$999.00"` and assert a `Text("\$999.00")` widget is found — will fail on unfixed code because the screen ignores the parameter
2. **Transactions List Length Test**: Pump `SmartFinScreen` (transactions) with a list of 2 `TransactionModel` items and assert exactly 2 `TransactionTile` widgets are found — will fail on unfixed code because 7 tiles are always rendered
3. **Analytics Balance Test**: Pump `AnalyticsScreen` with `totalBalance = "\$1.00"` and assert `Text("\$1.00")` is found — will fail on unfixed code
4. **Welcome Headline Test**: Pump `SmartFinScreen` (welcome) with `headline = "Test headline"` and assert it appears — will fail on unfixed code

**Expected Counterexamples**:
- Widget tree contains the old hardcoded value instead of the injected model value
- Possible causes: no constructor parameter exists, parameter exists but widget tree still uses literal, list is not iterated

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed screen reads from the model.

**Pseudocode:**
```
FOR ALL screen WHERE isBugCondition(screen) DO
  data := createModelWithDistinctValues()
  result := pumpWidget(screen(data: data))
  ASSERT widgetTree(result) CONTAINS data.fields
  ASSERT widgetTree(result) DOES NOT CONTAIN old hardcoded literals
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold (layout, colors, structure), the fixed screen produces the same output as the original when given matching dummy data.

**Pseudocode:**
```
FOR ALL screen WHERE NOT isBugCondition(screen) DO
  ASSERT fixedScreen(dummyData) RENDERS SAME AS originalScreen()
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many variations of model data and verifies structural widget properties hold across all of them
- It catches regressions where a refactor accidentally removes a widget or changes its type
- It provides strong guarantees that non-data widget properties (colors, layout) are unchanged

**Test Plan**: Observe widget structure on UNFIXED code first (widget counts, widget types, decoration values), then write tests that assert the same structure holds after the fix when dummy data is supplied.

**Test Cases**:
1. **Account Card Count Preservation**: Verify `DashboardScreen` with 2-account dummy data still renders exactly 2 `AccountCard` widgets in a horizontal list
2. **Transaction Section Header Preservation**: Verify `TransactionsScreen` still renders `SectionTitle` widgets with the correct group labels
3. **Analytics Progress Indicator Preservation**: Verify `OverviewCard` still contains a `CircularProgressIndicator` with the correct `value` from the model
4. **OTP Box Count Preservation**: Verify `VerifyScreen` still renders exactly 6 OTP input boxes regardless of content model

### Unit Tests

- Test each model class: verify field assignment and that `const` construction works
- Test `dummy_data.dart`: verify exported instances have the expected field values matching the original hardcoded literals
- Test each screen widget: pump with dummy data and assert key `Text` widgets display the correct values

### Property-Based Tests

- Generate random `List<TransactionModel>` of length 1–20 and verify `TransactionsScreen` renders exactly that many `TransactionTile` widgets
- Generate random `List<AccountModel>` of length 1–5 and verify `DashboardScreen` renders exactly that many `AccountCard` widgets
- Generate random `List<SpendingCategory>` and verify `SpendingCard` renders exactly that many `CategoryBar` widgets
- Generate random `AnalyticsData` with `monthlyUsageRatio` in [0.0, 1.0] and verify `CircularProgressIndicator.value` matches

### Integration Tests

- Test full screen render for each of the 7 screens using dummy data — assert no exceptions thrown and key structural widgets are present
- Test that `main.dart` compiles and runs with all screens receiving their dummy data instances
- Test switching between screens (if navigation is wired) does not cause data bleed between screens
