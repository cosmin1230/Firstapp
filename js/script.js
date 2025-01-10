// script.js

// Form validation for order page
document.querySelector("form").addEventListener("submit", function (e) {
    const quantity = document.getElementById("quantity").value;
    if (quantity <= 0) {
        alert("Please enter a valid quantity.");
        e.preventDefault();  // Prevent the form from submitting
    }
});

