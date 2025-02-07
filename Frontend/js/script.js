document.addEventListener("DOMContentLoaded", () => {
    const logoutLink = document.getElementById("logout");
    const welcomeMessage = document.getElementById("welcomeMessage");
    const authMessage = document.getElementById("authMessage");
    const orderForm = document.getElementById("orderForm");
    const loginForm = document.getElementById("loginForm");

    // Function to show login form dynamically
    function showLoginForm() {
        if (authMessage) {
            authMessage.style.display = "block";
        }
        if (loginForm) {
            loginForm.style.display = "block";
        }
    }

    // Function to hide login form and show welcome message
    function showWelcomeMessage(username) {
        if (loginForm) {
            loginForm.style.display = "none";
        }
        if (welcomeMessage) {
            welcomeMessage.textContent = `Welcome, ${username}!`;
            welcomeMessage.style.display = "block";
        }
        if (logoutLink) {
            logoutLink.style.display = "block";
        }
        if (orderForm) {
            orderForm.style.display = "block";
        }
    }

    // Check authentication status
    fetch("http://backend.local:8080/auth", {  // Ensure the backend URL matches
        method: "GET",
        headers: { "Content-Type": "application/json" },
    })
        .then((response) => response.json())
        .then((data) => {
            console.log("Auth status response:", data);
            if (data.authenticated) {
                // If authenticated, show the welcome message and order form
                showWelcomeMessage(data.username);
            } else {
                // If not authenticated, show login form
                showLoginForm();
            }
        })
        .catch((error) => {
            console.error("Error fetching auth status:", error);
            // If there is an error fetching authentication status, show login form
            showLoginForm();
        });

    // Handle login form submission
    if (loginForm) {
        loginForm.addEventListener("submit", (e) => {
            e.preventDefault();
            const username = document.getElementById("username").value;
            const password = document.getElementById("password").value;
            console.log("Login form submitted:", username, password);

            // Send login request to backend
            fetch("http://backend.local:8080/auth/login", {  // Ensure the backend URL matches
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username, password }),
            })
                .then((response) => response.json())
                .then((data) => {
                    console.log("Login response:", data);
                    if (data.message === "Login successful") {
                        alert("Login successful!");
                        showWelcomeMessage(data.username); // Show welcome message after successful login
                    } else {
                        alert(data.message);
                    }
                })
                .catch((error) => {
                    console.error("Login error:", error);
                    alert("Login failed. Please try again.");
                });
        });
    }

    // Handle logout
    if (logoutLink) {
        logoutLink.addEventListener("click", () => {
            console.log("Logout clicked");
            // Send logout request to backend
            fetch("http://backend.local:8080/auth/logout", {  // Ensure the backend URL matches
                method: "POST",
                headers: { "Content-Type": "application/json" },
            })
                .then(() => {
                    alert("Logged out successfully");
                    window.location.reload();  // Reload the page after logout
                })
                .catch((error) => {
                    console.error("Logout error:", error);
                    alert("Error logging out. Please try again.");
                });
        });
    }

    // Handle order form submission
    if (orderForm) {
        orderForm.addEventListener("submit", (e) => {
            e.preventDefault();
            const part = document.getElementById("part").value;
            const quantity = document.getElementById("quantity").value;
            console.log("Order form submitted:", { part, quantity });

            // Send order request to backend
            fetch("http://backend.local:8080/order/submit", {  // Ensure the backend URL matches
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ part, quantity }),
            })
                .then((response) => response.json())
                .then((data) => {
                    console.log("Order response:", data);
                    if (data.message) {
                        alert(data.message);
                    }
                })
                .catch((error) => {
                    console.error("Order error:", error);
                    alert("Order failed. Please try again.");
                });
        });
    }
});