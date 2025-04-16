const express = require("express");
const router = express.Router();

// Order submission endpoint
router.post("/submit", (req, res) => {
    const { part, quantity } = req.body;
    console.log("Order received:", req.body);

    if (!part || quantity <= 0) {
        return res.status(400).json({ message: "Invalid order details" });
    }

    res.status(200).json({
        message: `Order for ${quantity} ${part}(s) submitted successfully!`,
    });
});

module.exports = router;