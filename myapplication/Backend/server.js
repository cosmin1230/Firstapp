const express = require("express");
const cors = require("cors");
const authRoutes = require("./routes/auth");
const orderRoutes = require("./routes/order");

const app = express();
const PORT = 3000;

// Middleware
app.use(express.json());
app.use(cors());

// Routes
app.use("/auth", authRoutes);
app.use("/order", orderRoutes);

// Default route
app.get("/", (req, res) => {
    res.send("Backend for PC Parts App");
});

// Comment to trigger change
// Start the server
app.listen(PORT, () => {
    console.log(`Backend running on http://localhost:${PORT}`);
});
