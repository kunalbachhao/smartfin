const mongoose = require("mongoose");

/**
 * Account document.
 *
 * Flutter mapping:
 *   _id     → AccountModel.id (String)
 *   name    → AccountModel.title
 *   number  → AccountModel.number  (last 4 digits, stored as "**** XXXX")
 *   balance → AccountModel.balance (numeric; formatted on Flutter side)
 *   userId  → owner reference (never sent to client)
 */
const AccountSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 80,
    },
    number: {
      type: String,
      required: true,
      trim: true,
      maxlength: 20,
    },
    balance: {
      type: Number,
      required: true,
      default: 0,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Account", AccountSchema);
