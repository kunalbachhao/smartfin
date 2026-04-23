# Bugfix Requirements Document

## Introduction

All Flutter UI screens in the SmartFin app (`welcome_screen.dart`, `signup_screen.dart`, `login_screen.dart`, `dashboard_screen.dart`, `otp_verify_screen.dart`, `transactions_screen.dart`, `analytics_screen.dart`) currently render data that is hardcoded directly inside widget trees. This makes the UI impossible to drive from real or mock data sources, prevents testability, and violates separation of concerns. The fix replaces all hardcoded values with proper Dart models and a centralized `dummy_data.dart` file, while keeping every pixel of the visual output identical.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the dashboard screen renders THEN the system displays a hardcoded net worth value (`$124,592.40`), hardcoded growth indicator (`↗ 2.4%`), hardcoded account cards (`Checking Account **** 4492`, `High-Yield Savings **** 8891`), and hardcoded transaction tiles (`Blue Bottle Coffee`, `Monthly Salary`, `Skyline Properties`, `Apple Store`) as string literals inside the widget tree

1.2 WHEN the transactions screen renders THEN the system displays hardcoded transaction entries (`Whole Foods Market`, `Freelance Payment`, `Uber Trip`, `Netflix Premium`, `Monthly Rent`, `Dividend Payment`) with hardcoded amounts, times, categories, and section labels (`TODAY`, `YESTERDAY`, `JULY 2024`) as inline widget constructors

1.3 WHEN the analytics screen renders THEN the system displays hardcoded financial figures (`$14,250.00` total balance, `+12.4%` net performance, `68%` monthly usage), hardcoded legend entries (`Fixed Costs $2,400`, `Lifestyle $1,120`), and hardcoded category bars (`Food & Drinks`, `Rent`, `Electronics`, `Groceries`, `Transport`) with hardcoded amounts and progress values as literal constants

1.4 WHEN the welcome screen renders THEN the system displays hardcoded headline text (`Smart finance for your future.`) and subtitle (`Take control of your smart financial future today.`) as string literals with no data source

1.5 WHEN the OTP verify screen renders THEN the system displays a hardcoded expiry timer label (`Code expires in 02:59`) and a hardcoded social proof string (`Join 40k+ verified investors`) as string literals

1.6 WHEN the login screen renders THEN the system displays a hardcoded tagline (`Precision finance for the modern architect.`) and hardcoded email hint (`name@atelier.com`) as string literals

1.7 WHEN the signup screen renders THEN the system displays hardcoded placeholder text (`John Doe`, `name@company.com`) and hardcoded social button icon URLs as string literals embedded in the widget

### Expected Behavior (Correct)

2.1 WHEN the dashboard screen renders THEN the system SHALL read net worth, growth percentage, account list, and recent transaction list from a `DashboardData` model populated by `dummy_data.dart`, and pass each value as a named parameter to the relevant widget

2.2 WHEN the transactions screen renders THEN the system SHALL read a list of `Transaction` model objects (each carrying title, subtitle, amount, isIncome flag, icon, color, and section label) from `dummy_data.dart` and render them by iterating the list, with no hardcoded string or value inside the widget tree

2.3 WHEN the analytics screen renders THEN the system SHALL read an `AnalyticsData` model (carrying total balance, net performance, monthly usage ratio, legend entries, and a list of `SpendingCategory` models) from `dummy_data.dart` and pass each field to the corresponding widget parameter

2.4 WHEN the welcome screen renders THEN the system SHALL read headline and subtitle strings from a `WelcomeContent` model supplied via `dummy_data.dart` and render them through widget parameters

2.5 WHEN the OTP verify screen renders THEN the system SHALL read the expiry label and social proof string from an `OtpScreenContent` model supplied via `dummy_data.dart`

2.6 WHEN the login screen renders THEN the system SHALL read the tagline and email hint from a `LoginContent` model supplied via `dummy_data.dart`

2.7 WHEN the signup screen renders THEN the system SHALL read placeholder texts and social provider configurations (label + icon source) from a `SignupContent` model supplied via `dummy_data.dart`, with no hardcoded URLs or strings inside the widget

### Unchanged Behavior (Regression Prevention)

3.1 WHEN any screen renders with the dummy data values THEN the system SHALL CONTINUE TO display pixel-identical output to the current hardcoded UI — same layout, spacing, colors, fonts, icons, and structure

3.2 WHEN the dashboard account cards are displayed THEN the system SHALL CONTINUE TO render a horizontally scrollable row of cards with the same card dimensions, typography, and decoration

3.3 WHEN the transactions screen renders its list THEN the system SHALL CONTINUE TO group transactions under section headers and display each tile with the same icon, color badge, title, subtitle, and amount styling

3.4 WHEN the analytics screen renders the overview card THEN the system SHALL CONTINUE TO show the circular progress indicator and legend rows with the same visual proportions and colors

3.5 WHEN the analytics screen renders the spending card THEN the system SHALL CONTINUE TO show labeled linear progress bars per category with the same bar height, border radius, and color scheme

3.6 WHEN the OTP verify screen renders THEN the system SHALL CONTINUE TO show six individual input boxes with the same focus behavior, keyboard type, and layout

3.7 WHEN the signup screen renders THEN the system SHALL CONTINUE TO show the terms checkbox, password visibility toggles, and social sign-in buttons with the same interaction behavior

3.8 WHEN models and dummy data are introduced THEN the system SHALL CONTINUE TO compile without errors and all existing widget classes SHALL remain in their original screen files unless explicitly extracted into `widgets/`
