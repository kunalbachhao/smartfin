import 'package:flutter/material.dart';
import '../models/app_models.dart';

// ── Accounts ──────────────────────────────────────────────────────────────────
const List<AccountModel> dummyAccounts = [
  AccountModel(title: 'Savings Account',    number: '**** 4492', balance: '₹9,45,200.00'),
  AccountModel(title: 'Current Account',    number: '**** 8891', balance: '₹2,18,750.00'),
];

// ── Transactions ──────────────────────────────────────────────────────────────
// amountValue is always the positive magnitude; isIncome determines sign.
const List<TransactionModel> dummyTransactions = [
  // Dashboard recent transactions
  TransactionModel(
    title: 'Blue Tokai Coffee',
    subtitle: 'Food & Drinks • Today, 10:45 AM',
    amount: '-₹350.00',
    amountValue: 350.00,
    isIncome: false,
    icon: Icons.local_cafe,
    color: Colors.teal,
    sectionLabel: 'TODAY',
    category: 'Food & Drinks',
  ),
  TransactionModel(
    title: 'Monthly Salary',
    subtitle: 'Income • Aug 01, 2024',
    amount: '+₹85,000.00',
    amountValue: 85000.00,
    isIncome: true,
    icon: Icons.attach_money,
    color: Colors.blue,
    sectionLabel: 'TODAY',
    category: 'Income',
  ),
  TransactionModel(
    title: 'Prestige Properties',
    subtitle: 'Rent • Aug 01, 2024',
    amount: '-₹22,000.00',
    amountValue: 22000.00,
    isIncome: false,
    icon: Icons.home,
    color: Colors.orange,
    sectionLabel: 'TODAY',
    category: 'Rent',
  ),
  TransactionModel(
    title: 'Croma Electronics',
    subtitle: 'Electronics • Jul 28, 2024',
    amount: '-₹14,999.00',
    amountValue: 14999.00,
    isIncome: false,
    icon: Icons.phone_iphone,
    color: Colors.grey,
    sectionLabel: 'TODAY',
    category: 'Electronics',
  ),
  // Transactions screen entries
  TransactionModel(
    icon: Icons.shopping_cart,
    title: 'Big Basket',
    subtitle: '14:30 • Groceries',
    amount: '- ₹1,840.00',
    amountValue: 1840.00,
    isIncome: false,
    color: Color(0xFF6ED3CF),
    sectionLabel: 'TODAY',
    category: 'Groceries',
  ),
  TransactionModel(
    icon: Icons.attach_money,
    title: 'Freelance Payment',
    subtitle: '09:15 • Income',
    amount: '+ ₹35,000.00',
    amountValue: 35000.00,
    isIncome: true,
    color: Color(0xFF3B82F6),
    sectionLabel: 'TODAY',
    category: 'Income',
  ),
  TransactionModel(
    icon: Icons.directions_car,
    title: 'Ola Ride',
    subtitle: '21:40 • Transport',
    amount: '- ₹320.00',
    amountValue: 320.00,
    isIncome: false,
    color: Color(0xFFF4C27A),
    sectionLabel: 'YESTERDAY',
    category: 'Transport',
  ),
  TransactionModel(
    icon: Icons.movie,
    title: 'Netflix Premium',
    subtitle: '00:01 • Entertainment',
    amount: '- ₹649.00',
    amountValue: 649.00,
    isIncome: false,
    color: Colors.grey,
    sectionLabel: 'YESTERDAY',
    category: 'Food & Drinks',
  ),
  TransactionModel(
    icon: Icons.home,
    title: 'Monthly Rent',
    subtitle: 'Jul 31 • Housing',
    amount: '- ₹22,000.00',
    amountValue: 22000.00,
    isIncome: false,
    color: Color(0xFF6ED3CF),
    sectionLabel: 'JULY 2024',
    category: 'Rent',
  ),
  TransactionModel(
    icon: Icons.savings,
    title: 'Dividend Payment',
    subtitle: 'Jul 30 • Investments',
    amount: '+ ₹1,250.00',
    amountValue: 1250.00,
    isIncome: true,
    color: Color(0xFF3B82F6),
    sectionLabel: 'JULY 2024',
    category: 'Income',
  ),
];

// ── Static content (unchanged) ────────────────────────────────────────────────
const WelcomeContent dummyWelcomeContent = WelcomeContent(
  headline: 'Smart finance for\nyour future.',
  subtitle: 'Take control of your smart\nfinancial future today.',
);

const OtpScreenContent dummyOtpContent = OtpScreenContent(
  expiryLabel: 'Code expires in 02:59',
  socialProof: 'Join 40k+ verified investors',
);

const LoginContent dummyLoginContent = LoginContent(
  tagline: 'Precision finance for the modern architect.',
  emailHint: 'name@atelier.com',
);

const SignupContent dummySignupContent = SignupContent(
  namePlaceholder: 'Rahul Sharma',
  emailPlaceholder: 'name@company.com',
  socialProviders: [
    SocialProvider(
      label: 'Google',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
    ),
    SocialProvider(
      label: 'Apple',
      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/f/fa/Apple_logo_black.svg',
    ),
  ],
);
