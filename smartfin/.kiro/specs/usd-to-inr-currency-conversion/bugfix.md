# Bugfix Requirements Document

## Introduction

The application was originally built with USD ($) as the currency throughout the UI, backend formatting logic, and data layer. All currency values must be converted to Indian Rupees (INR, ₹) with correct Indian numbering system formatting (e.g. ₹1,00,000.00 instead of $100,000.00). This affects formatted strings returned by the backend API, currency symbols displayed in the Flutter frontend, dummy/seed data, and any fallback/default values that reference "$" or USD formatting.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the backend `/transactions` route formats a transaction amount THEN the system returns a plain numeric string (e.g. `"+85000.00"`) with no currency symbol and no Indian grouping

1.2 WHEN the backend `/analytics` route formats currency values (totalBalance, legendEntries amounts, category amounts) THEN the system uses a simple US-style comma grouping with no ₹ symbol (e.g. `"1,000.00"` instead of `"₹10,000.00"`)

1.3 WHEN the backend `/accounts` route formats an account balance THEN the system prepends `₹` but applies incorrect US-style grouping (e.g. `"₹100,000.00"` instead of `"₹1,00,000.00"`)

1.4 WHEN the Flutter `TransactionModel` or `AccountModel` falls back to a default formatted value THEN the system uses `"$0.00"` as the default string instead of `"₹0.00"`

1.5 WHEN the Flutter `app_models.dart` comment describes the `amount` field THEN the system documents it as `"-$84.20"` (USD example), indicating USD was the intended format

1.6 WHEN dummy transaction data is displayed in the app THEN the system shows amounts without the ₹ symbol or with incorrect grouping for large Indian Rupee values

### Expected Behavior (Correct)

2.1 WHEN the backend `/transactions` route formats a transaction amount THEN the system SHALL return a string with the ₹ symbol and Indian number grouping (e.g. `"+₹85,000.00"` for income, `"-₹350.00"` for expense)

2.2 WHEN the backend `/analytics` route formats currency values THEN the system SHALL use the ₹ symbol with Indian number grouping (e.g. `"₹1,00,000.00"`)

2.3 WHEN the backend `/accounts` route formats an account balance THEN the system SHALL use the ₹ symbol with correct Indian number grouping (e.g. `"₹9,45,200.00"`)

2.4 WHEN the Flutter `TransactionModel` or `AccountModel` falls back to a default formatted value THEN the system SHALL use `"₹0.00"` as the default string

2.5 WHEN the Flutter `FinanceProvider._formatCurrency` helper formats any numeric value THEN the system SHALL produce a string with the ₹ symbol and Indian grouping (rightmost 3 digits, then groups of 2)

2.6 WHEN dummy/seed transaction and account data is used THEN the system SHALL display amounts with the ₹ symbol and Indian number grouping consistent with real API data

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a transaction amount is a positive number THEN the system SHALL CONTINUE TO display income with a `+` prefix and expenses with a `-` prefix

3.2 WHEN an account balance is zero THEN the system SHALL CONTINUE TO display `₹0.00`

3.3 WHEN the analytics endpoint computes `netPerformance` as a percentage THEN the system SHALL CONTINUE TO return a percentage string (e.g. `"+12.5%"`) unchanged — this value is not a currency amount

3.4 WHEN the analytics endpoint computes `monthlyUsageRatio` THEN the system SHALL CONTINUE TO return a decimal ratio between 0 and 1 unchanged — this value is not a currency amount

3.5 WHEN a numeric `balanceValue` or `amountValue` field is returned in API responses THEN the system SHALL CONTINUE TO return the raw numeric value without any currency symbol or formatting

3.6 WHEN the Flutter `FinanceProvider` computes `totalIncome`, `totalExpenses`, and `netBalance` as doubles THEN the system SHALL CONTINUE TO perform arithmetic on raw numeric values, not formatted strings

3.7 WHEN the Indian grouping function receives a number with 3 or fewer integer digits THEN the system SHALL CONTINUE TO return the number without any comma grouping (e.g. `₹350.00`)

3.8 WHEN the backend authentication, OTP, and user management routes handle requests THEN the system SHALL CONTINUE TO operate without any changes — these routes contain no currency logic
