require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const nodemailer = require("nodemailer");

const app = express();
const PORT = process.env.PORT || 3000;

// ================= MIDDLEWARE =================
app.use(cors());
app.use(express.json());

// Logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Rate limiting for OTP
const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 requests per window
  message: { message: "Too many OTP requests. Please try again later." }
});

// ================= MONGODB CONNECTION =================
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("✅ Connected to MongoDB Atlas"))
  .catch((err) => {
    console.error("❌ MongoDB Connection Error:", err.message);
    process.exit(1);
  });

// ================= GMAIL SETUP =================
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_APP_PASSWORD
  }
});

// Verify Gmail connection
transporter.verify((error, success) => {
  if (error) {
    console.error("\n❌ Gmail Configuration Error:", error.message);
    console.log("\n📧 HOW TO FIX:");
    console.log("1. Go to: https://myaccount.google.com/security");
    console.log("2. Enable 2-Step Verification");
    console.log("3. Go to: https://myaccount.google.com/apppasswords");
    console.log("4. Generate an app password");
    console.log("5. Copy the 16-character password");
    console.log("6. Paste it in EMAIL_APP_PASSWORD in .env file\n");
  } else {
    console.log("✅ Gmail is ready to send emails");
  }
});

// ================= MONGOOSE SCHEMAS =================
const UserSchema = new mongoose.Schema({
  email: { 
    type: String, 
    required: true, 
    unique: true, 
    lowercase: true,
    trim: true
  },
  password: { 
    type: String, 
    required: true 
  },
  verified: { 
    type: Boolean, 
    default: true 
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

const User = mongoose.model("User", UserSchema);

const OtpSchema = new mongoose.Schema({
  email: { 
    type: String, 
    required: true, 
    lowercase: true 
  },
  otpHash: { 
    type: String, 
    required: true 
  },
  hashedPassword: { 
    type: String, 
    required: true 
  },
  attempts: { 
    type: Number, 
    default: 0,
    max: 3
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  expiresAt: { 
    type: Date, 
    required: true,
    index: { expireAfterSeconds: 0 }
  }
});

const Otp = mongoose.model("Otp", OtpSchema);

// ================= UTILITY FUNCTIONS =================
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function getOTPEmailTemplate(otp, userName = "User") {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          padding: 40px 20px;
        }
        .container {
          max-width: 500px;
          margin: 0 auto;
          background: white;
          border-radius: 20px;
          box-shadow: 0 20px 40px rgba(0,0,0,0.1);
          overflow: hidden;
        }
        .header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 40px 30px;
          text-align: center;
        }
        .header h1 {
          font-size: 28px;
          margin-bottom: 10px;
        }
        .header p {
          opacity: 0.9;
          font-size: 16px;
        }
        .content {
          padding: 40px 30px;
        }
        .greeting {
          font-size: 18px;
          color: #333;
          margin-bottom: 20px;
        }
        .otp-container {
          background: #f8f9fa;
          border: 2px dashed #667eea;
          border-radius: 15px;
          padding: 25px;
          text-align: center;
          margin: 30px 0;
        }
        .otp-label {
          font-size: 14px;
          color: #666;
          margin-bottom: 10px;
          text-transform: uppercase;
          letter-spacing: 1px;
        }
        .otp-code {
          font-size: 40px;
          font-weight: bold;
          color: #667eea;
          letter-spacing: 8px;
          font-family: 'Courier New', monospace;
        }
        .timer {
          display: inline-block;
          background: #fef3c7;
          color: #92400e;
          padding: 8px 16px;
          border-radius: 20px;
          font-size: 14px;
          margin-top: 20px;
        }
        .warning {
          background: #fee2e2;
          border-left: 4px solid #ef4444;
          padding: 15px;
          margin: 30px 0;
          border-radius: 5px;
        }
        .warning-title {
          color: #dc2626;
          font-weight: bold;
          margin-bottom: 5px;
        }
        .warning-text {
          color: #7f1d1d;
          font-size: 14px;
        }
        .footer {
          background: #f8f9fa;
          padding: 30px;
          text-align: center;
          color: #666;
          font-size: 13px;
        }
        .footer a {
          color: #667eea;
          text-decoration: none;
        }
        .divider {
          height: 1px;
          background: #e5e7eb;
          margin: 20px 0;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🔐 Verification Required</h1>
          <p>Secure your account with OTP verification</p>
        </div>
        
        <div class="content">
          <div class="greeting">
            Hello ${userName}! 👋
          </div>
          
          <p style="color: #666; line-height: 1.6;">
            You've requested to create an account. Please use the verification code below to complete your registration:
          </p>
          
          <div class="otp-container">
            <div class="otp-label">Your OTP Code</div>
            <div class="otp-code">${otp}</div>
            <div class="timer">⏰ Valid for 10 minutes</div>
          </div>
          
          <div class="warning">
            <div class="warning-title">⚠️ Security Notice</div>
            <div class="warning-text">
              Never share this code with anyone. Our team will never ask for this code via phone, email, or any other medium.
            </div>
          </div>
          
          <div class="divider"></div>
          
          <p style="color: #666; font-size: 14px; line-height: 1.6;">
            If you didn't request this verification code, please ignore this email. Your account security is our top priority.
          </p>
        </div>
        
        <div class="footer">
          <p>This is an automated message, please do not reply.</p>
          <p style="margin-top: 10px;">
            © ${new Date().getFullYear()} Your App. All rights reserved.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
}

async function sendOTPEmail(email, otp) {
  try {
    const mailOptions = {
      from: {
        name: "Your App",
        address: process.env.EMAIL_USER
      },
      to: email,
      subject: "🔐 Your OTP Verification Code",
      text: `Your OTP verification code is: ${otp}. This code will expire in 10 minutes. Never share this code with anyone.`,
      html: getOTPEmailTemplate(otp, email.split('@')[0])
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`✅ OTP email sent to ${email} (Message ID: ${info.messageId})`);
    return true;
  } catch (error) {
    console.error("❌ Email sending failed:", error.message);
    throw error;
  }
}

// ================= API ROUTES =================

// Health check endpoint
app.get("/", (req, res) => {
  res.json({
    message: "OTP Authentication Server",
    status: "Running",
    endpoints: {
      health: "GET /health",
      signup: "POST /signup-init",
      verify: "POST /verify-signup",
      resend: "POST /resend-otp",
      login: "POST /login"
    }
  });
});

// Detailed health check
app.get("/health", async (req, res) => {
  try {
    // Check MongoDB connection
    const mongoStatus = mongoose.connection.readyState === 1 ? "connected" : "disconnected";
    
    // Check Gmail
    let emailStatus = "configured";
    try {
      await transporter.verify();
    } catch (error) {
      emailStatus = "error";
    }

    res.json({
      status: "OK",
      timestamp: new Date().toISOString(),
      services: {
        mongodb: mongoStatus,
        email: emailStatus,
        server: "running"
      },
      environment: {
        port: PORT,
        nodeVersion: process.version
      }
    });
  } catch (error) {
    res.status(503).json({
      status: "ERROR",
      error: error.message
    });
  }
});

// SIGNUP - Step 1: Send OTP
app.post("/signup-init", otpLimiter, async (req, res) => {
  try {
    let { email, password } = req.body;

    // Validation
    if (!email || !password) {
      return res.status(400).json({ 
        success: false,
        message: "Email and password are required" 
      });
    }

    email = email.toLowerCase().trim();

    if (!validateEmail(email)) {
      return res.status(400).json({ 
        success: false,
        message: "Please provide a valid email address" 
      });
    }

    if (password.length < 6) {
      return res.status(400).json({ 
        success: false,
        message: "Password must be at least 6 characters long" 
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ 
        success: false,
        message: "An account with this email already exists" 
      });
    }

    // Generate OTP and hash password
    const otp = generateOTP();
    const otpHash = await bcrypt.hash(otp, 10);
    const hashedPassword = await bcrypt.hash(password, 10);

    // Save or update OTP record
    await Otp.findOneAndUpdate(
      { email },
      {
        email,
        otpHash,
        hashedPassword,
        attempts: 0,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000) // 10 minutes
      },
      { upsert: true, new: true }
    );

    // Send OTP email
    await sendOTPEmail(email, otp);

    res.json({
      success: true,
      message: "Verification code sent to your email",
      email: email
    });

  } catch (error) {
    console.error("Signup error:", error);
    
    // Clean up on error
    if (req.body.email) {
      await Otp.deleteOne({ email: req.body.email.toLowerCase().trim() });
    }
    
    res.status(500).json({ 
      success: false,
      message: "Failed to process signup. Please try again." 
    });
  }
});

// SIGNUP - Step 2: Verify OTP
app.post("/verify-signup", async (req, res) => {
  try {
    let { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ 
        success: false,
        message: "Email and verification code are required" 
      });
    }

    email = email.toLowerCase().trim();
    code = code.trim();

    // Find OTP record
    const otpRecord = await Otp.findOne({ email });

    if (!otpRecord) {
      return res.status(400).json({ 
        success: false,
        message: "Verification code expired or invalid. Please request a new one." 
      });
    }

    // Check if max attempts exceeded
    if (otpRecord.attempts >= 3) {
      await Otp.deleteOne({ email });
      return res.status(429).json({ 
        success: false,
        message: "Too many failed attempts. Please request a new code." 
      });
    }

    // Verify OTP
    const isValidOTP = await bcrypt.compare(code, otpRecord.otpHash);

    if (!isValidOTP) {
      // Increment attempts
      otpRecord.attempts += 1;
      await otpRecord.save();
      
      return res.status(400).json({ 
        success: false,
        message: "Invalid verification code",
        attemptsLeft: 3 - otpRecord.attempts 
      });
    }

    // Create new user
    const newUser = await User.create({
      email,
      password: otpRecord.hashedPassword,
      verified: true
    });

    // Delete OTP record
    await Otp.deleteOne({ email });

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: newUser._id, 
        email: newUser.email 
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.status(201).json({
      success: true,
      message: "Account created successfully!",
      token,
      user: {
        id: newUser._id,
        email: newUser.email
      }
    });

  } catch (error) {
    console.error("Verification error:", error);
    res.status(500).json({ 
      success: false,
      message: "Verification failed. Please try again." 
    });
  }
});

