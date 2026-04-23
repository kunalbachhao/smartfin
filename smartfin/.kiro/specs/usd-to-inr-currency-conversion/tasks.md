# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Formatted Currency Strings Missing ₹ Symbol and Indian Grouping
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists in `toFlutterTransaction` and `formatCurrency`
  - **Scoped PBT Approach**: Scope the property to the concrete failing cases for reproducibility
  - Test `toFlutterTransaction` with `amount=85000, type="income"` — assert result.amount equals `"+₹85,000.00"` (isBugCondition: formatted string does not contain ₹)
  - Test `toFlutterTransaction` with `amount=350, type="expense"` — assert result.amount equals `"-₹350.00"` (isBugCondition: formatted string does not contain ₹)
  - Test `formatCurrency(1000000)` in analytics — assert result equals `"₹10,00,000.00"` (isBugCondition: no ₹ and uses US grouping `/\d{1,3}(,\d{3})+/`)
  - Test `formatCurrency(500)` in analytics — assert result equals `"₹500.00"` (isBugCondition: no ₹)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g. `toFlutterTransaction` returns `"+85000.00"` instead of `"+₹85,000.00"`)
  - Mark task complete when tests are written, run, and failures are documented
  - _Requirements: 1.1, 1.2_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Currency Fields and Sign Prefixes Are Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: income transactions have `+` prefix on UNFIXED code (e.g. `toFlutterTransaction({amount:100, type:"income"}).amount` starts with `+`)
  - Observe: expense transactions have `-` prefix on UNFIXED code
  - Observe: `amountValue` field is a plain number (no ₹) on UNFIXED code
  - Observe: `netPerformance` matches `/^[+-]\d+\.\d+%$/` on UNFIXED code
  - Observe: `monthlyUsageRatio` is a number in [0, 1] on UNFIXED code
  - Observe: accounts route `balance` already uses ₹ with Indian grouping on UNFIXED code — must remain unchanged
  - Write property-based test: for any positive income amount, `toFlutterTransaction` result.amount starts with `+` (from Preservation Requirements 3.1)
  - Write property-based test: for any positive expense amount, `toFlutterTransaction` result.amount starts with `-` (from Preservation Requirements 3.1)
  - Write property-based test: for any amount, `toFlutterTransaction` result.amountValue is a plain number with no ₹ (from Preservation Requirements 3.5)
  - Write property-based test: for any numeric value, `formatIndian` in accounts route output is unchanged before and after fix (from Preservation Requirements 3.2, 3.7)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 3. Fix USD to INR currency formatting

  - [x] 3.1 Fix `toFlutterTransaction` in `backend/routes/transactions.js`
    - Replace `` `${sign}${doc.amount.toFixed(2)}` `` with `` `${sign}₹${formatIndian(doc.amount)}` ``
    - `formatIndian` is already defined in the same file — reuse it, do not introduce new logic
    - _Bug_Condition: isBugCondition(formattedString) where NOT formattedString.contains('₹')_
    - _Expected_Behavior: result.amount matches `/^[+-]₹\d{1,2}(,\d{2})*,\d{3}\.\d{2}$|^[+-]₹\d+\.\d{2}$/`_
    - _Preservation: sign prefix (+/-) must be preserved; amountValue must remain a plain number_
    - _Requirements: 2.1, 3.1, 3.5_

  - [x] 3.2 Fix `formatCurrency` in `backend/routes/analytics.js`
    - Replace the US-style grouping regex `/\B(?=(\d{3})+(?!\d))/g` with Indian grouping logic (rightmost 3 digits, then groups of 2)
    - Prepend `₹` to the result
    - Mirror the `formatIndian` logic from `transactions.js` — define a local helper or inline the same approach
    - _Bug_Condition: isBugCondition(formattedString) where usesUSGrouping(s) OR NOT s.contains('₹')_
    - _Expected_Behavior: result starts with '₹', uses Indian grouping for values ≥ 10000_
    - _Preservation: netPerformance (percentage string) and monthlyUsageRatio (decimal) are not passed through formatCurrency — they must remain unchanged_
    - _Requirements: 2.2, 3.3, 3.4, 3.7_

  - [x] 3.3 Update stale comment in `frontend/lib/models/app_models.dart`
    - In `TransactionModel`, change `// formatted display string, e.g. "-$84.20"` to `// formatted display string, e.g. "-₹350.00"`
    - This is a comment-only change — no logic is modified
    - _Requirements: 1.5, 2.1_

  - [x] 3.4 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Formatted Currency Strings Use ₹ with Indian Grouping
    - **IMPORTANT**: Re-run the SAME tests from task 1 - do NOT write new tests
    - The tests from task 1 encode the expected behavior
    - When these tests pass, it confirms the expected behavior is satisfied
    - Run bug condition exploration tests from step 1
    - **EXPECTED OUTCOME**: Tests PASS (confirms bug is fixed)
    - _Requirements: 2.1, 2.2_

  - [x] 3.5 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Currency Fields and Sign Prefixes Are Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm sign prefixes, raw numeric fields, percentage strings, and ratio values are all unchanged

- [x] 4. Checkpoint - Ensure all tests pass
  - Run the full test suite (unit + property-based tests from tasks 1 and 2)
  - Ensure all tests pass; ask the user if any questions arise
