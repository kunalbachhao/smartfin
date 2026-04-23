# USD to INR Currency Conversion Bugfix Design

## Overview

The application was built with USD ($) formatting throughout the backend API and Flutter frontend. This bugfix converts all currency formatting to Indian Rupees (INR, ₹) with correct Indian number grouping (e.g. ₹1,00,000.00 instead of $100,000.00 or ₹100,000.00).

The primary defects are:
1. `backend/routes/transactions.js` — `toFlutterTransaction` formats amounts as plain numbers with no ₹ symbol and no Indian grouping (e.g. `"+85000.00"`)
2. `backend/routes/analytics.js` — `formatCurrency` uses US-style comma grouping with no ₹ symbol (e.g. `"1,000.00"`)
3. `frontend/lib/models/app_models.dart` — `TransactionModel` comment documents the `amount` field with a USD example (`"-$84.20"`)

The fix is minimal and targeted: update the two backend formatting functions and the one comment. Dummy data and model fallbacks already use ₹ correctly.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — a currency value is formatted without the ₹ symbol or without Indian number grouping
- **Property (P)**: The desired behavior — every formatted currency string uses ₹ with Indian grouping (rightmost 3 digits, then groups of 2)
- **Preservation**: Existing behaviors that must remain unchanged — sign prefixes (+/-), raw numeric fields, percentage strings, ratio values, and auth routes
- **formatCurrency**: The function in `backend/routes/analytics.js` that formats a number as a currency string (currently uses US-style grouping, no ₹)
- **toFlutterTransaction**: The function in `backend/routes/transactions.js` that serializes a Transaction document to the Flutter JSON shape (currently omits ₹ symbol)
- **formatIndian**: The helper in `backend/routes/transactions.js` and `backend/routes/accounts.js` that applies Indian number grouping (correct logic, but not used in `toFlutterTransaction`)
- **_formatCurrency**: The static helper in `frontend/lib/providers/finance_provider.dart` that formats a double as INR (already correct)
- **Indian grouping**: Rightmost 3 digits form the first group, then groups of 2 from right — e.g. 1234567 → 12,34,567

## Bug Details

### Bug Condition

The bug manifests when a currency amount is serialized to a display string. In `toFlutterTransaction` (transactions route), the formatted string is built without calling `formatIndian` and without prepending ₹. In `formatCurrency` (analytics route), the function uses a US-style grouping regex and no ₹ symbol.

**Formal Specification:**
```
FUNCTION isBugCondition(formattedString)
  INPUT: formattedString of type String (a currency display value)
  OUTPUT: boolean

  RETURN NOT formattedString.contains('₹')
         OR usesUSGrouping(formattedString)

FUNCTION usesUSGrouping(s)
  // US grouping: groups of 3 from right (e.g. 1,000,000)
  // Indian grouping: rightmost 3, then groups of 2 (e.g. 10,00,000)
  RETURN s matches regex /\d{1,3}(,\d{3})+/ AND value >= 10000
END FUNCTION
```

### Examples

- `toFlutterTransaction` with amount=85000, type="income" → currently returns `"+85000.00"`, expected `"+₹85,000.00"`
- `toFlutterTransaction` with amount=350, type="expense" → currently returns `"-350.00"`, expected `"-₹350.00"`
- `formatCurrency` in analytics with value=100000 → currently returns `"1,00,000.00"` (no ₹), expected `"₹1,00,000.00"`
- `formatCurrency` in analytics with value=1000000 → currently returns `"1,000,000.00"` (US grouping, no ₹), expected `"₹10,00,000.00"`
- Edge case: amount=500 → currently `"+500.00"`, expected `"+₹500.00"` (no commas, ≤3 integer digits)

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Income transactions must continue to display with a `+` prefix; expenses with a `-` prefix
- Raw numeric fields (`amountValue`, `balanceValue`, `totalIncome`, `totalExpenses`, `netBalance`) must remain plain numbers with no currency symbol
- `netPerformance` must remain a percentage string (e.g. `"+12.5%"`) — it is not a currency value
- `monthlyUsageRatio` must remain a decimal between 0 and 1
- Account balance formatting in `accounts.js` already uses ₹ with Indian grouping and must not be changed
- Flutter `_formatCurrency` and `_indianGroup` in `finance_provider.dart` are already correct and must not be changed
- Dummy data in `dummy_data.dart` already uses ₹ with Indian grouping and must not be changed
- Model fallback values in `app_models.dart` already use `'₹0.00'` and must not be changed
- All authentication, OTP, and user management routes must remain completely unaffected

