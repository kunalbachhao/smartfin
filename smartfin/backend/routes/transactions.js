const express = require("express");
const mongoose = require("mongoose");
const Transaction = require("../models/Transaction");
const authMiddleware = require("../middleware/auth");

const router = express.Router();

// All routes require a valid JWT
router.use(authMiddleware);

// ── Helpers ────────────────────────────────────────────────────────────────

/**
 * Formats a number using the Indian numbering system.
 * e.g. 100000 → "1,00,000.00"
 */
function formatIndian(value) {
  const abs  = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  const [intStr, dec] = abs.toFixed(2).split(".");
  if (intStr.length <= 3) return `${sign}${intStr}.${dec}`;
  const last3  = intStr.slice(-3);
  const rest   = intStr.slice(0, intStr.length - 3);
  const grouped = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ",");
  return `${sign}${grouped},${last3}.${dec}`;
}

/**
 * Converts a Mongoose Transaction document to the JSON shape Flutter expects.
 *
 * Flutter TransactionModel fields:
 *   id, title, subtitle, amount (formatted string), amountValue (double),
 *   isIncome, category, sectionLabel, date (ISO string)
 *
 * sectionLabel is derived from the date:
 *   - today          → "TODAY"
 *   - yesterday      → "YESTERDAY"
 *   - same month     → "MONTH YYYY"  (e.g. "JULY 2024")
 *   - older          → "MONTH YYYY"
 */
function toFlutterTransaction(doc) {
  const now = new Date();
  const txDate = new Date(doc.date);

  const isToday =
    txDate.toDateString() === now.toDateString();

  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  const isYesterday = txDate.toDateString() === yesterday.toDateString();

  let sectionLabel;
  if (isToday) {
    sectionLabel = "TODAY";
  } else if (isYesterday) {
    sectionLabel = "YESTERDAY";
  } else {
    sectionLabel = txDate
      .toLocaleString("en-US", { month: "long", year: "numeric" })
      .toUpperCase(); // e.g. "JULY 2024"
  }

  const isIncome = doc.type === "income";
  const sign = isIncome ? "+" : "-";
  const formatted = `${sign}₹${formatIndian(doc.amount)}`;

  // subtitle: "category • time"
  const timeStr = txDate.toLocaleTimeString("en-US", {
    hour: "2-digit",
    minute: "2-digit",
  });
  const subtitle = `${doc.category} • ${timeStr}`;

  return {
    id: doc._id.toString(),
    title: doc.title,
    subtitle,
    amount: formatted,
    amountValue: doc.amount,
    isIncome,
    category: doc.category,
    sectionLabel,
    date: doc.date.toISOString(),
  };
}

function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

// ── GET /transactions ──────────────────────────────────────────────────────
// Returns paginated list of transactions for the authenticated user.
//
// Query params:
//   page     (default 1)
//   limit    (default 20, max 100)
//   category (optional filter)
//   type     (optional: "income" | "expense")
//   from     (optional ISO date — inclusive lower bound)
//   to       (optional ISO date — inclusive upper bound)
router.get("/", async (req, res) => {
  try {
    const page  = Math.max(1, parseInt(req.query.page)  || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const skip  = (page - 1) * limit;

    const filter = { userId: req.user.userId };

    if (req.query.category) filter.category = req.query.category;
    if (req.query.type && ["income", "expense"].includes(req.query.type)) {
      filter.type = req.query.type;
    }
    if (req.query.from || req.query.to) {
      filter.date = {};
      if (req.query.from) filter.date.$gte = new Date(req.query.from);
      if (req.query.to)   filter.date.$lte = new Date(req.query.to);
    }

    const [transactions, total] = await Promise.all([
      Transaction.find(filter).sort({ date: -1 }).skip(skip).limit(limit),
      Transaction.countDocuments(filter),
    ]);

    res.json({
      success: true,
      data: transactions.map(toFlutterTransaction),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNext: page * limit < total,
        hasPrev: page > 1,
      },
    });
  } catch (err) {
    console.error("GET /transactions error:", err);
    res.status(500).json({ success: false, message: "Failed to fetch transactions" });
  }
});

