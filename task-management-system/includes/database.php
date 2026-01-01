<?php
require_once __DIR__ . '/../vendor/autoload.php';

// Load environment variables if .env file exists
if (file_exists(__DIR__ . '/../.env')) {
    $dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
    $dotenv->load();
}

// Get database connection details from environment variables or use defaults
$servername = $_ENV['DB_HOST'] ?? getenv('DB_HOST');
$username = $_ENV['DB_USER'] ?? getenv('DB_USER');
$password = $_ENV['DB_PASS'] ?? getenv('DB_PASS');
$dbname = $_ENV['DB_NAME'] ?? $_ENV['DB_DATABASE'] ?? getenv('DB_NAME') ?? getenv('DB_DATABASE') ?? 'task_manager';
$port = $_ENV['DB_PORT'] ?? getenv('DB_PORT') ?? '1433';

// Build SQL Server connection string for Azure SQL
// Format: sqlsrv:Server=server,port;Database=database
// Valid keywords: Server, Database, Encrypt, TrustServerCertificate
// Note: LoginTimeout is set via PDO options, not DSN string
$connectionString = "sqlsrv:Server=" . $servername . "," . $port . ";Database=" . $dbname . ";Encrypt=yes;TrustServerCertificate=no;";

try {
    // Create PDO connection for SQL Server
    $conn = new PDO($connectionString, $username, $password, array(
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::SQLSRV_ATTR_ENCODING => PDO::SQLSRV_ENCODING_UTF8,
        PDO::SQLSRV_ATTR_QUERY_TIMEOUT => 30
    ));
} catch (PDOException $e) {
    error_log("Database connection failed: " . $e->getMessage());
    die("Connection failed: " . $e->getMessage());
}