**Scope:**
All inputs that do NOT produce a formatted currency display string are completely unaffected. This includes:
- Raw numeric API fields (`amountValue`, `balanceValue`, summary totals)
- Percentage and ratio fields (`netPerformance`, `monthlyUsageRatio`)
- Non-financial string fields (titles, subtitles, categories, dates, IDs)
- All auth/OTP/login endpoints

## Hypothesized Root Cause

Based on code inspection, the root causes are confirmed (not just hypothesized):

1. **Missing ₹ symbol in `toFlutterTransaction`**: The formatted string is built as `` `${sign}${doc.amount.toFixed(2)}` `` — it calls `toFixed(2)` directly instead of using the already-defined `formatIndian` helper, and never prepends `₹`

2. **Wrong grouping regex in `formatCurrency` (analytics)**: The function uses `/\B(?=(\d{3})+(?!\d))/g` which is US-style (groups of 3). It also never prepends `₹`. The `formatIndian` function defined in `transactions.js` is not shared/imported into `analytics.js`

3. **Stale comment in `TransactionModel`**: The `amount` field comment says `// formatted display string, e.g. "-$84.20"` — a USD example that should be updated to `"-₹350.00"`

## Correctness Properties

Property 1: Bug Condition - Formatted Currency Strings Use ₹ with Indian Grouping

_For any_ numeric currency value formatted by `toFlutterTransaction` (transactions route) or `formatCurrency` (analytics route), the fixed functions SHALL return a string that begins with an optional sign (`+` or `-`), followed by `₹`, followed by the absolute value formatted with Indian number grouping (rightmost 3 digits, then groups of 2) and 2 decimal places.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Non-Currency Fields and Existing Correct Formatters Are Unchanged

_For any_ input that does NOT go through the two buggy formatting paths (`toFlutterTransaction` amount field, `formatCurrency` in analytics), the fixed code SHALL produce exactly the same output as the original code — preserving sign prefixes, raw numeric values, percentage strings, ratio values, account balance formatting, Flutter `_formatCurrency` output, and dummy data display strings.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

## Fix Implementation

### Changes Required

**File 1**: `backend/routes/transactions.js`

**Function**: `toFlutterTransaction`

**Specific Changes**:
1. **Use `formatIndian` and prepend ₹**: Replace `` const formatted = `${sign}${doc.amount.toFixed(2)}`; `` with `` const formatted = `${sign}₹${formatIndian(doc.amount)}`; ``
   - `formatIndian` is already defined in the same file and handles Indian grouping correctly
   - This reuses existing correct logic rather than introducing new code

---

**File 2**: `backend/routes/analytics.js`

**Function**: `formatCurrency`

**Specific Changes**:
1. **Replace US-style grouping with Indian grouping and add ₹**: Rewrite `formatCurrency` to use the same Indian grouping logic as `formatIndian` in transactions.js, and prepend `₹`
   - Change the regex from `/\B(?=(\d{3})+(?!\d))/g` (US) to the Indian grouping approach (last 3 digits, then groups of 2)
   - Prepend `₹` to the result

---

**File 3**: `frontend/lib/models/app_models.dart`

**Comment**: `TransactionModel.amount` field

**Specific Changes**:
1. **Update stale USD example in comment**: Change `// formatted display string, e.g. "-$84.20"` to `// formatted display string, e.g. "-₹350.00"`

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm the root cause analysis.

**Test Plan**: Write unit tests that call `toFlutterTransaction` and `formatCurrency` with known inputs and assert the output matches the expected ₹-formatted string. Run these tests on the UNFIXED code to observe failures.

