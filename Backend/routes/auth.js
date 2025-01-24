const express = require("express");
const router = express.Router();

// Simulated user database
const users = { admin: "1234" };

// Authentication status
let authenticatedUser = null;

// Login endpoint
router.post("/login", (req, res) => {
    const { username, password } = req.body;

    if (users[username] === password) {
        authenticatedUser = username;
        res.status(200).json({ message: "Login successful", username });
    } else {
        res.status(401).json({ message: "Invalid credentials" });
    }
});

// Check authentication status
router.get("/", (req, res) => {
    if (authenticatedUser) {
        res.status(200).json({ authenticated: true, username: authenticatedUser });
    } else {
        res.status(401).json({ authenticated: false });
    }
});

// Logout endpoint
router.post("/logout", (req, res) => {
    authenticatedUser = null;
    res.status(200).json({ message: "Logout successful" });
});

module.exports = router;