// ── POST /transactions ─────────────────────────────────────────────────────
// Create a new transaction.
//
// Body: { title, amount, type, category, date? }
router.post("/", async (req, res) => {
  try {
    const { title, amount, type, category, date } = req.body;

    // Validation
    const errors = [];
    if (!title || typeof title !== "string" || !title.trim()) {
      errors.push("title is required");
    }
    if (amount === undefined || isNaN(Number(amount)) || Number(amount) <= 0) {
      errors.push("amount must be a positive number");
    }
    if (!type || !["income", "expense"].includes(type)) {
      errors.push("type must be 'income' or 'expense'");
    }
    if (!category || typeof category !== "string" || !category.trim()) {
      errors.push("category is required");
    }
    if (date && isNaN(Date.parse(date))) {
      errors.push("date must be a valid ISO date string");
    }

    if (errors.length > 0) {
      return res.status(400).json({ success: false, message: errors.join("; ") });
    }

    const tx = await Transaction.create({
      userId: req.user.userId,
      title: title.trim(),
      amount: Number(amount),
      type,
      category: category.trim(),
      date: date ? new Date(date) : new Date(),
    });

    res.status(201).json({
      success: true,
      message: "Transaction created",
      data: toFlutterTransaction(tx),
    });
  } catch (err) {
    console.error("POST /transactions error:", err);
    res.status(500).json({ success: false, message: "Failed to create transaction" });
  }
});

// ── PUT /transactions/:id ──────────────────────────────────────────────────
// Update an existing transaction (partial update — only provided fields change).
//
// Body: { title?, amount?, type?, category?, date? }
router.put("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, message: "Invalid transaction id" });
    }

    const tx = await Transaction.findOne({ _id: id, userId: req.user.userId });
    if (!tx) {
      return res.status(404).json({ success: false, message: "Transaction not found" });
    }

    const { title, amount, type, category, date } = req.body;
    const errors = [];

    if (title !== undefined) {
      if (typeof title !== "string" || !title.trim()) errors.push("title cannot be empty");
      else tx.title = title.trim();
    }
    if (amount !== undefined) {
      if (isNaN(Number(amount)) || Number(amount) <= 0) errors.push("amount must be a positive number");
      else tx.amount = Number(amount);
    }
    if (type !== undefined) {
      if (!["income", "expense"].includes(type)) errors.push("type must be 'income' or 'expense'");
      else tx.type = type;
    }
    if (category !== undefined) {
      if (typeof category !== "string" || !category.trim()) errors.push("category cannot be empty");
      else tx.category = category.trim();
    }
    if (date !== undefined) {
      if (isNaN(Date.parse(date))) errors.push("date must be a valid ISO date string");
      else tx.date = new Date(date);
    }

    if (errors.length > 0) {
      return res.status(400).json({ success: false, message: errors.join("; ") });
    }

    await tx.save();

    res.json({
      success: true,
      message: "Transaction updated",
      data: toFlutterTransaction(tx),
    });
  } catch (err) {
    console.error("PUT /transactions/:id error:", err);
    res.status(500).json({ success: false, message: "Failed to update transaction" });
  }
});

// ── DELETE /transactions/:id ───────────────────────────────────────────────
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, message: "Invalid transaction id" });
    }

    const tx = await Transaction.findOneAndDelete({ _id: id, userId: req.user.userId });
    if (!tx) {
      return res.status(404).json({ success: false, message: "Transaction not found" });
    }

    res.json({ success: true, message: "Transaction deleted", id });
  } catch (err) {
    console.error("DELETE /transactions/:id error:", err);
    res.status(500).json({ success: false, message: "Failed to delete transaction" });
  }
});

module.exports = router;
