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

// Handle task deletion
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['task_id'])) {
    $taskId = $_POST['task_id'];
    
    try {
        // Delete task only if it belongs to the current user
        $stmt = $conn->prepare("DELETE FROM tasks WHERE id = ? AND user_id = ?");
        $result = $stmt->execute([$taskId, $userId]);
        
        if ($result) {
            // Redirect back to dashboard on success
            header("Location: dashboard.php");
            exit();
        } else {
            $error = "Failed to delete task.";
        }
    } catch (PDOException $e) {
        error_log("Delete task failed: " . $e->getMessage());
        $error = "An error occurred while deleting the task.";
    }
} else {
    // If not POST or no task_id, redirect to dashboard
    header("Location: dashboard.php");
    exit();
}

