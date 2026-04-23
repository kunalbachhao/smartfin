const mongoose = require("mongoose");

/**
 * Transaction document.
 *
 * Flutter mapping:
 *   _id        → TransactionModel.id (String)
 *   title      → TransactionModel.title
 *   subtitle   → TransactionModel.subtitle  (auto-built: "category • date")
 *   amount     → TransactionModel.amountValue (numeric)
 *   type       → "income" | "expense"  → TransactionModel.isIncome
 *   category   → TransactionModel.category
 *   date       → used to derive TransactionModel.sectionLabel
 *   userId     → owner reference (never sent to client)
 */
const TransactionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    amount: {
      type: Number,
      required: true,
      min: 0.01,
    },
    type: {
      type: String,
      required: true,
      enum: ["income", "expense"],
    },
    category: {
      type: String,
      required: true,
      trim: true,
      maxlength: 60,
    },
    date: {
      type: Date,
      required: true,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// Compound index for efficient per-user date-sorted queries
TransactionSchema.index({ userId: 1, date: -1 });

module.exports = mongoose.model("Transaction", TransactionSchema);
