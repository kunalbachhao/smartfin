const jwt = require("jsonwebtoken");

/**
 * JWT authentication middleware.
 * Reads the Bearer token from the Authorization header, verifies it,
 * and attaches { userId, email } to req.user.
 *
 * Returns 401 if the token is missing, malformed, or expired.
 */
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({
      success: false,
      message: "Authorization token required",
    });
  }

  const token = authHeader.slice(7); // strip "Bearer "

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { userId: decoded.userId, email: decoded.email };
    next();
  } catch (err) {
    const message =
      err.name === "TokenExpiredError"
        ? "Token has expired. Please log in again."
        : "Invalid token. Please log in again.";

    return res.status(401).json({ success: false, message });
  }
}

module.exports = authMiddleware;
