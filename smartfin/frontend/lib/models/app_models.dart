import 'package:flutter/material.dart';

// ── Color name → Flutter Color mapping ────────────────────────────────────────
// The backend stores color names as strings (e.g. "blue", "teal").
// This map converts them back to Flutter Color objects.
const Map<String, Color> _colorMap = {
  'blue':   Colors.blue,
  'teal':   Colors.teal,
  'orange': Colors.orange,
  'brown':  Colors.brown,
  'grey':   Colors.grey,
  'purple': Colors.purple,
  'red':    Colors.red,
  'green':  Colors.green,
};

Color _colorFromName(String? name) =>
    _colorMap[name?.toLowerCase()] ?? Colors.blue;

// ── AccountModel ───────────────────────────────────────────────────────────────

class AccountModel {
  final String id;
  final String title;
  final String number;
  final String balance;
  final double balanceValue;

  const AccountModel({
    this.id = '',
    required this.title,
    required this.number,
    required this.balance,
    this.balanceValue = 0,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id:           json['id']?.toString() ?? '',
      title:        json['title']?.toString() ?? '',
      number:       json['number']?.toString() ?? '',
      balance:      json['balance']?.toString() ?? '₹0.00',
      balanceValue: (json['balanceValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ── TransactionModel ───────────────────────────────────────────────────────────

class TransactionModel {
  final String id;
  final String title;
  final String subtitle;
  final String amount;       // formatted display string, e.g. "-₹350.00"
  final double amountValue;  // numeric value, always positive
  final bool isIncome;
  final IconData icon;
  final Color color;
  final String sectionLabel;
  final String category;

  // ── Optional SMS breakdown fields ─────────────────────────────────────────
  // Populated only for SMS-sourced transactions (category == 'Bank SMS').
  // Null for API-sourced transactions — consumers must null-check.
  //
  // These fields carry the structured SMS breakdown so the detail screen
  // can render them without a separate data fetch.
  final String? smsBankName;      // e.g. "HDFC Bank"
  final String? smsAccountNumber; // masked, e.g. "XX1234" or "Unknown"
  final String? smsCounterparty;  // UPI ID or merchant name or "Unknown"
  final String? smsRawBody;       // full original SMS text
  final String? smsTimestamp;     // formatted: "11 Apr 2026, 14:30"

  /// SQLite row ID of the local [BankSmsRecord], if this is an SMS transaction.
  ///
  /// `null` for API-sourced transactions.
  /// Used by [FinanceProvider.removeTransaction] to delete the local DB record.
  final int? localDbId;

  const TransactionModel({
    this.id = '',
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountValue,
    required this.isIncome,
    required this.icon,
    required this.color,
    required this.sectionLabel,
    this.category = 'Other',
    // SMS extras — all optional
    this.smsBankName,
    this.smsAccountNumber,
    this.smsCounterparty,
    this.smsRawBody,
    this.smsTimestamp,
    this.localDbId,
  });

  /// Whether this transaction was sourced from a local bank SMS.
  bool get isSmsTransaction => category == 'Bank SMS';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id:           json['id']?.toString() ?? '',
      title:        json['title']?.toString() ?? '',
      subtitle:     json['subtitle']?.toString() ?? '',
      amount:       json['amount']?.toString() ?? '₹0.00',
      amountValue:  (json['amountValue'] as num?)?.toDouble() ?? 0,
      isIncome:     json['isIncome'] as bool? ?? false,
      icon:         Icons.monetization_on,
      color:        _colorFromName(json['color']?.toString()),
      sectionLabel: json['sectionLabel']?.toString() ?? 'OTHER',
      category:     json['category']?.toString() ?? 'Other',
      // SMS extras are never present in API responses.
    );
  }
}

// ── LegendEntry ────────────────────────────────────────────────────────────────

class LegendEntry {
  final String title;
  final String amount;
  final Color color;

  const LegendEntry({
    required this.title,
    required this.amount,
    required this.color,
  });

  factory LegendEntry.fromJson(Map<String, dynamic> json) {
    return LegendEntry(
      title:  json['title']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '₹0',
      color:  _colorFromName(json['color']?.toString()),
    );
  }
}

// ── SpendingCategory ───────────────────────────────────────────────────────────

class SpendingCategory {
  final String title;
  final String amount;
  final double progress;
  final Color color;

  const SpendingCategory({
    required this.title,
    required this.amount,
    required this.progress,
    required this.color,
  });

  factory SpendingCategory.fromJson(Map<String, dynamic> json) {
    return SpendingCategory(
      title:    json['title']?.toString() ?? '',
      amount:   json['amount']?.toString() ?? '₹0.00',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      color:    _colorFromName(json['color']?.toString()),
    );
  }
}

// ── AnalyticsData ──────────────────────────────────────────────────────────────

class AnalyticsData {
  final String totalBalance;
  final String netPerformance;
  final double monthlyUsageRatio;
  final List<LegendEntry> legendEntries;
  final List<SpendingCategory> categories;

  const AnalyticsData({
    required this.totalBalance,
    required this.netPerformance,
    required this.monthlyUsageRatio,
    required this.legendEntries,
    required this.categories,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      totalBalance:      json['totalBalance']?.toString() ?? '₹0.00',
      netPerformance:    json['netPerformance']?.toString() ?? '+0.0%',
      monthlyUsageRatio: (json['monthlyUsageRatio'] as num?)?.toDouble() ?? 0,
      legendEntries: (json['legendEntries'] as List<dynamic>? ?? [])
          .map((e) => LegendEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => SpendingCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Static UI content models (unchanged) ──────────────────────────────────────

class DashboardData {
  final String netWorth;
  final String growthPercent;
  final List<AccountModel> accounts;
  final List<TransactionModel> recentTransactions;

  const DashboardData({
    required this.netWorth,
    required this.growthPercent,
    required this.accounts,
    required this.recentTransactions,
  });
}

class WelcomeContent {
  final String headline;
  final String subtitle;
  const WelcomeContent({required this.headline, required this.subtitle});
}

class OtpScreenContent {
  final String expiryLabel;
  final String socialProof;
  const OtpScreenContent({required this.expiryLabel, required this.socialProof});
}

class LoginContent {
  final String tagline;
  final String emailHint;
  const LoginContent({required this.tagline, required this.emailHint});
}

class SocialProvider {
  final String label;
  final String iconUrl;
  const SocialProvider({required this.label, required this.iconUrl});
}

class SignupContent {
  final String namePlaceholder;
  final String emailPlaceholder;
  final List<SocialProvider> socialProviders;
  const SignupContent({
    required this.namePlaceholder,
    required this.emailPlaceholder,
    required this.socialProviders,
  });
}
