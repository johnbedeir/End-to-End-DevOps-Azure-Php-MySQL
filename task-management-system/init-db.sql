CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password VARCHAR(255) NOT NULL
);

CREATE TABLE tasks (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT,
    task VARCHAR(255) NOT NULL,
    due_date DATE,
    completed BIT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
