-- =============================================
-- INIT SQL — Kamsis Database
-- Dijalankan otomatis saat MySQL pertama kali start
-- =============================================

-- Pastikan database kamsis ada
CREATE DATABASE IF NOT EXISTS kamsis;
USE kamsis;

-- Tabel users sesuai struct User di main.go
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(100) NOT NULL,
    nim VARCHAR(20) NOT NULL UNIQUE,
    asal_kampus VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    umur INT NOT NULL CHECK (umur >= 1 AND umur <= 100),
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Grant privileges ke appuser (sesuai docker-compose.yaml)
-- MySQL image otomatis buat user dari env var, tapi pastikan privileges benar
GRANT ALL PRIVILEGES ON kamsis.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
