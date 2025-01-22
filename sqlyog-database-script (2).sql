-- Create the database
DROP DATABASE IF EXISTS social_media_analyzer;
CREATE DATABASE social_media_analyzer;
USE social_media_analyzer;

-- Create Users table
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,  -- Storing hashed passwords
    profile_image VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create Posts table
CREATE TABLE posts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT,
    file_path VARCHAR(255),
    file_type VARCHAR(50),
    file_size INT,
    processing_status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending',
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create Analysis table
CREATE TABLE analysis (
    id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    sentiment_score DECIMAL(4,2),  -- Range from -1.00 to 1.00
    engagement_score DECIMAL(4,2),  -- Range from 0.00 to 100.00
    readability_score DECIMAL(4,2),
    suggestions TEXT,
    keywords TEXT,
    analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create Tags table for categorizing content
CREATE TABLE tags (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create Post_Tags junction table
CREATE TABLE post_tags (
    post_id INT,
    tag_id INT,
    PRIMARY KEY (post_id, tag_id),
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create Error_Logs table for tracking issues
CREATE TABLE error_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    entity_type VARCHAR(50),  -- 'post', 'analysis', etc.
    entity_id INT,
    error_message TEXT,
    stack_trace TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create indexes for better performance
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_analysis_post_id ON analysis(post_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_post_tags_tag_id ON post_tags(tag_id);
CREATE INDEX idx_error_logs_entity ON error_logs(entity_type, entity_id);

-- Create Views
CREATE VIEW user_analytics AS
SELECT 
    u.id AS user_id,
    u.username,
    COUNT(DISTINCT p.id) AS total_posts,
    AVG(a.engagement_score) AS avg_engagement,
    AVG(a.sentiment_score) AS avg_sentiment,
    MAX(p.upload_date) AS last_post_date
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
LEFT JOIN analysis a ON p.id = a.post_id
GROUP BY u.id, u.username;

CREATE VIEW post_performance AS
SELECT 
    p.id AS post_id,
    p.user_id,
    u.username,
    p.content,
    a.sentiment_score,
    a.engagement_score,
    a.readability_score,
    GROUP_CONCAT(t.name) AS tags
FROM posts p
JOIN users u ON p.user_id = u.id
LEFT JOIN analysis a ON p.id = a.post_id
LEFT JOIN post_tags pt ON p.id = pt.post_id
LEFT JOIN tags t ON pt.tag_id = t.id
GROUP BY p.id, p.user_id, u.username, p.content, a.sentiment_score, a.engagement_score, a.readability_score;

-- Create Stored Procedures
DELIMITER //

CREATE PROCEDURE GetUserStats(IN userId INT)
BEGIN
    SELECT 
        COUNT(DISTINCT p.id) AS total_posts,
        AVG(a.engagement_score) AS avg_engagement,
        AVG(a.sentiment_score) AS avg_sentiment,
        COUNT(DISTINCT t.id) AS unique_tags_used
    FROM users u
    LEFT JOIN posts p ON u.id = p.user_id
    LEFT JOIN analysis a ON p.id = a.post_id
    LEFT JOIN post_tags pt ON p.id = pt.post_id
    LEFT JOIN tags t ON pt.tag_id = t.id
    WHERE u.id = userId;
END //

CREATE PROCEDURE AddNewPost(
    IN p_user_id INT,
    IN p_content TEXT,
    IN p_file_path VARCHAR(255),
    IN p_file_type VARCHAR(50),
    IN p_file_size INT
)
BEGIN
    INSERT INTO posts (user_id, content, file_path, file_type, file_size)
    VALUES (p_user_id, p_content, p_file_path, p_file_type, p_file_size);
    SELECT LAST_INSERT_ID() AS post_id;
END //

CREATE PROCEDURE UpdateAnalysis(
    IN p_post_id INT,
    IN p_sentiment_score DECIMAL(4,2),
    IN p_engagement_score DECIMAL(4,2),
    IN p_suggestions TEXT
)
BEGIN
    INSERT INTO analysis (post_id, sentiment_score, engagement_score, suggestions)
    VALUES (p_post_id, p_sentiment_score, p_engagement_score, p_suggestions)
    ON DUPLICATE KEY UPDATE
        sentiment_score = p_sentiment_score,
        engagement_score = p_engagement_score,
        suggestions = p_suggestions,
        last_updated = CURRENT_TIMESTAMP;
END //

DELIMITER ;

-- Insert sample data
INSERT INTO users (username, email, password) VALUES
('john_doe', 'john@example.com', 'hashed_password_1'),
('jane_smith', 'jane@example.com', 'hashed_password_2');

INSERT INTO tags (name) VALUES
('Marketing'),
('Engagement'),
('Trending'),
('Business'),
('Technology');

-- Add triggers
DELIMITER //

CREATE TRIGGER before_post_delete
BEFORE DELETE ON posts
FOR EACH ROW
BEGIN
    INSERT INTO error_logs (entity_type, entity_id, error_message)
    VALUES ('post', OLD.id, 'Post deleted');
END //

CREATE TRIGGER after_analysis_update
AFTER UPDATE ON analysis
FOR EACH ROW
BEGIN
    IF NEW.sentiment_score < -0.8 THEN
        INSERT INTO error_logs (entity_type, entity_id, error_message)
        VALUES ('analysis', NEW.id, 'Very negative sentiment detected');
    END IF;
END //

DELIMITER ;
