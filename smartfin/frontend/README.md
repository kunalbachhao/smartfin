# SmartFin — Flutter Frontend

This is the Flutter (Android) frontend for SmartFin.

For full documentation, setup instructions, and API reference see the [root README](../README.md).

## Quick start

```bash
flutter pub get
flutter run
```

## Key directories

```
lib/
├── main.dart                   # App entry, provider wiring, lifecycle observer
├── providers/                  # FinanceProvider, AuthProvider
├── screens/                    # All UI screens
├── services/                   # API client, SMS pipeline, database, classifier
└── models/                     # Data models
```
