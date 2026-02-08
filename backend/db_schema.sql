CREATE DATABASE IF NOT EXISTS ayurveda_db;
USE ayurveda_db;

CREATE TABLE IF NOT EXISTS patients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    age INT,
    gender VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT,
    video_path VARCHAR(255),
    test_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    spreading_speed FLOAT, -- Area change per second
    spreading_direction VARCHAR(50), -- e.g., 'North', 'South-East'
    shape_detected VARCHAR(50), -- e.g., 'Snake', 'Pearl', 'Ring'
    image_result_path VARCHAR(255),
    FOREIGN KEY (patient_id) REFERENCES patients(id)
);
