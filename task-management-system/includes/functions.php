<?php
include 'database.php';

//User Register

function registerUser($username, $password) {
    global $conn;

    try {
        // Hash the password for security
        $hashed_password = password_hash($password, PASSWORD_DEFAULT);

        // Prepare SQL statement to prevent SQL injection
        $stmt = $conn->prepare("INSERT INTO users (username, password) VALUES (?, ?)");
        $result = $stmt->execute([$username, $hashed_password]);
        
        return $result;
    } catch (PDOException $e) {
        error_log("Register failed: " . $e->getMessage());
        return false;
    }
}

// User Login - returns user ID on success, false on failure
function checkLogin($username, $password) {
    global $conn;

    try {
        // Prepare SQL to get both id and password
        $stmt = $conn->prepare("SELECT id, password FROM users WHERE username = ?");
        $stmt->execute([$username]);
        
        // Fetch result
        $row = $stmt->fetch();
        
        if ($row && isset($row['password'])) {
            // Verify password
            if (password_verify($password, $row['password'])) {
                return $row['id']; // Return user ID on successful login
            }
        }
        
        return false;
    } catch (PDOException $e) {
        error_log("Login failed: " . $e->getMessage());
        return false;
    }
}

?>
