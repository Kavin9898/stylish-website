const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const path = require("path");
require("dotenv").config();

const app = express();

app.use(cors());
app.use(express.json());

/* ===============================
   DATABASE CONNECTION (AWS RDS)
================================= */

const db = mysql.createConnection({
    host: process.env.DB_HOST,        // RDS endpoint
    user: process.env.DB_USER,        // DB username
    password: process.env.DB_PASSWORD,// DB password
    database: "webshop"
});

db.connect((err) => {
    if (err) {
        console.error("❌ Database connection failed:", err);
    } else {
        console.log("✅ Connected to RDS MySQL");
    }
});

/* ===============================
   CREATE TABLE (if not exists)
================================= */

const createTableQuery = `
CREATE TABLE IF NOT EXISTS contacts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(150),
    subject VARCHAR(200),
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)`;

db.query(createTableQuery, (err) => {
    if (err) {
        console.error("Table creation error:", err);
    } else {
        console.log("✅ Contacts table ready");
    }
});

/* ===============================
   SAVE CONTACT FORM
================================= */

app.post("/contact", (req, res) => {
    const { name, email, subject, message } = req.body;

    if (!name || !email || !message) {
        return res.status(400).json({ message: "Required fields missing" });
    }

    const sql = `
        INSERT INTO contacts (name, email, subject, message)
        VALUES (?, ?, ?, ?)
    `;

    db.query(sql, [name, email, subject, message], (err) => {
        if (err) {
            console.error("Insert error:", err);
            return res.status(500).json({ message: "Database error" });
        }

        res.json({ message: "Message saved successfully!" });
    });
});

/* ===============================
   GET ALL CONTACTS (Admin API)
================================= */

app.get("/contacts", (req, res) => {
    db.query("SELECT * FROM contacts ORDER BY created_at DESC", (err, results) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: "Database error" });
        }

        res.json(results);
    });
});

/* ===============================
   SERVE FRONTEND
================================= */

app.use(express.static(path.join(__dirname, "..")));

app.get("*", (req, res) => {
    res.sendFile(path.join(__dirname, "../index.html"));
});

/* ===============================
   START SERVER
================================= */

const PORT = 5000;

app.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running on port ${PORT}`);
});
