const express = require("express");
const mongoose = require("mongoose");
const Account = require("../models/Account");
const authMiddleware = require("../middleware/auth");

const router = express.Router();
router.use(authMiddleware);

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Formats a number using the Indian numbering system with ₹ symbol.
 * e.g. 100000 → "1,00,000.00"
 */
function formatIndian(value) {
  const abs  = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  const [intStr, dec] = abs.toFixed(2).split(".");
  if (intStr.length <= 3) return `${sign}${intStr}.${dec}`;
  const last3 = intStr.slice(-3);
  const rest  = intStr.slice(0, intStr.length - 3);
  const grouped = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ",");
  return `${sign}${grouped},${last3}.${dec}`;
}

// ── Helper ─────────────────────────────────────────────────────────────────

/**
 * Converts an Account document to the JSON shape Flutter expects.
 *
 * Flutter AccountModel fields: id, title, number, balance (formatted string)
 * The numeric balance is also included so Flutter can compute totals.
 */
function toFlutterAccount(doc) {
  return {
    id: doc._id.toString(),
    title: doc.name,
    number: doc.number,
    balance: `₹${formatIndian(doc.balance)}`,
    balanceValue: doc.balance,
  };
}

function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

// ── GET /accounts ──────────────────────────────────────────────────────────
router.get("/", async (req, res) => {
  try {
    const accounts = await Account.find({ userId: req.user.userId }).sort({ createdAt: 1 });

    res.json({
      success: true,
      data: accounts.map(toFlutterAccount),
    });
  } catch (err) {
    console.error("GET /accounts error:", err);
    res.status(500).json({ success: false, message: "Failed to fetch accounts" });
  }
});

// ── POST /accounts ─────────────────────────────────────────────────────────
// Body: { name, number, balance? }
router.post("/", async (req, res) => {
  try {
    const { name, number, balance } = req.body;

    const errors = [];
    if (!name || typeof name !== "string" || !name.trim()) {
      errors.push("name is required");
    }
    if (!number || typeof number !== "string" || !number.trim()) {
      errors.push("number is required (e.g. '**** 4492')");
    }
    if (balance !== undefined && isNaN(Number(balance))) {
      errors.push("balance must be a number");
    }

    if (errors.length > 0) {
      return res.status(400).json({ success: false, message: errors.join("; ") });
    }

    const account = await Account.create({
      userId: req.user.userId,
      name: name.trim(),
      number: number.trim(),
      balance: balance !== undefined ? Number(balance) : 0,
    });

    res.status(201).json({
      success: true,
      message: "Account created",
      data: toFlutterAccount(account),
    });
  } catch (err) {
    console.error("POST /accounts error:", err);
    res.status(500).json({ success: false, message: "Failed to create account" });
  }
});

// ── PUT /accounts/:id ──────────────────────────────────────────────────────
// Body: { name?, number?, balance? }
router.put("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, message: "Invalid account id" });
    }

    const account = await Account.findOne({ _id: id, userId: req.user.userId });
    if (!account) {
      return res.status(404).json({ success: false, message: "Account not found" });
    }

    const { name, number, balance } = req.body;
    const errors = [];

    if (name !== undefined) {
      if (typeof name !== "string" || !name.trim()) errors.push("name cannot be empty");
      else account.name = name.trim();
    }
    if (number !== undefined) {
      if (typeof number !== "string" || !number.trim()) errors.push("number cannot be empty");
      else account.number = number.trim();
    }
    if (balance !== undefined) {
      if (isNaN(Number(balance))) errors.push("balance must be a number");
      else account.balance = Number(balance);
    }

    if (errors.length > 0) {
      return res.status(400).json({ success: false, message: errors.join("; ") });
    }

    await account.save();

    res.json({
      success: true,
      message: "Account updated",
      data: toFlutterAccount(account),
    });
  } catch (err) {
    console.error("PUT /accounts/:id error:", err);
    res.status(500).json({ success: false, message: "Failed to update account" });
  }
});

// ── DELETE /accounts/:id ───────────────────────────────────────────────────
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({ success: false, message: "Invalid account id" });
    }

    const account = await Account.findOneAndDelete({ _id: id, userId: req.user.userId });
    if (!account) {
      return res.status(404).json({ success: false, message: "Account not found" });
    }

    res.json({ success: true, message: "Account deleted", id });
  } catch (err) {
    console.error("DELETE /accounts/:id error:", err);
    res.status(500).json({ success: false, message: "Failed to delete account" });
  }
});

module.exports = router;
