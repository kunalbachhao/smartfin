const express = require("express");
const Transaction = require("../models/Transaction");
const Account = require("../models/Account");
const authMiddleware = require("../middleware/auth");

const router = express.Router();
router.use(authMiddleware);

// ── GET /analytics ─────────────────────────────────────────────────────────
//
// Computes all financial analytics for the authenticated user dynamically
// from the Transaction and Account collections.
//
// Optional query params:
//   from  (ISO date — start of period, default: start of current month)
//   to    (ISO date — end of period,   default: now)
//
// Response shape matches Flutter's AnalyticsData model:
// {
//   totalBalance:      "$X,XXX.XX"   (total income in period)
//   netPerformance:    "+X.X%"       ((income - expenses) / income)
//   monthlyUsageRatio: 0.68          (expenses / income, clamped 0–1)
//   legendEntries: [
//     { title: "Fixed Costs", amount: "$X,XXX", color: "blue" },
//     { title: "Lifestyle",   amount: "$X,XXX", color: "teal" }
//   ]
//   categories: [
//     { title: "Rent", amount: "$X,XXX.XX", progress: 0.85, color: "teal" }
//   ]
//   summary: {
//     totalIncome:   number,
//     totalExpenses: number,
//     netBalance:    number,
//     transactionCount: number
//   }
// }
router.get("/", async (req, res) => {
  try {
    // ── Date range ───────────────────────────────────────────────────────────
    const now = new Date();
    const defaultFrom = new Date(now.getFullYear(), now.getMonth(), 1); // start of month

    const from = req.query.from ? new Date(req.query.from) : defaultFrom;
    const to   = req.query.to   ? new Date(req.query.to)   : now;

    if (isNaN(from.getTime()) || isNaN(to.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid date range. Use ISO date strings for 'from' and 'to'.",
      });
    }

    const userId = req.user.userId;

    // ── Aggregate transactions ───────────────────────────────────────────────
    const [incomeAgg, expenseAgg, categoryAgg] = await Promise.all([
      // Total income
      Transaction.aggregate([
        { $match: { userId: toObjectId(userId), type: "income", date: { $gte: from, $lte: to } } },
        { $group: { _id: null, total: { $sum: "$amount" } } },
      ]),

      // Total expenses
      Transaction.aggregate([
        { $match: { userId: toObjectId(userId), type: "expense", date: { $gte: from, $lte: to } } },
        { $group: { _id: null, total: { $sum: "$amount" } } },
      ]),

      // Expenses grouped by category
      Transaction.aggregate([
        { $match: { userId: toObjectId(userId), type: "expense", date: { $gte: from, $lte: to } } },
        { $group: { _id: "$category", total: { $sum: "$amount" }, count: { $sum: 1 } } },
        { $sort: { total: -1 } },
      ]),
    ]);

    const totalIncome   = incomeAgg[0]?.total  ?? 0;
    const totalExpenses = expenseAgg[0]?.total ?? 0;
    const netBalance    = totalIncome - totalExpenses;

    // ── Derived metrics ──────────────────────────────────────────────────────
    const monthlyUsageRatio =
      totalIncome === 0 ? 0 : Math.min(1, totalExpenses / totalIncome);

    const netPerformancePct =
      totalIncome === 0
        ? 0
        : ((totalIncome - totalExpenses) / totalIncome) * 100;

    const netPerformance =
      (netPerformancePct >= 0 ? "+" : "") + netPerformancePct.toFixed(1) + "%";

    // ── Category bars ────────────────────────────────────────────────────────
    // progress = category_total / max_category_total (so the biggest bar = 1.0)
    const CATEGORY_COLORS = [
      "blue", "teal", "orange", "brown", "grey", "purple", "red", "green",
    ];

    const maxCategoryTotal =
      categoryAgg.length > 0 ? categoryAgg[0].total : 1;

    const categories = categoryAgg.map((cat, i) => ({
      title:    cat._id,
      amount:   formatCurrency(cat.total),
      progress: parseFloat((cat.total / maxCategoryTotal).toFixed(4)),
      color:    CATEGORY_COLORS[i % CATEGORY_COLORS.length],
    }));

    // ── Legend entries ───────────────────────────────────────────────────────
    const legendEntries = [
      { title: "Fixed Costs", amount: formatCurrency(totalExpenses), color: "blue" },
      { title: "Lifestyle",   amount: formatCurrency(totalIncome),   color: "teal" },
    ];

    // ── Transaction count ────────────────────────────────────────────────────
    const transactionCount = await Transaction.countDocuments({
      userId: toObjectId(userId),
      date: { $gte: from, $lte: to },
    });

    res.json({
      success: true,
      data: {
        totalBalance:      formatCurrency(totalIncome),
        netPerformance,
        monthlyUsageRatio: parseFloat(monthlyUsageRatio.toFixed(4)),
        legendEntries,
        categories,
        summary: {
          totalIncome,
          totalExpenses,
          netBalance,
          transactionCount,
          period: { from: from.toISOString(), to: to.toISOString() },
        },
      },
    });
  } catch (err) {
    console.error("GET /analytics error:", err);
    res.status(500).json({ success: false, message: "Failed to compute analytics" });
  }
});

// ── Helpers ────────────────────────────────────────────────────────────────

const mongoose = require("mongoose");

function toObjectId(id) {
  return new mongoose.Types.ObjectId(id);
}

function formatCurrency(value) {
  const abs = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  const [intStr, dec] = abs.toFixed(2).split(".");
  if (intStr.length <= 3) return `${sign}₹${intStr}.${dec}`;
  const last3 = intStr.slice(-3);
  const rest = intStr.slice(0, intStr.length - 3);
  const grouped = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ",");
  return `${sign}₹${grouped},${last3}.${dec}`;
}

module.exports = router;
