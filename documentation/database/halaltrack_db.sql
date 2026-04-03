-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3307
-- Generation Time: Mar 28, 2026 at 01:25 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `halaltrack_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `batches`
--

CREATE TABLE `batches` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `batch_id` varchar(255) NOT NULL,
  `processor_id` bigint(20) UNSIGNED NOT NULL,
  `current_holder_id` bigint(20) UNSIGNED DEFAULT NULL,
  `product_type` varchar(255) NOT NULL,
  `weight` varchar(255) NOT NULL,
  `slaughter_date` date NOT NULL,
  `origin_farm` varchar(255) NOT NULL,
  `processing_factory` varchar(255) NOT NULL,
  `current_location` varchar(255) NOT NULL,
  `qr_code_hash` varchar(255) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'Processing',
  `freshness_score` int(11) NOT NULL DEFAULT 100,
  `halal_status` enum('compliant','breached','investigation') NOT NULL DEFAULT 'compliant',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `driver_id` bigint(20) UNSIGNED DEFAULT NULL,
  `truck_plate` varchar(255) DEFAULT NULL,
  `destination_address` varchar(255) DEFAULT NULL,
  `estimated_arrival` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `batches`
--

INSERT INTO `batches` (`id`, `batch_id`, `processor_id`, `current_holder_id`, `product_type`, `weight`, `slaughter_date`, `origin_farm`, `processing_factory`, `current_location`, `qr_code_hash`, `status`, `freshness_score`, `halal_status`, `created_at`, `updated_at`, `driver_id`, `truck_plate`, `destination_address`, `estimated_arrival`) VALUES
(1, 'B-2025-001', 1, 2, 'Whole Chicken', '500kg', '2025-10-10', 'Farm A (Perak)', 'Ali Halal Factory', 'In Transit (Truck JPG 8832)', 'd6d08b44478c173328cdccf47250e1a8', 'In Transit', 98, 'compliant', '2026-01-10 22:45:00', '2026-03-06 05:50:20', 2, 'JPG 8832', 'Fresh Mart KL (Bukit Bintang)', '2026-01-11 17:34:20'),
(2, 'B-2025-004', 1, 1, 'Chicken Drumsticks', '300kg', '2025-10-12', 'Farm B (Johor)', 'Ali Halal Factory', 'Factory Cold Room B', 'c2c3cb857ce6b3f2f82b2008e65e068d', 'Processing', 99, 'compliant', '2026-01-11 06:57:26', '2026-01-11 07:04:17', NULL, NULL, NULL, NULL),
(3, 'B-2025-005', 1, 2, 'Chicken Feet', '150kg', '2025-10-13', 'Farm A (Perak)', 'Ali Halal Factory', 'Hwy E1 Northbound (Truck JPG 8832)', 'ead230ee5291127d437e4d0edfd66d16', 'In Transit', 94, 'compliant', '2026-01-11 06:57:26', '2026-01-11 06:57:26', 2, 'JPG 8832', 'Fresh Mart KL (Bukit Bintang)', '2026-01-11 17:34:20'),
(4, 'B-2025-006', 1, 3, 'Nuggets (Processed)', '500kg', '2025-10-09', 'Farm C (Kedah)', 'Ali Halal Factory', 'Fresh Mart KL - Store Room', '595c316b291dccd6f4dae676385fa6f2', 'Delivered', 90, 'compliant', '2026-01-11 06:57:26', '2026-01-11 06:57:26', 2, 'JPG 8832', 'Tesco Penang (George Town)', '2026-01-11 20:34:20'),
(5, 'B-2025-007', 1, 1, 'Whole Chicken', '1000kg', '2025-10-14', 'Farm A (Perak)', 'Ali Halal Factory', 'Processing Line 1', '55901585b7532b72c1d9ff1912e32e3f', 'Processing', 100, 'compliant', '2026-01-11 06:57:26', '2026-01-11 06:57:26', NULL, NULL, NULL, NULL),
(6, 'B-2025-008', 1, 2, 'Chicken Wings', '250kg', '2025-10-11', 'Farm B (Johor)', 'Ali Halal Factory', 'Rest Stop Tapah', '12375d84208e81acd0a5de1273cd1d9e', 'In Transit', 75, 'compliant', '2026-01-11 06:57:26', '2026-01-11 06:57:26', 2, 'JPG 8832', 'Fresh Mart KL (Bukit Bintang)', '2026-01-11 17:34:20'),
(7, 'B-2025-009', 1, 3, 'Chicken Breast', '200kg', '2025-10-08', 'Farm A (Perak)', 'Ali Halal Factory', 'Fresh Mart KL - Quarantine Zone', '3d6b5adae28967ec0afec258f8fef924', 'Delivered', 85, 'investigation', '2026-01-11 06:57:26', '2026-01-11 06:57:26', 2, 'JPG 8832', 'Fresh Mart KL (Bukit Bintang)', '2026-01-11 20:36:12'),
(8, 'B-2025-010', 1, 1, 'Whole Chicken', '2000kg', '2025-10-13', 'Farm C (Kedah)', 'Ali Halal Factory', 'Factory Loading Bay', 'c2427fbaed6fd9a4bbf3d1dfcba49693', 'Ready', 98, 'compliant', '2026-01-11 06:57:26', '2026-01-11 06:57:26', NULL, NULL, NULL, NULL),
(9, 'B-2025-101', 9, 9, 'Premium Beef Cuts', '400kg', '2025-10-20', 'Farm D (Pahang)', 'Top Halal Meat Processor', 'Cold Room A', 'c708b4d3a8d4f55c78003742b4930d20', 'Processing', 100, 'compliant', '2026-03-06 05:46:42', '2026-03-06 05:46:42', NULL, NULL, NULL, NULL),
(10, 'B-2025-102', 9, 10, 'Whole Chicken', '800kg', '2025-10-21', 'Farm E (Negeri Sembilan)', 'Top Halal Meat Processor', 'In Transit (Truck BEM 1234)', 'd1f5b1c3a7d335ebcd6df04a613fca87', 'In Transit', 96, 'compliant', '2026-03-06 05:46:42', '2026-03-06 05:46:42', 10, 'BEM 1234', 'Premium Grocers (Bangsar)', '2026-03-06 15:46:42'),
(11, 'B-2025-103', 1, 3, 'Lamb Chops', '150kg', '2025-10-18', 'Farm F (Selangor)', 'Ali Halal Factory', 'Fresh Mart KL - Meat Section', 'a7a5e8b303150d40369189ad3683e892', 'Delivered', 92, 'compliant', '2026-03-06 05:46:42', '2026-03-06 05:46:42', 2, 'JPG 8832', 'Fresh Mart KL (Bukit Bintang)', '2026-03-06 13:46:42'),
(12, 'B-2025-104', 9, 10, 'Chicken Wings', '500kg', '2025-10-22', 'Farm D (Pahang)', 'Top Halal Meat Processor', 'Rest Stop Seremban', '25c908868e74b9eaf8fdac28ee1b1037', 'In Transit', 88, 'investigation', '2026-03-06 05:46:42', '2026-03-06 05:46:42', 10, 'BEM 1234', 'Premium Grocers (Bangsar)', '2026-03-06 17:46:42'),
(13, 'B-2025-105', 1, 11, 'Beef Ribs', '200kg', '2025-10-19', 'Farm A (Perak)', 'Ali Halal Factory', 'Premium Grocers - Freezer', '71ab69d6d089770bdfb73b99a17fec8d', 'Delivered', 95, 'compliant', '2026-03-06 05:46:42', '2026-03-06 05:46:42', 10, 'BEM 1234', 'Premium Grocers (Bangsar)', '2026-03-06 13:46:42'),
(14, 'SMOKE-1773062274', 12, 12, 'Whole Chicken', '100kg', '2026-03-09', 'Farm A', 'Factory A', 'Kuala Lumpur', NULL, 'Processing', 100, 'compliant', '2026-03-09 13:17:57', '2026-03-09 13:17:57', NULL, NULL, NULL, NULL),
(15, 'SMOKE-1773062338', 13, 13, 'Whole Chicken', '100kg', '2026-03-09', 'Farm A', 'Factory A', 'Kuala Lumpur', NULL, 'Processing', 100, 'compliant', '2026-03-09 13:18:59', '2026-03-09 13:18:59', NULL, NULL, NULL, NULL),
(16, 'ROLE-1773062378', 14, 16, 'Whole Chicken', '60kg', '2026-03-09', 'Farm Z', 'Plant Z', 'Lot 12, Kuala Lumpur', NULL, 'Delivered', 100, 'compliant', '2026-03-09 13:19:39', '2026-03-09 13:19:41', 15, 'JPG1234', NULL, NULL),
(17, 'ROLECHECK-1773062607', 17, 17, 'Chicken', '10kg', '2026-03-09', 'Farm', 'Plant', 'Loc', NULL, 'Processing', 100, 'compliant', '2026-03-09 13:23:28', '2026-03-09 13:23:28', NULL, NULL, NULL, NULL),
(18, 'B-2026-201', 1, 3, 'Marinated Chicken Fillet', '420kg', '2026-03-20', 'Farm G (Perlis)', 'Ali Halal Factory', 'Fresh Mart KL - Receiving Cold Room', 'f81f9411257437ed2b67f2b3f64ff6f5', 'Delivered', 97, 'compliant', '2026-03-20 01:10:00', '2026-03-20 08:15:00', 2, 'JPG 8832', 'Fresh Mart KL (Bukit Bintang)', '2026-03-20 09:00:00'),
(19, 'B-2026-202', 9, 10, 'Frozen Chicken Cubes', '650kg', '2026-03-21', 'Farm H (Terengganu)', 'Top Halal Meat Processor', 'North-South Expressway, Seremban Bound', '2fab98512bfdb131d3ea704f2a2f91a0', 'In Transit', 84, 'investigation', '2026-03-21 00:30:00', '2026-03-21 05:10:00', 10, 'BEM 1234', 'Premium Grocers (Bangsar)', '2026-03-21 08:30:00');

-- --------------------------------------------------------

--
-- Table structure for table `checkpoints`
--

CREATE TABLE `checkpoints` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `batch_id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `location_name` varchar(255) NOT NULL,
  `latitude` decimal(10,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `temperature` decimal(5,2) NOT NULL,
  `action_type` enum('departure','transit_update','arrival','handover') NOT NULL,
  `notes` text DEFAULT NULL,
  `signature_path` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `checkpoints`
--

INSERT INTO `checkpoints` (`id`, `batch_id`, `user_id`, `location_name`, `latitude`, `longitude`, `temperature`, `action_type`, `notes`, `signature_path`, `created_at`, `updated_at`) VALUES
(1, 2, 1, 'Factory Cold Room B', NULL, NULL, -18.00, 'transit_update', 'Status updated to Processing', NULL, '2026-01-11 07:04:17', '2026-01-11 07:04:17'),
(2, 1, 2, 'North-South Hwy, Slim River', 3.83330000, 101.40000000, -18.50, 'transit_update', 'Routine temp check', NULL, '2026-01-11 07:34:20', '2026-01-11 07:34:20'),
(3, 3, 2, 'Guthrie Corridor Expressway', 3.16670000, 101.55000000, -19.20, 'transit_update', 'System auto-log', NULL, '2026-01-11 07:34:20', '2026-01-11 07:34:20'),
(4, 4, 3, 'Fresh Mart KL Loading Bay', 3.14660000, 101.69580000, -17.80, 'arrival', 'Accepted by Retailer', NULL, '2026-01-11 07:34:20', '2026-01-11 07:34:20'),
(5, 6, 2, 'Rest Stop Tapah', 4.19450000, 101.26000000, -12.00, 'transit_update', 'Warning: Temp rising', NULL, '2026-01-11 07:34:20', '2026-01-11 07:34:20'),
(6, 10, 10, 'Departure from Top Halal Meat', 2.20080000, 102.25110000, -18.50, 'departure', 'Loaded onto freezer truck BEM 1234', NULL, '2026-03-06 02:46:43', '2026-03-06 02:46:43'),
(7, 10, 10, 'PLUS Highway Melaka', 2.31200000, 102.13200000, -18.20, 'transit_update', 'Routine check, temp stable', NULL, '2026-03-06 03:46:43', '2026-03-06 03:46:43'),
(8, 11, 2, 'Fresh Mart KL Loading Bay', 3.14660000, 101.69580000, -17.50, 'arrival', 'Safely delivered to retail', NULL, '2026-03-05 05:46:43', '2026-03-05 05:46:43'),
(9, 12, 10, 'Rest Stop Seremban', 2.73100000, 101.95400000, -10.50, 'transit_update', 'WARNING: Freezer unit malfunction detected', NULL, '2026-03-06 05:46:43', '2026-03-06 05:46:43'),
(10, 13, 10, 'Premium Grocers Bangsar', 3.13100000, 101.67000000, -18.00, 'arrival', 'Stock handed over and verified', NULL, '2026-03-05 17:46:43', '2026-03-05 17:46:43'),
(11, 7, 2, 'In Transit - KL Highway', 3.14660000, 101.69500000, -15.50, 'transit_update', 'Seal checked - slightly loosened', NULL, '2026-01-11 07:30:00', '2026-01-11 07:30:00'),
(12, 7, 3, 'Fresh Mart KL Receiving Zone', 3.14660000, 101.69580000, -12.00, 'arrival', 'Accepted but under investigation for broken seal & temp breach', NULL, '2026-01-11 12:36:12', '2026-01-11 12:36:12'),
(13, 14, 12, 'Kuala Lumpur', NULL, NULL, 0.00, 'arrival', 'Batch created in system', NULL, '2026-03-09 13:17:57', '2026-03-09 13:17:57'),
(14, 15, 13, 'Kuala Lumpur', NULL, NULL, 0.00, 'arrival', 'Batch created in system', NULL, '2026-03-09 13:18:59', '2026-03-09 13:18:59'),
(15, 16, 14, 'Shah Alam', NULL, NULL, 0.00, 'arrival', 'Batch created in system', NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39'),
(16, 16, 15, 'Warehouse Hub', NULL, NULL, -18.50, 'handover', 'Custody transferred to Logistics Driver.', 'base64-demo', '2026-03-09 13:19:40', '2026-03-09 13:19:40'),
(17, 16, 15, 'Highway MRR2', NULL, NULL, 0.00, 'transit_update', '[INCIDENT: Delay] Traffic jam', NULL, '2026-03-09 13:19:40', '2026-03-09 13:19:40'),
(18, 16, 16, 'Lot 12, Kuala Lumpur', NULL, NULL, 0.00, 'arrival', 'Accepted by Retailer. Quality checks passed: temperature_check, quantity_match, halal_cert_present, expiry_valid, packaging_intact', NULL, '2026-03-09 13:19:41', '2026-03-09 13:19:41'),
(19, 17, 17, 'Loc', NULL, NULL, 0.00, 'arrival', 'Batch created in system', NULL, '2026-03-09 13:23:28', '2026-03-09 13:23:28'),
(20, 17, 17, 'Test', NULL, NULL, 0.00, 'transit_update', '[INCIDENT: Delay] Processor user posting logistics incident', NULL, '2026-03-09 13:23:29', '2026-03-09 13:23:29'),
(21, 17, 17, 'Processor Site', NULL, NULL, -10.00, 'transit_update', 'Processor posting logistics checkpoint', NULL, '2026-03-09 13:23:29', '2026-03-09 13:23:29'),
(22, 18, 1, 'Ali Halal Factory - Packing Line 2', 3.77350000, 101.49760000, -18.40, 'arrival', 'Batch created in system and sealed for dispatch', NULL, '2026-03-20 01:10:00', '2026-03-20 01:10:00'),
(23, 18, 2, 'Ali Halal Factory - Loading Bay', 3.77510000, 101.49940000, -18.60, 'departure', 'Loaded onto freezer truck JPG 8832 with intact halal seal', NULL, '2026-03-20 02:00:00', '2026-03-20 02:00:00'),
(24, 18, 2, 'PLUS Highway Rawang', 3.32140000, 101.57690000, -18.20, 'transit_update', 'Cold-chain check passed during northbound transit', NULL, '2026-03-20 04:25:00', '2026-03-20 04:25:00'),
(25, 18, 3, 'Fresh Mart KL - Receiving Cold Room', 3.14660000, 101.69580000, -17.90, 'arrival', 'Accepted by retailer after seal, quantity, and temperature verification', NULL, '2026-03-20 08:15:00', '2026-03-20 08:15:00'),
(26, 19, 9, 'Top Halal Meat Processor - Freezer Dock', 2.18960000, 102.25010000, -18.70, 'arrival', 'Batch created in system and queued for dispatch', NULL, '2026-03-21 00:30:00', '2026-03-21 00:30:00'),
(27, 19, 10, 'Top Halal Meat Processor - Departure Gate', 2.19090000, 102.25190000, -18.50, 'departure', 'Driver acknowledged custody transfer for truck BEM 1234', NULL, '2026-03-21 01:05:00', '2026-03-21 01:05:00'),
(28, 19, 10, 'North-South Expressway, Seremban Bound', 2.73180000, 101.93860000, -9.80, 'transit_update', '[INCIDENT: Temperature Breach] Freezer alarm triggered; truck diverted for inspection', NULL, '2026-03-21 05:10:00', '2026-03-21 05:10:00');

-- --------------------------------------------------------

--
-- Table structure for table `incidents`
--

CREATE TABLE `incidents` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `batch_id` varchar(255) NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `issue_type` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'Open',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `incidents`
--

INSERT INTO `incidents` (`id`, `batch_id`, `user_id`, `issue_type`, `description`, `location`, `status`, `created_at`, `updated_at`) VALUES
(1, 'B-2025-001', 2, 'Temperature Breach', 'Sensor reported -5°C (Threshold is -18°C) for over 30 mins.', 'Elite Highway, KM 14.5', 'Open', '2026-02-15 15:05:46', '2026-02-15 15:05:46'),
(2, 'B-2025-008', 3, 'Broken Seal', 'Batch arrived at retail bay with a tampered Halal security seal.', 'Fresh Mart KL Receiving Bay', 'Open', '2026-02-15 15:05:46', '2026-02-15 15:05:46'),
(3, 'B-2025-005', 2, 'Vehicle Breakdown', 'Refrigerated truck engine failure. Cold chain integrity at risk.', 'Guthrie Expressway', 'Open', '2026-02-15 15:05:46', '2026-02-15 15:05:46'),
(4, 'B-2025-104', 10, 'Temperature Breach', 'Freezer unit malfunction causing temp to rise to -10°C.', 'Rest Stop Seremban', 'Open', '2026-03-06 05:46:43', '2026-03-06 05:46:43'),
(5, 'B-2025-102', 11, 'Delayed Delivery', 'Truck is stuck in heavy traffic, delay of 2 hours expected.', 'PLUS Highway SG Besi', 'Resolved', '2026-03-05 05:46:43', '2026-03-06 05:46:43'),
(6, 'ROLE-1773062378', 15, 'Delay', 'Traffic jam', 'Highway MRR2', 'Open', '2026-03-09 13:19:40', '2026-03-09 13:19:40'),
(7, 'ROLECHECK-1773062607', 17, 'Delay', 'Processor user posting logistics incident', 'Test', 'Open', '2026-03-09 13:23:29', '2026-03-09 13:23:29'),
(8, 'B-2026-202', 10, 'Temperature Breach', 'Freezer alarm triggered in transit and core hold temperature rose above threshold.', 'North-South Expressway, Seremban Bound', 'Open', '2026-03-21 05:10:00', '2026-03-21 05:10:00');

-- --------------------------------------------------------

--
-- Table structure for table `logistics_profiles`
--

CREATE TABLE `logistics_profiles` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `vehicle_plate_no` varchar(255) NOT NULL,
  `driver_license_no` varchar(255) NOT NULL,
  `vehicle_type` varchar(255) NOT NULL,
  `gdl_license_path` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `logistics_profiles`
--

INSERT INTO `logistics_profiles` (`id`, `user_id`, `vehicle_plate_no`, `driver_license_no`, `vehicle_type`, `gdl_license_path`, `created_at`, `updated_at`) VALUES
(1, 2, 'JPG 8832', 'L-99281-DL', 'Refrigerated Truck', NULL, '2026-01-11 06:45:55', '2026-01-11 06:45:55'),
(2, 10, 'BEM 1234', 'D-55443-DL', 'Freezer Truck', NULL, '2026-03-06 05:46:42', '2026-03-06 05:46:42'),
(3, 15, 'JPG1234', 'D1234567', 'Refrigerated Truck', NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39');

-- --------------------------------------------------------

--
-- Table structure for table `migrations`
--

CREATE TABLE `migrations` (
  `id` int(10) UNSIGNED NOT NULL,
  `migration` varchar(255) NOT NULL,
  `batch` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `migrations`
--

INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
(1, '2026_01_09_132513_create_users_table', 1),
(2, '2026_01_09_132613_create_batches_table', 1),
(3, '2026_01_09_132613_create_checkpoints_table', 1),
(4, '2026_01_09_132614_create_transfers_table', 1),
(5, '2026_01_09_141057_create_personal_access_tokens_table', 1),
(6, '2026_01_11_134325_add_signature_to_checkpoints_table', 2),
(7, '2026_01_11_141812_create_user_profiles_tables', 3),
(8, '2026_01_11_141835_update_users_table_structure', 3),
(9, '2026_02_15_222250_create_incidents_table', 4);

-- --------------------------------------------------------

--
-- Table structure for table `personal_access_tokens`
--

CREATE TABLE `personal_access_tokens` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `tokenable_type` varchar(255) NOT NULL,
  `tokenable_id` bigint(20) UNSIGNED NOT NULL,
  `name` text NOT NULL,
  `token` varchar(64) NOT NULL,
  `abilities` text DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `personal_access_tokens`
--

INSERT INTO `personal_access_tokens` (`id`, `tokenable_type`, `tokenable_id`, `name`, `token`, `abilities`, `last_used_at`, `expires_at`, `created_at`, `updated_at`) VALUES
(3, 'App\\Models\\User', 1, 'auth_token', '385171e3a3e53b79c0491189e1a04fee2573a33a6dec439ce2b540f62b34d284', '[\"*\"]', '2026-01-10 16:38:11', NULL, '2026-01-10 16:38:10', '2026-01-10 16:38:11'),
(5, 'App\\Models\\User', 2, 'auth_token', 'adf1f687f33876731bef43653612981264f3bc9f3cf6ec6c01387d2b63e7e085', '[\"*\"]', '2026-01-11 06:11:34', NULL, '2026-01-11 06:10:21', '2026-01-11 06:11:34'),
(6, 'App\\Models\\User', 1, 'auth_token', 'b5284b645b98ee6d484dd1f81ae1e2a1a604e99e8fed32bb4db4fe08a7f6b140', '[\"*\"]', '2026-01-11 07:04:34', NULL, '2026-01-11 06:55:12', '2026-01-11 07:04:34'),
(7, 'App\\Models\\User', 2, 'auth_token', 'b423c31a70924cd09ace1a5531d6116205b1e8a3cf24ab96b9768daf96874ab0', '[\"*\"]', '2026-01-11 07:05:12', NULL, '2026-01-11 07:05:11', '2026-01-11 07:05:12'),
(8, 'App\\Models\\User', 2, 'auth_token', '305d9da826535094f8a04a1aeea15ed9903000c6cd19e092cccfbbf8b84dd8a6', '[\"*\"]', '2026-01-11 07:08:24', NULL, '2026-01-11 07:08:23', '2026-01-11 07:08:24'),
(9, 'App\\Models\\User', 1, 'auth_token', 'dbdf1e3b6c95f11be0a8443217119e3b30effa6858b81f0b91e5c7b3f1fb7b55', '[\"*\"]', '2026-01-11 07:22:10', NULL, '2026-01-11 07:22:09', '2026-01-11 07:22:10'),
(10, 'App\\Models\\User', 2, 'auth_token', 'c84ac7dcd9dbf5b56debdf70b1e33e89d9978780ae13c467316b5844dcf795ff', '[\"*\"]', '2026-01-11 07:44:46', NULL, '2026-01-11 07:23:39', '2026-01-11 07:44:46'),
(11, 'App\\Models\\User', 1, 'auth_token', 'fbb0849d489163b630072fef8b33e954469005bb260f09031a3180bc0c3e0fa9', '[\"*\"]', '2026-01-11 07:59:09', NULL, '2026-01-11 07:59:08', '2026-01-11 07:59:09'),
(12, 'App\\Models\\User', 2, 'auth_token', 'ced3df3d4f61e9794d188707de96e3a1e3348f5579a25416fb2458567108157c', '[\"*\"]', '2026-01-11 07:59:35', NULL, '2026-01-11 07:59:34', '2026-01-11 07:59:35'),
(13, 'App\\Models\\User', 3, 'auth_token', '32bf4f9a2176d42c80e1241c2d604e1d3ed436344a322a140307ffe5f09aa51a', '[\"*\"]', NULL, NULL, '2026-01-11 08:09:24', '2026-01-11 08:09:24'),
(14, 'App\\Models\\User', 1, 'auth_token', '3d202d0ab356817718a9930ef51d08405883d709c33c374bd26dd740ef17cf2a', '[\"*\"]', '2026-01-12 06:29:44', NULL, '2026-01-12 06:28:59', '2026-01-12 06:29:44'),
(15, 'App\\Models\\User', 2, 'auth_token', '515570d03982683afd857f1a2e9a5f289208b847f4f0d8f2762750c9511c34b7', '[\"*\"]', '2026-01-12 06:30:53', NULL, '2026-01-12 06:30:52', '2026-01-12 06:30:53'),
(16, 'App\\Models\\User', 3, 'auth_token', '1ef3bbdd7e2811441f47c1e5b7961e2318aede94690602663b5e15cb2f0a297d', '[\"*\"]', NULL, NULL, '2026-01-12 06:32:15', '2026-01-12 06:32:15'),
(17, 'App\\Models\\User', 2, 'auth_token', '961c3f21f2c792a6adcdc82068c62c73ae181b49ebb7115655c766d077f3cb9b', '[\"*\"]', '2026-02-14 08:33:11', NULL, '2026-02-14 08:33:10', '2026-02-14 08:33:11'),
(18, 'App\\Models\\User', 1, 'auth_token', 'c978f639646cb5b404466f3f89e5abb761bb61d7756f306f5297e253132c3534', '[\"*\"]', '2026-02-14 08:34:06', NULL, '2026-02-14 08:33:37', '2026-02-14 08:34:06'),
(19, 'App\\Models\\User', 3, 'auth_token', 'ad9bbb12a0c1407898e210c3be09b698a9099d5e043b2e44ee938ee33219b55a', '[\"*\"]', NULL, NULL, '2026-02-14 08:34:56', '2026-02-14 08:34:56'),
(20, 'App\\Models\\User', 3, 'auth_token', '3f3a8c1687ac26fdd975ffa3ebc1081ad9530911f2ae7a95cf7b95b027f29d96', '[\"*\"]', '2026-02-15 12:36:15', NULL, '2026-02-15 12:36:13', '2026-02-15 12:36:15'),
(21, 'App\\Models\\User', 1, 'auth_token', 'afa8d0844ca3ea7a4521db0715cb5bf804fbfd11f1c95337f9881aedd42c4c63', '[\"*\"]', '2026-02-15 12:42:48', NULL, '2026-02-15 12:42:47', '2026-02-15 12:42:48'),
(22, 'App\\Models\\User', 3, 'auth_token', '95485875e1b2c42c0f055f1a7b69ffed89d601ba569fb8412a10dc4ae75e6c76', '[\"*\"]', '2026-02-15 13:51:11', NULL, '2026-02-15 12:43:20', '2026-02-15 13:51:11'),
(23, 'App\\Models\\User', 3, 'auth_token', '2b64ce265a544a80cafdfe76970be8eafc0ac10397bcff5763d64619327f73c8', '[\"*\"]', '2026-02-15 14:06:48', NULL, '2026-02-15 13:51:38', '2026-02-15 14:06:48'),
(24, 'App\\Models\\User', 1, 'auth_token', 'f9b74570fbe8d659127c8db6a9d8c2b2492d73c306d0d8f07d484bf0dc84ee2e', '[\"*\"]', '2026-02-15 14:11:05', NULL, '2026-02-15 14:10:54', '2026-02-15 14:11:05'),
(25, 'App\\Models\\User', 3, 'auth_token', 'eb73f20bb36336c5858f56427c5217f1b8fda5327df08eb1371c54266cb28b1f', '[\"*\"]', '2026-02-15 14:11:31', NULL, '2026-02-15 14:11:29', '2026-02-15 14:11:31'),
(26, 'App\\Models\\User', 4, 'auth_token', '9da51d2be79a7d7b751891b60a02a6c52a0d938ebf102c7063613b183a160960', '[\"*\"]', NULL, NULL, '2026-02-15 14:27:22', '2026-02-15 14:27:22'),
(27, 'App\\Models\\User', 4, 'auth_token', '7252a33ac84871d06251273531fb2ce6acc080e62fbb1bc8d74df92b703e9ad3', '[\"*\"]', NULL, NULL, '2026-02-15 14:27:44', '2026-02-15 14:27:44'),
(28, 'App\\Models\\User', 1, 'auth_token', '2c5bd2ad27c2b20d902150ed4b01108783362b9278b0d7eb1d61627a98cc9027', '[\"*\"]', '2026-02-15 14:28:09', NULL, '2026-02-15 14:28:08', '2026-02-15 14:28:09'),
(29, 'App\\Models\\User', 4, 'auth_token', '1c311f572a6e1ff050c43d371172bfdebd83886abcc15d5365981db12b760041', '[\"*\"]', '2026-02-15 14:36:30', NULL, '2026-02-15 14:28:28', '2026-02-15 14:36:30'),
(30, 'App\\Models\\User', 3, 'auth_token', '2834072ae0ace8fc046b46710ed31d0427027e8fbd426e331ba9dd82c0c2538b', '[\"*\"]', NULL, NULL, '2026-02-15 14:37:08', '2026-02-15 14:37:08'),
(31, 'App\\Models\\User', 3, 'auth_token', 'b95eb8b42cb5e624a84cda9ac1ca76584b834b2ae6d619a4ee2060a880c81412', '[\"*\"]', NULL, NULL, '2026-02-15 14:37:14', '2026-02-15 14:37:14'),
(32, 'App\\Models\\User', 3, 'auth_token', '458c7c17dc710654511ee5179be65f3ab0fba427aaa227c329a6d17b7072efdf', '[\"*\"]', NULL, NULL, '2026-02-15 14:37:17', '2026-02-15 14:37:17'),
(33, 'App\\Models\\User', 3, 'auth_token', 'b51e8f8977201d4a01ad4c18c2c4c90e325175ace2f1680df99697f4407a500b', '[\"*\"]', NULL, NULL, '2026-02-15 14:37:19', '2026-02-15 14:37:19'),
(34, 'App\\Models\\User', 3, 'auth_token', '2c57d4ecaa43ae0a927c0adf1536a672d2a28099aea2b745af096d1a338ec5a0', '[\"*\"]', NULL, NULL, '2026-02-15 14:37:20', '2026-02-15 14:37:20'),
(35, 'App\\Models\\User', 4, 'auth_token', '9f0e03887f3b4ac69db0359db385dafdd1c07f8c2ef2698ec65412c034c43d11', '[\"*\"]', NULL, NULL, '2026-02-15 14:37:46', '2026-02-15 14:37:46'),
(36, 'App\\Models\\User', 3, 'auth_token', 'e86a8118acdadf6bdfd8223e40064c782368dec5a76ba0cebbfba10e55073d04', '[\"*\"]', '2026-02-15 14:38:30', NULL, '2026-02-15 14:38:29', '2026-02-15 14:38:30'),
(37, 'App\\Models\\User', 4, 'auth_token', 'da67b8d3f6ba0dc64898f29e60ac0cd3e242df3c950ee6d557987d183b8572de', '[\"*\"]', '2026-02-15 15:05:58', NULL, '2026-02-15 14:41:19', '2026-02-15 15:05:58'),
(38, 'App\\Models\\User', 1, 'auth_token', '65d484d8d37f65ab8a975ab9297498c729749b1da2aad47c9962dd9e1e73b03e', '[\"*\"]', '2026-02-15 15:07:52', NULL, '2026-02-15 15:07:51', '2026-02-15 15:07:52'),
(39, 'App\\Models\\User', 4, 'auth_token', '0dfdea28e991853121c722e8df5ad8e459c786a1a3d2777f553f8abc697d9a09', '[\"*\"]', '2026-02-15 15:09:25', NULL, '2026-02-15 15:09:23', '2026-02-15 15:09:25'),
(40, 'App\\Models\\User', 1, 'auth_token', 'ebce94d4c33b0582913afd559232a10ff3d2cdafd9edb304ff58cedf53b999e8', '[\"*\"]', '2026-02-28 14:03:37', NULL, '2026-02-28 14:03:33', '2026-02-28 14:03:37'),
(41, 'App\\Models\\User', 1, 'auth_token', 'f6cdd22bb941ba887adf1ebaa9997d2c9ed7d6d224901b028b30f3a692931f89', '[\"*\"]', '2026-02-28 14:04:19', NULL, '2026-02-28 14:04:18', '2026-02-28 14:04:19'),
(42, 'App\\Models\\User', 2, 'auth_token', 'a96688704509f430289ba2d7058a48f538bae98b22f20759dca7de1007d7c871', '[\"*\"]', '2026-02-28 14:05:41', NULL, '2026-02-28 14:05:39', '2026-02-28 14:05:41'),
(43, 'App\\Models\\User', 3, 'auth_token', '710df886fb4e33a2b7bf5c4afcbd3219300ad2024f1b51483f1f57a7c851a6e6', '[\"*\"]', '2026-02-28 14:06:07', NULL, '2026-02-28 14:06:06', '2026-02-28 14:06:07'),
(44, 'App\\Models\\User', 3, 'auth_token', '700e5786dff17a5b8b1d19c125c839f65a25dfbf0bb9e1cad934e12a8fb20d88', '[\"*\"]', '2026-02-28 14:06:37', NULL, '2026-02-28 14:06:35', '2026-02-28 14:06:37'),
(45, 'App\\Models\\User', 4, 'auth_token', 'c89108b0dbccc9cbbc8f823be13e858858b85dee69f2cdd6fb4aed153f8fe00f', '[\"*\"]', '2026-02-28 14:07:13', NULL, '2026-02-28 14:07:02', '2026-02-28 14:07:13'),
(46, 'App\\Models\\User', 4, 'auth_token', '988be09529223014e9dd53bd6115146f4a0695c2cd42ab24ba4c3ab562cf148c', '[\"*\"]', '2026-02-28 14:15:13', NULL, '2026-02-28 14:12:18', '2026-02-28 14:15:13'),
(47, 'App\\Models\\User', 8, 'test-token', '6470670aaea6faf4d7a2e90603b8609759fefa71d5c73821d73a0039b09f93d1', '[\"*\"]', '2026-03-05 08:10:16', NULL, '2026-03-05 08:10:14', '2026-03-05 08:10:16'),
(48, 'App\\Models\\User', 1, 'auth_token', '6bf7f78ecdabf420e8c2d05126488cd53427e982b61f106273293c2ccafff99e', '[\"*\"]', '2026-03-05 13:19:54', NULL, '2026-03-05 13:19:07', '2026-03-05 13:19:54'),
(49, 'App\\Models\\User', 2, 'auth_token', '3738a3222bc21e7079134a562a5b4a47f186d066968fea3d7eda33346440a0a4', '[\"*\"]', '2026-03-05 13:20:26', NULL, '2026-03-05 13:20:24', '2026-03-05 13:20:26'),
(50, 'App\\Models\\User', 3, 'auth_token', '9f109e61150ce756cdbb4d573d54b26c378346212105ee45c22c7bd47f59903e', '[\"*\"]', '2026-03-05 13:21:23', NULL, '2026-03-05 13:21:22', '2026-03-05 13:21:23'),
(51, 'App\\Models\\User', 4, 'auth_token', 'b085bd9754837da0f3ed6bcced90b1d0fc7dc3843b831421103bd533b0b12335', '[\"*\"]', '2026-03-05 13:22:38', NULL, '2026-03-05 13:22:02', '2026-03-05 13:22:38'),
(52, 'App\\Models\\User', 3, 'auth_token', '5146ffaa6fffa05ef4cdcf48bff9925d7f540a31c3d5f92c13870b9161a0af8d', '[\"*\"]', '2026-03-05 13:26:23', NULL, '2026-03-05 13:23:00', '2026-03-05 13:26:23'),
(53, 'App\\Models\\User', 1, 'auth_token', 'fe731875a34e5c995c9e273d61952335c4497313c973fd994bd104a800e791f8', '[\"*\"]', '2026-03-05 13:30:44', NULL, '2026-03-05 13:27:01', '2026-03-05 13:30:44'),
(54, 'App\\Models\\User', 3, 'auth_token', '3b6142d8bc53bdb2a293f4173ef72e6cb93cb78403740b4e32e78ae41b9c7848', '[\"*\"]', '2026-03-05 13:31:05', NULL, '2026-03-05 13:31:04', '2026-03-05 13:31:05'),
(55, 'App\\Models\\User', 2, 'auth_token', '4c58d334291eb04854cd30098b223e7fb4526d846515040b1c1aa81c4175f3d4', '[\"*\"]', '2026-03-05 13:31:39', NULL, '2026-03-05 13:31:38', '2026-03-05 13:31:39'),
(56, 'App\\Models\\User', 3, 'auth_token', '074171d629d12d0c2c55008e71a59877c08dee8fca029e447b0449117ea78f11', '[\"*\"]', '2026-03-05 13:35:00', NULL, '2026-03-05 13:32:04', '2026-03-05 13:35:00'),
(57, 'App\\Models\\User', 1, 'auth_token', '7b460b8a1f4ded0d6776bacd9ba53280d813af027387eda66bfd204554dd8217', '[\"*\"]', '2026-03-05 13:35:54', NULL, '2026-03-05 13:35:44', '2026-03-05 13:35:54'),
(58, 'App\\Models\\User', 2, 'auth_token', 'a9dc1c653536b1426e635b6a6495b180540a03c595b6a959cf65030b573d2a45', '[\"*\"]', '2026-03-05 13:36:20', NULL, '2026-03-05 13:36:19', '2026-03-05 13:36:20'),
(59, 'App\\Models\\User', 3, 'auth_token', '83ad87587c791e2a0c4fabe9f6a3b07042453b32de4289e548fe2c3bd9ccabb2', '[\"*\"]', '2026-03-05 14:00:20', NULL, '2026-03-05 13:37:01', '2026-03-05 14:00:20'),
(60, 'App\\Models\\User', 2, 'auth_token', '3d94ce9deabbe87c3f2c5a6106680c255a30a05965398c8526ae954fd6c28db8', '[\"*\"]', '2026-03-05 14:01:05', NULL, '2026-03-05 14:01:04', '2026-03-05 14:01:05'),
(61, 'App\\Models\\User', 3, 'auth_token', '32cfbed4ce7e79bafb51e9c35c42b5d811b9f60cb79fef6655f7d31e3cc6dc11', '[\"*\"]', '2026-03-05 14:02:36', NULL, '2026-03-05 14:02:35', '2026-03-05 14:02:36'),
(62, 'App\\Models\\User', 2, 'auth_token', '6a2d3027b59af511eb265442c182fcbae1c0016529d574b35c9657b728057a0d', '[\"*\"]', '2026-03-05 14:19:21', NULL, '2026-03-05 14:03:20', '2026-03-05 14:19:21'),
(63, 'App\\Models\\User', 1, 'auth_token', '471ac54d06242eec060e3c68bc8a13f68bfeea685b61a82455cb33789631c53a', '[\"*\"]', '2026-03-05 14:20:47', NULL, '2026-03-05 14:20:46', '2026-03-05 14:20:47'),
(64, 'App\\Models\\User', 2, 'auth_token', '21dc23489a17f87a0ff69e081bebed924162352673f0f2a2dc3d9c1d2d7fc372', '[\"*\"]', '2026-03-05 14:21:23', NULL, '2026-03-05 14:21:22', '2026-03-05 14:21:23'),
(65, 'App\\Models\\User', 3, 'auth_token', '67dc1a2cd03db624a35c9da4ecc85ce07a7d833fc9fe2d0be1f05b6a00f31769', '[\"*\"]', '2026-03-05 14:30:27', NULL, '2026-03-05 14:21:56', '2026-03-05 14:30:27'),
(66, 'App\\Models\\User', 1, 'auth_token', 'df7281fb75b96e0d59f6def6218701b305d6ac2293cac50b2827da4ca090c5f6', '[\"*\"]', '2026-03-06 05:24:06', NULL, '2026-03-05 14:30:50', '2026-03-06 05:24:06'),
(67, 'App\\Models\\User', 1, 'auth_token', 'eefa891a66ccdde0d0ac791e4aa3188f96442af8ad472d7691b1102e31a79209', '[\"*\"]', '2026-03-06 05:26:47', NULL, '2026-03-06 05:24:44', '2026-03-06 05:26:47'),
(68, 'App\\Models\\User', 3, 'auth_token', '70d1af778d0cedf76175c6218d683557a7ae52b2ea5797e9b92b09413c527b22', '[\"*\"]', '2026-03-06 05:27:31', NULL, '2026-03-06 05:27:13', '2026-03-06 05:27:31'),
(69, 'App\\Models\\User', 2, 'auth_token', '2c30be18dfb6343ba213ff9bbb031b8ddbc9552ef1124bb6091c985f8c8685b2', '[\"*\"]', '2026-03-06 05:33:54', NULL, '2026-03-06 05:27:54', '2026-03-06 05:33:54'),
(70, 'App\\Models\\User', 1, 'auth_token', 'eccdae41049dabffdccc37e2f9ee3c02c24d8494205fc25884c63d081173560d', '[\"*\"]', '2026-03-06 05:50:56', NULL, '2026-03-06 05:34:10', '2026-03-06 05:50:56'),
(71, 'App\\Models\\User', 4, 'auth_token', '679a50cefec876133d936a12b34a0b97beda9b64c198fcb6bd3ad5333cc8e7e7', '[\"*\"]', '2026-03-06 06:03:56', NULL, '2026-03-06 05:51:17', '2026-03-06 06:03:56'),
(72, 'App\\Models\\User', 4, 'auth_token', '109ba78e5cb1f3bb609eef804dfb7c24e115feda34471ea0b3f94ac3b04df560', '[\"*\"]', '2026-03-06 06:09:22', NULL, '2026-03-06 06:05:46', '2026-03-06 06:09:22'),
(73, 'App\\Models\\User', 4, 'auth_token', '95540ea4bf035dee99919a4120099ffad82a0f652aea11c54b26ad95942bfc9a', '[\"*\"]', '2026-03-06 06:13:38', NULL, '2026-03-06 06:11:51', '2026-03-06 06:13:38'),
(74, 'App\\Models\\User', 1, 'auth_token', 'dc31453c3a6c0e85a57ea562ba25e93d30fae6b23c6b84fdcb1c15436d4d2430', '[\"*\"]', '2026-03-06 06:36:36', NULL, '2026-03-06 06:36:35', '2026-03-06 06:36:36'),
(75, 'App\\Models\\User', 2, 'auth_token', 'c2dd2e849d2cd5eafa6d39f5cef62376c30daa8ff5e53715b7cfcbdf2a6b94a7', '[\"*\"]', '2026-03-06 06:37:14', NULL, '2026-03-06 06:37:13', '2026-03-06 06:37:14'),
(76, 'App\\Models\\User', 3, 'auth_token', '4e32617e3765f5a7a7a7e24f5284ae1a558d71f9a7f9ec59bacd67d5f13c0a74', '[\"*\"]', '2026-03-06 06:38:28', NULL, '2026-03-06 06:38:02', '2026-03-06 06:38:28'),
(77, 'App\\Models\\User', 4, 'auth_token', '606e8507c3d998b03a8e74766d7398c2f09a75a4af00e2cfcad5d59fe648824d', '[\"*\"]', '2026-03-06 06:38:56', NULL, '2026-03-06 06:38:55', '2026-03-06 06:38:56'),
(78, 'App\\Models\\User', 1, 'auth_token', '15ec0abed659454a166bcf3b05034f72685df038aba210d22acf125168194a12', '[\"*\"]', '2026-03-06 14:22:03', NULL, '2026-03-06 07:03:12', '2026-03-06 14:22:03'),
(79, 'App\\Models\\User', 1, 'auth_token', 'dfdce4ec72d7be37b7f62948d68f548acdc7629b05a38a11146a5e6d5de3ea73', '[\"*\"]', '2026-03-06 14:23:31', NULL, '2026-03-06 14:23:30', '2026-03-06 14:23:31'),
(80, 'App\\Models\\User', 2, 'auth_token', '038999adc3d0fa58b335a2870abbdded013e366fa2d2c5a9fa6d359171c096a3', '[\"*\"]', '2026-03-06 14:23:57', NULL, '2026-03-06 14:23:56', '2026-03-06 14:23:57'),
(81, 'App\\Models\\User', 3, 'auth_token', '427606445cc54111585727cc2e67fb753cff998372e4de7f55cc29e89b33ffb5', '[\"*\"]', '2026-03-06 14:24:23', NULL, '2026-03-06 14:24:21', '2026-03-06 14:24:23'),
(82, 'App\\Models\\User', 4, 'auth_token', '7c203028efbdd2bbadc9792d31e04f4d9d14d3ed9f31c0c1c6ff5eda3e063ddb', '[\"*\"]', '2026-03-06 14:24:48', NULL, '2026-03-06 14:24:44', '2026-03-06 14:24:48'),
(83, 'App\\Models\\User', 1, 'auth_token', 'd8ac68274a196877d9cc54398dc85820ec43b5fc6670a6a1c990b407ab2b1c92', '[\"*\"]', '2026-03-06 14:25:30', NULL, '2026-03-06 14:25:29', '2026-03-06 14:25:30'),
(84, 'App\\Models\\User', 1, 'auth_token', '0b362758e0003dfc192bbe90152b154996291874410c0e998e4884cffbc41cca', '[\"*\"]', '2026-03-06 14:41:49', NULL, '2026-03-06 14:41:48', '2026-03-06 14:41:49'),
(85, 'App\\Models\\User', 8, 'test-token', '900c9744672f85bbbc529a297bf58d11384e4332f8781d581a240051287a087b', '[\"*\"]', '2026-03-09 13:17:19', NULL, '2026-03-09 13:17:18', '2026-03-09 13:17:19'),
(86, 'App\\Models\\User', 12, 'auth_token', '12576f492c20a2ad9f33a700b91d928e30ca1434a683773e1254cc0083787cbb', '[\"*\"]', NULL, NULL, '2026-03-09 13:17:56', '2026-03-09 13:17:56'),
(87, 'App\\Models\\User', 12, 'auth_token', 'e5319090e5e499ff1604bc1516e62b8fac7815dc438a8064c922218173fe471d', '[\"*\"]', '2026-03-09 13:17:57', NULL, '2026-03-09 13:17:57', '2026-03-09 13:17:57'),
(88, 'App\\Models\\User', 13, 'auth_token', 'd513f73795721ce5688a514a4c8d4b1cbd15d3eb696fc59206b33ceac34406d7', '[\"*\"]', NULL, NULL, '2026-03-09 13:18:59', '2026-03-09 13:18:59'),
(89, 'App\\Models\\User', 13, 'auth_token', '06382626987a936cbc010f3f069ccfe235457408d9d8b4139bfd7fe5037e3ca2', '[\"*\"]', '2026-03-09 13:19:00', NULL, '2026-03-09 13:18:59', '2026-03-09 13:19:00'),
(90, 'App\\Models\\User', 14, 'auth_token', '7b08e30b474601783f9f334d10bebab9fa1005463275834f98d3d12041992bb1', '[\"*\"]', NULL, NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39'),
(91, 'App\\Models\\User', 14, 'auth_token', 'e70a53b06e43da4aa05e04db0f6ffd86fbab5c2a41be473e1981aa6d703f842e', '[\"*\"]', '2026-03-09 13:19:39', NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39'),
(92, 'App\\Models\\User', 15, 'auth_token', 'dbbaeba2121d1fc0a3c3cba97a0b40362541005d260afaff43b2ed645f63280c', '[\"*\"]', NULL, NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39'),
(93, 'App\\Models\\User', 15, 'auth_token', '4c948d558fc86cfc0c91f90018f8065911164cb659ce94ad49462c68b7440cf9', '[\"*\"]', '2026-03-09 13:19:40', NULL, '2026-03-09 13:19:40', '2026-03-09 13:19:40'),
(94, 'App\\Models\\User', 16, 'auth_token', '57866ba447d63ede16849982fed4a5998252151439e460759875c47f536f11d1', '[\"*\"]', NULL, NULL, '2026-03-09 13:19:41', '2026-03-09 13:19:41'),
(95, 'App\\Models\\User', 16, 'auth_token', 'e93f8f7addd2cc7e7a754a34c64e95f3c08ebee6c1dcfe64e0222a27a96ee796', '[\"*\"]', '2026-03-09 13:19:41', NULL, '2026-03-09 13:19:41', '2026-03-09 13:19:41'),
(96, 'App\\Models\\User', 17, 'auth_token', '4a35f2180e9f47eee2fa886a9eb2e5c0fbf6725b6b577fbb54c8d999d4d2f99a', '[\"*\"]', NULL, NULL, '2026-03-09 13:23:28', '2026-03-09 13:23:28'),
(97, 'App\\Models\\User', 17, 'auth_token', 'b591817819338410f586675716238863fac4ac71fca8df6c1e360742afeda4f2', '[\"*\"]', '2026-03-09 13:23:29', NULL, '2026-03-09 13:23:28', '2026-03-09 13:23:29'),
(98, 'App\\Models\\User', 18, 'auth_token', '280216c7ccd5791b2927accc12f90426fb4bcaebaa3befe2208eef93d959b9c0', '[\"*\"]', NULL, NULL, '2026-03-09 13:29:10', '2026-03-09 13:29:10'),
(99, 'App\\Models\\User', 18, 'auth_token', 'e897d503cff47009e7b4938cb59c9af19d18c38ec8cc1b9d964c5ff00674c698', '[\"*\"]', '2026-03-09 13:29:11', NULL, '2026-03-09 13:29:10', '2026-03-09 13:29:11'),
(100, 'App\\Models\\User', 19, 'auth_token', '179eb2fed9f8184ecd085747b3e095f48787cd85d410b9f96fb99094f8f953ee', '[\"*\"]', NULL, NULL, '2026-03-09 13:29:33', '2026-03-09 13:29:33'),
(101, 'App\\Models\\User', 19, 'auth_token', '1f75f3806304015967a238230f48d4ba16ea0c0118da0fefef2e119d89f346c4', '[\"*\"]', '2026-03-09 13:29:34', NULL, '2026-03-09 13:29:34', '2026-03-09 13:29:34'),
(102, 'App\\Models\\User', 1, 'auth_token', 'f8ec952cbe05537d3b9daa87646323e5a2b0436618915110f8fd3e2694d2eab7', '[\"*\"]', '2026-03-10 06:24:47', NULL, '2026-03-10 06:24:25', '2026-03-10 06:24:47'),
(103, 'App\\Models\\User', 3, 'auth_token', 'ebd159dce7310fa48ae9d3b88bca19cba0529933398fe1fb702259ca6ed0acb9', '[\"*\"]', '2026-03-10 06:25:18', NULL, '2026-03-10 06:25:16', '2026-03-10 06:25:18'),
(104, 'App\\Models\\User', 2, 'auth_token', 'b0c023691d7f31e7d965f72b31be933e0ca4d052814ff08b27985726e010a6f7', '[\"*\"]', '2026-03-10 06:26:03', NULL, '2026-03-10 06:26:02', '2026-03-10 06:26:03'),
(105, 'App\\Models\\User', 4, 'auth_token', '1c29c66fe0cf412aa4437c5f671b4878b6b118bebbceaf8937fe9785ad3c5b3c', '[\"*\"]', '2026-03-10 06:27:05', NULL, '2026-03-10 06:26:34', '2026-03-10 06:27:05'),
(106, 'App\\Models\\User', 1, 'auth_token', 'b140f4d6a702829dcb97f92928bd40aab18805dd92f0052499e5ab200bd07229', '[\"*\"]', '2026-03-12 04:03:50', NULL, '2026-03-12 04:03:43', '2026-03-12 04:03:50'),
(107, 'App\\Models\\User', 4, 'auth_token', '249f69bffc99a68b4cdd08bdf9b62b1c3a43fed6b5e362e3d7e5f2a6b0a60a9a', '[\"*\"]', '2026-03-12 04:04:40', NULL, '2026-03-12 04:04:24', '2026-03-12 04:04:40');

-- --------------------------------------------------------

--
-- Table structure for table `processor_profiles`
--

CREATE TABLE `processor_profiles` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `company_reg_no` varchar(255) NOT NULL,
  `halal_cert_no` varchar(255) NOT NULL,
  `halal_expiry_date` date NOT NULL,
  `factory_address` text NOT NULL,
  `cert_document_path` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `processor_profiles`
--

INSERT INTO `processor_profiles` (`id`, `user_id`, `company_reg_no`, `halal_cert_no`, `halal_expiry_date`, `factory_address`, `cert_document_path`, `created_at`, `updated_at`) VALUES
(1, 1, 'SSM-2024-001', 'JAKIM-HALAL-9981', '2026-12-31', 'Lot 88, Shah Alam Industrial Park, Selangor', NULL, '2026-01-11 06:45:55', '2026-01-11 06:45:55'),
(2, 9, 'SSM-2025-992', 'JAKIM-HALAL-8832', '2027-12-31', 'Lot 44, Halal Hub, Melaka', NULL, '2026-03-06 05:46:42', '2026-03-06 05:46:42'),
(3, 8, 'SSM-8899-TEST', 'JAKIM-HALAL-TEST123', '2026-12-31', 'Testing Area, Selangor', NULL, '2026-03-06 05:50:20', '2026-03-06 05:50:20'),
(4, 12, 'SSM12345', 'HALAL-9988', '2026-12-31', 'Test Factory Address', NULL, '2026-03-09 13:17:56', '2026-03-09 13:17:56'),
(5, 13, 'SSM12345', 'HALAL-9988', '2026-12-31', 'Test Factory Address', NULL, '2026-03-09 13:18:59', '2026-03-09 13:18:59'),
(6, 14, 'SSM7788', 'HAL-7788', '2026-12-31', 'Proc Address', NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39'),
(7, 17, 'SSM-RTEST', 'HAL-RTEST', '2026-12-31', 'Address', NULL, '2026-03-09 13:23:28', '2026-03-09 13:23:28'),
(8, 18, 'SSM-M', 'HAL-M', '2026-12-31', 'Addr', NULL, '2026-03-09 13:29:10', '2026-03-09 13:29:10');

-- --------------------------------------------------------

--
-- Table structure for table `retailer_profiles`
--

CREATE TABLE `retailer_profiles` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `user_id` bigint(20) UNSIGNED NOT NULL,
  `store_name` varchar(255) NOT NULL,
  `business_reg_no` varchar(255) NOT NULL,
  `outlet_address` text NOT NULL,
  `store_contact_number` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `retailer_profiles`
--

INSERT INTO `retailer_profiles` (`id`, `user_id`, `store_name`, `business_reg_no`, `outlet_address`, `store_contact_number`, `created_at`, `updated_at`) VALUES
(1, 3, 'Fresh Mart Kuala Lumpur', 'REG-55123', 'No 12, Jalan Bukit Bintang, KL', '+603-2144-5555', '2026-01-11 06:45:55', '2026-01-11 06:45:55'),
(2, 11, 'Premium Grocers Bangsar', 'REG-AM98', 'No 5, Jalan Telawi, Bangsar, KL', '+603-2288-9999', '2026-03-06 05:46:42', '2026-03-06 05:46:42'),
(3, 16, 'Fresh Mart KL', 'BRN7788', 'Lot 12, Kuala Lumpur', NULL, '2026-03-09 13:19:41', '2026-03-09 13:19:41');

-- --------------------------------------------------------

--
-- Table structure for table `transfers`
--

CREATE TABLE `transfers` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `batch_id` bigint(20) UNSIGNED NOT NULL,
  `from_user_id` bigint(20) UNSIGNED NOT NULL,
  `to_user_id` bigint(20) UNSIGNED NOT NULL,
  `packaging_check_passed` tinyint(1) NOT NULL,
  `seal_check_passed` tinyint(1) NOT NULL,
  `temp_check_passed` tinyint(1) NOT NULL,
  `digital_signature_hash` varchar(255) DEFAULT NULL,
  `transferred_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `transfers`
--

INSERT INTO `transfers` (`id`, `batch_id`, `from_user_id`, `to_user_id`, `packaging_check_passed`, `seal_check_passed`, `temp_check_passed`, `digital_signature_hash`, `transferred_at`) VALUES
(1, 1, 1, 2, 1, 1, 1, '1bc6f3fd455d231b63ed72df855d67dd', '2026-01-10 23:00:00'),
(2, 3, 1, 2, 1, 1, 1, '2d3255b57cc04f6519df07053fce69c5', '2026-01-10 23:15:00'),
(3, 4, 1, 2, 1, 1, 1, '34442a8599a35c7dd1b4b489bb94c36b', '2026-01-10 22:15:00'),
(4, 4, 2, 3, 1, 1, 1, '370515b45245a910a855396c40500320', '2026-01-10 23:34:20'),
(5, 6, 1, 2, 1, 1, 1, '3236e07a2dd1b291399f821ccd70498d', '2026-01-10 23:10:00'),
(6, 7, 1, 2, 1, 1, 1, 'be52c5a1628b39cfb20290ff059836d3', '2026-01-10 22:30:00'),
(7, 7, 2, 3, 1, 0, 1, 'f5541e75d90a8e162bf19d5505759630', '2026-01-11 12:36:12');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `remember_token` varchar(100) DEFAULT NULL,
  `phone_number` varchar(255) DEFAULT NULL,
  `profile_image` varchar(255) DEFAULT NULL,
  `role` enum('admin','processor','logistics','retailer','consumer') NOT NULL DEFAULT 'consumer',
  `is_approved` tinyint(1) NOT NULL DEFAULT 0,
  `approved_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `email_verified_at`, `password`, `remember_token`, `phone_number`, `profile_image`, `role`, `is_approved`, `approved_at`, `created_at`, `updated_at`) VALUES
(1, 'Ali Halal Factory', 'ali@processor.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+60123456789', 'avatars/sm2eu9NrUdspycNIyvus5xWgNmiAeiTX0rXGqGPy.jpg', 'processor', 1, NULL, '2026-01-11 06:45:55', '2026-03-06 05:34:32'),
(2, 'Swift Logistics', 'driver@logistics.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+60198765432', 'avatars/0uEef2kumpoCkpkzSaeJTcFG9d3fRMQ8tBbH2ybw.jpg', 'logistics', 1, NULL, '2026-01-11 06:45:55', '2026-03-06 05:33:54'),
(3, 'Fresh Mart KL', 'manager@retailer.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+601122334455', 'avatars/smyoH2chQ05dA5VlXmEAOLBoHhumo3qEBthk5acE.jpg', 'retailer', 1, NULL, '2026-01-11 06:45:55', '2026-03-06 06:38:27'),
(4, 'System Administrator', 'admin@halalchain.my', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+60100000000', NULL, 'admin', 1, NULL, '2026-02-15 14:26:57', '2026-02-15 14:26:57'),
(5, 'Pending Processor Ltd', 'test_p@halal.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+60170000001', NULL, 'processor', 0, NULL, '2026-02-15 15:04:05', '2026-02-15 15:04:05'),
(6, 'Fast Track Logistics', 'test_l@halal.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+60170000002', NULL, 'logistics', 0, NULL, '2026-02-15 15:04:05', '2026-02-15 15:04:05'),
(7, 'Neighborhood Grocery', 'test_r@halal.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+60170000003', NULL, 'retailer', 0, NULL, '2026-02-15 15:04:05', '2026-02-15 15:04:05'),
(8, 'Test Processor', 'testprocessor@example.com', NULL, '$2y$12$iME8scmoL52DD7bS4QrVXOd7x5XPVm.tM1NmMABaZofHPgSRZgdI6', NULL, '1234567890', NULL, 'processor', 1, NULL, '2026-03-05 08:10:13', '2026-03-05 08:10:13'),
(9, 'Top Halal Meat Processor', 'processor2@halal.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+601122334400', NULL, 'processor', 1, NULL, '2026-03-06 05:46:42', '2026-03-06 05:46:42'),
(10, 'Global Cold Chain Logistics', 'driver2@logistics.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+601122334411', NULL, 'logistics', 1, NULL, '2026-03-06 05:46:42', '2026-03-06 05:46:42'),
(11, 'Premium Grocers', 'manager2@retailer.com', NULL, '$2y$12$Y9UiQwl24TNBm59/J91iR.KhKzD4Zahd136jvuViJ1bR0U3.8dYWe', NULL, '+601122334422', NULL, 'retailer', 1, NULL, '2026-03-06 05:46:42', '2026-03-06 05:46:42'),
(12, 'Smoke Processor', 'processor.1773062274@example.com', NULL, '$2y$12$QdbvRlva3qpAeGIV3gVBm.dZjvMVg0QbVmPKkmxCDY1DR4Swd1VzO', NULL, '+60111222333', NULL, 'processor', 1, NULL, '2026-03-09 13:17:56', '2026-03-09 13:17:56'),
(13, 'Smoke Processor', 'processor.1773062338@example.com', NULL, '$2y$12$pDFj2s5m0JomeAdUQ6djBeWnK1mWavnCpn1N7VLVOvgPedYe0VZh2', NULL, '+60111222333', NULL, 'processor', 1, NULL, '2026-03-09 13:18:59', '2026-03-09 13:18:59'),
(14, 'Processor Two', 'processor2.1773062378@example.com', NULL, '$2y$12$FjbD0NbcdQ10hlBMqcWkEeA6Fjldd.7pVDCNtSe4aXFjmDQCTlo7y', NULL, '+60111000001', NULL, 'processor', 1, NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39'),
(15, 'Logistics User', 'logistics.1773062378@example.com', NULL, '$2y$12$XSwdu//HhAo.yZ1iiwdcn.8gb.NviJV1Y6OeiQNZ1HP2dXLhyNxRa', NULL, '+60111000002', NULL, 'logistics', 1, NULL, '2026-03-09 13:19:39', '2026-03-09 13:19:39'),
(16, 'Retailer User', 'retailer.1773062378@example.com', NULL, '$2y$12$8ssHrNnc/OITAqh5KW9eFuTYHTEtQ3jmUJUrs3NWn3RN7nyU2ECTu', NULL, '+60111000003', NULL, 'retailer', 1, NULL, '2026-03-09 13:19:41', '2026-03-09 13:19:41'),
(17, 'Processor Role Test', 'processor3.1773062607@example.com', NULL, '$2y$12$W3tBbDoxNl41A3dbAfe2JuoBbb6idtzAkzxab7XsZuNXpVA4tIepG', NULL, '+60119999999', NULL, 'processor', 1, NULL, '2026-03-09 13:23:28', '2026-03-09 13:23:28'),
(18, 'Manifest User', 'manifest.1773062950@example.com', NULL, '$2y$12$UDDf4vmOcxi4A0vFtEUznuhpgy.AHCeaPJP.8drjPQr.OEfBeEWz2', NULL, '+60110000000', NULL, 'processor', 1, NULL, '2026-03-09 13:29:10', '2026-03-09 13:29:10'),
(19, 'Consumer User', 'consumer.1773062973@example.com', NULL, '$2y$12$VtddHcym5/Rxz0oo2navCewOxGs/6tmKB2Lo4FNUp/0cI8050.7PG', NULL, '+60112223333', NULL, 'consumer', 1, NULL, '2026-03-09 13:29:33', '2026-03-09 13:29:33');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `batches`
--
ALTER TABLE `batches`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `batches_batch_id_unique` (`batch_id`),
  ADD KEY `batches_processor_id_foreign` (`processor_id`),
  ADD KEY `batches_current_holder_id_foreign` (`current_holder_id`);

--
-- Indexes for table `checkpoints`
--
ALTER TABLE `checkpoints`
  ADD PRIMARY KEY (`id`),
  ADD KEY `checkpoints_batch_id_foreign` (`batch_id`),
  ADD KEY `checkpoints_user_id_foreign` (`user_id`);

--
-- Indexes for table `incidents`
--
ALTER TABLE `incidents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `incidents_user_id_foreign` (`user_id`),
  ADD KEY `incidents_batch_id_index` (`batch_id`);

--
-- Indexes for table `logistics_profiles`
--
ALTER TABLE `logistics_profiles`
  ADD PRIMARY KEY (`id`),
  ADD KEY `logistics_profiles_user_id_foreign` (`user_id`);

--
-- Indexes for table `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `personal_access_tokens`
--
ALTER TABLE `personal_access_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  ADD KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`),
  ADD KEY `personal_access_tokens_expires_at_index` (`expires_at`);

--
-- Indexes for table `processor_profiles`
--
ALTER TABLE `processor_profiles`
  ADD PRIMARY KEY (`id`),
  ADD KEY `processor_profiles_user_id_foreign` (`user_id`);

--
-- Indexes for table `retailer_profiles`
--
ALTER TABLE `retailer_profiles`
  ADD PRIMARY KEY (`id`),
  ADD KEY `retailer_profiles_user_id_foreign` (`user_id`);

--
-- Indexes for table `transfers`
--
ALTER TABLE `transfers`
  ADD PRIMARY KEY (`id`),
  ADD KEY `transfers_batch_id_foreign` (`batch_id`),
  ADD KEY `transfers_from_user_id_foreign` (`from_user_id`),
  ADD KEY `transfers_to_user_id_foreign` (`to_user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `users_email_unique` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `batches`
--
ALTER TABLE `batches`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `checkpoints`
--
ALTER TABLE `checkpoints`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT for table `incidents`
--
ALTER TABLE `incidents`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `logistics_profiles`
--
ALTER TABLE `logistics_profiles`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `personal_access_tokens`
--
ALTER TABLE `personal_access_tokens`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=108;

--
-- AUTO_INCREMENT for table `processor_profiles`
--
ALTER TABLE `processor_profiles`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `retailer_profiles`
--
ALTER TABLE `retailer_profiles`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `transfers`
--
ALTER TABLE `transfers`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `batches`
--
ALTER TABLE `batches`
  ADD CONSTRAINT `batches_current_holder_id_foreign` FOREIGN KEY (`current_holder_id`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `batches_processor_id_foreign` FOREIGN KEY (`processor_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `checkpoints`
--
ALTER TABLE `checkpoints`
  ADD CONSTRAINT `checkpoints_batch_id_foreign` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `checkpoints_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `incidents`
--
ALTER TABLE `incidents`
  ADD CONSTRAINT `incidents_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `logistics_profiles`
--
ALTER TABLE `logistics_profiles`
  ADD CONSTRAINT `logistics_profiles_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `processor_profiles`
--
ALTER TABLE `processor_profiles`
  ADD CONSTRAINT `processor_profiles_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `retailer_profiles`
--
ALTER TABLE `retailer_profiles`
  ADD CONSTRAINT `retailer_profiles_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `transfers`
--
ALTER TABLE `transfers`
  ADD CONSTRAINT `transfers_batch_id_foreign` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`),
  ADD CONSTRAINT `transfers_from_user_id_foreign` FOREIGN KEY (`from_user_id`) REFERENCES `users` (`id`),
  ADD CONSTRAINT `transfers_to_user_id_foreign` FOREIGN KEY (`to_user_id`) REFERENCES `users` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