// RESEND OTP
app.post("/resend-otp", otpLimiter, async (req, res) => {
  try {
    let { email } = req.body;

    if (!email) {
      return res.status(400).json({ 
        success: false,
        message: "Email is required" 
      });
    }

    email = email.toLowerCase().trim();

    // Find existing OTP record
    const otpRecord = await Otp.findOne({ email });

    if (!otpRecord) {
      return res.status(404).json({ 
        success: false,
        message: "No pending signup found. Please start the signup process." 
      });
    }

    // Generate new OTP
    const newOTP = generateOTP();
    otpRecord.otpHash = await bcrypt.hash(newOTP, 10);
    otpRecord.attempts = 0;
    otpRecord.expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    await otpRecord.save();

    // Send new OTP
    await sendOTPEmail(email, newOTP);

    res.json({
      success: true,
      message: "New verification code sent to your email",
      email: email
    });

  } catch (error) {
    console.error("Resend OTP error:", error);
    res.status(500).json({ 
      success: false,
      message: "Failed to resend verification code" 
    });
  }
});

// LOGIN
app.post("/login", async (req, res) => {
  try {
    let { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ 
        success: false,
        message: "Email and password are required" 
      });
    }

    email = email.toLowerCase().trim();

    // Find user
    const user = await User.findOne({ email });

    if (!user) {
      return res.status(401).json({ 
        success: false,
        message: "Invalid email or password" 
      });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({ 
        success: false,
        message: "Invalid email or password" 
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user._id, 
        email: user.email 
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      success: true,
      message: "Login successful",
      token,
      user: {
        id: user._id,
        email: user.email
      }
    });

  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ 
      success: false,
      message: "Login failed. Please try again." 
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Endpoint not found",
    path: req.path
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({
    success: false,
    message: "Internal server error"
  });
});

// ================= START SERVER =================
const server = app.listen(PORT, "0.0.0.0", () => {
  console.log("\n================================================");
  console.log("🚀 OTP Authentication Server Started");
  console.log("================================================");
  console.log(`📡 Port: ${PORT}`);
  console.log(`🌐 URL: http://localhost:${PORT}`);
  console.log(`📧 Email: ${process.env.EMAIL_USER || "Not configured"}`);
  console.log(`🗄️  Database: MongoDB Atlas`);
  console.log("================================================");
  console.log("\n📝 Available Endpoints:");
  console.log("  GET  /         - Server info");
  console.log("  GET  /health   - Health check");
  console.log("  POST /signup-init    - Start signup (send OTP)");
  console.log("  POST /verify-signup  - Verify OTP");
  console.log("  POST /resend-otp     - Resend OTP");
  console.log("  POST /login          - User login");
  console.log("================================================\n");
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM signal received: closing HTTP server");
  server.close(() => {
    console.log("HTTP server closed");
    mongoose.connection.close(false, () => {
      console.log("MongoDB connection closed");
      process.exit(0);
    });
  });
});