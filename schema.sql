-- =========================================================
-- AWAKEN YOUR SKILL — Skema Database MySQL
-- =========================================================
-- Prototipe HTML/CSS/JS yang menyertai file ini menyimpan
-- data sementara di memori browser agar bisa langsung dicoba
-- tanpa server. Browser TIDAK BISA konek langsung ke MySQL,
-- jadi untuk versi produksi kamu perlu backend kecil
-- (PHP/Node.js/Express, dsb.) yang menjembatani JavaScript
-- di sisi client dengan database ini lewat REST API.
-- =========================================================

CREATE DATABASE IF NOT EXISTS awaken_your_skill
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE awaken_your_skill;

-- ---------------------------------------------------------
-- Jurusan
-- ---------------------------------------------------------
CREATE TABLE jurusan (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  kode          VARCHAR(30) NOT NULL UNIQUE,   -- contoh: 'rpl', 'tkj'
  nama          VARCHAR(100) NOT NULL,
  deskripsi     TEXT
);

-- ---------------------------------------------------------
-- User / Siswa
-- ---------------------------------------------------------
CREATE TABLE users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  nama          VARCHAR(100) NOT NULL,
  kelas         VARCHAR(50) NOT NULL,
  jurusan_id    INT NOT NULL,
  coins         INT NOT NULL DEFAULT 0,
  theme         ENUM('dark','light') NOT NULL DEFAULT 'dark',
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (jurusan_id) REFERENCES jurusan(id)
);

-- ---------------------------------------------------------
-- Games (per jurusan)
-- ---------------------------------------------------------
CREATE TABLE games (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  kode          VARCHAR(50) NOT NULL UNIQUE,   -- contoh: 'calc', 'sqldetective'
  jurusan_id    INT NOT NULL,
  judul         VARCHAR(150) NOT NULL,
  deskripsi     TEXT,
  tipe          ENUM('quiz','color','custom') NOT NULL DEFAULT 'quiz',
  reward_coin   INT NOT NULL DEFAULT 20,
  FOREIGN KEY (jurusan_id) REFERENCES jurusan(id)
);

-- Soal untuk game bertipe quiz
CREATE TABLE game_questions (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  game_id       INT NOT NULL,
  pertanyaan    TEXT NOT NULL,
  pilihan_a     VARCHAR(255) NOT NULL,
  pilihan_b     VARCHAR(255) NOT NULL,
  pilihan_c     VARCHAR(255),
  pilihan_d     VARCHAR(255),
  jawaban_benar ENUM('a','b','c','d') NOT NULL,
  FOREIGN KEY (game_id) REFERENCES games(id)
);

-- Riwayat penyelesaian game per user
CREATE TABLE game_progress (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  user_id         INT NOT NULL,
  game_id         INT NOT NULL,
  skor_benar      INT NOT NULL,
  total_soal      INT NOT NULL,
  lulus           BOOLEAN NOT NULL DEFAULT FALSE,
  coin_didapat    INT NOT NULL DEFAULT 0,
  selesai_pada    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (game_id) REFERENCES games(id)
);

-- ---------------------------------------------------------
-- Outfit / karakter
-- ---------------------------------------------------------
CREATE TABLE outfits (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  kode          VARCHAR(50) NOT NULL UNIQUE,   -- contoh: 'body-jaket'
  kategori      ENUM('body','head') NOT NULL,
  nama          VARCHAR(100) NOT NULL,
  harga_koin    INT NOT NULL DEFAULT 0
);

-- Outfit yang sudah dimiliki user
CREATE TABLE user_outfits (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  user_id       INT NOT NULL,
  outfit_id     INT NOT NULL,
  dibeli_pada   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_owned (user_id, outfit_id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (outfit_id) REFERENCES outfits(id)
);

-- Outfit yang sedang dipakai user (satu per kategori)
CREATE TABLE user_equipped (
  user_id       INT NOT NULL,
  kategori      ENUM('body','head') NOT NULL,
  outfit_id     INT NOT NULL,
  PRIMARY KEY (user_id, kategori),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (outfit_id) REFERENCES outfits(id)
);

-- ---------------------------------------------------------
-- Kunci jurusan per akun (anti bypass)
-- ---------------------------------------------------------
-- Satu akun (di prototipe: satu nama) hanya boleh terikat pada SATU
-- jurusan seumur hidup akun tersebut, supaya tidak ada yang gonta-ganti
-- jurusan berkali-kali hanya untuk mengumpulkan koin dari semua jenis
-- game. Di prototipe front-end ini ditegakkan lewat "accounts registry"
-- di memori JS. Untuk backend sungguhan, tegakkan juga di database
-- lewat trigger supaya tidak bisa dilewati walau lewat query langsung:
DELIMITER $$
CREATE TRIGGER prevent_jurusan_change
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
  IF NEW.jurusan_id <> OLD.jurusan_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Jurusan tidak dapat diubah setelah akun dibuat.';
  END IF;
END$$
DELIMITER ;

-- Catatan: nama siswa saja mudah dipalsukan/diketik ulang untuk membuat
-- "akun baru". Untuk produksi sesungguhnya, tambahkan kolom identitas unik
-- yang sulit diduplikasi, misalnya NISN, lalu jadikan UNIQUE:
--   ALTER TABLE users ADD COLUMN nisn VARCHAR(20) UNIQUE;
-- dan gunakan NISN (bukan nama) sebagai kunci login/akun.

-- ---------------------------------------------------------
-- Contoh data awal jurusan
-- ---------------------------------------------------------
INSERT INTO jurusan (kode, nama, deskripsi) VALUES
('elektro', 'Teknik Elektronika Industri', 'Mempelajari sistem kontrol dan perawatan alat industri.'),
('pemesinan', 'Teknik Pemesinan', 'Mempelajari cara kerja mesin produksi dan logam.'),
('gambarmesin', 'Teknik Gambar Mesin', 'Mempelajari perancangan dan desain teknik menggunakan komputer.'),
('tkr', 'Teknik Kendaraan Ringan', 'Mempelajari perbaikan dan perawatan mobil.'),
('tkj', 'Teknik Komputer Jaringan', 'Mempelajari instalasi jaringan komputer dan internet.'),
('multimedia', 'Multimedia', 'Mempelajari desain grafis, animasi, dan video.'),
('rpl', 'Rekayasa Perangkat Lunak', 'Mempelajari pembuatan aplikasi dan pemrograman.'),
('tekstil', 'Tekstil', 'Mempelajari bahan, pewarnaan, dan pembuatan produk tekstil.');

-- ---------------------------------------------------------
-- Catatan soal acak (RNG)
-- ---------------------------------------------------------
-- Di prototipe front-end, tiap game punya "pool" soal yang lebih
-- besar dari jumlah yang ditampilkan per sesi main; soal dan urutan
-- pilihan jawaban diacak tiap kali mulai. Di backend nyata, ini
-- diterjemahkan menjadi: simpan semua soal per game di
-- `game_questions`, lalu saat user mulai main, query mengambil
-- N baris acak, misalnya:
--   SELECT * FROM game_questions WHERE game_id = ? ORDER BY RAND() LIMIT 5;
-- dan urutan pilihan a/b/c/d diacak di sisi aplikasi sebelum dikirim
-- ke client (bukan disimpan acak permanen di database).
