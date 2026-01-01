<?php
session_start();

// Include database connection and functions
include '../includes/database.php';
include '../includes/functions.php';

// Redirect to login if not logged in
if (!isset($_SESSION['user_id'])) {
    header("Location: login.php");
    exit();
}

$userId = $_SESSION['user_id'];

// Handle form submission
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['title'])) {
    $title = $_POST['title'] ?? '';
    $description = $_POST['description'] ?? '';
    
    // Combine title and description for the task field (since DB only has 'task' field)
    // Or you can use just the title/description based on your preference
    $task = trim($title . " - " . $description);
    
    if (!empty($task)) {
        try {
            // Insert task into database
            $stmt = $conn->prepare("INSERT INTO tasks (user_id, task) VALUES (?, ?)");
            $result = $stmt->execute([$userId, $task]);
            
            if ($result) {
                // Redirect back to dashboard on success
                header("Location: dashboard.php");
                exit();
            } else {
                $error = "Failed to add task.";
            }
        } catch (PDOException $e) {
            error_log("Add task failed: " . $e->getMessage());
            $error = "An error occurred while adding the task.";
        }
    } else {
        $error = "Task cannot be empty.";
    }
} else {
    // If not POST, redirect to dashboard
    header("Location: dashboard.php");
    exit();
}