**Test Cases**:
1. **Transaction income formatting**: Call `toFlutterTransaction` with `amount=85000, type="income"` — assert result.amount equals `"+₹85,000.00"` (will fail on unfixed code, returns `"+85000.00"`)
2. **Transaction expense formatting**: Call `toFlutterTransaction` with `amount=350, type="expense"` — assert result.amount equals `"-₹350.00"` (will fail on unfixed code, returns `"-350.00"`)
3. **Analytics large value**: Call `formatCurrency(1000000)` — assert result equals `"₹10,00,000.00"` (will fail on unfixed code, returns `"1,000,000.00"`)
4. **Analytics small value**: Call `formatCurrency(500)` — assert result equals `"₹500.00"` (will fail on unfixed code, returns `"500.00"`)

**Expected Counterexamples**:
- `toFlutterTransaction` returns amount strings without ₹ symbol
- `formatCurrency` returns strings without ₹ symbol and with US-style grouping for values ≥ 10,000

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed functions produce the expected ₹-formatted output.

**Pseudocode:**
```
FOR ALL amount WHERE isBugCondition(formatAmount(amount)) DO
  result := toFlutterTransaction_fixed({ amount, type })
  ASSERT result.amount contains '₹'
  ASSERT result.amount uses Indian grouping
  ASSERT result.amount has correct sign prefix
END FOR

FOR ALL value WHERE isBugCondition(formatCurrency(value)) DO
  result := formatCurrency_fixed(value)
  ASSERT result starts with '₹'
  ASSERT result uses Indian grouping
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed code produces the same result as the original code.

**Pseudocode:**
```
FOR ALL field WHERE NOT isBugCondition(field) DO
  ASSERT original_output(field) = fixed_output(field)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many numeric inputs automatically to verify Indian grouping correctness across the full range
- It catches edge cases (values < 1000, values with exactly 4 digits, very large values) that manual tests might miss
- It provides strong guarantees that sign prefixes, raw numeric fields, and percentage strings are unchanged

**Test Plan**: Observe behavior of non-currency fields on UNFIXED code first, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Sign prefix preservation**: For any income transaction, `+` prefix is present; for any expense, `-` prefix is present — verify this holds before and after fix
2. **Raw numeric field preservation**: `amountValue` and `balanceValue` remain plain numbers (no ₹) — verify unchanged
3. **netPerformance preservation**: Output always matches `/^[+-]\d+\.\d+%$/` — verify unchanged
4. **monthlyUsageRatio preservation**: Output is always a number in [0, 1] — verify unchanged
5. **Accounts route preservation**: `toFlutterAccount` balance output is unchanged (already correct)

### Unit Tests

- Test `toFlutterTransaction` with income and expense amounts at various magnitudes (< 1000, 1000–9999, ≥ 10000, ≥ 100000)
- Test `formatCurrency` in analytics with the same magnitude ranges
- Test edge cases: amount = 0, amount = 999.99, amount = 1000, amount = 99999.99
- Test that `amountValue` in `toFlutterTransaction` output remains a plain number

### Property-Based Tests

- Generate random positive doubles and verify `toFlutterTransaction` amount field always contains ₹ and uses Indian grouping
- Generate random positive doubles and verify `formatCurrency` (analytics) always starts with ₹ and uses Indian grouping
- Generate random transaction objects and verify sign prefix (+/-) is preserved after fix
- Generate random doubles and verify `_formatCurrency` (Flutter, already correct) output is unchanged by the fix

### Integration Tests

- Call `GET /transactions` with a seeded transaction and verify the `amount` field in the response uses ₹ with Indian grouping
- Call `GET /analytics` and verify `totalBalance`, `legendEntries[].amount`, and `categories[].amount` all use ₹ with Indian grouping
- Call `GET /accounts` and verify `balance` field continues to use ₹ with Indian grouping (regression check — already correct)
- Verify `netPerformance` and `monthlyUsageRatio` in analytics response are unchanged in format
