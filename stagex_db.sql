-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Dec 07, 2025 at 03:01 PM
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
-- Database: `stagex_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_active_shows` ()   BEGIN
    -- Cập nhật trạng thái suất diễn và vở diễn trước khi lấy dữ liệu
    CALL proc_update_statuses();

    -- Trả về các vở diễn đang chiếu (chỉ những vở có ít nhất một suất đang mở bán hoặc đang diễn)
    SELECT show_id, title
    FROM shows
    WHERE status = 'Đang chiếu';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_add_show_genre` (IN `in_show_id` INT, IN `in_genre_id` INT)   BEGIN
    INSERT INTO show_genres (show_id, genre_id)
    VALUES (in_show_id, in_genre_id);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_approve_theater` (IN `in_theater_id` INT)   BEGIN
    UPDATE theaters
    SET status = 'Đã hoạt động'
    WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_available_seats` (IN `in_performance_id` INT)   BEGIN
    SELECT s.seat_id,
           s.row_char,
           s.seat_number,
           IFNULL(sc.category_name, '') AS category_name,
           IFNULL(sc.base_price, 0)      AS base_price
    FROM seats s
    JOIN seat_performance sp ON sp.seat_id = s.seat_id
    LEFT JOIN seat_categories sc ON sc.category_id = s.category_id
    WHERE sp.performance_id = in_performance_id
      AND sp.status = 'trống';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_can_delete_seat_category` (IN `in_category_id` INT)   BEGIN
    SELECT COUNT(*) AS cnt
    FROM seats s
    JOIN performances p ON s.theater_id = p.theater_id
    WHERE s.category_id = in_category_id
      AND p.status = 'Đang mở bán';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_can_delete_theater` (IN `in_theater_id` INT)   BEGIN
    SELECT COUNT(*) AS cnt
    FROM performances
    WHERE theater_id = in_theater_id
      AND status = 'Đang mở bán';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_chart_last_12_months` ()   BEGIN
    SELECT 
        DATE_FORMAT(p.performance_date, '%m/%Y') as period,
        SUM(CASE WHEN sp.status != 'trống' THEN 1 ELSE 0 END) as sold_tickets,
        SUM(CASE WHEN sp.status = 'trống' THEN 1 ELSE 0 END) as unsold_tickets
    FROM performances p
    JOIN seat_performance sp ON p.performance_id = sp.performance_id
    WHERE p.performance_date >= DATE_SUB(NOW(), INTERVAL 11 MONTH)
    GROUP BY YEAR(p.performance_date), MONTH(p.performance_date)
    ORDER BY p.performance_date ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_chart_last_4_weeks` ()   BEGIN
    SELECT 
        CONCAT('Tuần ', WEEK(p.performance_date, 1)) as period,
        SUM(CASE WHEN sp.status != 'trống' THEN 1 ELSE 0 END) as sold_tickets,
        SUM(CASE WHEN sp.status = 'trống' THEN 1 ELSE 0 END) as unsold_tickets
    FROM performances p
    JOIN seat_performance sp ON p.performance_id = sp.performance_id
    WHERE p.performance_date >= DATE_SUB(NOW(), INTERVAL 4 WEEK)
    GROUP BY YEAR(p.performance_date), WEEK(p.performance_date, 1)
    ORDER BY p.performance_date ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_chart_last_7_days` ()   BEGIN
    SELECT 
        DATE_FORMAT(p.performance_date, '%d/%m') as period,
        SUM(CASE WHEN sp.status != 'trống' THEN 1 ELSE 0 END) as sold_tickets,
        SUM(CASE WHEN sp.status = 'trống' THEN 1 ELSE 0 END) as unsold_tickets
    FROM performances p
    JOIN seat_performance sp ON p.performance_id = sp.performance_id
    WHERE p.performance_date >= DATE(NOW()) - INTERVAL 6 DAY
    GROUP BY DATE(p.performance_date)
    ORDER BY p.performance_date ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_check_user_exists` (IN `in_email` VARCHAR(255), IN `in_account_name` VARCHAR(255))   BEGIN
    SELECT COUNT(*) AS exists_count
    FROM users
    WHERE email = in_email OR account_name = in_account_name;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_count_performances_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT COUNT(*) AS performance_count
    FROM performances
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_count_tickets_by_booking` (IN `in_booking_id` INT)   BEGIN
    SELECT COUNT(*) AS ticket_count
    FROM tickets
    WHERE booking_id = in_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_booking` (IN `p_user_id` INT, IN `p_performance_id` INT, IN `p_total` DECIMAL(10,2))   BEGIN
   
    INSERT INTO bookings (
        user_id,
        performance_id,
        total_amount,
        booking_status,
        created_at
    )
    VALUES (
        p_user_id,
        p_performance_id,
        p_total,
        'Đang xử lý',
        NOW()
    );

    SELECT LAST_INSERT_ID() AS booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_booking_pos` (IN `in_user_id` INT, IN `in_performance_id` INT, IN `in_total_amount` DECIMAL(10,2), IN `in_created_by` INT)   BEGIN
    INSERT INTO bookings (user_id, performance_id, total_amount, booking_status, created_at, created_by)
    VALUES (in_user_id, in_performance_id, in_total_amount, 'Đã hoàn thành', NOW(), in_created_by);

    SELECT LAST_INSERT_ID() AS booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_genre` (IN `in_name` VARCHAR(100))   BEGIN
    INSERT INTO genres (genre_name) VALUES (in_name);
    SELECT LAST_INSERT_ID() AS genre_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_payment` (IN `in_booking_id` INT, IN `in_amount` DECIMAL(10,3), IN `in_status` VARCHAR(20), IN `in_txn_ref` VARCHAR(255), IN `in_payment_method` VARCHAR(50))   BEGIN
    INSERT INTO payments (booking_id, amount, status, vnp_txn_ref, payment_method, created_at, updated_at)
    VALUES (in_booking_id, in_amount, in_status, in_txn_ref, in_payment_method, NOW(), NOW());
    SELECT LAST_INSERT_ID() AS payment_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_performance` (IN `in_show_id` INT, IN `in_theater_id` INT, IN `in_performance_date` DATE, IN `in_start_time` TIME, IN `in_end_time` TIME, IN `in_price` DECIMAL(10,3))   BEGIN
   
    DECLARE new_pid INT;
    INSERT INTO performances (show_id, theater_id, performance_date, start_time, end_time, price, status)
    VALUES (in_show_id, in_theater_id, in_performance_date, in_start_time, in_end_time, in_price, 'Đang mở bán');
    SET new_pid = LAST_INSERT_ID();
    INSERT INTO seat_performance (seat_id, performance_id, status)
    SELECT s.seat_id, new_pid, 'trống'
    FROM seats s
    WHERE s.theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_review` (IN `in_show_id` INT, IN `in_user_id` INT, IN `in_rating` INT, IN `in_content` TEXT)   BEGIN
    INSERT INTO reviews (show_id, user_id, rating, content, created_at)
    VALUES (in_show_id, in_user_id, in_rating, in_content, NOW());
    SELECT LAST_INSERT_ID() AS review_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_seat_category` (IN `in_name` VARCHAR(100), IN `in_base_price` DECIMAL(10,3), IN `in_color_class` VARCHAR(50))   BEGIN
    INSERT INTO seat_categories (category_name, base_price, color_class)
    VALUES (in_name, in_base_price, in_color_class);
    SELECT LAST_INSERT_ID() AS category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_show` (IN `in_title` VARCHAR(255), IN `in_description` TEXT, IN `in_duration` INT, IN `in_director` VARCHAR(255), IN `in_poster` VARCHAR(255), IN `in_status` VARCHAR(50))   BEGIN
    INSERT INTO shows (title, description, duration_minutes, director, poster_image_url, status, created_at)
    VALUES (in_title, in_description, in_duration, in_director, in_poster, in_status, NOW());
    SELECT LAST_INSERT_ID() AS show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_theater` (IN `in_name` VARCHAR(255), IN `in_rows` INT, IN `in_cols` INT)   BEGIN
 
    DECLARE new_tid INT;
    DECLARE r INT DEFAULT 1;
    DECLARE c INT;

    INSERT INTO theaters (name, total_seats, status)
    VALUES (in_name, in_rows * in_cols, 'Chờ xử lý');
    SET new_tid = LAST_INSERT_ID();

   
    WHILE r <= in_rows DO
        SET c = 1;
        WHILE c <= in_cols DO
            
            INSERT INTO seats (theater_id, row_char, seat_number, real_seat_number, category_id)
            VALUES (new_tid, CHAR(64 + r), c, c, NULL);
            SET c = c + 1;
        END WHILE;
        SET r = r + 1;
    END WHILE;

   
    SELECT new_tid AS theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_ticket` (IN `p_booking_id` INT, IN `p_seat_id` INT)   BEGIN
    DECLARE v_performance_id INT;
    DECLARE v_new_code BIGINT;
    DECLARE v_exists INT DEFAULT 1;

    -- Vòng lặp sinh mã để đảm bảo không trùng
    WHILE v_exists > 0 DO
        -- Sinh số ngẫu nhiên 13 chữ số
        SET v_new_code = FLOOR(1000000000000 + RAND() * 8999999999999);
        
        -- Kiểm tra xem mã này đã tồn tại chưa
        SELECT COUNT(*) INTO v_exists FROM tickets WHERE ticket_code = v_new_code;
    END WHILE;

    -- Thêm vé mới
    INSERT INTO tickets (booking_id, seat_id, ticket_code, status, created_at)
    VALUES (p_booking_id, p_seat_id, v_new_code, 'Hơp lệ', NOW());

    -- Cập nhật trạng thái ghế trong bảng seat_performance
    SELECT performance_id INTO v_performance_id
    FROM bookings
    WHERE booking_id = p_booking_id;

    IF v_performance_id IS NOT NULL THEN
        UPDATE seat_performance
        SET status = 'đã đặt'
        WHERE seat_id = p_seat_id
          AND performance_id = v_performance_id;
    END IF;
    
    -- Trả về mã vé vừa tạo (nếu cần dùng ngay)
    SELECT v_new_code AS new_ticket_code;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_user` (IN `in_email` VARCHAR(255), IN `in_password` VARCHAR(255), IN `in_account_name` VARCHAR(100), IN `in_user_type` VARCHAR(20), IN `in_verified` TINYINT(1))   BEGIN
    INSERT INTO users (email, password, account_name, user_type, status, is_verified)
    VALUES (in_email, in_password, in_account_name, in_user_type, 'hoạt động', in_verified);
    SELECT LAST_INSERT_ID() AS user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_dashboard_summary` ()   BEGIN
    SELECT 
        (SELECT COALESCE(SUM(total_amount), 0) FROM bookings b JOIN payments p ON b.booking_id = p.booking_id WHERE p.status = 'Thành công') as total_revenue,
        (SELECT COUNT(*) FROM bookings) as total_bookings,
        (SELECT COUNT(*) FROM shows) as total_shows,
        (SELECT COUNT(*) FROM genres) as total_genres;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_actor` (IN `in_actor_id` INT)   BEGIN
    DELETE FROM actors WHERE actor_id = in_actor_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_genre` (IN `in_id` INT)   BEGIN
    DELETE FROM genres WHERE genre_id = in_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_performance_if_ended` (IN `in_performance_id` INT)   BEGIN
    DELETE FROM performances
    WHERE performance_id = in_performance_id AND status = 'Đã kết thúc';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_review` (IN `in_review_id` INT)   BEGIN
    DELETE FROM reviews WHERE review_id = in_review_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_seats_by_theater` (IN `in_theater_id` INT)   BEGIN
    DELETE FROM seats WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_seat_category` (IN `in_category_id` INT)   BEGIN
    DELETE FROM seat_categories WHERE category_id = in_category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_show` (IN `in_show_id` INT)   BEGIN
    DELETE FROM shows WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_show_genres` (IN `in_show_id` INT)   BEGIN
    DELETE FROM show_genres WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_theater` (IN `in_theater_id` INT)   BEGIN
    DELETE FROM theaters WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_user_safe` (IN `in_user_id` INT)   BEGIN
    DECLARE booking_count INT;

    -- 1. Kiểm tra: User này có là Khách hàng (user_id) hoặc Người lập đơn (created_by) không?
    SELECT COUNT(*) INTO booking_count
    FROM bookings
    WHERE user_id = in_user_id OR created_by = in_user_id;

    -- 2. Xử lý logic
    IF booking_count > 0 THEN
        -- Nếu dính dữ liệu -> Bắn lỗi về cho C# (Mã 45000 là lỗi người dùng định nghĩa)
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'USER_HAS_BOOKING_HISTORY';
    ELSE
        -- Nếu sạch -> Xóa User và các thông tin liên quan (UserDetail tự xóa theo Cascade)
        DELETE FROM users WHERE user_id = in_user_id;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_expire_pending_payments` ()   BEGIN
  
    UPDATE payments p
    JOIN bookings b ON p.booking_id = b.booking_id
    SET p.status = 'Thất bại',
        p.updated_at = NOW(),
        b.booking_status = 'Đã hủy'
    WHERE p.status = 'Đang chờ'
      AND TIMESTAMPDIFF(MINUTE, p.created_at, NOW()) >= 15;

    UPDATE tickets t
    JOIN payments p2 ON p2.booking_id = t.booking_id
    SET t.status = 'Đã hủy'
    WHERE p2.status = 'Thất bại'
      AND TIMESTAMPDIFF(MINUTE, p2.created_at, NOW()) >= 15
      AND t.status IN ('Đang chờ', 'Hợp lệ');

    UPDATE seat_performance sp
    JOIN tickets t2 ON sp.seat_id = t2.seat_id
    JOIN payments p3 ON p3.booking_id = t2.booking_id
    JOIN bookings b2 ON b2.booking_id = p3.booking_id
    SET sp.status = 'trống'
    WHERE p3.status = 'Thất bại'
      AND TIMESTAMPDIFF(MINUTE, p3.created_at, NOW()) >= 15
      AND sp.performance_id = b2.performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_actors` (IN `in_keyword` VARCHAR(255))   BEGIN
    SELECT * -- Lấy hết các cột mới
    FROM actors
    WHERE in_keyword IS NULL
          OR in_keyword = ''
          OR full_name LIKE CONCAT('%', in_keyword, '%')
          OR nick_name LIKE CONCAT('%', in_keyword, '%')
    ORDER BY actor_id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_admin_staff_users` ()   BEGIN
    SELECT *
    FROM users
    WHERE user_type IN ('Nhân viên','Admin')
    ORDER BY user_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_bookings` ()   BEGIN
    SELECT b.*, u.email
    FROM bookings b
    JOIN users u ON b.user_id = u.user_id
    ORDER BY b.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_genres` ()   BEGIN
   
    SELECT * FROM genres ORDER BY genre_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_performances_detailed` ()   BEGIN
    SELECT p.*, s.title, t.name AS theater_name
    FROM performances p
    JOIN shows s ON p.show_id = s.show_id
    JOIN theaters t ON p.theater_id = t.theater_id
    ORDER BY p.performance_date, p.start_time;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_reviews` ()   BEGIN
 
    SELECT r.*, r.show_id AS show_id, u.account_name AS account_name, s.title
    FROM reviews r
    JOIN users u ON r.user_id = u.user_id
    JOIN shows s ON r.show_id = s.show_id
    ORDER BY r.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_seat_categories` ()   BEGIN
    SELECT * FROM seat_categories ORDER BY category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_shows` ()   BEGIN
    SELECT s.*, GROUP_CONCAT(g.genre_name SEPARATOR ', ') AS genres
    FROM shows s
    LEFT JOIN show_genres sg ON s.show_id = sg.show_id
    LEFT JOIN genres g ON sg.genre_id = g.genre_id
    GROUP BY s.show_id
    ORDER BY s.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_theaters` ()   BEGIN

    SELECT * FROM theaters ORDER BY theater_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_average_rating_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT AVG(rating) AS avg_rating
    FROM reviews
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_booked_seat_ids` (IN `in_performance_id` INT)   BEGIN

    SELECT sp.seat_id
    FROM seat_performance sp
    WHERE sp.performance_id = in_performance_id
      AND sp.status = 'đã đặt';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_bookings_by_user` (IN `in_user_id` INT)   BEGIN
    SELECT * FROM bookings
    WHERE user_id = in_user_id
    ORDER BY created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_booking_with_tickets` (IN `in_booking_id` INT)   BEGIN
 
    SELECT b.*, t.ticket_id, t.ticket_code, s.row_char, s.real_seat_number AS seat_number,
           sc.category_name, sc.color_class,
           (p.price + sc.base_price) AS ticket_price
    FROM bookings b
    LEFT JOIN tickets t ON b.booking_id = t.booking_id
    LEFT JOIN seats s ON t.seat_id = s.seat_id
    LEFT JOIN seat_categories sc ON s.category_id = sc.category_id
    LEFT JOIN performances p ON b.performance_id = p.performance_id
    WHERE b.booking_id = in_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_genres` ()   BEGIN
    SELECT * FROM genres ORDER BY genre_name;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_genre_ids_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT genre_id
    FROM show_genres
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_latest_reviews` (IN `in_limit` INT)   BEGIN
    SELECT r.*, u.account_name AS account_name, s.title AS show_title
    FROM reviews r
    JOIN users u ON r.user_id = u.user_id
    JOIN shows s ON r.show_id = s.show_id
    ORDER BY r.created_at DESC
    LIMIT in_limit;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_payments_by_booking` (IN `in_booking_id` INT)   BEGIN
    SELECT * FROM payments WHERE booking_id = in_booking_id ORDER BY created_at ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_payment_by_txn` (IN `in_txn_ref` VARCHAR(255))   BEGIN
    SELECT * FROM payments WHERE vnp_txn_ref = in_txn_ref LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_performances_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT p.*, t.name AS theater_name
    FROM performances p
    JOIN theaters t ON p.theater_id = t.theater_id
 
    WHERE p.show_id = in_show_id AND p.status = 'Đang mở bán'
    ORDER BY p.performance_date, p.start_time;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_performance_by_id` (IN `in_performance_id` INT)   BEGIN
    SELECT p.*, t.name AS theater_name
    FROM performances p
    JOIN theaters t ON p.theater_id = t.theater_id
    WHERE p.performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_performance_detailed_by_id` (IN `in_performance_id` INT)   BEGIN
    SELECT p.*, s.title, t.name AS theater_name
    FROM performances p
    JOIN shows s ON p.show_id = s.show_id
    JOIN theaters t ON p.theater_id = t.theater_id
    WHERE p.performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_reviews_by_show` (IN `in_show_id` INT)   BEGIN
  
    SELECT r.*, u.account_name AS account_name
    FROM reviews r
    JOIN users u ON r.user_id = u.user_id
    WHERE r.show_id = in_show_id
    ORDER BY r.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seats_for_theater` (IN `in_theater_id` INT)   BEGIN
  
    SELECT
        s.seat_id,
        s.theater_id,
        s.category_id,
        s.row_char,
        s.seat_number,
        s.real_seat_number,
        s.created_at,
        c.category_name,
        c.base_price,
        c.color_class
    FROM seats s
    LEFT JOIN seat_categories c ON s.category_id = c.category_id
    WHERE s.theater_id = in_theater_id
    ORDER BY s.row_char, s.seat_number;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seat_categories` ()   BEGIN
    SELECT category_id, category_name, base_price, color_class
    FROM seat_categories
    ORDER BY category_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seat_category_by_id` (IN `in_category_id` INT)   BEGIN
    SELECT * FROM seat_categories WHERE category_id = in_category_id LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seat_category_by_price` (IN `in_base_price` DECIMAL(10,3))   BEGIN
    SELECT * FROM seat_categories WHERE base_price = in_base_price LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_show_by_id` (IN `in_show_id` INT)   BEGIN
    SELECT s.*, GROUP_CONCAT(g.genre_name SEPARATOR ', ') AS genres
    FROM shows s
    LEFT JOIN show_genres sg ON s.show_id = sg.show_id
    LEFT JOIN genres g ON sg.genre_id = g.genre_id
    WHERE s.show_id = in_show_id
    GROUP BY s.show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_staff_users` ()   BEGIN
    SELECT * FROM users WHERE user_type = 'Nhân viên' ORDER BY user_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_bookings_detailed` (IN `in_user_id` INT)   BEGIN
  
    SELECT b.*, GROUP_CONCAT(CONCAT(s.row_char, s.real_seat_number) ORDER BY s.row_char, s.seat_number SEPARATOR ', ') AS seats
    FROM bookings b
    LEFT JOIN tickets t ON b.booking_id = t.booking_id
    LEFT JOIN seats s ON t.seat_id = s.seat_id
    WHERE b.user_id = in_user_id
    GROUP BY b.booking_id
    ORDER BY b.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_by_account_name` (IN `in_account_name` VARCHAR(100))   BEGIN
    SELECT * FROM users WHERE account_name = in_account_name LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_by_email` (IN `in_email` VARCHAR(255))   BEGIN
    SELECT * FROM users WHERE email = in_email LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_by_id` (IN `in_user_id` INT)   BEGIN
    SELECT * FROM users WHERE user_id = in_user_id LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_detail_by_id` (IN `in_user_id` INT)   BEGIN
    SELECT * FROM user_detail WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_insert_actor` (IN `in_full_name` VARCHAR(255), IN `in_date_of_birth` DATE, IN `in_gender` VARCHAR(10), IN `in_nick_name` VARCHAR(255), IN `in_email` VARCHAR(255), IN `in_phone` VARCHAR(20), IN `in_status` VARCHAR(50))   BEGIN
    INSERT INTO actors (full_name, date_of_birth, gender, nick_name, email, phone, status, created_at)
    VALUES (in_full_name, in_date_of_birth, in_gender, in_nick_name, in_email, in_phone, in_status, NOW());
    SELECT LAST_INSERT_ID() AS actor_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_modify_theater_size` (IN `in_theater_id` INT, IN `in_add_rows` INT, IN `in_add_cols` INT)   BEGIN
    DECLARE maxRowChar CHAR(1);
    DECLARE oldRows INT;
    DECLARE oldCols INT;
    DECLARE r INT;
    DECLARE c INT;
    DECLARE addc INT;
 
    SELECT MAX(row_char) INTO maxRowChar FROM seats WHERE theater_id = in_theater_id;
    IF maxRowChar IS NULL THEN
        SET oldRows = 0;
    ELSE
        SET oldRows = ASCII(maxRowChar) - 64;
    END IF;
    SELECT MAX(seat_number) INTO oldCols FROM seats WHERE theater_id = in_theater_id;
    IF oldCols IS NULL THEN
        SET oldCols = 0;
    END IF;
  
    IF in_add_rows > 0 THEN
        SET r = oldRows + 1;
        WHILE r <= oldRows + in_add_rows DO
            SET c = 1;
            WHILE c <= oldCols DO
                INSERT INTO seats (theater_id, row_char, seat_number, real_seat_number, category_id)
                VALUES (in_theater_id, CHAR(64 + r), c, c, NULL);
                SET c = c + 1;
            END WHILE;
            SET r = r + 1;
        END WHILE;
    END IF;
 
    IF in_add_rows < 0 THEN
        DELETE FROM seats
        WHERE theater_id = in_theater_id
          AND (ASCII(row_char) - 64) > oldRows + in_add_rows;
    END IF;
  
    IF in_add_cols > 0 THEN
        SET addc = 1;
        WHILE addc <= in_add_cols DO
            INSERT INTO seats (theater_id, row_char, seat_number, real_seat_number, category_id)
            SELECT in_theater_id, row_char, oldCols + addc, oldCols + addc, NULL
            FROM (SELECT DISTINCT row_char FROM seats WHERE theater_id = in_theater_id) AS row_list;
            SET addc = addc + 1;
        END WHILE;
    END IF;

    IF in_add_cols < 0 THEN
        DELETE FROM seats
        WHERE theater_id = in_theater_id
          AND seat_number > oldCols + in_add_cols;
    END IF;

    CALL proc_update_theater_seat_counts();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_performances_by_show` (IN `in_show_id` INT)   BEGIN
    -- Cập nhật trạng thái suất diễn và vở diễn trước khi lấy dữ liệu
    CALL proc_update_statuses();

    -- Trả về các suất chiếu thuộc vở diễn đang mở bán
    SELECT performance_id,
           performance_date,
           start_time,
           end_time,
           price
    FROM performances
    WHERE show_id = in_show_id
      AND status = 'Đang mở bán';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_rating_distribution` ()   BEGIN
    SELECT rating as star, COUNT(*) as rating_count
    FROM reviews
    GROUP BY rating
    ORDER BY rating;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_revenue_monthly` ()   BEGIN
    SELECT 
        DATE_FORMAT(b.created_at, '%m/%Y') as month, 
        COALESCE(SUM(b.total_amount), 0) as total_revenue
    FROM bookings b
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.status = 'Thành công'
    GROUP BY YEAR(b.created_at), MONTH(b.created_at)
    ORDER BY b.created_at ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_save_actor` (IN `in_id` INT, IN `in_fullname` VARCHAR(255), IN `in_nickname` VARCHAR(255), IN `in_dob` DATE, IN `in_gender` VARCHAR(10), IN `in_email` VARCHAR(255), IN `in_phone` VARCHAR(20), IN `in_status` VARCHAR(50))   BEGIN
    IF in_id > 0 THEN
        -- Cập nhật
        UPDATE actors 
        SET full_name = in_fullname, nick_name = in_nickname, date_of_birth = in_dob,
            gender = in_gender, email = in_email, phone = in_phone, status = in_status
        WHERE actor_id = in_id;
    ELSE
        -- Thêm mới
        INSERT INTO actors (full_name, nick_name, date_of_birth, gender, email, phone, status, created_at)
        VALUES (in_fullname, in_nickname, in_dob, in_gender, in_email, in_phone, in_status, NOW());
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_save_genre` (IN `in_id` INT, IN `in_name` VARCHAR(100))   BEGIN
    IF in_id > 0 THEN
        UPDATE genres SET genre_name = in_name WHERE genre_id = in_id;
    ELSE
        INSERT INTO genres (genre_name) VALUES (in_name);
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_seats_with_status` (IN `in_performance_id` INT)   BEGIN
    SELECT s.seat_id                    AS seat_id,
           s.row_char                   AS row_char,
           s.seat_number                AS seat_number,
           s.real_seat_number           AS real_seat_number, -- [THÊM DÒNG NÀY]
           IFNULL(sc.category_name, '') AS category_name,
           IFNULL(sc.base_price, 0)     AS base_price,
           (sp.status <> 'trống')       AS is_sold,
           sc.color_class               AS color_class
    FROM seats s
    JOIN seat_performance sp ON sp.seat_id = s.seat_id
    LEFT JOIN seat_categories sc ON sc.category_id = s.category_id
    WHERE sp.performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_set_user_otp` (IN `in_user_id` INT, IN `in_otp_code` VARCHAR(10), IN `in_expires` DATETIME)   BEGIN
    UPDATE users
    SET otp_code = in_otp_code,
        otp_expires_at = in_expires
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_daily` ()   BEGIN
    /*
      Trả về danh sách số lượng vé đã bán theo từng ngày.
      Vé được coi là đã bán khi status nằm trong ('Hợp lệ','Đã sử dụng').
    */
    SELECT DATE_FORMAT(t.created_at, '%Y-%m-%d') AS period,
           COUNT(*) AS sold_tickets
    FROM tickets t
    WHERE t.status IN ('Hợp lệ','Đã sử dụng')
    GROUP BY DATE_FORMAT(t.created_at, '%Y-%m-%d')
    ORDER BY DATE_FORMAT(t.created_at, '%Y-%m-%d');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_monthly` ()   BEGIN
    /*
      Trả về số lượng vé bán cho mỗi tháng (yyyy-mm).
    */
    SELECT DATE_FORMAT(t.created_at, '%Y-%m') AS period,
           COUNT(*) AS sold_tickets
    FROM tickets t
    WHERE t.status IN ('Hợp lệ','Đã sử dụng')
    GROUP BY DATE_FORMAT(t.created_at, '%Y-%m')
    ORDER BY DATE_FORMAT(t.created_at, '%Y-%m');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_weekly` ()   BEGIN
    /*
      Trả về số lượng vé bán cho mỗi tuần ISO (năm và số tuần).
      period trả về dạng YEARWEEK ISO.
    */
    SELECT CONVERT(YEARWEEK(t.created_at, 3), CHAR) AS period,
           COUNT(*) AS sold_tickets
    FROM tickets t
    WHERE t.status IN ('Hợp lệ','Đã sử dụng')
    GROUP BY YEARWEEK(t.created_at, 3)
    ORDER BY YEARWEEK(t.created_at, 3);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_yearly` ()   BEGIN
    SELECT 
        CAST(YEAR(p.performance_date) AS CHAR) as period,
        SUM(CASE WHEN sp.status != 'trống' THEN 1 ELSE 0 END) as sold_tickets,
        SUM(CASE WHEN sp.status = 'trống' THEN 1 ELSE 0 END) as unsold_tickets
    FROM performances p
    JOIN seat_performance sp ON p.performance_id = sp.performance_id
    GROUP BY YEAR(p.performance_date)
    ORDER BY YEAR(p.performance_date);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top3_nearest_performances` ()   BEGIN
    -- Cập nhật trạng thái suất diễn và vở diễn để đảm bảo dữ liệu chính xác
    CALL proc_update_statuses();
    -- Lấy các suất đang mở bán hoặc đang diễn, sắp xếp tăng dần theo ngày giờ bắt đầu, giới hạn 3 suất
    SELECT performance_id,
           performance_date,
           start_time,
           end_time,
           price
    FROM performances
    WHERE status IN ('Đang mở bán','Đang diễn')
    ORDER BY CONCAT(performance_date, ' ', start_time) ASC
    LIMIT 3;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top3_nearest_performances_extended` ()   BEGIN
    -- Cập nhật trạng thái trước khi lấy dữ liệu
    CALL proc_update_statuses();
    -- Lấy top 3 suất diễn sớm nhất đang mở bán hoặc đang diễn, kèm thông tin vở diễn và số vé đã bán
    SELECT p.performance_id,
           s.title AS show_title,
           p.performance_date,
           p.start_time,
           p.end_time,
           p.price,
           SUM(sp.status <> 'trống') AS sold_count,
           COUNT(sp.seat_id)         AS total_count
    FROM performances p
    JOIN shows s ON s.show_id = p.show_id
    JOIN seat_performance sp ON sp.performance_id = p.performance_id
    WHERE p.status IN ('Đang mở bán','Đang diễn')
    GROUP BY p.performance_id
    ORDER BY CONCAT(p.performance_date, ' ', p.start_time) ASC
    LIMIT 3;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top5_shows_by_date_range` (IN `p_start_date` DATETIME, IN `p_end_date` DATETIME)   BEGIN
    SELECT 
        s.title as show_name, 
        COUNT(t.ticket_id) as sold_tickets
    FROM shows s
    JOIN performances p ON s.show_id = p.show_id
    JOIN bookings b ON p.performance_id = b.performance_id
    JOIN tickets t ON b.booking_id = t.booking_id
    JOIN payments pay ON b.booking_id = pay.booking_id
    WHERE pay.status = 'Thành công'
      -- Nếu tham số NULL thì lấy hết, ngược lại lọc theo ngày tạo đơn
      AND (p_start_date IS NULL OR b.created_at >= p_start_date)
      AND (p_end_date IS NULL OR b.created_at <= p_end_date)
    GROUP BY s.show_id
    ORDER BY sold_tickets DESC
    LIMIT 5;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top5_shows_by_tickets` ()   BEGIN
    SELECT 
        s.title as show_name, 
        COUNT(t.ticket_id) as sold_tickets
    FROM shows s
    JOIN performances p ON s.show_id = p.show_id
    JOIN bookings b ON p.performance_id = b.performance_id
    JOIN tickets t ON b.booking_id = t.booking_id
    JOIN payments pay ON b.booking_id = pay.booking_id
    WHERE pay.status = 'Thành công'
    GROUP BY s.show_id
    ORDER BY sold_tickets DESC
    LIMIT 5;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_actor` (IN `in_actor_id` INT, IN `in_full_name` VARCHAR(255), IN `in_date_of_birth` DATE, IN `in_gender` VARCHAR(10), IN `in_nick_name` VARCHAR(255), IN `in_email` VARCHAR(255), IN `in_phone` VARCHAR(20), IN `in_status` VARCHAR(50))   BEGIN
    UPDATE actors
    SET full_name = in_full_name,
        date_of_birth = in_date_of_birth,
        gender = in_gender,
        nick_name = in_nick_name,
        email = in_email,
        phone = in_phone,
        status = in_status
    WHERE actor_id = in_actor_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_booking_status` (IN `in_booking_id` INT, IN `in_booking_status` VARCHAR(20))   BEGIN
    UPDATE bookings
    SET booking_status = in_booking_status
    WHERE booking_id = in_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_genre` (IN `in_id` INT, IN `in_name` VARCHAR(100))   BEGIN
    UPDATE genres
    SET genre_name = in_name
    WHERE genre_id = in_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_payment_status` (IN `in_txn_ref` VARCHAR(255), IN `in_status` VARCHAR(20), IN `in_bank_code` VARCHAR(255), IN `in_pay_date` VARCHAR(255))   BEGIN

    UPDATE payments
    SET status = in_status,
        vnp_bank_code = in_bank_code,
        vnp_pay_date = in_pay_date,
        updated_at = NOW()
    WHERE vnp_txn_ref = in_txn_ref;

    IF in_status = 'Thất bại' THEN
      
        UPDATE bookings b
        JOIN payments p ON p.booking_id = b.booking_id
        SET b.booking_status = 'Đã hủy'
        WHERE p.vnp_txn_ref = in_txn_ref;

        UPDATE tickets t
        JOIN payments p2 ON p2.booking_id = t.booking_id
        SET t.status = 'Đã hủy'
        WHERE p2.vnp_txn_ref = in_txn_ref
          AND t.status IN ('Đang chờ','Hợp lệ');

        UPDATE seat_performance sp
        JOIN tickets t2 ON sp.seat_id = t2.seat_id
        JOIN payments p3 ON p3.booking_id = t2.booking_id
        JOIN bookings b2 ON b2.booking_id = p3.booking_id
        SET sp.status = 'trống'
        WHERE p3.vnp_txn_ref = in_txn_ref
          AND sp.performance_id = b2.performance_id;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_performance_statuses` ()   BEGIN
    UPDATE performances
    SET status = 'Đã kết thúc'
    WHERE status NOT IN ('Đã kết thúc','Đã hủy')
      AND (
        performance_date < CURDATE()
        OR (performance_date = CURDATE() AND end_time IS NOT NULL AND end_time < CURTIME())
      );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_performance_status_single` (IN `in_performance_id` INT, IN `in_status` VARCHAR(20))   BEGIN
    UPDATE performances
    SET status = in_status
    WHERE performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_seat_category` (IN `in_category_id` INT, IN `in_name` VARCHAR(100), IN `in_base_price` DECIMAL(10,3), IN `in_color_class` VARCHAR(50))   BEGIN
    UPDATE seat_categories
    SET category_name = in_name,
        base_price    = in_base_price,
        color_class   = in_color_class
    WHERE category_id = in_category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_seat_category_range` (IN `in_theater_id` INT, IN `in_row_char` CHAR(1), IN `in_start_seat` INT, IN `in_end_seat` INT, IN `in_category_id` INT)   BEGIN
 
    UPDATE seats
    SET category_id = IF(in_category_id = 0, NULL, in_category_id)
    WHERE theater_id = in_theater_id
      AND row_char = in_row_char
      AND seat_number BETWEEN in_start_seat AND in_end_seat;

    SET @rn := 0;
    UPDATE seats s
    JOIN (
        SELECT seat_id, (@rn := @rn + 1) AS new_num
        FROM seats
        WHERE theater_id = in_theater_id
          AND row_char = in_row_char
          AND category_id IS NOT NULL
        ORDER BY seat_number
    ) AS ordered ON s.seat_id = ordered.seat_id
    SET s.real_seat_number = ordered.new_num;

    UPDATE seats
    SET real_seat_number = 0
    WHERE theater_id = in_theater_id
      AND row_char = in_row_char
      AND category_id IS NULL;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_show_details` (IN `in_show_id` INT, IN `in_title` VARCHAR(255), IN `in_description` TEXT, IN `in_duration` INT, IN `in_director` VARCHAR(255), IN `in_poster` VARCHAR(255))   BEGIN
    UPDATE shows
    SET title            = in_title,
        description      = in_description,
        duration_minutes = in_duration,
        director         = in_director,
        poster_image_url = in_poster
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_show_statuses` ()   BEGIN

    UPDATE shows s
    SET s.status = (
        CASE
            WHEN (SELECT COUNT(*) FROM performances p WHERE p.show_id = s.show_id) = 0 THEN 'Sắp chiếu'
            WHEN (SELECT COUNT(*) FROM performances p WHERE p.show_id = s.show_id AND p.status <> 'Đã kết thúc') = 0 THEN 'Đã kết thúc'
            ELSE 'Đang chiếu'
        END
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_staff_user` (IN `in_user_id` INT, IN `in_account_name` VARCHAR(100), IN `in_email` VARCHAR(255), IN `in_status` VARCHAR(50))   BEGIN
    UPDATE users
    SET account_name = in_account_name,
        email        = in_email,
        status       = in_status
    WHERE user_id = in_user_id AND user_type = 'Nhân viên';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_statuses` ()   BEGIN
    -- Cập nhật trạng thái cho performances (TRỪ NHỮNG SUẤT ĐÃ HỦY)
    UPDATE performances
    SET status =
        CASE
            -- 1. Nếu hiện tại > Giờ kết thúc -> 'Đã kết thúc'
            WHEN (CONCAT(performance_date, ' ', COALESCE(end_time, start_time)) < NOW()) THEN 'Đã kết thúc'
            
            -- 2. Nếu chưa qua giờ kết thúc (bất kể đã bắt đầu hay chưa) -> Giữ nguyên trạng thái cũ
            -- (Trừ khi bạn muốn thêm trạng thái 'Đang diễn', nếu không thì cứ để 'Đang mở bán')
            ELSE 'Đang mở bán' 
        END
    WHERE status != 'Đã hủy' -- Không đụng vào suất đã hủy
      AND status != 'Đã kết thúc'; -- Tối ưu: Không cần update lại cái đã kết thúc rồi

    -- Cập nhật trạng thái bảng Shows (Giữ nguyên logic cũ)
    UPDATE shows s
    SET s.status = (
        CASE
            WHEN EXISTS (SELECT 1 FROM performances p WHERE p.show_id = s.show_id AND p.status = 'Đang mở bán') THEN 'Đang chiếu'
            WHEN NOT EXISTS (SELECT 1 FROM performances p WHERE p.show_id = s.show_id AND p.status <> 'Đã kết thúc' AND p.status <> 'Đã hủy') THEN 'Đã kết thúc'
            ELSE s.status
        END
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_theater` (IN `in_theater_id` INT, IN `in_name` VARCHAR(255))   BEGIN
    UPDATE theaters
    SET name = in_name
    WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_theater_seat_counts` ()   BEGIN
    UPDATE theaters t
    LEFT JOIN (
        SELECT theater_id, COUNT(seat_id) AS total_seats
        FROM seats
        GROUP BY theater_id
    ) AS seat_count
    ON t.theater_id = seat_count.theater_id
    SET t.total_seats = COALESCE(seat_count.total_seats, 0);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_unverified_user_password_email` (IN `in_user_id` INT, IN `in_password` VARCHAR(255), IN `in_email` VARCHAR(255))   BEGIN
    UPDATE users
    SET password = in_password,
        email = in_email
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_unverified_user_password_name` (IN `in_user_id` INT, IN `in_password` VARCHAR(255), IN `in_account_name` VARCHAR(100))   BEGIN
    UPDATE users
    SET password = in_password,
        account_name = in_account_name
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_user_password` (IN `in_user_id` INT, IN `in_password` VARCHAR(255))   BEGIN
    UPDATE users
    SET password = in_password,
        otp_code = NULL,
        otp_expires_at = NULL
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_upsert_user_detail` (IN `in_user_id` INT, IN `in_full_name` VARCHAR(255), IN `in_date_of_birth` DATE, IN `in_address` VARCHAR(255), IN `in_phone` VARCHAR(20))   BEGIN
    INSERT INTO user_detail (user_id, full_name, date_of_birth, address, phone)
    VALUES (in_user_id, in_full_name, in_date_of_birth, in_address, in_phone)
    ON DUPLICATE KEY UPDATE
        full_name     = VALUES(full_name),
        date_of_birth = VALUES(date_of_birth),
        address       = VALUES(address),
        phone         = VALUES(phone);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_verify_user_otp` (IN `in_user_id` INT, IN `in_otp_code` VARCHAR(10))   BEGIN
    DECLARE v INT DEFAULT 0;
    SELECT CASE
            WHEN otp_code = in_otp_code AND otp_expires_at >= NOW() THEN 1
            ELSE 0
        END AS verified
    INTO v
    FROM users
    WHERE user_id = in_user_id;
    IF v = 1 THEN
        UPDATE users
        SET is_verified = 1,
            otp_code = NULL,
            otp_expires_at = NULL
        WHERE user_id = in_user_id;
    END IF;
    SELECT v AS verified;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `actors`
--

CREATE TABLE `actors` (
  `actor_id` int(11) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `date_of_birth` date DEFAULT NULL,
  `gender` varchar(10) DEFAULT NULL,
  `nick_name` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `status` enum('Hoạt động','Ngừng hoạt động') NOT NULL DEFAULT 'Hoạt động',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `actors`
--

INSERT INTO `actors` (`actor_id`, `full_name`, `date_of_birth`, `gender`, `nick_name`, `email`, `phone`, `status`, `created_at`) VALUES
(1, 'Thành Lộc', NULL, NULL, 'Phù thủy sân khấu', NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(2, 'Hữu Châu', NULL, NULL, NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(3, 'Hồng Vân', NULL, NULL, 'NSND Hồng Vân', NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(4, 'Hoài Linh', NULL, NULL, 'Sáu Bảnh', NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(5, 'Trấn Thành', NULL, NULL, 'A Xìn', NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(6, 'Thu Trang', NULL, NULL, 'Hoa hậu hài', NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(7, 'Tiến Luật', NULL, NULL, NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(8, 'Diệu Nhi', NULL, NULL, NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(9, 'Minh Dự', NULL, NULL, 'Thánh chửi', NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(10, 'Hải Triều', NULL, NULL, 'Lụa', NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58');

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `booking_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `performance_id` int(11) NOT NULL,
  `total_amount` decimal(10,3) NOT NULL,
  `booking_status` enum('Đang xử lý','Đã hoàn thành','Đã hủy') NOT NULL DEFAULT 'Đang xử lý',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `created_by` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `bookings`
--

INSERT INTO `bookings` (`booking_id`, `user_id`, `performance_id`, `total_amount`, `booking_status`, `created_at`, `created_by`) VALUES
(1, NULL, 1, 900000.000, 'Đã hoàn thành', '2024-12-20 10:15:22', 6),
(2, NULL, 1, 600000.000, 'Đã hoàn thành', '2024-12-20 15:33:11', 11),
(3, NULL, 1, 900000.000, 'Đã hoàn thành', '2024-12-21 09:44:55', 12),
(4, 3, 1, 600000.000, 'Đã hoàn thành', '2024-12-21 16:22:33', NULL),
(5, NULL, 1, 900000.000, 'Đã hoàn thành', '2024-12-22 11:11:08', 13),
(6, NULL, 1, 600000.000, 'Đã hoàn thành', '2024-12-22 19:55:19', 6),
(7, NULL, 1, 900000.000, 'Đã hoàn thành', '2024-12-23 08:33:44', 11),
(8, 4, 1, 900000.000, 'Đã hoàn thành', '2024-12-23 14:44:22', NULL),
(9, NULL, 1, 600000.000, 'Đã hoàn thành', '2024-12-24 10:55:11', 12),
(10, NULL, 1, 825000.000, 'Đã hoàn thành', '2024-12-24 17:22:55', 13),
(11, NULL, 1, 450000.000, 'Đã hoàn thành', '2024-12-25 12:33:19', 6),
(12, NULL, 2, 1200000.000, 'Đã hoàn thành', '2025-01-08 09:18:33', 11),
(13, NULL, 2, 1200000.000, 'Đã hoàn thành', '2025-01-08 15:29:11', 12),
(14, 8, 2, 800000.000, 'Đã hoàn thành', '2025-01-09 11:44:55', NULL),
(15, NULL, 2, 800000.000, 'Đã hoàn thành', '2025-01-09 17:33:22', 13),
(16, NULL, 2, 1200000.000, 'Đã hoàn thành', '2025-01-10 10:22:08', 6),
(17, NULL, 2, 700000.000, 'Đã hoàn thành', '2025-01-10 19:11:44', 11),
(18, 2, 2, 700000.000, 'Đã hoàn thành', '2025-01-11 13:55:33', NULL),
(19, NULL, 3, 675000.000, 'Đã hoàn thành', '2024-12-21 10:18:22', 12),
(20, NULL, 3, 675000.000, 'Đã hoàn thành', '2024-12-21 16:29:11', 13),
(21, 9, 3, 450000.000, 'Đã hoàn thành', '2024-12-22 09:44:55', NULL),
(22, NULL, 3, 675000.000, 'Đã hoàn thành', '2024-12-22 14:33:33', 6),
(23, NULL, 3, 450000.000, 'Đã hoàn thành', '2024-12-23 11:11:08', 11),
(24, NULL, 3, 450000.000, 'Đã hoàn thành', '2024-12-23 18:55:19', 12),
(25, 4, 3, 450000.000, 'Đã hoàn thành', '2024-12-24 10:22:44', NULL),
(26, NULL, 3, 300000.000, 'Đã hoàn thành', '2024-12-24 15:33:11', 13),
(27, NULL, 3, 450000.000, 'Đã hoàn thành', '2024-12-25 09:11:22', 6),
(28, NULL, 3, 300000.000, 'Đã hoàn thành', '2024-12-25 14:44:55', 11),
(29, 10, 3, 300000.000, 'Đã hoàn thành', '2024-12-25 19:22:33', NULL),
(30, NULL, 4, 1050000.000, 'Đã hoàn thành', '2025-01-10 10:25:44', 12),
(31, NULL, 4, 1050000.000, 'Đã hoàn thành', '2025-01-10 15:33:22', 13),
(32, 3, 4, 700000.000, 'Đã hoàn thành', '2025-01-11 09:55:11', NULL),
(33, NULL, 4, 550000.000, 'Đã hoàn thành', '2025-01-11 14:22:44', 6),
(34, NULL, 4, 1050000.000, 'Đã hoàn thành', '2025-01-12 11:33:55', 11),
(35, 8, 4, 450000.000, 'Đã hoàn thành', '2025-01-12 17:44:22', NULL),
(36, NULL, 5, 750000.000, 'Đã hoàn thành', '2024-12-28 10:18:33', 13),
(37, NULL, 5, 750000.000, 'Đã hoàn thành', '2024-12-28 15:29:11', 6),
(38, 2, 5, 500000.000, 'Đã hoàn thành', '2024-12-29 09:44:55', NULL),
(39, NULL, 5, 400000.000, 'Đã hoàn thành', '2024-12-29 14:33:22', 11),
(40, NULL, 5, 750000.000, 'Đã hoàn thành', '2024-12-30 11:22:08', 12),
(41, NULL, 5, 400000.000, 'Đã hoàn thành', '2024-12-30 18:55:44', 11),
(42, 4, 5, 300000.000, 'Đã hoàn thành', '2024-12-31 12:33:19', NULL),
(43, NULL, 6, 900000.000, 'Đã hoàn thành', '2025-01-11 09:22:33', 6),
(44, NULL, 6, 600000.000, 'Đã hoàn thành', '2025-01-11 14:44:11', 11),
(45, NULL, 6, 900000.000, 'Đã hoàn thành', '2025-01-12 10:55:22', 12),
(46, 9, 6, 600000.000, 'Đã hoàn thành', '2025-01-12 16:11:44', NULL),
(47, NULL, 6, 900000.000, 'Đã hoàn thành', '2025-01-13 11:33:55', 13),
(48, NULL, 6, 600000.000, 'Đã hoàn thành', '2025-01-13 19:22:08', 6),
(49, NULL, 6, 450000.000, 'Đã hoàn thành', '2025-01-14 09:11:33', 11),
(50, 3, 6, 675000.000, 'Đã hoàn thành', '2025-01-14 13:44:55', NULL),
(51, NULL, 6, 450000.000, 'Đã hoàn thành', '2025-01-14 17:22:22', 12),
(52, NULL, 6, 300000.000, 'Đã hoàn thành', '2025-01-15 10:33:11', 13),
(53, NULL, 6, 300000.000, 'Đã hoàn thành', '2025-01-15 14:55:44', 6),
(54, NULL, 6, 300000.000, 'Đã hoàn thành', '2025-01-15 18:12:08', 11),
(55, 8, 6, 450000.000, 'Đã hoàn thành', '2025-01-15 20:25:33', NULL),
(56, NULL, 7, 1050000.000, 'Đã hoàn thành', '2025-01-03 09:22:11', 6),
(57, NULL, 7, 1050000.000, 'Đã hoàn thành', '2025-01-03 14:33:44', 11),
(58, NULL, 7, 700000.000, 'Đã hoàn thành', '2025-01-04 10:55:22', 12),
(59, 3, 7, 700000.000, 'Đã hoàn thành', '2025-01-04 17:11:33', NULL),
(60, NULL, 7, 900000.000, 'Đã hoàn thành', '2025-01-05 11:44:55', 13),
(61, NULL, 8, 1200000.000, 'Đã hoàn thành', '2025-01-17 09:18:33', 6),
(62, NULL, 8, 1200000.000, 'Đã hoàn thành', '2025-01-17 15:29:11', 11),
(63, NULL, 8, 1200000.000, 'Đã hoàn thành', '2025-01-18 10:22:08', 12),
(64, 4, 8, 800000.000, 'Đã hoàn thành', '2025-01-18 16:33:44', NULL),
(65, NULL, 8, 1200000.000, 'Đã hoàn thành', '2025-01-19 11:55:22', 13),
(66, NULL, 8, 800000.000, 'Đã hoàn thành', '2025-01-19 18:11:33', 6),
(67, NULL, 8, 1200000.000, 'Đã hoàn thành', '2025-01-20 09:44:55', 11),
(68, 8, 8, 800000.000, 'Đã hoàn thành', '2025-01-20 14:22:11', NULL),
(69, NULL, 9, 750000.000, 'Đã hoàn thành', '2025-01-04 10:18:22', 12),
(70, NULL, 9, 750000.000, 'Đã hoàn thành', '2025-01-04 15:29:11', 13),
(71, NULL, 9, 600000.000, 'Đã hoàn thành', '2025-01-05 09:44:55', 6),
(72, 2, 9, 500000.000, 'Đã hoàn thành', '2025-01-05 14:33:22', NULL),
(73, NULL, 9, 750000.000, 'Đã hoàn thành', '2025-01-06 11:22:08', 11),
(74, 9, 9, 400000.000, 'Đã hoàn thành', '2025-01-06 17:55:44', NULL),
(75, NULL, 10, 900000.000, 'Đã hoàn thành', '2025-01-18 09:33:11', 12),
(76, NULL, 10, 900000.000, 'Đã hoàn thành', '2025-01-18 14:44:55', 13),
(77, NULL, 10, 900000.000, 'Đã hoàn thành', '2025-01-19 10:55:22', 6),
(78, NULL, 10, 675000.000, 'Đã hoàn thành', '2025-01-19 17:11:33', 11),
(79, 3, 10, 600000.000, 'Đã hoàn thành', '2025-01-20 11:22:08', NULL),
(80, NULL, 10, 900000.000, 'Đã hoàn thành', '2025-01-20 18:33:44', 12),
(81, 4, 10, 450000.000, 'Đã hoàn thành', '2025-01-21 09:44:55', NULL),
(82, NULL, 11, 1200000.000, 'Đã hoàn thành', '2025-01-03 10:15:22', 6),
(83, NULL, 11, 1200000.000, 'Đã hoàn thành', '2025-01-03 15:33:11', 11),
(84, NULL, 11, 800000.000, 'Đã hoàn thành', '2025-01-04 09:22:33', 12),
(85, 8, 11, 800000.000, 'Đã hoàn thành', '2025-01-04 14:44:11', NULL),
(86, NULL, 11, 1200000.000, 'Đã hoàn thành', '2025-01-05 11:55:22', 13),
(87, 10, 11, 700000.000, 'Đã hoàn thành', '2025-01-05 17:22:44', NULL),
(88, NULL, 12, 900000.000, 'Đã hoàn thành', '2025-01-17 09:11:33', 6),
(89, NULL, 12, 900000.000, 'Đã hoàn thành', '2025-01-17 14:22:08', 11),
(90, NULL, 12, 900000.000, 'Đã hoàn thành', '2025-01-18 10:33:55', 12),
(91, NULL, 12, 675000.000, 'Đã hoàn thành', '2025-01-18 16:44:22', 13),
(92, 2, 12, 600000.000, 'Đã hoàn thành', '2025-01-19 11:55:33', NULL),
(93, NULL, 12, 900000.000, 'Đã hoàn thành', '2025-01-19 18:11:44', 6),
(94, 9, 12, 450000.000, 'Đã hoàn thành', '2025-01-20 09:22:11', NULL),
(95, NULL, 13, 900000.000, 'Đã hoàn thành', '2025-02-15 09:11:22', 6),
(96, NULL, 13, 900000.000, 'Đã hoàn thành', '2025-02-15 14:33:44', 11),
(97, NULL, 13, 900000.000, 'Đã hoàn thành', '2025-02-16 10:22:08', 12),
(98, NULL, 13, 675000.000, 'Đã hoàn thành', '2025-02-16 17:55:33', 13),
(99, 3, 13, 600000.000, 'Đã hoàn thành', '2025-02-17 11:44:55', NULL),
(100, NULL, 13, 900000.000, 'Đã hoàn thành', '2025-02-17 18:22:11', 6),
(101, NULL, 14, 1200000.000, 'Đã hoàn thành', '2025-02-01 09:33:11', 11),
(102, NULL, 14, 1200000.000, 'Đã hoàn thành', '2025-02-01 15:44:55', 12),
(103, NULL, 14, 800000.000, 'Đã hoàn thành', '2025-02-02 10:55:22', 6),
(104, 8, 14, 800000.000, 'Đã hoàn thành', '2025-02-02 16:11:33', NULL),
(105, NULL, 14, 1200000.000, 'Đã hoàn thành', '2025-02-03 11:22:08', 13),
(106, NULL, 15, 1050000.000, 'Đã hoàn thành', '2025-02-22 09:18:33', 6),
(107, NULL, 15, 1050000.000, 'Đã hoàn thành', '2025-02-22 14:29:11', 11),
(108, NULL, 15, 700000.000, 'Đã hoàn thành', '2025-02-23 10:44:55', 12),
(109, 4, 15, 700000.000, 'Đã hoàn thành', '2025-02-23 17:33:22', NULL),
(110, NULL, 16, 1200000.000, 'Đã hoàn thành', '2025-02-08 09:22:33', 6),
(111, NULL, 16, 1200000.000, 'Đã hoàn thành', '2025-02-08 15:33:11', 11),
(112, NULL, 16, 1200000.000, 'Đã hoàn thành', '2025-02-09 10:55:22', 12),
(113, NULL, 16, 900000.000, 'Đã hoàn thành', '2025-02-09 17:11:44', 13),
(114, 2, 16, 800000.000, 'Đã hoàn thành', '2025-02-10 11:33:55', NULL),
(115, NULL, 16, 800000.000, 'Đã hoàn thành', '2025-02-10 18:44:22', 6),
(116, NULL, 17, 750000.000, 'Đã hoàn thành', '2025-02-15 10:18:22', 11),
(117, NULL, 17, 750000.000, 'Đã hoàn thành', '2025-02-15 15:29:11', 12),
(118, NULL, 17, 750000.000, 'Đã hoàn thành', '2025-02-16 09:44:55', 6),
(119, NULL, 17, 750000.000, 'Đã hoàn thành', '2025-02-16 14:33:22', 13),
(120, 9, 17, 500000.000, 'Đã hoàn thành', '2025-02-17 11:22:08', NULL),
(121, 10, 17, 500000.000, 'Đã hoàn thành', '2025-02-17 17:55:44', NULL),
(122, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-02-28 09:11:33', 6),
(123, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-02-28 14:22:08', 11),
(124, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-02-28 15:00:00', 12),
(125, NULL, 18, 675000.000, 'Đã hoàn thành', '2025-02-28 15:30:00', 13),
(126, 3, 18, 600000.000, 'Đã hoàn thành', '2025-03-01 11:55:33', NULL),
(127, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-03-01 18:11:44', 6),
(128, 8, 18, 450000.000, 'Đã hoàn thành', '2025-03-02 09:22:11', NULL),
(129, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-03-15 09:22:11', 6),
(130, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-03-15 14:33:44', 11),
(131, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-03-16 10:55:22', 12),
(132, NULL, 19, 675000.000, 'Đã hoàn thành', '2025-03-16 17:11:33', 13),
(133, 3, 19, 600000.000, 'Đã hoàn thành', '2025-03-17 11:44:55', NULL),
(134, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-03-17 18:22:08', 6),
(135, NULL, 20, 1200000.000, 'Đã hoàn thành', '2025-03-01 09:18:33', 11),
(136, NULL, 20, 1200000.000, 'Đã hoàn thành', '2025-03-01 15:29:11', 12),
(137, NULL, 20, 800000.000, 'Đã hoàn thành', '2025-03-02 10:44:55', 6),
(138, 8, 20, 800000.000, 'Đã hoàn thành', '2025-03-02 16:33:22', NULL),
(139, NULL, 20, 1200000.000, 'Đã hoàn thành', '2025-03-03 11:55:33', 13),
(140, NULL, 21, 1050000.000, 'Đã hoàn thành', '2025-03-22 09:33:11', 6),
(141, NULL, 21, 900000.000, 'Đã hoàn thành', '2025-03-22 14:44:55', 11),
(142, NULL, 21, 700000.000, 'Đã hoàn thành', '2025-03-23 10:22:08', 12),
(143, 4, 21, 550000.000, 'Đã hoàn thành', '2025-03-23 17:11:33', NULL),
(144, NULL, 22, 1200000.000, 'Đã hoàn thành', '2025-03-08 09:11:22', 6),
(145, NULL, 22, 1200000.000, 'Đã hoàn thành', '2025-03-08 15:22:44', 11),
(146, NULL, 22, 1200000.000, 'Đã hoàn thành', '2025-03-09 10:33:55', 12),
(147, NULL, 22, 1200000.000, 'Đã hoàn thành', '2025-03-09 16:44:22', 13),
(148, 2, 22, 800000.000, 'Đã hoàn thành', '2025-03-10 11:55:33', NULL),
(149, NULL, 22, 1200000.000, 'Đã hoàn thành', '2025-03-10 18:11:44', 6),
(150, NULL, 22, 800000.000, 'Đã hoàn thành', '2025-03-11 09:22:11', 11),
(151, NULL, 23, 750000.000, 'Đã hoàn thành', '2025-03-15 10:18:22', 12),
(152, NULL, 23, 750000.000, 'Đã hoàn thành', '2025-03-15 15:29:11', 13),
(153, NULL, 23, 600000.000, 'Đã hoàn thành', '2025-03-16 09:44:55', 6),
(154, 9, 23, 500000.000, 'Đã hoàn thành', '2025-03-16 14:33:22', NULL),
(155, NULL, 24, 900000.000, 'Đã hoàn thành', '2025-03-29 09:11:33', 6),
(156, NULL, 24, 900000.000, 'Đã hoàn thành', '2025-03-29 14:22:08', 11),
(157, NULL, 24, 900000.000, 'Đã hoàn thành', '2025-03-30 10:33:55', 12),
(158, NULL, 24, 675000.000, 'Đã hoàn thành', '2025-03-30 16:44:22', 13),
(159, 3, 24, 600000.000, 'Đã hoàn thành', '2025-03-31 11:55:33', NULL),
(160, NULL, 24, 900000.000, 'Đã hoàn thành', '2025-03-31 18:11:44', 6),
(161, 8, 24, 450000.000, 'Đã hoàn thành', '2025-04-01 09:22:11', NULL),
(162, NULL, 25, 1200000.000, 'Đã hoàn thành', '2025-04-17 09:11:33', 6),
(163, NULL, 25, 1200000.000, 'Đã hoàn thành', '2025-04-17 14:22:08', 11),
(164, NULL, 25, 1200000.000, 'Đã hoàn thành', '2025-04-18 10:33:55', 12),
(165, NULL, 25, 1200000.000, 'Đã hoàn thành', '2025-04-18 16:44:22', 13),
(166, 3, 25, 800000.000, 'Đã hoàn thành', '2025-04-19 11:55:33', NULL),
(167, NULL, 25, 1200000.000, 'Đã hoàn thành', '2025-04-19 18:11:44', 6),
(168, NULL, 26, 900000.000, 'Đã hoàn thành', '2025-04-03 09:22:11', 11),
(169, NULL, 26, 900000.000, 'Đã hoàn thành', '2025-04-03 15:33:44', 12),
(170, NULL, 26, 750000.000, 'Đã hoàn thành', '2025-04-04 10:55:22', 6),
(171, 8, 26, 600000.000, 'Đã hoàn thành', '2025-04-04 17:11:33', NULL),
(172, NULL, 27, 1050000.000, 'Đã hoàn thành', '2025-04-24 09:18:33', 6),
(173, NULL, 27, 1050000.000, 'Đã hoàn thành', '2025-04-24 14:29:11', 11),
(174, NULL, 27, 700000.000, 'Đã hoàn thành', '2025-04-25 10:44:55', 12),
(175, 4, 27, 700000.000, 'Đã hoàn thành', '2025-04-25 17:33:22', NULL),
(176, NULL, 28, 900000.000, 'Đã hoàn thành', '2025-04-10 09:33:11', 6),
(177, NULL, 28, 900000.000, 'Đã hoàn thành', '2025-04-10 15:44:55', 11),
(178, NULL, 28, 900000.000, 'Đã hoàn thành', '2025-04-11 10:22:08', 12),
(179, NULL, 28, 675000.000, 'Đã hoàn thành', '2025-04-11 17:11:33', 13),
(180, 2, 28, 600000.000, 'Đã hoàn thành', '2025-04-12 11:55:22', NULL),
(181, NULL, 29, 1200000.000, 'Đã hoàn thành', '2025-04-17 10:18:22', 11),
(182, NULL, 29, 1200000.000, 'Đã hoàn thành', '2025-04-17 15:29:11', 12),
(183, NULL, 29, 1000000.000, 'Đã hoàn thành', '2025-04-18 09:44:55', 6),
(184, NULL, 29, 1200000.000, 'Đã hoàn thành', '2025-04-18 14:33:22', 13),
(185, 9, 29, 800000.000, 'Đã hoàn thành', '2025-04-19 11:22:08', NULL),
(186, NULL, 30, 900000.000, 'Đã hoàn thành', '2025-04-30 09:11:33', 6),
(187, NULL, 30, 900000.000, 'Đã hoàn thành', '2025-04-30 14:22:08', 11),
(188, NULL, 30, 900000.000, 'Đã hoàn thành', '2025-05-01 10:33:55', 12),
(189, NULL, 30, 675000.000, 'Đã hoàn thành', '2025-05-01 16:44:22', 13),
(190, 3, 30, 600000.000, 'Đã hoàn thành', '2025-05-02 11:55:33', NULL),
(191, NULL, 30, 900000.000, 'Đã hoàn thành', '2025-05-02 18:11:44', 6),
(192, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-05-14 09:22:11', 6),
(193, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-05-14 14:00:00', 11),
(194, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-05-15 10:55:22', 12),
(195, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-05-15 17:11:33', 13),
(196, 3, 31, 600000.000, 'Đã hoàn thành', '2025-05-16 11:44:55', NULL),
(197, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-05-16 18:22:08', 6),
(198, NULL, 32, 1200000.000, 'Đã hoàn thành', '2025-05-31 09:18:33', 11),
(199, NULL, 32, 1200000.000, 'Đã hoàn thành', '2025-05-31 15:29:11', 12),
(200, NULL, 32, 800000.000, 'Đã hoàn thành', '2025-06-01 10:44:55', 6),
(201, 8, 32, 800000.000, 'Đã hoàn thành', '2025-06-01 16:33:22', NULL),
(202, NULL, 32, 1200000.000, 'Đã hoàn thành', '2025-06-02 11:55:33', 13),
(203, NULL, 33, 1050000.000, 'Đã hoàn thành', '2025-05-21 09:33:11', 6),
(204, NULL, 33, 900000.000, 'Đã hoàn thành', '2025-05-21 14:44:55', 11),
(205, NULL, 33, 700000.000, 'Đã hoàn thành', '2025-05-22 10:22:08', 12),
(206, 4, 33, 550000.000, 'Đã hoàn thành', '2025-05-22 17:11:33', NULL),
(207, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-05-07 09:11:22', 6),
(208, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-05-07 15:22:44', 11),
(209, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-05-08 10:33:55', 12),
(210, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-05-08 16:44:22', 13),
(211, 2, 34, 800000.000, 'Đã hoàn thành', '2025-05-09 11:55:33', NULL),
(212, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-05-09 18:11:44', 6),
(213, NULL, 34, 800000.000, 'Đã hoàn thành', '2025-05-10 09:22:11', 11),
(214, NULL, 35, 900000.000, 'Đã hoàn thành', '2025-05-28 10:18:22', 12),
(215, NULL, 35, 900000.000, 'Đã hoàn thành', '2025-05-28 15:29:11', 13),
(216, NULL, 35, 750000.000, 'Đã hoàn thành', '2025-05-29 09:44:55', 6),
(217, 9, 35, 600000.000, 'Đã hoàn thành', '2025-05-29 14:33:22', NULL),
(218, NULL, 36, 900000.000, 'Đã hoàn thành', '2025-06-13 09:11:33', 6),
(219, NULL, 36, 900000.000, 'Đã hoàn thành', '2025-06-13 14:22:08', 11),
(220, NULL, 36, 900000.000, 'Đã hoàn thành', '2025-06-14 10:33:55', 12),
(221, NULL, 36, 675000.000, 'Đã hoàn thành', '2025-06-14 16:44:22', 13),
(222, 3, 36, 600000.000, 'Đã hoàn thành', '2025-06-15 11:55:33', NULL),
(223, NULL, 37, 900000.000, 'Đã hoàn thành', '2025-06-15 09:22:11', 6),
(224, NULL, 37, 900000.000, 'Đã hoàn thành', '2025-06-15 14:33:44', 11),
(225, NULL, 37, 900000.000, 'Đã hoàn thành', '2025-06-16 10:55:22', 12),
(226, NULL, 37, 675000.000, 'Đã hoàn thành', '2025-06-16 17:11:33', 13),
(227, 3, 37, 600000.000, 'Đã hoàn thành', '2025-06-17 11:44:55', NULL),
(228, NULL, 37, 900000.000, 'Đã hoàn thành', '2025-06-17 18:22:08', 6),
(229, NULL, 38, 1200000.000, 'Đã hoàn thành', '2025-06-30 09:18:33', 11),
(230, NULL, 38, 1200000.000, 'Đã hoàn thành', '2025-06-30 15:29:11', 12),
(231, NULL, 38, 800000.000, 'Đã hoàn thành', '2025-07-01 10:44:55', 6),
(232, 8, 38, 800000.000, 'Đã hoàn thành', '2025-07-01 16:33:22', NULL),
(233, NULL, 38, 1200000.000, 'Đã hoàn thành', '2025-07-02 11:55:33', 13),
(234, NULL, 39, 1050000.000, 'Đã hoàn thành', '2025-06-23 09:33:11', 6),
(235, NULL, 39, 1050000.000, 'Đã hoàn thành', '2025-06-23 14:44:55', 11),
(236, NULL, 39, 700000.000, 'Đã hoàn thành', '2025-06-24 10:22:08', 12),
(237, 4, 39, 700000.000, 'Đã hoàn thành', '2025-06-24 17:11:33', NULL),
(238, NULL, 40, 1200000.000, 'Đã hoàn thành', '2025-06-09 09:11:22', 6),
(239, NULL, 40, 1200000.000, 'Đã hoàn thành', '2025-06-09 15:22:44', 11),
(240, NULL, 40, 1200000.000, 'Đã hoàn thành', '2025-06-10 10:33:55', 12),
(241, NULL, 40, 1200000.000, 'Đã hoàn thành', '2025-06-10 16:44:22', 13),
(242, 2, 40, 800000.000, 'Đã hoàn thành', '2025-06-11 11:55:33', NULL),
(243, NULL, 40, 1200000.000, 'Đã hoàn thành', '2025-06-11 18:11:44', 6),
(244, NULL, 40, 800000.000, 'Đã hoàn thành', '2025-06-12 09:22:11', 11),
(245, NULL, 41, 900000.000, 'Đã hoàn thành', '2025-06-27 10:18:22', 12),
(246, NULL, 41, 750000.000, 'Đã hoàn thành', '2025-06-27 15:29:11', 13),
(247, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-06-28 09:44:55', 6),
(248, 9, 41, 500000.000, 'Đã hoàn thành', '2025-06-28 14:33:22', NULL),
(249, NULL, 42, 900000.000, 'Đã hoàn thành', '2025-07-14 09:11:33', 6),
(250, NULL, 42, 900000.000, 'Đã hoàn thành', '2025-07-14 14:22:08', 11),
(251, NULL, 42, 900000.000, 'Đã hoàn thành', '2025-07-15 10:33:55', 12),
(252, NULL, 42, 675000.000, 'Đã hoàn thành', '2025-07-15 16:44:22', 13),
(253, 3, 42, 600000.000, 'Đã hoàn thành', '2025-07-16 11:55:33', NULL),
(254, NULL, 42, 900000.000, 'Đã hoàn thành', '2025-07-16 18:11:44', 6),
(255, 8, 42, 450000.000, 'Đã hoàn thành', '2025-07-17 09:22:11', NULL),
(256, NULL, 43, 1200000.000, 'Đã hoàn thành', '2025-07-14 09:11:33', 6),
(257, NULL, 43, 1200000.000, 'Đã hoàn thành', '2025-07-14 14:22:08', 11),
(258, NULL, 43, 1200000.000, 'Đã hoàn thành', '2025-07-15 10:33:55', 12),
(259, NULL, 43, 1200000.000, 'Đã hoàn thành', '2025-07-15 16:44:22', 13),
(260, 3, 43, 800000.000, 'Đã hoàn thành', '2025-07-16 11:55:33', NULL),
(261, NULL, 43, 1200000.000, 'Đã hoàn thành', '2025-07-16 18:11:44', 6),
(262, NULL, 44, 900000.000, 'Đã hoàn thành', '2025-07-31 09:22:11', 11),
(263, NULL, 44, 900000.000, 'Đã hoàn thành', '2025-07-31 15:33:44', 12),
(264, NULL, 44, 750000.000, 'Đã hoàn thành', '2025-08-01 10:55:22', 6),
(265, 8, 44, 600000.000, 'Đã hoàn thành', '2025-08-01 17:11:33', NULL),
(266, NULL, 45, 1050000.000, 'Đã hoàn thành', '2025-07-21 09:18:33', 6),
(267, NULL, 45, 900000.000, 'Đã hoàn thành', '2025-07-21 14:29:11', 11),
(268, NULL, 45, 700000.000, 'Đã hoàn thành', '2025-07-22 10:44:55', 12),
(269, 4, 45, 550000.000, 'Đã hoàn thành', '2025-07-22 17:33:22', NULL),
(270, NULL, 46, 1200000.000, 'Đã hoàn thành', '2025-07-07 09:33:11', 6),
(271, NULL, 46, 1200000.000, 'Đã hoàn thành', '2025-07-07 15:44:55', 11),
(272, NULL, 46, 1200000.000, 'Đã hoàn thành', '2025-07-08 10:22:08', 12),
(273, NULL, 46, 1200000.000, 'Đã hoàn thành', '2025-07-08 17:11:33', 13),
(274, 2, 46, 800000.000, 'Đã hoàn thành', '2025-07-09 11:55:22', NULL),
(275, NULL, 46, 1200000.000, 'Đã hoàn thành', '2025-07-09 18:22:08', 6),
(276, NULL, 46, 800000.000, 'Đã hoàn thành', '2025-07-10 09:22:11', 11),
(277, NULL, 47, 900000.000, 'Đã hoàn thành', '2025-07-28 10:18:22', 12),
(278, NULL, 47, 900000.000, 'Đã hoàn thành', '2025-07-28 15:29:11', 13),
(279, NULL, 47, 750000.000, 'Đã hoàn thành', '2025-07-29 09:44:55', 6),
(280, 9, 47, 600000.000, 'Đã hoàn thành', '2025-07-29 14:33:22', NULL),
(281, NULL, 48, 900000.000, 'Đã hoàn thành', '2025-08-13 09:11:33', 6),
(282, NULL, 48, 900000.000, 'Đã hoàn thành', '2025-08-13 14:22:08', 11),
(283, NULL, 48, 900000.000, 'Đã hoàn thành', '2025-08-14 10:33:55', 12),
(284, NULL, 48, 675000.000, 'Đã hoàn thành', '2025-08-14 16:44:22', 13),
(285, 3, 48, 600000.000, 'Đã hoàn thành', '2025-08-15 11:55:33', NULL),
(286, NULL, 49, 900000.000, 'Đã hoàn thành', '2025-08-14 09:22:11', 6),
(287, NULL, 49, 900000.000, 'Đã hoàn thành', '2025-08-14 14:33:44', 11),
(288, NULL, 49, 900000.000, 'Đã hoàn thành', '2025-08-15 10:55:22', 12),
(289, NULL, 49, 900000.000, 'Đã hoàn thành', '2025-08-15 17:11:33', 13),
(290, 3, 49, 600000.000, 'Đã hoàn thành', '2025-08-16 11:44:55', NULL),
(291, NULL, 49, 900000.000, 'Đã hoàn thành', '2025-08-16 18:22:08', 6),
(292, NULL, 50, 1200000.000, 'Đã hoàn thành', '2025-08-30 09:18:33', 11),
(293, NULL, 50, 1200000.000, 'Đã hoàn thành', '2025-08-30 15:29:11', 12),
(294, NULL, 50, 800000.000, 'Đã hoàn thành', '2025-08-31 10:44:55', 6),
(295, 8, 50, 800000.000, 'Đã hoàn thành', '2025-08-31 16:33:22', NULL),
(296, NULL, 50, 1200000.000, 'Đã hoàn thành', '2025-09-01 11:55:33', 13),
(297, NULL, 51, 1050000.000, 'Đã hoàn thành', '2025-08-21 09:33:11', 6),
(298, NULL, 51, 900000.000, 'Đã hoàn thành', '2025-08-21 14:44:55', 11),
(299, NULL, 51, 700000.000, 'Đã hoàn thành', '2025-08-22 10:22:08', 12),
(300, 4, 51, 550000.000, 'Đã hoàn thành', '2025-08-22 17:11:33', NULL),
(301, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-08-07 09:11:22', 6),
(302, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-08-07 15:22:44', 11),
(303, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-08-08 10:33:55', 12),
(304, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-08-08 16:44:22', 13),
(305, 2, 52, 800000.000, 'Đã hoàn thành', '2025-08-09 11:55:33', NULL),
(306, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-08-09 18:11:44', 6),
(307, NULL, 52, 800000.000, 'Đã hoàn thành', '2025-08-10 09:22:11', 11),
(308, NULL, 53, 900000.000, 'Đã hoàn thành', '2025-08-28 10:18:22', 12),
(309, NULL, 53, 900000.000, 'Đã hoàn thành', '2025-08-28 15:29:11', 13),
(310, NULL, 53, 750000.000, 'Đã hoàn thành', '2025-08-29 09:44:55', 6),
(311, 9, 53, 600000.000, 'Đã hoàn thành', '2025-08-29 14:33:22', NULL),
(312, NULL, 54, 900000.000, 'Đã hoàn thành', '2025-09-13 09:11:33', 6),
(313, NULL, 54, 900000.000, 'Đã hoàn thành', '2025-09-13 14:22:08', 11),
(314, NULL, 54, 900000.000, 'Đã hoàn thành', '2025-09-14 10:33:55', 12),
(315, NULL, 54, 675000.000, 'Đã hoàn thành', '2025-09-14 16:44:22', 13),
(316, 3, 54, 600000.000, 'Đã hoàn thành', '2025-09-15 11:55:33', NULL),
(317, NULL, 54, 900000.000, 'Đã hoàn thành', '2025-09-15 18:11:44', 6),
(318, 8, 54, 450000.000, 'Đã hoàn thành', '2025-09-16 09:22:11', NULL),
(319, NULL, 55, 1200000.000, 'Đã hoàn thành', '2025-09-10 09:15:22', 6),
(320, NULL, 55, 1200000.000, 'Đã hoàn thành', '2025-09-10 14:30:44', 11),
(321, NULL, 55, 1000000.000, 'Đã hoàn thành', '2025-09-11 10:22:11', 12),
(322, NULL, 55, 800000.000, 'Đã hoàn thành', '2025-09-11 16:45:33', 13),
(323, 3, 55, 600000.000, 'Đã hoàn thành', '2025-09-12 11:11:55', NULL),
(324, NULL, 56, 900000.000, 'Đã hoàn thành', '2025-10-01 09:30:11', 6),
(325, NULL, 56, 900000.000, 'Đã hoàn thành', '2025-10-01 15:18:44', 11),
(326, NULL, 56, 750000.000, 'Đã hoàn thành', '2025-10-02 10:55:22', 12),
(327, 8, 56, 600000.000, 'Đã hoàn thành', '2025-10-02 17:33:11', NULL),
(328, NULL, 57, 700000.000, 'Đã hoàn thành', '2025-09-08 09:22:33', 6),
(329, NULL, 57, 600000.000, 'Đã hoàn thành', '2025-09-08 14:44:55', 11),
(330, 4, 57, 400000.000, 'Đã hoàn thành', '2025-09-09 11:11:22', NULL),
(331, NULL, 58, 1200000.000, 'Đã hoàn thành', '2025-09-20 09:11:33', 6),
(332, NULL, 58, 1050000.000, 'Đã hoàn thành', '2025-09-20 14:22:08', 11),
(333, NULL, 58, 900000.000, 'Đã hoàn thành', '2025-09-21 10:33:55', 12),
(334, NULL, 58, 750000.000, 'Đã hoàn thành', '2025-09-21 16:44:22', 13),
(335, 3, 58, 600000.000, 'Đã hoàn thành', '2025-09-22 11:55:33', NULL),
(336, NULL, 59, 1400000.000, 'Đã hoàn thành', '2025-09-05 09:18:22', 6),
(337, NULL, 59, 1400000.000, 'Đã hoàn thành', '2025-09-05 15:29:11', 11),
(338, NULL, 59, 1200000.000, 'Đã hoàn thành', '2025-09-06 10:44:55', 12),
(339, NULL, 59, 1000000.000, 'Đã hoàn thành', '2025-09-06 17:11:33', 13),
(340, 2, 59, 800000.000, 'Đã hoàn thành', '2025-09-07 11:55:22', NULL),
(341, NULL, 59, 800000.000, 'Đã hoàn thành', '2025-09-07 18:22:08', 6),
(342, NULL, 60, 1050000.000, 'Đã hoàn thành', '2025-10-03 09:33:11', 6),
(343, NULL, 60, 900000.000, 'Đã hoàn thành', '2025-10-03 14:44:55', 11),
(344, NULL, 60, 600000.000, 'Đã hoàn thành', '2025-10-04 10:22:08', 12),
(345, 9, 60, 450000.000, 'Đã hoàn thành', '2025-10-04 16:33:22', NULL),
(346, NULL, 61, 1200000.000, 'Đã hoàn thành', '2025-10-18 09:22:11', 6),
(347, NULL, 61, 1050000.000, 'Đã hoàn thành', '2025-10-18 15:33:44', 11),
(348, NULL, 61, 900000.000, 'Đã hoàn thành', '2025-10-19 10:55:22', 12),
(349, NULL, 61, 750000.000, 'Đã hoàn thành', '2025-10-19 17:11:33', 13),
(350, 3, 61, 600000.000, 'Đã hoàn thành', '2025-10-20 11:44:55', NULL),
(351, NULL, 62, 1200000.000, 'Đã hoàn thành', '2025-10-31 09:18:33', 6),
(352, NULL, 62, 1000000.000, 'Đã hoàn thành', '2025-10-31 14:29:11', 11),
(353, NULL, 62, 800000.000, 'Đã hoàn thành', '2025-11-01 10:44:55', 12),
(354, 8, 62, 600000.000, 'Đã hoàn thành', '2025-11-01 16:33:22', NULL),
(355, NULL, 63, 900000.000, 'Đã hoàn thành', '2025-10-22 09:33:11', 6),
(356, NULL, 63, 750000.000, 'Đã hoàn thành', '2025-10-22 14:44:55', 11),
(357, 4, 63, 450000.000, 'Đã hoàn thành', '2025-10-23 11:22:08', NULL),
(358, NULL, 64, 1000000.000, 'Đã hoàn thành', '2025-11-10 09:22:11', 6),
(359, NULL, 64, 800000.000, 'Đã hoàn thành', '2025-11-10 14:33:44', 11),
(360, NULL, 64, 600000.000, 'Đã hoàn thành', '2025-11-11 10:55:22', 12),
(361, 3, 64, 400000.000, 'Đã hoàn thành', '2025-11-11 16:11:33', NULL),
(362, NULL, 65, 750000.000, 'Đã hoàn thành', '2025-11-15 09:30:22', 6),
(363, NULL, 65, 600000.000, 'Đã hoàn thành', '2025-11-15 15:18:44', 11),
(364, 9, 65, 450000.000, 'Đã hoàn thành', '2025-11-16 11:44:55', NULL),
(365, NULL, 66, 500000.000, 'Đã hoàn thành', '2025-11-20 09:11:33', 6),
(366, NULL, 66, 400000.000, 'Đã hoàn thành', '2025-11-20 14:22:08', 11),
(367, NULL, 67, 1000000.000, 'Đã hoàn thành', '2025-11-25 09:11:33', 6),
(368, NULL, 67, 800000.000, 'Đã hoàn thành', '2025-11-25 14:22:08', 11),
(369, NULL, 67, 600000.000, 'Đã hoàn thành', '2025-11-26 10:33:55', 12),
(370, 3, 67, 400000.000, 'Đã hoàn thành', '2025-11-26 16:44:22', NULL),
(371, NULL, 68, 750000.000, 'Đã hoàn thành', '2025-11-28 09:22:11', 6),
(372, NULL, 68, 600000.000, 'Đã hoàn thành', '2025-11-28 15:18:44', 11),
(373, 9, 68, 450000.000, 'Đã hoàn thành', '2025-11-29 11:44:55', NULL),
(374, NULL, 69, 500000.000, 'Đã hoàn thành', '2025-11-20 09:33:22', 6),
(375, NULL, 69, 400000.000, 'Đã hoàn thành', '2025-11-20 14:55:11', 11),
(376, NULL, 70, 750000.000, 'Đã hoàn thành', '2025-12-01 09:18:33', 6),
(377, NULL, 70, 600000.000, 'Đã hoàn thành', '2025-12-01 15:29:11', 11),
(378, NULL, 70, 450000.000, 'Đã hoàn thành', '2025-12-02 10:44:55', 12);

-- --------------------------------------------------------

--
-- Table structure for table `genres`
--

CREATE TABLE `genres` (
  `genre_id` int(11) NOT NULL,
  `genre_name` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `genres`
--

INSERT INTO `genres` (`genre_id`, `genre_name`, `created_at`) VALUES
(6, 'Bi kịch', '2025-10-03 16:00:14'),
(7, 'Hài kịch', '2025-10-03 16:00:24'),
(8, 'Tâm lý - Xã hội', '2025-10-03 16:00:33'),
(9, 'Hiện thực', '2025-10-03 16:00:41'),
(10, 'Dân gian', '2025-10-03 16:00:49'),
(11, 'Lãng mạn', '2025-10-03 16:01:04'),
(12, 'Giả tưởng - huyền ảo', '2025-10-03 16:01:15'),
(13, 'Huyền bí', '2025-10-03 16:01:22'),
(14, 'Chuyển thể cổ tích', '2025-10-03 16:01:35'),
(15, 'Kinh điển', '2025-10-03 16:01:42'),
(16, 'Gia đình - tình cảm', '2025-11-04 12:32:59'),
(17, 'Lịch sử', '2025-11-04 12:34:03'),
(18, 'Chính luận - Xã hội', '2025-11-04 12:34:20'),
(19, 'Châm biếm - Trào phúng', '2025-11-04 12:34:51');

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `payment_id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `amount` decimal(10,3) NOT NULL,
  `status` enum('Đang chờ','Thành công','Thất bại') NOT NULL DEFAULT 'Đang chờ',
  `payment_method` varchar(50) DEFAULT NULL,
  `vnp_txn_ref` varchar(64) DEFAULT NULL,
  `vnp_bank_code` varchar(20) DEFAULT NULL,
  `vnp_pay_date` varchar(14) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`payment_id`, `booking_id`, `amount`, `status`, `payment_method`, `vnp_txn_ref`, `vnp_bank_code`, `vnp_pay_date`, `created_at`, `updated_at`) VALUES
(1, 1, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-20 10:15:22', '2024-12-20 10:15:22'),
(2, 2, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-20 15:33:11', '2024-12-20 15:33:11'),
(3, 3, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-21 09:44:55', '2024-12-21 09:44:55'),
(4, 4, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2024-12-21 16:22:33', '2024-12-21 16:22:33'),
(5, 5, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-22 11:11:08', '2024-12-22 11:11:08'),
(6, 6, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-22 19:55:19', '2024-12-22 19:55:19'),
(7, 7, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-23 08:33:44', '2024-12-23 08:33:44'),
(8, 8, 900000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2024-12-23 14:44:22', '2024-12-23 14:44:22'),
(9, 9, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-24 10:55:11', '2024-12-24 10:55:11'),
(10, 10, 825000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-24 17:22:55', '2024-12-24 17:22:55'),
(11, 11, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-25 12:33:19', '2024-12-25 12:33:19'),
(12, 12, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-08 09:18:33', '2025-01-08 09:18:33'),
(13, 13, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-08 15:29:11', '2025-01-08 15:29:11'),
(14, 14, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-09 11:44:55', '2025-01-09 11:44:55'),
(15, 15, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-09 17:33:22', '2025-01-09 17:33:22'),
(16, 16, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-10 10:22:08', '2025-01-10 10:22:08'),
(17, 17, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-10 19:11:44', '2025-01-10 19:11:44'),
(18, 18, 700000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-11 13:55:33', '2025-01-11 13:55:33'),
(19, 19, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-21 10:18:22', '2024-12-21 10:18:22'),
(20, 20, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-21 16:29:11', '2024-12-21 16:29:11'),
(21, 21, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2024-12-22 09:44:55', '2024-12-22 09:44:55'),
(22, 22, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-22 14:33:33', '2024-12-22 14:33:33'),
(23, 23, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-23 11:11:08', '2024-12-23 11:11:08'),
(24, 24, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-23 18:55:19', '2024-12-23 18:55:19'),
(25, 25, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2024-12-24 10:22:44', '2024-12-24 10:22:44'),
(26, 26, 300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-24 15:33:11', '2024-12-24 15:33:11'),
(27, 27, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-25 09:11:22', '2024-12-25 09:11:22'),
(28, 28, 300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-25 14:44:55', '2024-12-25 14:44:55'),
(29, 29, 300000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2024-12-25 19:22:33', '2024-12-25 19:22:33'),
(30, 30, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-10 10:25:44', '2025-01-10 10:25:44'),
(31, 31, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-10 15:33:22', '2025-01-10 15:33:22'),
(32, 32, 700000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-11 09:55:11', '2025-01-11 09:55:11'),
(33, 33, 550000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-11 14:22:44', '2025-01-11 14:22:44'),
(34, 34, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-12 11:33:55', '2025-01-12 11:33:55'),
(35, 35, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-12 17:44:22', '2025-01-12 17:44:22'),
(36, 36, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-28 10:18:33', '2024-12-28 10:18:33'),
(37, 37, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-28 15:29:11', '2024-12-28 15:29:11'),
(38, 38, 500000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2024-12-29 09:44:55', '2024-12-29 09:44:55'),
(39, 39, 400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-29 14:33:22', '2024-12-29 14:33:22'),
(40, 40, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-30 11:22:08', '2024-12-30 11:22:08'),
(41, 41, 400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2024-12-30 18:55:44', '2024-12-30 18:55:44'),
(42, 42, 300000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2024-12-31 12:33:19', '2024-12-31 12:33:19'),
(43, 43, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-11 09:22:33', '2025-01-11 09:22:33'),
(44, 44, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-11 14:44:11', '2025-01-11 14:44:11'),
(45, 45, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-12 10:55:22', '2025-01-12 10:55:22'),
(46, 46, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-12 16:11:44', '2025-01-12 16:11:44'),
(47, 47, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-13 11:33:55', '2025-01-13 11:33:55'),
(48, 48, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-13 19:22:08', '2025-01-13 19:22:08'),
(49, 49, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-14 09:11:33', '2025-01-14 09:11:33'),
(50, 50, 675000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-14 13:44:55', '2025-01-14 13:44:55'),
(51, 51, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-14 17:22:22', '2025-01-14 17:22:22'),
(52, 52, 300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-15 10:33:11', '2025-01-15 10:33:11'),
(53, 53, 300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-15 14:55:44', '2025-01-15 14:55:44'),
(54, 54, 300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-15 18:12:08', '2025-01-15 18:12:08'),
(55, 55, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-15 20:25:33', '2025-01-15 20:25:33'),
(56, 56, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 09:22:11', '2025-01-03 09:22:11'),
(57, 57, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 14:33:44', '2025-01-03 14:33:44'),
(58, 58, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-04 10:55:22', '2025-01-04 10:55:22'),
(59, 59, 700000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-04 17:11:33', '2025-01-04 17:11:33'),
(60, 60, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-05 11:44:55', '2025-01-05 11:44:55'),
(61, 61, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-17 09:18:33', '2025-01-17 09:18:33'),
(62, 62, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-17 15:29:11', '2025-01-17 15:29:11'),
(63, 63, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 10:22:08', '2025-01-18 10:22:08'),
(64, 64, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-18 16:33:44', '2025-01-18 16:33:44'),
(65, 65, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 11:55:22', '2025-01-19 11:55:22'),
(66, 66, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 18:11:33', '2025-01-19 18:11:33'),
(67, 67, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-20 09:44:55', '2025-01-20 09:44:55'),
(68, 68, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-20 14:22:11', '2025-01-20 14:22:11'),
(69, 69, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-04 10:18:22', '2025-01-04 10:18:22'),
(70, 70, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-04 15:29:11', '2025-01-04 15:29:11'),
(71, 71, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-05 09:44:55', '2025-01-05 09:44:55'),
(72, 72, 500000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-05 14:33:22', '2025-01-05 14:33:22'),
(73, 73, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-06 11:22:08', '2025-01-06 11:22:08'),
(74, 74, 400000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-06 17:55:44', '2025-01-06 17:55:44'),
(75, 75, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 09:33:11', '2025-01-18 09:33:11'),
(76, 76, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 14:44:55', '2025-01-18 14:44:55'),
(77, 77, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 10:55:22', '2025-01-19 10:55:22'),
(78, 78, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 17:11:33', '2025-01-19 17:11:33'),
(79, 79, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-20 11:22:08', '2025-01-20 11:22:08'),
(80, 80, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-20 18:33:44', '2025-01-20 18:33:44'),
(81, 81, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-21 09:44:55', '2025-01-21 09:44:55'),
(82, 82, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 10:15:22', '2025-01-03 10:15:22'),
(83, 83, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 15:33:11', '2025-01-03 15:33:11'),
(84, 84, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-04 09:22:33', '2025-01-04 09:22:33'),
(85, 85, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-04 14:44:11', '2025-01-04 14:44:11'),
(86, 86, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-05 11:55:22', '2025-01-05 11:55:22'),
(87, 87, 700000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-05 17:22:44', '2025-01-05 17:22:44'),
(88, 88, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-17 09:11:33', '2025-01-17 09:11:33'),
(89, 89, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-17 14:22:08', '2025-01-17 14:22:08'),
(90, 90, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 10:33:55', '2025-01-18 10:33:55'),
(91, 91, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 16:44:22', '2025-01-18 16:44:22'),
(92, 92, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-19 11:55:33', '2025-01-19 11:55:33'),
(93, 93, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 18:11:44', '2025-01-19 18:11:44'),
(94, 94, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-01-20 09:22:11', '2025-01-20 09:22:11'),
(95, 95, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-15 09:11:22', '2025-02-15 09:11:22'),
(96, 96, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-15 14:33:44', '2025-02-15 14:33:44'),
(97, 97, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-16 10:22:08', '2025-02-16 10:22:08'),
(98, 98, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-16 17:55:33', '2025-02-16 17:55:33'),
(99, 99, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-02-17 11:44:55', '2025-02-17 11:44:55'),
(100, 100, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-17 18:22:11', '2025-02-22 18:22:11'),
(101, 101, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-01 09:33:11', '2025-02-01 09:33:11'),
(102, 102, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-01 15:44:55', '2025-02-01 15:44:55'),
(103, 103, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-02 10:55:22', '2025-02-02 10:55:22'),
(104, 104, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-02-02 16:11:33', '2025-02-02 16:11:33'),
(105, 105, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-03 11:22:08', '2025-02-03 11:22:08'),
(106, 106, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-22 09:18:33', '2025-02-22 09:18:33'),
(107, 107, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-22 14:29:11', '2025-02-22 14:29:11'),
(108, 108, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-23 10:44:55', '2025-02-23 10:44:55'),
(109, 109, 700000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-02-23 17:33:22', '2025-02-23 17:33:22'),
(110, 110, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-08 09:22:33', '2025-02-08 09:22:33'),
(111, 111, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-08 15:33:11', '2025-02-08 15:33:11'),
(112, 112, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-09 10:55:22', '2025-02-09 10:55:22'),
(113, 113, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-09 17:11:44', '2025-02-09 17:11:44'),
(114, 114, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-02-10 11:33:55', '2025-02-10 11:33:55'),
(115, 115, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-10 18:44:22', '2025-02-10 18:44:22'),
(116, 116, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-15 10:18:22', '2025-02-15 10:18:22'),
(117, 117, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-15 15:29:11', '2025-02-15 15:29:11'),
(118, 118, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-16 09:44:55', '2025-02-16 09:44:55'),
(119, 119, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-16 14:33:22', '2025-02-16 14:33:22'),
(120, 120, 500000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-02-17 11:22:08', '2025-02-17 11:22:08'),
(121, 121, 500000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-02-17 17:55:44', '2025-02-17 17:55:44'),
(122, 122, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 09:11:33', '2025-02-28 09:11:33'),
(123, 123, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 14:22:08', '2025-02-28 14:22:08'),
(124, 124, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 15:00:00', '2025-02-28 15:00:00'),
(125, 125, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 15:30:00', '2025-02-28 15:30:00'),
(126, 126, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-01 11:55:33', '2025-03-01 11:55:33'),
(127, 127, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-01 18:11:44', '2025-03-01 18:11:44'),
(128, 128, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-02 09:22:11', '2025-03-02 09:22:11'),
(129, 129, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 09:22:11', '2025-03-15 09:22:11'),
(130, 130, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 14:33:44', '2025-03-15 14:33:44'),
(131, 131, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-16 10:55:22', '2025-03-16 10:55:22'),
(132, 132, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-16 17:11:33', '2025-03-16 17:11:33'),
(133, 133, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-17 11:44:55', '2025-03-17 11:44:55'),
(134, 134, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-17 18:22:08', '2025-03-17 18:22:08'),
(135, 135, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-01 09:18:33', '2025-03-01 09:18:33'),
(136, 136, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-01 15:29:11', '2025-03-01 15:29:11'),
(137, 137, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-02 10:44:55', '2025-03-02 10:44:55'),
(138, 138, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-02 16:33:22', '2025-03-02 16:33:22'),
(139, 139, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-03 11:55:33', '2025-03-03 11:55:33'),
(140, 140, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-22 09:33:11', '2025-03-22 09:33:11'),
(141, 141, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-22 14:44:55', '2025-03-22 14:44:55'),
(142, 142, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-23 10:22:08', '2025-03-23 10:22:08'),
(143, 143, 550000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-23 17:11:33', '2025-03-23 17:11:33'),
(144, 144, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-08 09:11:22', '2025-03-08 09:11:22'),
(145, 145, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-08 15:22:44', '2025-03-08 15:22:44'),
(146, 146, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-09 10:33:55', '2025-03-09 10:33:55'),
(147, 147, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-09 16:44:22', '2025-03-09 16:44:22'),
(148, 148, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-10 11:55:33', '2025-03-10 11:55:33'),
(149, 149, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-10 18:11:44', '2025-03-10 18:11:44'),
(150, 150, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-11 09:22:11', '2025-03-11 09:22:11'),
(151, 151, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 10:18:22', '2025-03-15 10:18:22'),
(152, 152, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 15:29:11', '2025-03-15 15:29:11'),
(153, 153, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-16 09:44:55', '2025-03-16 09:44:55'),
(154, 154, 500000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-16 14:33:22', '2025-03-16 14:33:22'),
(155, 155, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-29 09:11:33', '2025-03-29 09:11:33'),
(156, 156, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-29 14:22:08', '2025-03-29 14:22:08'),
(157, 157, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-30 10:33:55', '2025-03-30 10:33:55'),
(158, 158, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-30 16:44:22', '2025-03-30 16:44:22'),
(159, 159, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-03-31 11:55:33', '2025-03-31 11:55:33'),
(160, 160, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-31 18:11:44', '2025-03-31 18:11:44'),
(161, 161, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-04-01 09:22:11', '2025-04-01 09:22:11'),
(162, 162, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-17 09:11:33', '2025-04-17 09:11:33'),
(163, 163, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-17 14:22:08', '2025-04-17 14:22:08'),
(164, 164, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-18 10:33:55', '2025-04-18 10:33:55'),
(165, 165, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-18 16:44:22', '2025-04-18 16:44:22'),
(166, 166, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-04-19 11:55:33', '2025-04-19 11:55:33'),
(167, 167, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-19 18:11:44', '2025-04-19 18:11:44'),
(168, 168, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-03 09:22:11', '2025-04-03 09:22:11'),
(169, 169, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-03 15:33:44', '2025-04-03 15:33:44'),
(170, 170, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-04 10:55:22', '2025-04-04 10:55:22'),
(171, 171, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-04-04 17:11:33', '2025-04-04 17:11:33'),
(172, 172, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-24 09:18:33', '2025-04-24 09:18:33'),
(173, 173, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-24 14:29:11', '2025-04-24 14:29:11'),
(174, 174, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-25 10:44:55', '2025-04-25 10:44:55'),
(175, 175, 700000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-04-25 17:33:22', '2025-04-25 17:33:22'),
(176, 176, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-10 09:33:11', '2025-04-10 09:33:11'),
(177, 177, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-10 15:44:55', '2025-04-10 15:44:55'),
(178, 178, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-11 10:22:08', '2025-04-11 10:22:08'),
(179, 179, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-11 17:11:33', '2025-04-11 17:11:33'),
(180, 180, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-04-12 11:55:22', '2025-04-12 11:55:22'),
(181, 181, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-17 10:18:22', '2025-04-17 10:18:22'),
(182, 182, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-17 15:29:11', '2025-04-17 15:29:11'),
(183, 183, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-18 09:44:55', '2025-04-18 09:44:55'),
(184, 184, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-18 14:33:22', '2025-04-18 14:33:22'),
(185, 185, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-04-19 11:22:08', '2025-04-19 11:22:08'),
(186, 186, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-30 09:11:33', '2025-04-30 09:11:33'),
(187, 187, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-30 14:22:08', '2025-04-30 14:22:08'),
(188, 188, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-01 10:33:55', '2025-05-01 10:33:55'),
(189, 189, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-01 16:44:22', '2025-05-01 16:44:22'),
(190, 190, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-05-02 11:55:33', '2025-05-02 11:55:33'),
(191, 191, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-02 18:11:44', '2025-05-02 18:11:44'),
(192, 192, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-14 09:22:11', '2025-05-14 09:22:11'),
(193, 193, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-14 14:33:44', '2025-05-14 14:33:44'),
(194, 194, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-15 10:55:22', '2025-05-15 10:55:22'),
(195, 195, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-15 17:11:33', '2025-05-15 17:11:33'),
(196, 196, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-05-16 11:44:55', '2025-05-16 11:44:55'),
(197, 197, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-16 18:22:08', '2025-05-16 18:22:08'),
(198, 198, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-31 09:18:33', '2025-05-31 09:18:33'),
(199, 199, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-31 15:29:11', '2025-05-31 15:29:11'),
(200, 200, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-01 10:44:55', '2025-06-01 10:44:55'),
(201, 201, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-06-01 16:33:22', '2025-06-01 16:33:22'),
(202, 202, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-02 11:55:33', '2025-06-02 11:55:33'),
(203, 203, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-21 09:33:11', '2025-05-21 09:33:11'),
(204, 204, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-21 14:44:55', '2025-05-21 14:44:55'),
(205, 205, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-22 10:22:08', '2025-05-22 10:22:08'),
(206, 206, 550000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-05-22 17:11:33', '2025-05-22 17:11:33'),
(207, 207, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-07 09:11:22', '2025-05-07 09:11:22'),
(208, 208, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-07 15:22:44', '2025-05-07 15:22:44'),
(209, 209, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-08 10:33:55', '2025-05-08 10:33:55'),
(210, 210, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-08 16:44:22', '2025-05-08 16:44:22'),
(211, 211, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-05-09 11:55:33', '2025-05-09 11:55:33'),
(212, 212, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-09 18:11:44', '2025-05-09 18:11:44'),
(213, 213, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-10 09:22:11', '2025-05-10 09:22:11'),
(214, 214, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-28 10:18:22', '2025-05-28 10:18:22'),
(215, 215, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-28 15:29:11', '2025-05-28 15:29:11'),
(216, 216, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-29 09:44:55', '2025-05-29 09:44:55'),
(217, 217, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-05-29 14:33:22', '2025-05-29 14:33:22'),
(218, 218, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-13 09:11:33', '2025-06-13 09:11:33'),
(219, 219, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-13 14:22:08', '2025-06-13 14:22:08'),
(220, 220, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-14 10:33:55', '2025-06-14 10:33:55'),
(221, 221, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-14 16:44:22', '2025-06-14 16:44:22'),
(222, 222, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-06-15 11:55:33', '2025-06-15 11:55:33'),
(223, 223, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-15 09:22:11', '2025-06-15 09:22:11'),
(224, 224, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-15 14:33:44', '2025-06-15 14:33:44'),
(225, 225, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-16 10:55:22', '2025-06-16 10:55:22'),
(226, 226, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-16 17:11:33', '2025-06-16 17:11:33'),
(227, 227, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-06-17 11:44:55', '2025-06-17 11:44:55'),
(228, 228, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-17 18:22:08', '2025-06-17 18:22:08'),
(229, 229, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-30 09:18:33', '2025-06-30 09:18:33'),
(230, 230, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-30 15:29:11', '2025-06-30 15:29:11'),
(231, 231, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-01 10:44:55', '2025-07-01 10:44:55'),
(232, 232, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-07-01 16:33:22', '2025-07-01 16:33:22'),
(233, 233, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-02 11:55:33', '2025-07-02 11:55:33'),
(234, 234, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-23 09:33:11', '2025-06-23 09:33:11'),
(235, 235, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-23 14:44:55', '2025-06-23 14:44:55'),
(236, 236, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-24 10:22:08', '2025-06-24 10:22:08'),
(237, 237, 700000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-06-24 17:11:33', '2025-06-24 17:11:33'),
(238, 238, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-09 09:11:22', '2025-06-09 09:11:22'),
(239, 239, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-09 15:22:44', '2025-06-09 15:22:44'),
(240, 240, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-10 10:33:55', '2025-06-10 10:33:55'),
(241, 241, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-10 16:44:22', '2025-06-10 16:44:22'),
(242, 242, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-06-11 11:55:33', '2025-06-11 11:55:33'),
(243, 243, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-11 18:11:44', '2025-06-11 18:11:44'),
(244, 244, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-12 09:22:11', '2025-06-12 09:22:11'),
(245, 245, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-27 10:18:22', '2025-06-27 10:18:22'),
(246, 246, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-27 15:29:11', '2025-06-27 15:29:11'),
(247, 247, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-28 09:44:55', '2025-06-28 09:44:55'),
(248, 248, 500000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-06-28 14:33:22', '2025-06-28 14:33:22'),
(249, 249, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(250, 250, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(251, 251, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(252, 252, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(253, 253, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-07-16 11:55:33', '2025-07-16 11:55:33'),
(254, 254, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(255, 255, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-07-17 09:22:11', '2025-07-17 09:22:11'),
(256, 256, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(257, 257, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(258, 258, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(259, 259, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(260, 260, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-07-16 11:55:33', '2025-07-16 11:55:33'),
(261, 261, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(262, 262, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-31 09:22:11', '2025-07-31 09:22:11'),
(263, 263, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-31 15:33:44', '2025-07-31 15:33:44'),
(264, 264, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-01 10:55:22', '2025-08-01 10:55:22'),
(265, 265, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-01 17:11:33', '2025-08-01 17:11:33'),
(266, 266, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-21 09:18:33', '2025-07-21 09:18:33'),
(267, 267, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-21 14:29:11', '2025-07-21 14:29:11'),
(268, 268, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-22 10:44:55', '2025-07-22 10:44:55'),
(269, 269, 550000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-07-22 17:33:22', '2025-07-22 17:33:22'),
(270, 270, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-07 09:33:11', '2025-07-07 09:33:11'),
(271, 271, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-07 15:44:55', '2025-07-07 15:44:55'),
(272, 272, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-08 10:22:08', '2025-07-08 10:22:08'),
(273, 273, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-08 17:11:33', '2025-07-08 17:11:33'),
(274, 274, 800000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-07-09 11:55:22', '2025-07-09 11:55:22'),
(275, 275, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-09 18:22:08', '2025-07-09 18:22:08'),
(276, 276, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-10 09:22:11', '2025-07-10 09:22:11'),
(277, 277, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-28 10:18:22', '2025-07-28 10:18:22'),
(278, 278, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-28 15:29:11', '2025-07-28 15:29:11'),
(279, 279, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-29 09:44:55', '2025-07-29 09:44:55'),
(280, 280, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-07-29 14:33:22', '2025-07-29 14:33:22'),
(281, 281, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-13 09:11:33', '2025-08-13 09:11:33'),
(282, 282, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-13 15:22:44', '2025-08-13 15:22:44'),
(283, 283, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-14 10:33:55', '2025-08-14 10:33:55'),
(284, 284, 900000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-14 15:44:11', '2025-08-14 15:44:11'),
(285, 285, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-15 11:55:33', '2025-08-15 11:55:33'),
(286, 286, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-15 16:22:44', '2025-08-15 16:22:44'),
(287, 287, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-16 10:33:55', '2025-08-16 10:33:55'),
(288, 288, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-16 14:44:11', '2025-08-16 14:44:11'),
(289, 289, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-17 09:55:22', '2025-08-17 09:55:22'),
(290, 290, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-17 16:11:33', '2025-08-17 16:11:33'),
(291, 291, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-18 10:22:44', '2025-08-18 10:22:44'),
(292, 292, 900000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-18 15:33:55', '2025-08-18 15:33:55'),
(293, 293, 825000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-19 09:44:11', '2025-08-19 09:44:11'),
(294, 294, 825000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-19 14:55:22', '2025-08-19 14:55:22'),
(295, 295, 825000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-20 10:11:33', '2025-08-20 10:11:33'),
(296, 296, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-20 16:22:44', '2025-08-20 16:22:44'),
(297, 297, 675000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-21 09:33:55', '2025-08-21 09:33:55'),
(298, 298, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-21 14:44:11', '2025-08-21 14:44:11'),
(299, 299, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-22 10:55:22', '2025-08-22 10:55:22'),
(300, 300, 525000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-22 16:11:33', '2025-08-22 16:11:33'),
(301, 301, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-23 09:22:44', '2025-08-23 09:22:44'),
(302, 302, 525000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-23 14:33:55', '2025-08-23 14:33:55'),
(303, 303, 525000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-24 09:44:11', '2025-08-24 09:44:11'),
(304, 304, 525000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-24 14:55:22', '2025-08-24 14:55:22'),
(305, 305, 525000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-25 09:11:33', '2025-08-25 09:11:33'),
(306, 306, 525000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-25 14:22:44', '2025-08-25 14:22:44'),
(307, 307, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-26 10:33:55', '2025-08-26 10:33:55'),
(308, 308, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-26 15:44:11', '2025-08-26 15:44:11'),
(309, 309, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-27 09:55:22', '2025-08-27 09:55:22'),
(310, 310, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-27 15:11:33', '2025-08-27 15:11:33'),
(311, 311, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-28 09:22:44', '2025-08-28 09:22:44'),
(312, 312, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-28 14:33:55', '2025-08-28 14:33:55'),
(313, 313, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-29 09:44:11', '2025-08-29 09:44:11'),
(314, 314, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-29 14:55:22', '2025-08-29 14:55:22'),
(315, 315, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-30 10:11:33', '2025-08-30 10:11:33'),
(316, 316, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-08-30 15:22:44', '2025-08-30 15:22:44'),
(317, 317, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-31 09:33:55', '2025-08-31 09:33:55'),
(318, 318, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-31 14:44:11', '2025-08-31 14:44:11'),
(319, 319, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-09-01 10:55:22', '2025-09-01 10:55:22'),
(320, 320, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-01 16:11:33', '2025-09-01 16:11:33'),
(321, 321, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-02 09:22:44', '2025-09-02 09:22:44'),
(322, 322, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-02 14:33:55', '2025-09-02 14:33:55'),
(323, 323, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-09-03 09:44:11', '2025-09-03 09:44:11'),
(324, 324, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-03 14:55:22', '2025-09-03 14:55:22'),
(325, 325, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-04 10:11:33', '2025-09-04 10:11:33'),
(326, 326, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-04 15:22:44', '2025-09-04 15:22:44'),
(327, 327, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-09-05 09:33:55', '2025-09-05 09:33:55'),
(328, 328, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-05 14:44:11', '2025-09-05 14:44:11'),
(329, 329, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-06 10:55:22', '2025-09-06 10:55:22'),
(330, 330, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-06 16:11:33', '2025-09-06 16:11:33'),
(331, 331, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-09-07 09:22:44', '2025-09-07 09:22:44'),
(332, 332, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-07 14:33:55', '2025-09-07 14:33:55'),
(333, 333, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-08 09:44:11', '2025-09-08 09:44:11'),
(334, 334, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-08 15:55:22', '2025-09-08 15:55:22'),
(335, 335, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-09-09 10:11:33', '2025-09-09 10:11:33'),
(336, 336, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-09 14:22:44', '2025-09-09 14:22:44'),
(337, 337, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-10 09:33:55', '2025-09-10 09:33:55'),
(338, 338, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-10 14:44:11', '2025-09-10 14:44:11'),
(339, 339, 750000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-09-11 10:55:22', '2025-09-11 10:55:22'),
(340, 340, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-11 16:11:33', '2025-09-11 16:11:33'),
(341, 341, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-12 09:22:44', '2025-09-12 09:22:44'),
(342, 342, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-12 14:33:55', '2025-09-12 14:33:55'),
(343, 343, 750000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-09-13 09:44:11', '2025-09-13 09:44:11'),
(344, 344, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-13 15:55:22', '2025-09-13 15:55:22'),
(345, 345, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-09 09:11:33', '2025-10-09 09:11:33'),
(346, 346, 1050000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-09 14:22:44', '2025-10-09 14:22:44'),
(347, 347, 675000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-10-10 10:33:55', '2025-10-10 10:33:55'),
(348, 348, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-10 15:44:11', '2025-10-10 15:44:11'),
(349, 349, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-11 09:55:22', '2025-10-11 09:55:22'),
(350, 350, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-11 15:11:33', '2025-10-11 15:11:33'),
(351, 351, 675000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-10-12 10:22:44', '2025-10-12 10:22:44'),
(352, 352, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-12 14:33:55', '2025-10-12 14:33:55'),
(353, 353, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-13 09:44:11', '2025-10-13 09:44:11'),
(354, 354, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-13 14:55:22', '2025-10-13 14:55:22'),
(355, 355, 675000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-10-14 10:11:33', '2025-10-14 10:11:33'),
(356, 356, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-14 15:22:44', '2025-10-14 15:22:44'),
(357, 357, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-15 09:33:55', '2025-10-15 09:33:55'),
(358, 358, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-15 14:44:11', '2025-10-15 14:44:11'),
(359, 359, 675000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-10-16 10:55:22', '2025-10-16 10:55:22'),
(360, 360, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-16 16:11:33', '2025-10-16 16:11:33'),
(361, 361, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-17 09:22:44', '2025-10-17 09:22:44'),
(362, 362, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-17 14:33:55', '2025-10-17 14:33:55'),
(363, 363, 675000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-10-18 09:44:11', '2025-10-18 09:44:11'),
(364, 364, 675000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-18 15:55:22', '2025-10-18 15:55:22'),
(365, 365, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-29 11:11:33', '2025-11-29 11:11:33'),
(366, 366, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-29 16:22:44', '2025-11-29 16:22:44'),
(367, 367, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-12-01 10:33:55', '2025-12-01 10:33:55'),
(368, 368, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-12-01 15:44:11', '2025-12-01 15:44:11'),
(369, 369, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-12-02 09:55:22', '2025-12-02 09:55:22'),
(370, 370, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-12-02 15:11:33', '2025-12-02 15:11:33'),
(371, 371, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-12-03 10:22:44', '2025-12-03 10:22:44'),
(387, 372, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-28 15:18:44', '2025-11-28 15:18:44'),
(388, 373, 450000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-11-29 11:44:55', '2025-11-29 11:44:55'),
(389, 374, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-20 09:33:22', '2025-11-20 09:33:22'),
(390, 375, 400000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-11-20 14:55:11', '2025-11-20 14:55:11'),
(391, 376, 750000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-12-01 09:18:33', '2025-12-01 09:18:33'),
(392, 377, 600000.000, 'Thành công', 'Chuyển khoản', NULL, NULL, NULL, '2025-12-01 15:29:11', '2025-12-01 15:29:11'),
(393, 378, 450000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-12-02 10:44:55', '2025-12-02 10:44:55');

-- --------------------------------------------------------

--
-- Table structure for table `performances`
--

CREATE TABLE `performances` (
  `performance_id` int(11) NOT NULL,
  `show_id` int(11) DEFAULT NULL,
  `theater_id` int(11) DEFAULT NULL,
  `performance_date` date NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time DEFAULT NULL,
  `status` enum('Đang mở bán','Đã hủy','Đã kết thúc') DEFAULT 'Đang mở bán',
  `price` decimal(10,0) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `performances`
--

INSERT INTO `performances` (`performance_id`, `show_id`, `theater_id`, `performance_date`, `start_time`, `end_time`, `status`, `price`, `created_at`, `updated_at`) VALUES
(1, 8, 1, '2025-01-01', '19:30:00', '21:30:00', 'Đã kết thúc', 150000, '2024-12-20 18:00:00', '2024-12-02 18:00:00'),
(2, 8, 2, '2025-01-15', '19:30:00', '21:30:00', 'Đã kết thúc', 200000, '2024-12-16 22:00:00', '2024-12-16 22:00:00'),
(3, 11, 1, '2025-01-01', '14:00:00', '16:20:00', 'Đã kết thúc', 150000, '2024-12-20 18:00:00', '2024-12-02 18:00:00'),
(4, 11, 3, '2025-01-15', '19:30:00', '21:50:00', 'Đã kết thúc', 200000, '2024-12-16 22:00:00', '2024-12-16 22:00:00'),
(5, 17, 2, '2025-01-01', '19:30:00', '21:25:00', 'Đã kết thúc', 100000, '2024-12-20 18:00:00', '2024-12-02 18:00:00'),
(6, 17, 1, '2025-01-15', '14:00:00', '15:55:00', 'Đã kết thúc', 150000, '2024-12-16 22:00:00', '2024-12-16 22:00:00'),
(7, 10, 3, '2025-02-01', '19:30:00', '21:10:00', 'Đã kết thúc', 150000, '2025-01-02 18:00:00', '2025-01-02 18:00:00'),
(8, 10, 1, '2025-02-15', '19:30:00', '21:10:00', 'Đã kết thúc', 200000, '2025-01-16 22:00:00', '2025-01-16 22:00:00'),
(9, 14, 2, '2025-02-01', '14:00:00', '15:50:00', 'Đã kết thúc', 100000, '2025-01-02 18:00:00', '2025-01-02 18:00:00'),
(10, 14, 1, '2025-02-15', '19:30:00', '21:20:00', 'Đã kết thúc', 150000, '2025-01-16 22:00:00', '2025-01-16 22:00:00'),
(11, 20, 1, '2025-02-01', '19:30:00', '21:25:00', 'Đã kết thúc', 200000, '2025-01-02 18:00:00', '2025-01-02 18:00:00'),
(12, 20, 3, '2025-02-15', '14:00:00', '15:55:00', 'Đã kết thúc', 150000, '2025-01-16 22:00:00', '2025-01-16 22:00:00'),
(13, 13, 1, '2025-03-01', '14:00:00', '15:35:00', 'Đã kết thúc', 100000, '2025-02-02 18:00:00', '2025-02-02 18:00:00'),
(14, 13, 2, '2025-03-15', '19:30:00', '21:05:00', 'Đã kết thúc', 150000, '2025-02-16 22:00:00', '2025-02-16 22:00:00'),
(15, 16, 1, '2025-03-01', '19:30:00', '21:40:00', 'Đã kết thúc', 200000, '2025-02-02 18:00:00', '2025-02-02 22:00:00'),
(16, 16, 3, '2025-03-15', '19:30:00', '21:40:00', 'Đã kết thúc', 200000, '2025-02-16 22:00:00', '2025-02-16 22:00:00'),
(17, 19, 2, '2025-03-01', '19:30:00', '21:15:00', 'Đã kết thúc', 150000, '2025-02-02 18:00:00', '2025-02-02 22:00:00'),
(18, 19, 1, '2025-03-15', '14:00:00', '15:45:00', 'Đã kết thúc', 100000, '2025-02-16 22:00:00', '2025-02-16 18:00:00'),
(19, 9, 1, '2025-04-01', '19:30:00', '21:20:00', 'Đã kết thúc', 150000, '2025-03-01 09:00:00', '2025-03-01 09:00:00'),
(20, 9, 3, '2025-04-15', '19:30:00', '21:20:00', 'Đã kết thúc', 200000, '2025-03-01 09:00:00', '2025-03-01 09:00:00'),
(21, 12, 2, '2025-04-01', '14:00:00', '15:44:00', 'Đã kết thúc', 100000, '2025-03-01 09:00:00', '2025-03-01 09:00:00'),
(22, 12, 1, '2025-04-15', '19:30:00', '21:14:00', 'Đã kết thúc', 150000, '2025-03-01 09:00:00', '2025-03-01 09:00:00'),
(23, 18, 1, '2025-04-01', '19:30:00', '21:10:00', 'Đã kết thúc', 150000, '2025-03-01 09:00:00', '2025-03-01 09:00:00'),
(24, 18, 2, '2025-04-15', '14:00:00', '15:40:00', 'Đã kết thúc', 100000, '2025-03-01 09:00:00', '2025-03-01 09:00:00'),
(25, 15, 3, '2025-05-01', '19:30:00', '21:10:00', 'Đã kết thúc', 150000, '2025-04-01 10:00:00', '2025-04-01 10:00:00'),
(26, 15, 1, '2025-05-15', '19:30:00', '21:10:00', 'Đã kết thúc', 200000, '2025-04-01 10:00:00', '2025-04-01 10:00:00'),
(27, 8, 2, '2025-05-01', '14:00:00', '16:00:00', 'Đã kết thúc', 200000, '2025-04-01 10:00:00', '2025-04-01 10:00:00'),
(28, 8, 1, '2025-05-15', '19:30:00', '21:30:00', 'Đã kết thúc', 150000, '2025-04-01 10:00:00', '2025-04-01 10:00:00'),
(29, 19, 1, '2025-05-01', '19:30:00', '21:15:00', 'Đã kết thúc', 100000, '2025-04-01 10:00:00', '2025-04-01 10:00:00'),
(30, 19, 3, '2025-05-15', '14:00:00', '15:45:00', 'Đã kết thúc', 150000, '2025-04-01 10:00:00', '2025-04-01 10:00:00'),
(31, 11, 1, '2025-06-01', '19:30:00', '21:50:00', 'Đã kết thúc', 200000, '2025-05-01 11:00:00', '2025-05-01 11:00:00'),
(32, 11, 2, '2025-06-15', '19:30:00', '21:50:00', 'Đã kết thúc', 200000, '2025-05-01 11:00:00', '2025-05-01 11:00:00'),
(33, 16, 3, '2025-06-01', '14:00:00', '16:10:00', 'Đã kết thúc', 150000, '2025-05-01 11:00:00', '2025-05-01 11:00:00'),
(34, 16, 1, '2025-06-15', '19:30:00', '21:40:00', 'Đã kết thúc', 200000, '2025-05-01 11:00:00', '2025-05-01 11:00:00'),
(35, 13, 2, '2025-06-01', '19:30:00', '21:05:00', 'Đã kết thúc', 100000, '2025-05-01 11:00:00', '2025-05-01 11:00:00'),
(36, 13, 1, '2025-06-15', '14:00:00', '15:35:00', 'Đã kết thúc', 150000, '2025-05-01 11:00:00', '2025-05-01 11:00:00'),
(37, 20, 1, '2025-07-01', '19:30:00', '21:25:00', 'Đã kết thúc', 200000, '2025-06-01 09:30:00', '2025-06-01 09:30:00'),
(38, 20, 3, '2025-07-15', '19:30:00', '21:25:00', 'Đã kết thúc', 150000, '2025-06-01 09:30:00', '2025-06-01 09:30:00'),
(39, 10, 2, '2025-07-01', '14:00:00', '15:40:00', 'Đã kết thúc', 100000, '2025-06-01 09:30:00', '2025-06-01 09:30:00'),
(40, 10, 1, '2025-07-15', '19:30:00', '21:10:00', 'Đã kết thúc', 150000, '2025-06-01 09:30:00', '2025-06-01 09:30:00'),
(41, 17, 1, '2025-07-01', '19:30:00', '21:25:00', 'Đã kết thúc', 200000, '2025-06-01 09:30:00', '2025-06-01 09:30:00'),
(42, 17, 2, '2025-07-15', '14:00:00', '15:55:00', 'Đã kết thúc', 150000, '2025-06-01 09:30:00', '2025-06-01 09:30:00'),
(43, 14, 2, '2025-08-01', '19:30:00', '21:20:00', 'Đã kết thúc', 150000, '2025-07-01 10:00:00', '2025-07-01 10:00:00'),
(44, 14, 1, '2025-08-15', '19:30:00', '21:20:00', 'Đã kết thúc', 200000, '2025-07-01 10:00:00', '2025-07-01 10:00:00'),
(45, 12, 3, '2025-08-01', '14:00:00', '15:44:00', 'Đã kết thúc', 150000, '2025-07-01 10:00:00', '2025-07-01 10:00:00'),
(46, 12, 1, '2025-08-15', '19:30:00', '21:14:00', 'Đã kết thúc', 100000, '2025-07-01 10:00:00', '2025-07-01 10:00:00'),
(47, 8, 1, '2025-08-01', '19:30:00', '21:30:00', 'Đã kết thúc', 200000, '2025-07-01 10:00:00', '2025-07-01 10:00:00'),
(48, 8, 2, '2025-08-15', '14:00:00', '16:00:00', 'Đã kết thúc', 150000, '2025-07-01 10:00:00', '2025-07-01 10:00:00'),
(49, 18, 1, '2025-09-01', '19:30:00', '21:10:00', 'Đã kết thúc', 150000, '2025-08-01 09:00:00', '2025-08-01 09:00:00'),
(50, 18, 3, '2025-09-15', '19:30:00', '21:10:00', 'Đã kết thúc', 200000, '2025-08-01 09:00:00', '2025-08-01 09:00:00'),
(51, 11, 2, '2025-09-01', '14:00:00', '16:20:00', 'Đã kết thúc', 200000, '2025-08-01 09:00:00', '2025-08-01 09:00:00'),
(52, 11, 1, '2025-09-15', '19:30:00', '21:50:00', 'Đã kết thúc', 150000, '2025-08-01 09:00:00', '2025-08-01 09:00:00'),
(53, 19, 1, '2025-09-01', '19:30:00', '21:15:00', 'Đã kết thúc', 100000, '2025-08-01 09:00:00', '2025-08-01 09:00:00'),
(54, 19, 2, '2025-09-15', '14:00:00', '15:45:00', 'Đã kết thúc', 150000, '2025-08-01 09:00:00', '2025-08-01 09:00:00'),
(55, 16, 1, '2025-10-01', '19:30:00', '21:40:00', 'Đã kết thúc', 200000, '2025-09-01 10:00:00', '2025-09-01 10:00:00'),
(56, 16, 2, '2025-10-15', '19:30:00', '21:40:00', 'Đã kết thúc', 150000, '2025-09-01 10:00:00', '2025-09-01 10:00:00'),
(57, 13, 3, '2025-10-01', '14:00:00', '15:35:00', 'Đã kết thúc', 100000, '2025-09-01 10:00:00', '2025-09-01 10:00:00'),
(58, 13, 1, '2025-10-15', '19:30:00', '21:05:00', 'Đã kết thúc', 150000, '2025-09-01 10:00:00', '2025-09-01 10:00:00'),
(59, 17, 1, '2025-10-01', '19:30:00', '21:25:00', 'Đã kết thúc', 200000, '2025-09-01 10:00:00', '2025-09-01 10:00:00'),
(60, 17, 3, '2025-10-15', '14:00:00', '15:55:00', 'Đã kết thúc', 150000, '2025-09-01 10:00:00', '2025-09-01 10:00:00'),
(61, 8, 1, '2025-11-15', '19:30:00', '21:30:00', 'Đã kết thúc', 200000, '2025-10-15 10:00:00', '2025-10-15 10:00:00'),
(62, 14, 2, '2025-11-15', '19:30:00', '21:20:00', 'Đã kết thúc', 150000, '2025-10-15 10:00:00', '2025-10-15 10:00:00'),
(63, 20, 3, '2025-11-15', '14:00:00', '15:55:00', 'Đã kết thúc', 180000, '2025-10-15 10:00:00', '2025-10-15 10:00:00'),
(64, 8, 1, '2025-11-29', '19:30:00', '21:30:00', 'Đã kết thúc', 200000, '2025-10-15 10:00:00', '2025-10-15 10:00:00'),
(65, 14, 2, '2025-11-29', '19:30:00', '21:20:00', 'Đã kết thúc', 150000, '2025-10-15 10:00:00', '2025-10-15 10:00:00'),
(66, 20, 3, '2025-11-29', '14:00:00', '15:55:00', 'Đã kết thúc', 180000, '2025-10-15 10:00:00', '2025-10-15 10:00:00'),
(67, 11, 1, '2025-12-05', '19:30:00', '21:50:00', 'Đã kết thúc', 200000, '2025-10-25 09:00:00', '2025-12-07 11:30:19'),
(68, 17, 2, '2025-12-05', '19:30:00', '21:25:00', 'Đã kết thúc', 150000, '2025-10-25 09:00:00', '2025-12-07 11:30:19'),
(69, 13, 3, '2025-12-05', '14:00:00', '15:35:00', 'Đã kết thúc', 120000, '2025-10-25 09:00:00', '2025-12-07 11:30:19'),
(70, 11, 2, '2025-12-15', '19:30:00', '21:50:00', 'Đang mở bán', 200000, '2025-10-25 09:00:00', '2025-10-25 09:00:00'),
(71, 17, 1, '2025-12-15', '14:00:00', NULL, 'Đã hủy', 150000, '2025-10-25 09:00:00', '2025-12-01 11:48:59'),
(72, 13, 1, '2025-12-15', '19:30:00', '21:05:00', 'Đang mở bán', 150000, '2025-10-25 09:00:00', '2025-10-25 09:00:00');

-- --------------------------------------------------------

--
-- Table structure for table `reviews`
--

CREATE TABLE `reviews` (
  `review_id` int(11) NOT NULL,
  `show_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `rating` int(11) DEFAULT NULL CHECK (`rating` >= 1 and `rating` <= 5),
  `content` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `seats`
--

CREATE TABLE `seats` (
  `seat_id` int(11) NOT NULL,
  `theater_id` int(11) DEFAULT NULL,
  `category_id` int(11) DEFAULT NULL,
  `row_char` varchar(5) NOT NULL,
  `seat_number` int(11) NOT NULL,
  `real_seat_number` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `seats`
--

INSERT INTO `seats` (`seat_id`, `theater_id`, `category_id`, `row_char`, `seat_number`, `real_seat_number`, `created_at`) VALUES
(1, 1, 1, 'A', 1, 1, '2025-09-24 16:19:02'),
(2, 1, 1, 'A', 2, 2, '2025-09-24 16:19:02'),
(3, 1, 1, 'A', 3, 3, '2025-09-24 16:19:02'),
(4, 1, 1, 'A', 4, 4, '2025-09-24 16:19:02'),
(5, 1, 1, 'A', 5, 5, '2025-09-24 16:19:02'),
(6, 1, 1, 'A', 6, 6, '2025-09-24 16:19:02'),
(7, 1, 1, 'A', 7, 7, '2025-09-24 16:19:02'),
(8, 1, 1, 'A', 8, 8, '2025-09-24 16:19:02'),
(9, 1, 1, 'A', 9, 9, '2025-09-24 16:19:02'),
(10, 1, 1, 'A', 10, 10, '2025-09-24 16:19:02'),
(11, 1, 1, 'B', 1, 1, '2025-09-24 16:19:02'),
(12, 1, 1, 'B', 2, 2, '2025-09-24 16:19:02'),
(13, 1, 1, 'B', 3, 3, '2025-09-24 16:19:02'),
(14, 1, 1, 'B', 4, 4, '2025-09-24 16:19:02'),
(15, 1, 1, 'B', 5, 5, '2025-09-24 16:19:02'),
(16, 1, 1, 'B', 6, 6, '2025-09-24 16:19:02'),
(17, 1, 1, 'B', 7, 7, '2025-09-24 16:19:02'),
(18, 1, 1, 'B', 8, 8, '2025-09-24 16:19:02'),
(19, 1, 1, 'B', 9, 9, '2025-09-24 16:19:02'),
(20, 1, 1, 'B', 10, 10, '2025-09-24 16:19:02'),
(21, 1, 2, 'C', 1, 1, '2025-09-24 16:19:02'),
(22, 1, 2, 'C', 2, 2, '2025-09-24 16:19:02'),
(23, 1, 2, 'C', 3, 3, '2025-09-24 16:19:02'),
(24, 1, 2, 'C', 4, 4, '2025-09-24 16:19:02'),
(25, 1, 2, 'C', 5, 5, '2025-09-24 16:19:02'),
(26, 1, 2, 'C', 6, 6, '2025-09-24 16:19:02'),
(27, 1, 2, 'C', 7, 7, '2025-09-24 16:19:02'),
(28, 1, 2, 'C', 8, 8, '2025-09-24 16:19:02'),
(29, 1, 2, 'C', 9, 9, '2025-09-24 16:19:02'),
(30, 1, 2, 'C', 10, 10, '2025-09-24 16:19:02'),
(31, 1, 3, 'D', 1, 1, '2025-09-24 16:19:02'),
(32, 1, 3, 'D', 2, 2, '2025-09-24 16:19:02'),
(33, 1, 3, 'D', 3, 3, '2025-09-24 16:19:02'),
(34, 1, 3, 'D', 4, 4, '2025-09-24 16:19:02'),
(35, 1, 3, 'D', 5, 5, '2025-09-24 16:19:02'),
(36, 1, 3, 'D', 6, 6, '2025-09-24 16:19:02'),
(37, 1, 3, 'E', 1, 1, '2025-09-24 16:19:02'),
(38, 1, 3, 'E', 2, 2, '2025-09-24 16:19:02'),
(39, 1, 3, 'E', 3, 3, '2025-09-24 16:19:02'),
(40, 1, 3, 'E', 4, 4, '2025-09-24 16:19:02'),
(41, 1, 3, 'E', 5, 5, '2025-09-24 16:19:02'),
(42, 1, 3, 'E', 6, 6, '2025-09-24 16:19:02'),
(43, 1, 3, 'F', 1, 1, '2025-09-24 16:19:02'),
(44, 1, 3, 'F', 2, 2, '2025-09-24 16:19:02'),
(45, 1, 3, 'F', 3, 3, '2025-09-24 16:19:02'),
(46, 1, 3, 'F', 4, 4, '2025-09-24 16:19:02'),
(47, 1, 3, 'F', 5, 5, '2025-09-24 16:19:02'),
(48, 1, 3, 'F', 6, 6, '2025-09-24 16:19:02'),
(49, 1, 3, 'F', 7, 7, '2025-09-24 16:19:02'),
(50, 1, 3, 'F', 8, 8, '2025-09-24 16:19:02'),
(51, 1, 3, 'F', 9, 9, '2025-09-24 16:19:02'),
(52, 1, 3, 'F', 10, 10, '2025-09-24 16:19:02'),
(53, 2, 1, 'A', 1, 1, '2025-09-24 16:19:02'),
(54, 2, 1, 'A', 2, 2, '2025-09-24 16:19:02'),
(55, 2, 1, 'A', 3, 3, '2025-09-24 16:19:02'),
(56, 2, 1, 'A', 4, 4, '2025-09-24 16:19:02'),
(57, 2, 1, 'A', 5, 5, '2025-09-24 16:19:02'),
(58, 2, 1, 'A', 6, 6, '2025-09-24 16:19:02'),
(59, 2, 1, 'B', 1, 1, '2025-09-24 16:19:02'),
(60, 2, 1, 'B', 2, 2, '2025-09-24 16:19:02'),
(61, 2, 1, 'B', 3, 3, '2025-09-24 16:19:02'),
(62, 2, 1, 'B', 4, 4, '2025-09-24 16:19:02'),
(63, 2, 1, 'B', 5, 5, '2025-09-24 16:19:02'),
(64, 2, 1, 'B', 6, 6, '2025-09-24 16:19:02'),
(65, 2, 2, 'C', 1, 1, '2025-09-24 16:19:02'),
(66, 2, 2, 'C', 2, 2, '2025-09-24 16:19:02'),
(67, 2, 2, 'C', 3, 3, '2025-09-24 16:19:02'),
(68, 2, 2, 'C', 4, 4, '2025-09-24 16:19:02'),
(69, 2, 2, 'C', 5, 5, '2025-09-24 16:19:02'),
(70, 2, 2, 'C', 6, 6, '2025-09-24 16:19:02'),
(71, 2, 1, 'D', 1, 1, '2025-09-24 16:19:02'),
(72, 2, 1, 'D', 2, 2, '2025-09-24 16:19:02'),
(73, 2, 1, 'D', 3, 3, '2025-09-24 16:19:02'),
(74, 2, 1, 'D', 4, 4, '2025-09-24 16:19:02'),
(75, 2, 1, 'D', 5, 5, '2025-09-24 16:19:02'),
(76, 2, 1, 'D', 6, 6, '2025-09-24 16:19:02'),
(77, 3, 1, 'A', 1, 1, '2025-09-24 16:19:02'),
(78, 3, 1, 'A', 2, 2, '2025-09-24 16:19:02'),
(79, 3, 1, 'A', 3, 3, '2025-09-24 16:19:02'),
(80, 3, 1, 'A', 4, 4, '2025-09-24 16:19:02'),
(81, 3, 1, 'A', 5, 5, '2025-09-24 16:19:02'),
(82, 3, 1, 'A', 6, 6, '2025-09-24 16:19:02'),
(83, 3, 1, 'B', 1, 1, '2025-09-24 16:19:02'),
(84, 3, 1, 'B', 2, 2, '2025-09-24 16:19:02'),
(85, 3, 1, 'B', 3, 3, '2025-09-24 16:19:02'),
(86, 3, 1, 'B', 4, 4, '2025-09-24 16:19:02'),
(87, 3, 1, 'B', 5, 5, '2025-09-24 16:19:02'),
(88, 3, 1, 'B', 6, 6, '2025-09-24 16:19:02'),
(89, 3, 2, 'C', 1, 1, '2025-09-24 16:19:02'),
(90, 3, 2, 'C', 2, 2, '2025-09-24 16:19:02'),
(91, 3, 2, 'C', 3, 3, '2025-09-24 16:19:02'),
(92, 3, 2, 'C', 4, 4, '2025-09-24 16:19:02'),
(93, 3, 2, 'C', 5, 5, '2025-09-24 16:19:02'),
(94, 3, 2, 'C', 6, 6, '2025-09-24 16:19:02'),
(95, 3, 3, 'D', 1, 1, '2025-09-24 16:19:02'),
(96, 3, 3, 'D', 2, 2, '2025-09-24 16:19:02'),
(97, 3, 3, 'D', 3, 3, '2025-09-24 16:19:02'),
(98, 3, 3, 'D', 4, 4, '2025-09-24 16:19:02'),
(99, 3, 3, 'D', 5, 5, '2025-09-24 16:19:02'),
(100, 3, 3, 'D', 6, 6, '2025-09-24 16:19:02'),
(101, 3, 3, 'E', 1, 1, '2025-09-24 16:19:02'),
(102, 3, 3, 'E', 2, 2, '2025-09-24 16:19:02'),
(103, 3, 3, 'E', 3, 3, '2025-09-24 16:19:02'),
(104, 3, 3, 'E', 4, 4, '2025-09-24 16:19:02'),
(105, 3, 3, 'E', 5, 5, '2025-09-24 16:19:02'),
(106, 3, 3, 'E', 6, 6, '2025-09-24 16:19:02'),
(107, 2, 1, 'A', 7, 7, '2025-11-17 18:55:09'),
(108, 2, 1, 'B', 7, 7, '2025-11-17 18:55:09'),
(109, 2, 2, 'C', 7, 7, '2025-11-17 18:55:09'),
(110, 2, 1, 'D', 7, 7, '2025-11-17 18:55:09'),
(111, 2, 1, 'A', 8, 8, '2025-11-17 18:58:14'),
(112, 2, 1, 'B', 8, 8, '2025-11-17 18:58:14'),
(113, 2, 2, 'C', 8, 8, '2025-11-17 18:58:14'),
(114, 2, 1, 'D', 8, 8, '2025-11-17 18:58:14');

-- --------------------------------------------------------

--
-- Table structure for table `seat_categories`
--

CREATE TABLE `seat_categories` (
  `category_id` int(11) NOT NULL,
  `category_name` varchar(100) NOT NULL,
  `base_price` decimal(10,0) NOT NULL,
  `color_class` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `seat_categories`
--

INSERT INTO `seat_categories` (`category_id`, `category_name`, `base_price`, `color_class`) VALUES
(1, 'A', 150000, '0d6efd'),
(2, 'B', 75000, '198754'),
(3, 'C', 0, '6f42c1'),
(6, 'D', 50000, '27ae60'),
(7, 'E', 45000, '2980B9');

-- --------------------------------------------------------

--
-- Table structure for table `seat_performance`
--

CREATE TABLE `seat_performance` (
  `seat_id` int(11) NOT NULL,
  `performance_id` int(11) NOT NULL,
  `status` enum('trống','đã đặt') NOT NULL DEFAULT 'trống'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `seat_performance`
--

INSERT INTO `seat_performance` (`seat_id`, `performance_id`, `status`) VALUES
(1, 1, 'đã đặt'),
(2, 1, 'trống'),
(3, 1, 'đã đặt'),
(4, 1, 'trống'),
(5, 1, 'đã đặt'),
(6, 1, 'trống'),
(7, 1, 'đã đặt'),
(8, 1, 'trống'),
(9, 1, 'đã đặt'),
(10, 1, 'trống'),
(11, 1, 'đã đặt'),
(12, 1, 'trống'),
(13, 1, 'đã đặt'),
(14, 1, 'trống'),
(15, 1, 'đã đặt'),
(16, 1, 'trống'),
(17, 1, 'đã đặt'),
(18, 1, 'trống'),
(19, 1, 'đã đặt'),
(20, 1, 'trống'),
(21, 1, 'đã đặt'),
(22, 1, 'trống'),
(23, 1, 'đã đặt'),
(24, 1, 'trống'),
(25, 1, 'đã đặt'),
(26, 1, 'trống'),
(27, 1, 'đã đặt'),
(28, 1, 'trống'),
(29, 1, 'đã đặt'),
(30, 1, 'trống'),
(31, 1, 'đã đặt'),
(32, 1, 'trống'),
(33, 1, 'đã đặt'),
(34, 1, 'trống'),
(35, 1, 'đã đặt'),
(36, 1, 'trống'),
(37, 1, 'đã đặt'),
(38, 1, 'trống'),
(39, 1, 'đã đặt'),
(40, 1, 'trống'),
(41, 1, 'đã đặt'),
(42, 1, 'trống'),
(43, 1, 'đã đặt'),
(44, 1, 'trống'),
(45, 1, 'đã đặt'),
(46, 1, 'trống'),
(47, 1, 'đã đặt'),
(48, 1, 'trống'),
(49, 1, 'đã đặt'),
(50, 1, 'trống'),
(51, 1, 'đã đặt'),
(52, 1, 'trống'),
(53, 2, 'đã đặt'),
(54, 2, 'trống'),
(55, 2, 'đã đặt'),
(56, 2, 'trống'),
(57, 2, 'đã đặt'),
(58, 2, 'trống'),
(59, 2, 'đã đặt'),
(60, 2, 'trống'),
(61, 2, 'đã đặt'),
(62, 2, 'trống'),
(63, 2, 'đã đặt'),
(64, 2, 'trống'),
(65, 2, 'đã đặt'),
(66, 2, 'trống'),
(67, 2, 'đã đặt'),
(68, 2, 'trống'),
(69, 2, 'đã đặt'),
(70, 2, 'trống'),
(71, 2, 'đã đặt'),
(72, 2, 'trống'),
(73, 2, 'đã đặt'),
(74, 2, 'trống'),
(75, 2, 'đã đặt'),
(76, 2, 'trống'),
(107, 2, 'đã đặt'),
(108, 2, 'trống'),
(109, 2, 'đã đặt'),
(110, 2, 'trống'),
(111, 2, 'đã đặt'),
(112, 2, 'trống'),
(113, 2, 'đã đặt'),
(114, 2, 'trống'),
(1, 3, 'trống'),
(2, 3, 'đã đặt'),
(3, 3, 'trống'),
(4, 3, 'đã đặt'),
(5, 3, 'trống'),
(6, 3, 'đã đặt'),
(7, 3, 'trống'),
(8, 3, 'đã đặt'),
(9, 3, 'trống'),
(10, 3, 'đã đặt'),
(11, 3, 'trống'),
(12, 3, 'đã đặt'),
(13, 3, 'trống'),
(14, 3, 'đã đặt'),
(15, 3, 'trống'),
(16, 3, 'đã đặt'),
(17, 3, 'trống'),
(18, 3, 'đã đặt'),
(19, 3, 'trống'),
(20, 3, 'đã đặt'),
(21, 3, 'trống'),
(22, 3, 'đã đặt'),
(23, 3, 'trống'),
(24, 3, 'đã đặt'),
(25, 3, 'trống'),
(26, 3, 'đã đặt'),
(27, 3, 'trống'),
(28, 3, 'đã đặt'),
(29, 3, 'trống'),
(30, 3, 'đã đặt'),
(31, 3, 'trống'),
(32, 3, 'đã đặt'),
(33, 3, 'trống'),
(34, 3, 'đã đặt'),
(35, 3, 'trống'),
(36, 3, 'đã đặt'),
(37, 3, 'trống'),
(38, 3, 'đã đặt'),
(39, 3, 'trống'),
(40, 3, 'đã đặt'),
(41, 3, 'trống'),
(42, 3, 'đã đặt'),
(43, 3, 'trống'),
(44, 3, 'đã đặt'),
(45, 3, 'trống'),
(46, 3, 'đã đặt'),
(47, 3, 'trống'),
(48, 3, 'đã đặt'),
(49, 3, 'trống'),
(50, 3, 'đã đặt'),
(51, 3, 'trống'),
(52, 3, 'đã đặt'),
(77, 4, 'đã đặt'),
(78, 4, 'trống'),
(79, 4, 'đã đặt'),
(80, 4, 'trống'),
(81, 4, 'đã đặt'),
(82, 4, 'trống'),
(83, 4, 'đã đặt'),
(84, 4, 'trống'),
(85, 4, 'đã đặt'),
(86, 4, 'trống'),
(87, 4, 'đã đặt'),
(88, 4, 'trống'),
(89, 4, 'đã đặt'),
(90, 4, 'trống'),
(91, 4, 'đã đặt'),
(92, 4, 'trống'),
(93, 4, 'đã đặt'),
(94, 4, 'trống'),
(95, 4, 'đã đặt'),
(96, 4, 'trống'),
(97, 4, 'đã đặt'),
(98, 4, 'trống'),
(99, 4, 'đã đặt'),
(100, 4, 'trống'),
(101, 4, 'đã đặt'),
(102, 4, 'trống'),
(103, 4, 'đã đặt'),
(104, 4, 'trống'),
(105, 4, 'đã đặt'),
(106, 4, 'trống'),
(53, 5, 'trống'),
(54, 5, 'đã đặt'),
(55, 5, 'trống'),
(56, 5, 'đã đặt'),
(57, 5, 'trống'),
(58, 5, 'đã đặt'),
(59, 5, 'trống'),
(60, 5, 'đã đặt'),
(61, 5, 'trống'),
(62, 5, 'đã đặt'),
(63, 5, 'trống'),
(64, 5, 'đã đặt'),
(65, 5, 'trống'),
(66, 5, 'đã đặt'),
(67, 5, 'trống'),
(68, 5, 'đã đặt'),
(69, 5, 'trống'),
(70, 5, 'đã đặt'),
(71, 5, 'trống'),
(72, 5, 'đã đặt'),
(73, 5, 'trống'),
(74, 5, 'đã đặt'),
(75, 5, 'trống'),
(76, 5, 'đã đặt'),
(107, 5, 'trống'),
(108, 5, 'đã đặt'),
(109, 5, 'trống'),
(110, 5, 'đã đặt'),
(111, 5, 'trống'),
(112, 5, 'đã đặt'),
(113, 5, 'trống'),
(114, 5, 'đã đặt'),
(1, 6, 'đã đặt'),
(2, 6, 'trống'),
(3, 6, 'đã đặt'),
(4, 6, 'trống'),
(5, 6, 'đã đặt'),
(6, 6, 'trống'),
(7, 6, 'đã đặt'),
(8, 6, 'trống'),
(9, 6, 'đã đặt'),
(10, 6, 'trống'),
(11, 6, 'đã đặt'),
(12, 6, 'trống'),
(13, 6, 'đã đặt'),
(14, 6, 'trống'),
(15, 6, 'đã đặt'),
(16, 6, 'trống'),
(17, 6, 'đã đặt'),
(18, 6, 'trống'),
(19, 6, 'đã đặt'),
(20, 6, 'trống'),
(21, 6, 'đã đặt'),
(22, 6, 'trống'),
(23, 6, 'đã đặt'),
(24, 6, 'trống'),
(25, 6, 'đã đặt'),
(26, 6, 'trống'),
(27, 6, 'đã đặt'),
(28, 6, 'trống'),
(29, 6, 'đã đặt'),
(30, 6, 'trống'),
(31, 6, 'đã đặt'),
(32, 6, 'trống'),
(33, 6, 'đã đặt'),
(34, 6, 'trống'),
(35, 6, 'đã đặt'),
(36, 6, 'trống'),
(37, 6, 'đã đặt'),
(38, 6, 'trống'),
(39, 6, 'đã đặt'),
(40, 6, 'trống'),
(41, 6, 'đã đặt'),
(42, 6, 'trống'),
(43, 6, 'đã đặt'),
(44, 6, 'trống'),
(45, 6, 'đã đặt'),
(46, 6, 'trống'),
(47, 6, 'đã đặt'),
(48, 6, 'trống'),
(49, 6, 'đã đặt'),
(50, 6, 'trống'),
(51, 6, 'đã đặt'),
(52, 6, 'trống'),
(77, 7, 'đã đặt'),
(78, 7, 'trống'),
(79, 7, 'đã đặt'),
(80, 7, 'trống'),
(81, 7, 'đã đặt'),
(82, 7, 'trống'),
(83, 7, 'đã đặt'),
(84, 7, 'trống'),
(85, 7, 'đã đặt'),
(86, 7, 'trống'),
(87, 7, 'đã đặt'),
(88, 7, 'trống'),
(89, 7, 'đã đặt'),
(90, 7, 'trống'),
(91, 7, 'đã đặt'),
(92, 7, 'trống'),
(93, 7, 'đã đặt'),
(94, 7, 'trống'),
(95, 7, 'đã đặt'),
(96, 7, 'trống'),
(97, 7, 'đã đặt'),
(98, 7, 'trống'),
(99, 7, 'đã đặt'),
(100, 7, 'trống'),
(101, 7, 'đã đặt'),
(102, 7, 'trống'),
(103, 7, 'đã đặt'),
(104, 7, 'trống'),
(105, 7, 'đã đặt'),
(106, 7, 'trống'),
(1, 8, 'đã đặt'),
(2, 8, 'trống'),
(3, 8, 'đã đặt'),
(4, 8, 'trống'),
(5, 8, 'đã đặt'),
(6, 8, 'trống'),
(7, 8, 'đã đặt'),
(8, 8, 'trống'),
(9, 8, 'đã đặt'),
(10, 8, 'trống'),
(11, 8, 'đã đặt'),
(12, 8, 'trống'),
(13, 8, 'đã đặt'),
(14, 8, 'trống'),
(15, 8, 'đã đặt'),
(16, 8, 'trống'),
(17, 8, 'đã đặt'),
(18, 8, 'trống'),
(19, 8, 'đã đặt'),
(20, 8, 'trống'),
(21, 8, 'đã đặt'),
(22, 8, 'trống'),
(23, 8, 'đã đặt'),
(24, 8, 'trống'),
(25, 8, 'đã đặt'),
(26, 8, 'trống'),
(27, 8, 'đã đặt'),
(28, 8, 'trống'),
(29, 8, 'đã đặt'),
(30, 8, 'trống'),
(31, 8, 'đã đặt'),
(32, 8, 'trống'),
(33, 8, 'đã đặt'),
(34, 8, 'trống'),
(35, 8, 'đã đặt'),
(36, 8, 'trống'),
(37, 8, 'đã đặt'),
(38, 8, 'trống'),
(39, 8, 'đã đặt'),
(40, 8, 'trống'),
(41, 8, 'đã đặt'),
(42, 8, 'trống'),
(43, 8, 'đã đặt'),
(44, 8, 'trống'),
(45, 8, 'đã đặt'),
(46, 8, 'trống'),
(47, 8, 'đã đặt'),
(48, 8, 'trống'),
(49, 8, 'đã đặt'),
(50, 8, 'trống'),
(51, 8, 'trống'),
(52, 8, 'trống'),
(53, 9, 'đã đặt'),
(54, 9, 'trống'),
(55, 9, 'đã đặt'),
(56, 9, 'trống'),
(57, 9, 'đã đặt'),
(58, 9, 'trống'),
(59, 9, 'đã đặt'),
(60, 9, 'trống'),
(61, 9, 'đã đặt'),
(62, 9, 'trống'),
(63, 9, 'đã đặt'),
(64, 9, 'trống'),
(65, 9, 'đã đặt'),
(66, 9, 'trống'),
(67, 9, 'đã đặt'),
(68, 9, 'trống'),
(69, 9, 'đã đặt'),
(70, 9, 'trống'),
(71, 9, 'trống'),
(72, 9, 'trống'),
(73, 9, 'trống'),
(74, 9, 'trống'),
(75, 9, 'trống'),
(76, 9, 'trống'),
(107, 9, 'đã đặt'),
(108, 9, 'trống'),
(109, 9, 'đã đặt'),
(110, 9, 'trống'),
(111, 9, 'đã đặt'),
(112, 9, 'trống'),
(113, 9, 'đã đặt'),
(114, 9, 'trống'),
(1, 10, 'đã đặt'),
(2, 10, 'trống'),
(3, 10, 'đã đặt'),
(4, 10, 'trống'),
(5, 10, 'đã đặt'),
(6, 10, 'trống'),
(7, 10, 'đã đặt'),
(8, 10, 'trống'),
(9, 10, 'đã đặt'),
(10, 10, 'trống'),
(11, 10, 'đã đặt'),
(12, 10, 'trống'),
(13, 10, 'đã đặt'),
(14, 10, 'trống'),
(15, 10, 'đã đặt'),
(16, 10, 'trống'),
(17, 10, 'đã đặt'),
(18, 10, 'trống'),
(19, 10, 'đã đặt'),
(20, 10, 'trống'),
(21, 10, 'đã đặt'),
(22, 10, 'trống'),
(23, 10, 'đã đặt'),
(24, 10, 'trống'),
(25, 10, 'trống'),
(26, 10, 'trống'),
(27, 10, 'trống'),
(28, 10, 'trống'),
(29, 10, 'trống'),
(30, 10, 'trống'),
(31, 10, 'trống'),
(32, 10, 'trống'),
(33, 10, 'trống'),
(34, 10, 'trống'),
(35, 10, 'trống'),
(36, 10, 'trống'),
(37, 10, 'trống'),
(38, 10, 'trống'),
(39, 10, 'trống'),
(40, 10, 'trống'),
(41, 10, 'trống'),
(42, 10, 'trống'),
(43, 10, 'trống'),
(44, 10, 'trống'),
(45, 10, 'trống'),
(46, 10, 'trống'),
(47, 10, 'trống'),
(48, 10, 'trống'),
(49, 10, 'trống'),
(50, 10, 'trống'),
(51, 10, 'trống'),
(52, 10, 'trống'),
(53, 11, 'đã đặt'),
(54, 11, 'trống'),
(55, 11, 'đã đặt'),
(56, 11, 'trống'),
(57, 11, 'đã đặt'),
(58, 11, 'trống'),
(59, 11, 'đã đặt'),
(60, 11, 'trống'),
(61, 11, 'đã đặt'),
(62, 11, 'trống'),
(63, 11, 'đã đặt'),
(64, 11, 'trống'),
(65, 11, 'đã đặt'),
(66, 11, 'trống'),
(67, 11, 'đã đặt'),
(68, 11, 'trống'),
(69, 11, 'đã đặt'),
(70, 11, 'trống'),
(71, 11, 'đã đặt'),
(72, 11, 'trống'),
(73, 11, 'đã đặt'),
(74, 11, 'trống'),
(75, 11, 'trống'),
(76, 11, 'trống'),
(107, 11, 'đã đặt'),
(108, 11, 'trống'),
(109, 11, 'đã đặt'),
(110, 11, 'trống'),
(111, 11, 'đã đặt'),
(112, 11, 'trống'),
(113, 11, 'đã đặt'),
(114, 11, 'trống'),
(1, 12, 'đã đặt'),
(2, 12, 'trống'),
(3, 12, 'đã đặt'),
(4, 12, 'trống'),
(5, 12, 'đã đặt'),
(6, 12, 'trống'),
(7, 12, 'đã đặt'),
(8, 12, 'trống'),
(9, 12, 'đã đặt'),
(10, 12, 'trống'),
(11, 12, 'đã đặt'),
(12, 12, 'trống'),
(13, 12, 'đã đặt'),
(14, 12, 'trống'),
(15, 12, 'đã đặt'),
(16, 12, 'trống'),
(17, 12, 'đã đặt'),
(18, 12, 'trống'),
(19, 12, 'đã đặt'),
(20, 12, 'trống'),
(21, 12, 'đã đặt'),
(22, 12, 'trống'),
(23, 12, 'đã đặt'),
(24, 12, 'trống'),
(25, 12, 'trống'),
(26, 12, 'trống'),
(27, 12, 'trống'),
(28, 12, 'trống'),
(29, 12, 'trống'),
(30, 12, 'trống'),
(31, 12, 'trống'),
(32, 12, 'trống'),
(33, 12, 'trống'),
(34, 12, 'trống'),
(35, 12, 'trống'),
(36, 12, 'trống'),
(37, 12, 'trống'),
(38, 12, 'trống'),
(39, 12, 'trống'),
(40, 12, 'trống'),
(41, 12, 'trống'),
(42, 12, 'trống'),
(43, 12, 'trống'),
(44, 12, 'trống'),
(45, 12, 'trống'),
(46, 12, 'trống'),
(47, 12, 'trống'),
(48, 12, 'trống'),
(49, 12, 'trống'),
(50, 12, 'trống'),
(51, 12, 'trống'),
(52, 12, 'trống'),
(1, 13, 'đã đặt'),
(2, 13, 'trống'),
(3, 13, 'đã đặt'),
(4, 13, 'trống'),
(5, 13, 'đã đặt'),
(6, 13, 'trống'),
(7, 13, 'đã đặt'),
(8, 13, 'trống'),
(9, 13, 'đã đặt'),
(10, 13, 'trống'),
(11, 13, 'đã đặt'),
(12, 13, 'trống'),
(13, 13, 'đã đặt'),
(14, 13, 'trống'),
(15, 13, 'đã đặt'),
(16, 13, 'trống'),
(17, 13, 'đã đặt'),
(18, 13, 'trống'),
(19, 13, 'đã đặt'),
(20, 13, 'trống'),
(21, 13, 'đã đặt'),
(22, 13, 'trống'),
(23, 13, 'đã đặt'),
(24, 13, 'trống'),
(25, 13, 'trống'),
(26, 13, 'trống'),
(27, 13, 'trống'),
(28, 13, 'trống'),
(29, 13, 'trống'),
(30, 13, 'trống'),
(31, 13, 'trống'),
(32, 13, 'trống'),
(33, 13, 'trống'),
(34, 13, 'trống'),
(35, 13, 'trống'),
(36, 13, 'trống'),
(37, 13, 'trống'),
(38, 13, 'trống'),
(39, 13, 'trống'),
(40, 13, 'trống'),
(41, 13, 'trống'),
(42, 13, 'trống'),
(43, 13, 'trống'),
(44, 13, 'trống'),
(45, 13, 'trống'),
(46, 13, 'trống'),
(47, 13, 'trống'),
(48, 13, 'trống'),
(49, 13, 'trống'),
(50, 13, 'trống'),
(51, 13, 'trống'),
(52, 13, 'trống'),
(53, 14, 'đã đặt'),
(54, 14, 'trống'),
(55, 14, 'đã đặt'),
(56, 14, 'trống'),
(57, 14, 'đã đặt'),
(58, 14, 'trống'),
(59, 14, 'đã đặt'),
(60, 14, 'trống'),
(61, 14, 'đã đặt'),
(62, 14, 'trống'),
(63, 14, 'đã đặt'),
(64, 14, 'trống'),
(65, 14, 'đã đặt'),
(66, 14, 'trống'),
(67, 14, 'đã đặt'),
(68, 14, 'trống'),
(69, 14, 'đã đặt'),
(70, 14, 'trống'),
(71, 14, 'trống'),
(72, 14, 'trống'),
(73, 14, 'trống'),
(74, 14, 'trống'),
(75, 14, 'trống'),
(76, 14, 'trống'),
(107, 14, 'đã đặt'),
(108, 14, 'trống'),
(109, 14, 'đã đặt'),
(110, 14, 'trống'),
(111, 14, 'đã đặt'),
(112, 14, 'trống'),
(113, 14, 'đã đặt'),
(114, 14, 'trống'),
(77, 15, 'đã đặt'),
(78, 15, 'trống'),
(79, 15, 'đã đặt'),
(80, 15, 'trống'),
(81, 15, 'đã đặt'),
(82, 15, 'trống'),
(83, 15, 'đã đặt'),
(84, 15, 'trống'),
(85, 15, 'đã đặt'),
(86, 15, 'trống'),
(87, 15, 'đã đặt'),
(88, 15, 'trống'),
(89, 15, 'đã đặt'),
(90, 15, 'trống'),
(91, 15, 'đã đặt'),
(92, 15, 'trống'),
(93, 15, 'trống'),
(94, 15, 'trống'),
(95, 15, 'trống'),
(96, 15, 'trống'),
(97, 15, 'trống'),
(98, 15, 'trống'),
(99, 15, 'trống'),
(100, 15, 'trống'),
(101, 15, 'trống'),
(102, 15, 'trống'),
(103, 15, 'trống'),
(104, 15, 'trống'),
(105, 15, 'trống'),
(106, 15, 'trống'),
(1, 16, 'đã đặt'),
(2, 16, 'trống'),
(3, 16, 'đã đặt'),
(4, 16, 'trống'),
(5, 16, 'đã đặt'),
(6, 16, 'trống'),
(7, 16, 'đã đặt'),
(8, 16, 'trống'),
(9, 16, 'đã đặt'),
(10, 16, 'trống'),
(11, 16, 'đã đặt'),
(12, 16, 'trống'),
(13, 16, 'đã đặt'),
(14, 16, 'trống'),
(15, 16, 'đã đặt'),
(16, 16, 'trống'),
(17, 16, 'đã đặt'),
(18, 16, 'trống'),
(19, 16, 'đã đặt'),
(20, 16, 'trống'),
(21, 16, 'đã đặt'),
(22, 16, 'trống'),
(23, 16, 'trống'),
(24, 16, 'trống'),
(25, 16, 'trống'),
(26, 16, 'trống'),
(27, 16, 'trống'),
(28, 16, 'trống'),
(29, 16, 'trống'),
(30, 16, 'trống'),
(31, 16, 'trống'),
(32, 16, 'trống'),
(33, 16, 'trống'),
(34, 16, 'trống'),
(35, 16, 'trống'),
(36, 16, 'trống'),
(37, 16, 'trống'),
(38, 16, 'trống'),
(39, 16, 'trống'),
(40, 16, 'trống'),
(41, 16, 'trống'),
(42, 16, 'trống'),
(43, 16, 'trống'),
(44, 16, 'trống'),
(45, 16, 'trống'),
(46, 16, 'trống'),
(47, 16, 'trống'),
(48, 16, 'trống'),
(49, 16, 'trống'),
(50, 16, 'trống'),
(51, 16, 'trống'),
(52, 16, 'trống'),
(53, 17, 'đã đặt'),
(54, 17, 'trống'),
(55, 17, 'đã đặt'),
(56, 17, 'trống'),
(57, 17, 'đã đặt'),
(58, 17, 'trống'),
(59, 17, 'đã đặt'),
(60, 17, 'trống'),
(61, 17, 'đã đặt'),
(62, 17, 'trống'),
(63, 17, 'đã đặt'),
(64, 17, 'trống'),
(65, 17, 'đã đặt'),
(66, 17, 'trống'),
(67, 17, 'đã đặt'),
(68, 17, 'trống'),
(69, 17, 'đã đặt'),
(70, 17, 'trống'),
(71, 17, 'đã đặt'),
(72, 17, 'trống'),
(73, 17, 'đã đặt'),
(74, 17, 'trống'),
(75, 17, 'trống'),
(76, 17, 'trống'),
(107, 17, 'đã đặt'),
(108, 17, 'trống'),
(109, 17, 'đã đặt'),
(110, 17, 'trống'),
(111, 17, 'đã đặt'),
(112, 17, 'trống'),
(113, 17, 'đã đặt'),
(114, 17, 'trống'),
(1, 18, 'đã đặt'),
(2, 18, 'trống'),
(3, 18, 'đã đặt'),
(4, 18, 'trống'),
(5, 18, 'đã đặt'),
(6, 18, 'trống'),
(7, 18, 'đã đặt'),
(8, 18, 'trống'),
(9, 18, 'đã đặt'),
(10, 18, 'trống'),
(11, 18, 'đã đặt'),
(12, 18, 'trống'),
(13, 18, 'đã đặt'),
(14, 18, 'trống'),
(15, 18, 'đã đặt'),
(16, 18, 'trống'),
(17, 18, 'đã đặt'),
(18, 18, 'trống'),
(19, 18, 'đã đặt'),
(20, 18, 'trống'),
(21, 18, 'đã đặt'),
(22, 18, 'trống'),
(23, 18, 'đã đặt'),
(24, 18, 'trống'),
(25, 18, 'trống'),
(26, 18, 'trống'),
(27, 18, 'trống'),
(28, 18, 'trống'),
(29, 18, 'trống'),
(30, 18, 'trống'),
(31, 18, 'trống'),
(32, 18, 'trống'),
(33, 18, 'trống'),
(34, 18, 'trống'),
(35, 18, 'trống'),
(36, 18, 'trống'),
(37, 18, 'trống'),
(38, 18, 'trống'),
(39, 18, 'trống'),
(40, 18, 'trống'),
(41, 18, 'trống'),
(42, 18, 'trống'),
(43, 18, 'trống'),
(44, 18, 'trống'),
(45, 18, 'trống'),
(46, 18, 'trống'),
(47, 18, 'trống'),
(48, 18, 'trống'),
(49, 18, 'trống'),
(50, 18, 'trống'),
(51, 18, 'trống'),
(52, 18, 'trống'),
(1, 19, 'đã đặt'),
(2, 19, 'trống'),
(3, 19, 'đã đặt'),
(4, 19, 'trống'),
(5, 19, 'đã đặt'),
(6, 19, 'trống'),
(7, 19, 'đã đặt'),
(8, 19, 'trống'),
(9, 19, 'đã đặt'),
(10, 19, 'trống'),
(11, 19, 'đã đặt'),
(12, 19, 'trống'),
(13, 19, 'đã đặt'),
(14, 19, 'trống'),
(15, 19, 'đã đặt'),
(16, 19, 'trống'),
(17, 19, 'đã đặt'),
(18, 19, 'trống'),
(19, 19, 'đã đặt'),
(20, 19, 'trống'),
(21, 19, 'đã đặt'),
(22, 19, 'trống'),
(23, 19, 'đã đặt'),
(24, 19, 'trống'),
(25, 19, 'trống'),
(26, 19, 'trống'),
(27, 19, 'trống'),
(28, 19, 'trống'),
(29, 19, 'trống'),
(30, 19, 'trống'),
(31, 19, 'trống'),
(32, 19, 'trống'),
(33, 19, 'trống'),
(34, 19, 'trống'),
(35, 19, 'trống'),
(36, 19, 'trống'),
(37, 19, 'trống'),
(38, 19, 'trống'),
(39, 19, 'trống'),
(40, 19, 'trống'),
(41, 19, 'trống'),
(42, 19, 'trống'),
(43, 19, 'trống'),
(44, 19, 'trống'),
(45, 19, 'trống'),
(46, 19, 'trống'),
(47, 19, 'trống'),
(48, 19, 'trống'),
(49, 19, 'trống'),
(50, 19, 'trống'),
(51, 19, 'trống'),
(52, 19, 'trống'),
(53, 20, 'đã đặt'),
(54, 20, 'trống'),
(55, 20, 'đã đặt'),
(56, 20, 'trống'),
(57, 20, 'đã đặt'),
(58, 20, 'trống'),
(59, 20, 'đã đặt'),
(60, 20, 'trống'),
(61, 20, 'đã đặt'),
(62, 20, 'trống'),
(63, 20, 'đã đặt'),
(64, 20, 'trống'),
(65, 20, 'đã đặt'),
(66, 20, 'trống'),
(67, 20, 'đã đặt'),
(68, 20, 'trống'),
(69, 20, 'đã đặt'),
(70, 20, 'trống'),
(71, 20, 'đã đặt'),
(72, 20, 'trống'),
(73, 20, 'trống'),
(74, 20, 'trống'),
(75, 20, 'trống'),
(76, 20, 'trống'),
(107, 20, 'đã đặt'),
(108, 20, 'trống'),
(109, 20, 'đã đặt'),
(110, 20, 'trống'),
(111, 20, 'đã đặt'),
(112, 20, 'trống'),
(113, 20, 'đã đặt'),
(114, 20, 'trống'),
(77, 21, 'đã đặt'),
(78, 21, 'trống'),
(79, 21, 'đã đặt'),
(80, 21, 'trống'),
(81, 21, 'đã đặt'),
(82, 21, 'trống'),
(83, 21, 'đã đặt'),
(84, 21, 'trống'),
(85, 21, 'đã đặt'),
(86, 21, 'trống'),
(87, 21, 'đã đặt'),
(88, 21, 'trống'),
(89, 21, 'đã đặt'),
(90, 21, 'trống'),
(91, 21, 'trống'),
(92, 21, 'trống'),
(93, 21, 'trống'),
(94, 21, 'trống'),
(95, 21, 'trống'),
(96, 21, 'trống'),
(97, 21, 'trống'),
(98, 21, 'trống'),
(99, 21, 'trống'),
(100, 21, 'trống'),
(101, 21, 'trống'),
(102, 21, 'trống'),
(103, 21, 'trống'),
(104, 21, 'trống'),
(105, 21, 'trống'),
(106, 21, 'trống'),
(1, 22, 'đã đặt'),
(2, 22, 'trống'),
(3, 22, 'đã đặt'),
(4, 22, 'trống'),
(5, 22, 'đã đặt'),
(6, 22, 'trống'),
(7, 22, 'đã đặt'),
(8, 22, 'trống'),
(9, 22, 'đã đặt'),
(10, 22, 'trống'),
(11, 22, 'đã đặt'),
(12, 22, 'trống'),
(13, 22, 'đã đặt'),
(14, 22, 'trống'),
(15, 22, 'đã đặt'),
(16, 22, 'trống'),
(17, 22, 'đã đặt'),
(18, 22, 'trống'),
(19, 22, 'đã đặt'),
(20, 22, 'trống'),
(21, 22, 'đã đặt'),
(22, 22, 'trống'),
(23, 22, 'đã đặt'),
(24, 22, 'trống'),
(25, 22, 'đã đặt'),
(26, 22, 'trống'),
(27, 22, 'đã đặt'),
(28, 22, 'trống'),
(29, 22, 'đã đặt'),
(30, 22, 'trống'),
(31, 22, 'đã đặt'),
(32, 22, 'trống'),
(33, 22, 'đã đặt'),
(34, 22, 'trống'),
(35, 22, 'đã đặt'),
(36, 22, 'trống'),
(37, 22, 'đã đặt'),
(38, 22, 'trống'),
(39, 22, 'đã đặt'),
(40, 22, 'trống'),
(41, 22, 'đã đặt'),
(42, 22, 'trống'),
(43, 22, 'đã đặt'),
(44, 22, 'trống'),
(45, 22, 'đã đặt'),
(46, 22, 'trống'),
(47, 22, 'đã đặt'),
(48, 22, 'trống'),
(49, 22, 'đã đặt'),
(50, 22, 'trống'),
(51, 22, 'đã đặt'),
(52, 22, 'trống'),
(53, 23, 'đã đặt'),
(54, 23, 'trống'),
(55, 23, 'đã đặt'),
(56, 23, 'trống'),
(57, 23, 'đã đặt'),
(58, 23, 'trống'),
(59, 23, 'đã đặt'),
(60, 23, 'trống'),
(61, 23, 'đã đặt'),
(62, 23, 'trống'),
(63, 23, 'đã đặt'),
(64, 23, 'trống'),
(65, 23, 'đã đặt'),
(66, 23, 'trống'),
(67, 23, 'đã đặt'),
(68, 23, 'trống'),
(69, 23, 'trống'),
(70, 23, 'trống'),
(71, 23, 'trống'),
(72, 23, 'trống'),
(73, 23, 'trống'),
(74, 23, 'trống'),
(75, 23, 'trống'),
(76, 23, 'trống'),
(107, 23, 'đã đặt'),
(108, 23, 'trống'),
(109, 23, 'đã đặt'),
(110, 23, 'trống'),
(111, 23, 'đã đặt'),
(112, 23, 'trống'),
(113, 23, 'đã đặt'),
(114, 23, 'trống'),
(1, 24, 'đã đặt'),
(2, 24, 'trống'),
(3, 24, 'đã đặt'),
(4, 24, 'trống'),
(5, 24, 'đã đặt'),
(6, 24, 'trống'),
(7, 24, 'đã đặt'),
(8, 24, 'trống'),
(9, 24, 'đã đặt'),
(10, 24, 'trống'),
(11, 24, 'đã đặt'),
(12, 24, 'trống'),
(13, 24, 'đã đặt'),
(14, 24, 'trống'),
(15, 24, 'đã đặt'),
(16, 24, 'trống'),
(17, 24, 'đã đặt'),
(18, 24, 'trống'),
(19, 24, 'đã đặt'),
(20, 24, 'trống'),
(21, 24, 'đã đặt'),
(22, 24, 'trống'),
(23, 24, 'đã đặt'),
(24, 24, 'trống'),
(25, 24, 'trống'),
(26, 24, 'trống'),
(27, 24, 'trống'),
(28, 24, 'trống'),
(29, 24, 'trống'),
(30, 24, 'trống'),
(31, 24, 'trống'),
(32, 24, 'trống'),
(33, 24, 'trống'),
(34, 24, 'trống'),
(35, 24, 'trống'),
(36, 24, 'trống'),
(37, 24, 'trống'),
(38, 24, 'trống'),
(39, 24, 'trống'),
(40, 24, 'trống'),
(41, 24, 'trống'),
(42, 24, 'trống'),
(43, 24, 'trống'),
(44, 24, 'trống'),
(45, 24, 'trống'),
(46, 24, 'trống'),
(47, 24, 'trống'),
(48, 24, 'trống'),
(49, 24, 'trống'),
(50, 24, 'trống'),
(51, 24, 'trống'),
(52, 24, 'trống'),
(1, 25, 'đã đặt'),
(2, 25, 'trống'),
(3, 25, 'đã đặt'),
(4, 25, 'trống'),
(5, 25, 'đã đặt'),
(6, 25, 'trống'),
(7, 25, 'đã đặt'),
(8, 25, 'trống'),
(9, 25, 'đã đặt'),
(10, 25, 'trống'),
(11, 25, 'đã đặt'),
(12, 25, 'trống'),
(13, 25, 'đã đặt'),
(14, 25, 'trống'),
(15, 25, 'đã đặt'),
(16, 25, 'trống'),
(17, 25, 'đã đặt'),
(18, 25, 'trống'),
(19, 25, 'đã đặt'),
(20, 25, 'trống'),
(21, 25, 'đã đặt'),
(22, 25, 'trống'),
(23, 25, 'đã đặt'),
(24, 25, 'trống'),
(25, 25, 'đã đặt'),
(26, 25, 'trống'),
(27, 25, 'trống'),
(28, 25, 'trống'),
(29, 25, 'trống'),
(30, 25, 'trống'),
(31, 25, 'trống'),
(32, 25, 'trống'),
(33, 25, 'trống'),
(34, 25, 'trống'),
(35, 25, 'trống'),
(36, 25, 'trống'),
(37, 25, 'trống'),
(38, 25, 'trống'),
(39, 25, 'trống'),
(40, 25, 'trống'),
(41, 25, 'trống'),
(42, 25, 'trống'),
(43, 25, 'trống'),
(44, 25, 'trống'),
(45, 25, 'trống'),
(46, 25, 'trống'),
(47, 25, 'trống'),
(48, 25, 'trống'),
(49, 25, 'trống'),
(50, 25, 'trống'),
(51, 25, 'trống'),
(52, 25, 'trống'),
(53, 26, 'đã đặt'),
(54, 26, 'trống'),
(55, 26, 'đã đặt'),
(56, 26, 'trống'),
(57, 26, 'đã đặt'),
(58, 26, 'trống'),
(59, 26, 'đã đặt'),
(60, 26, 'trống'),
(61, 26, 'đã đặt'),
(62, 26, 'trống'),
(63, 26, 'đã đặt'),
(64, 26, 'trống'),
(65, 26, 'đã đặt'),
(66, 26, 'trống'),
(67, 26, 'đã đặt'),
(68, 26, 'trống'),
(69, 26, 'đã đặt'),
(70, 26, 'trống'),
(71, 26, 'trống'),
(72, 26, 'trống'),
(73, 26, 'trống'),
(74, 26, 'trống'),
(75, 26, 'trống'),
(76, 26, 'trống'),
(107, 26, 'đã đặt'),
(108, 26, 'trống'),
(109, 26, 'đã đặt'),
(110, 26, 'trống'),
(111, 26, 'đã đặt'),
(112, 26, 'trống'),
(113, 26, 'đã đặt'),
(114, 26, 'trống'),
(77, 27, 'đã đặt'),
(78, 27, 'trống'),
(79, 27, 'đã đặt'),
(80, 27, 'trống'),
(81, 27, 'đã đặt'),
(82, 27, 'trống'),
(83, 27, 'đã đặt'),
(84, 27, 'trống'),
(85, 27, 'đã đặt'),
(86, 27, 'trống'),
(87, 27, 'đã đặt'),
(88, 27, 'trống'),
(89, 27, 'đã đặt'),
(90, 27, 'trống'),
(91, 27, 'đã đặt'),
(92, 27, 'trống'),
(93, 27, 'trống'),
(94, 27, 'trống'),
(95, 27, 'trống'),
(96, 27, 'trống'),
(97, 27, 'trống'),
(98, 27, 'trống'),
(99, 27, 'trống'),
(100, 27, 'trống'),
(101, 27, 'trống'),
(102, 27, 'trống'),
(103, 27, 'trống'),
(104, 27, 'trống'),
(105, 27, 'trống'),
(106, 27, 'trống'),
(1, 28, 'đã đặt'),
(2, 28, 'trống'),
(3, 28, 'đã đặt'),
(4, 28, 'trống'),
(5, 28, 'đã đặt'),
(6, 28, 'trống'),
(7, 28, 'đã đặt'),
(8, 28, 'trống'),
(9, 28, 'đã đặt'),
(10, 28, 'trống'),
(11, 28, 'đã đặt'),
(12, 28, 'trống'),
(13, 28, 'đã đặt'),
(14, 28, 'trống'),
(15, 28, 'đã đặt'),
(16, 28, 'trống'),
(17, 28, 'đã đặt'),
(18, 28, 'trống'),
(19, 28, 'đã đặt'),
(20, 28, 'trống'),
(21, 28, 'đã đặt'),
(22, 28, 'trống'),
(23, 28, 'trống'),
(24, 28, 'trống'),
(25, 28, 'trống'),
(26, 28, 'trống'),
(27, 28, 'trống'),
(28, 28, 'trống'),
(29, 28, 'trống'),
(30, 28, 'trống'),
(31, 28, 'trống'),
(32, 28, 'trống'),
(33, 28, 'trống'),
(34, 28, 'trống'),
(35, 28, 'trống'),
(36, 28, 'trống'),
(37, 28, 'trống'),
(38, 28, 'trống'),
(39, 28, 'trống'),
(40, 28, 'trống'),
(41, 28, 'trống'),
(42, 28, 'trống'),
(43, 28, 'trống'),
(44, 28, 'trống'),
(45, 28, 'trống'),
(46, 28, ''),
(47, 28, 'trống'),
(48, 28, 'trống'),
(49, 28, 'trống'),
(50, 28, 'trống'),
(51, 28, 'trống'),
(52, 28, 'trống'),
(53, 29, 'đã đặt'),
(54, 29, 'trống'),
(55, 29, 'đã đặt'),
(56, 29, 'trống'),
(57, 29, 'đã đặt'),
(58, 29, 'trống'),
(59, 29, 'đã đặt'),
(60, 29, 'trống'),
(61, 29, 'đã đặt'),
(62, 29, 'trống'),
(63, 29, 'đã đặt'),
(64, 29, 'trống'),
(65, 29, 'đã đặt'),
(66, 29, 'trống'),
(67, 29, 'đã đặt'),
(68, 29, 'trống'),
(69, 29, 'đã đặt'),
(70, 29, 'trống'),
(71, 29, 'đã đặt'),
(72, 29, 'trống'),
(73, 29, 'đã đặt'),
(74, 29, 'trống'),
(75, 29, 'trống'),
(76, 29, 'trống'),
(107, 29, 'đã đặt'),
(108, 29, 'trống'),
(109, 29, 'đã đặt'),
(110, 29, 'trống'),
(111, 29, 'đã đặt'),
(112, 29, 'trống'),
(113, 29, 'đã đặt'),
(114, 29, 'trống'),
(1, 30, 'đã đặt'),
(2, 30, 'trống'),
(3, 30, 'đã đặt'),
(4, 30, 'trống'),
(5, 30, 'đã đặt'),
(6, 30, 'trống'),
(7, 30, 'đã đặt'),
(8, 30, 'trống'),
(9, 30, 'đã đặt'),
(10, 30, 'trống'),
(11, 30, 'đã đặt'),
(12, 30, 'trống'),
(13, 30, 'đã đặt'),
(14, 30, 'trống'),
(15, 30, 'đã đặt'),
(16, 30, 'trống'),
(17, 30, 'đã đặt'),
(18, 30, 'trống'),
(19, 30, 'đã đặt'),
(20, 30, 'trống'),
(21, 30, 'đã đặt'),
(22, 30, 'trống'),
(23, 30, 'đã đặt'),
(24, 30, 'trống'),
(25, 30, 'trống'),
(26, 30, 'trống'),
(27, 30, 'trống'),
(28, 30, 'trống'),
(29, 30, 'trống'),
(30, 30, 'trống'),
(31, 30, 'trống'),
(32, 30, 'trống'),
(33, 30, 'trống'),
(34, 30, 'trống'),
(35, 30, 'trống'),
(36, 30, 'trống'),
(37, 30, 'trống'),
(38, 30, 'trống'),
(39, 30, 'trống'),
(40, 30, 'trống'),
(41, 30, 'trống'),
(42, 30, 'trống'),
(43, 30, 'trống'),
(44, 30, 'trống'),
(45, 30, 'trống'),
(46, 30, 'trống'),
(47, 30, 'trống'),
(48, 30, 'trống'),
(49, 30, 'trống'),
(50, 30, 'trống'),
(51, 30, 'trống'),
(52, 30, 'trống'),
(1, 31, 'đã đặt'),
(2, 31, 'trống'),
(3, 31, 'đã đặt'),
(4, 31, 'trống'),
(5, 31, 'đã đặt'),
(6, 31, 'trống'),
(7, 31, 'đã đặt'),
(8, 31, 'trống'),
(9, 31, 'đã đặt'),
(10, 31, 'trống'),
(11, 31, 'đã đặt'),
(12, 31, 'trống'),
(13, 31, 'đã đặt'),
(14, 31, 'trống'),
(15, 31, 'đã đặt'),
(16, 31, 'trống'),
(17, 31, 'đã đặt'),
(18, 31, 'trống'),
(19, 31, 'đã đặt'),
(20, 31, 'trống'),
(21, 31, 'đã đặt'),
(22, 31, 'trống'),
(23, 31, 'đã đặt'),
(24, 31, 'trống'),
(25, 31, 'trống'),
(26, 31, 'trống'),
(27, 31, 'trống'),
(28, 31, 'trống'),
(29, 31, 'trống'),
(30, 31, 'trống'),
(31, 31, 'trống'),
(32, 31, 'trống'),
(33, 31, 'trống'),
(34, 31, 'trống'),
(35, 31, 'trống'),
(36, 31, 'trống'),
(37, 31, 'trống'),
(38, 31, 'trống'),
(39, 31, 'trống'),
(40, 31, 'trống'),
(41, 31, 'trống'),
(42, 31, 'trống'),
(43, 31, 'trống'),
(44, 31, 'trống'),
(45, 31, 'trống'),
(46, 31, 'trống'),
(47, 31, 'trống'),
(48, 31, 'trống'),
(49, 31, 'trống'),
(50, 31, 'trống'),
(51, 31, 'trống'),
(52, 31, 'trống'),
(53, 32, 'đã đặt'),
(54, 32, 'trống'),
(55, 32, 'đã đặt'),
(56, 32, 'trống'),
(57, 32, 'đã đặt'),
(58, 32, 'trống'),
(59, 32, 'đã đặt'),
(60, 32, 'trống'),
(61, 32, 'đã đặt'),
(62, 32, 'trống'),
(63, 32, 'đã đặt'),
(64, 32, 'trống'),
(65, 32, 'đã đặt'),
(66, 32, 'trống'),
(67, 32, 'đã đặt'),
(68, 32, 'trống'),
(69, 32, 'đã đặt'),
(70, 32, 'trống'),
(71, 32, 'đã đặt'),
(72, 32, 'trống'),
(73, 32, 'trống'),
(74, 32, 'trống'),
(75, 32, 'trống'),
(76, 32, 'trống'),
(107, 32, 'đã đặt'),
(108, 32, 'trống'),
(109, 32, 'đã đặt'),
(110, 32, 'trống'),
(111, 32, 'đã đặt'),
(112, 32, 'trống'),
(113, 32, 'đã đặt'),
(114, 32, 'trống'),
(77, 33, 'đã đặt'),
(78, 33, 'trống'),
(79, 33, 'đã đặt'),
(80, 33, 'trống'),
(81, 33, 'đã đặt'),
(82, 33, 'trống'),
(83, 33, 'đã đặt'),
(84, 33, 'trống'),
(85, 33, 'đã đặt'),
(86, 33, 'trống'),
(87, 33, 'đã đặt'),
(88, 33, 'trống'),
(89, 33, 'đã đặt'),
(90, 33, 'trống'),
(91, 33, 'trống'),
(92, 33, 'trống'),
(93, 33, 'trống'),
(94, 33, 'trống'),
(95, 33, 'trống'),
(96, 33, 'trống'),
(97, 33, 'trống'),
(98, 33, 'trống'),
(99, 33, 'trống'),
(100, 33, 'trống'),
(101, 33, 'trống'),
(102, 33, 'trống'),
(103, 33, 'trống'),
(104, 33, 'trống'),
(105, 33, 'trống'),
(106, 33, 'trống'),
(1, 34, 'đã đặt'),
(2, 34, 'trống'),
(3, 34, 'đã đặt'),
(4, 34, 'trống'),
(5, 34, 'đã đặt'),
(6, 34, 'trống'),
(7, 34, 'đã đặt'),
(8, 34, 'trống'),
(9, 34, 'đã đặt'),
(10, 34, 'trống'),
(11, 34, 'đã đặt'),
(12, 34, 'trống'),
(13, 34, 'đã đặt'),
(14, 34, 'trống'),
(15, 34, 'đã đặt'),
(16, 34, 'trống'),
(17, 34, 'đã đặt'),
(18, 34, 'trống'),
(19, 34, 'đã đặt'),
(20, 34, 'trống'),
(21, 34, 'đã đặt'),
(22, 34, 'trống'),
(23, 34, 'đã đặt'),
(24, 34, 'trống'),
(25, 34, 'đã đặt'),
(26, 34, 'trống'),
(27, 34, 'đã đặt'),
(28, 34, 'trống'),
(29, 34, 'đã đặt'),
(30, 34, 'trống'),
(31, 34, 'đã đặt'),
(32, 34, 'trống'),
(33, 34, 'đã đặt'),
(34, 34, 'trống'),
(35, 34, 'đã đặt'),
(36, 34, 'trống'),
(37, 34, 'đã đặt'),
(38, 34, 'trống'),
(39, 34, 'đã đặt'),
(40, 34, 'trống'),
(41, 34, 'đã đặt'),
(42, 34, 'trống'),
(43, 34, 'đã đặt'),
(44, 34, 'trống'),
(45, 34, 'đã đặt'),
(46, 34, 'trống'),
(47, 34, 'đã đặt'),
(48, 34, 'trống'),
(49, 34, 'đã đặt'),
(50, 34, 'trống'),
(51, 34, 'đã đặt'),
(52, 34, 'trống'),
(53, 35, 'đã đặt'),
(54, 35, 'trống'),
(55, 35, 'đã đặt'),
(56, 35, 'trống'),
(57, 35, 'đã đặt'),
(58, 35, 'trống'),
(59, 35, 'đã đặt'),
(60, 35, 'trống'),
(61, 35, 'đã đặt'),
(62, 35, 'trống'),
(63, 35, 'đã đặt'),
(64, 35, 'trống'),
(65, 35, 'đã đặt'),
(66, 35, 'trống'),
(67, 35, 'đã đặt'),
(68, 35, 'trống'),
(69, 35, 'trống'),
(70, 35, 'trống'),
(71, 35, 'trống'),
(72, 35, 'trống'),
(73, 35, 'trống'),
(74, 35, 'trống'),
(75, 35, 'trống'),
(76, 35, 'trống'),
(107, 35, 'đã đặt'),
(108, 35, 'trống'),
(109, 35, 'đã đặt'),
(110, 35, 'trống'),
(111, 35, 'đã đặt'),
(112, 35, 'trống'),
(113, 35, 'đã đặt'),
(114, 35, 'trống'),
(1, 36, 'đã đặt'),
(2, 36, 'trống'),
(3, 36, 'đã đặt'),
(4, 36, 'trống'),
(5, 36, 'đã đặt'),
(6, 36, 'trống'),
(7, 36, 'đã đặt'),
(8, 36, 'trống'),
(9, 36, 'đã đặt'),
(10, 36, 'trống'),
(11, 36, 'đã đặt'),
(12, 36, 'trống'),
(13, 36, 'đã đặt'),
(14, 36, 'trống'),
(15, 36, 'đã đặt'),
(16, 36, 'trống'),
(17, 36, 'đã đặt'),
(18, 36, 'trống'),
(19, 36, 'đã đặt'),
(20, 36, 'trống'),
(21, 36, 'đã đặt'),
(22, 36, 'trống'),
(23, 36, 'trống'),
(24, 36, 'trống'),
(25, 36, 'trống'),
(26, 36, 'trống'),
(27, 36, 'trống'),
(28, 36, 'trống'),
(29, 36, 'trống'),
(30, 36, 'trống'),
(31, 36, 'trống'),
(32, 36, 'trống'),
(33, 36, 'trống'),
(34, 36, 'trống'),
(35, 36, 'trống'),
(36, 36, 'trống'),
(37, 36, 'trống'),
(38, 36, 'trống'),
(39, 36, 'trống'),
(40, 36, 'trống'),
(41, 36, 'trống'),
(42, 36, 'trống'),
(43, 36, 'trống'),
(44, 36, 'trống'),
(45, 36, 'trống'),
(46, 36, 'trống'),
(47, 36, 'trống'),
(48, 36, 'trống'),
(49, 36, 'trống'),
(50, 36, 'trống'),
(51, 36, 'trống'),
(52, 36, 'trống'),
(1, 37, 'đã đặt'),
(2, 37, 'trống'),
(3, 37, 'đã đặt'),
(4, 37, 'trống'),
(5, 37, 'đã đặt'),
(6, 37, 'trống'),
(7, 37, 'đã đặt'),
(8, 37, 'trống'),
(9, 37, 'đã đặt'),
(10, 37, 'trống'),
(11, 37, 'đã đặt'),
(12, 37, 'trống'),
(13, 37, 'đã đặt'),
(14, 37, 'trống'),
(15, 37, 'đã đặt'),
(16, 37, 'trống'),
(17, 37, 'đã đặt'),
(18, 37, 'trống'),
(19, 37, 'đã đặt'),
(20, 37, 'trống'),
(21, 37, 'đã đặt'),
(22, 37, 'trống'),
(23, 37, 'đã đặt'),
(24, 37, 'trống'),
(25, 37, 'trống'),
(26, 37, 'trống'),
(27, 37, 'trống'),
(28, 37, 'trống'),
(29, 37, 'trống'),
(30, 37, 'trống'),
(31, 37, 'trống'),
(32, 37, 'trống'),
(33, 37, 'trống'),
(34, 37, 'trống'),
(35, 37, 'trống'),
(36, 37, 'trống'),
(37, 37, 'trống'),
(38, 37, 'trống'),
(39, 37, 'trống'),
(40, 37, 'trống'),
(41, 37, 'trống'),
(42, 37, 'trống'),
(43, 37, 'trống'),
(44, 37, 'trống'),
(45, 37, 'trống'),
(46, 37, 'trống'),
(47, 37, 'trống'),
(48, 37, 'trống'),
(49, 37, 'trống'),
(50, 37, 'trống'),
(51, 37, 'trống'),
(52, 37, 'trống'),
(53, 38, 'đã đặt'),
(54, 38, 'trống'),
(55, 38, 'đã đặt'),
(56, 38, 'trống'),
(57, 38, 'đã đặt'),
(58, 38, 'trống'),
(59, 38, 'đã đặt'),
(60, 38, 'trống'),
(61, 38, 'đã đặt'),
(62, 38, 'trống'),
(63, 38, 'đã đặt'),
(64, 38, 'trống'),
(65, 38, 'đã đặt'),
(66, 38, 'trống'),
(67, 38, 'đã đặt'),
(68, 38, 'trống'),
(69, 38, 'đã đặt'),
(70, 38, 'trống'),
(71, 38, 'đã đặt'),
(72, 38, 'trống'),
(73, 38, 'trống'),
(74, 38, 'trống'),
(75, 38, 'trống'),
(76, 38, 'trống'),
(107, 38, 'đã đặt'),
(108, 38, 'trống'),
(109, 38, 'đã đặt'),
(110, 38, 'trống'),
(111, 38, 'đã đặt'),
(112, 38, 'trống'),
(113, 38, 'đã đặt'),
(114, 38, 'trống'),
(77, 39, 'đã đặt'),
(78, 39, 'trống'),
(79, 39, 'đã đặt'),
(80, 39, 'trống'),
(81, 39, 'đã đặt'),
(82, 39, 'trống'),
(83, 39, 'đã đặt'),
(84, 39, 'trống'),
(85, 39, 'đã đặt'),
(86, 39, 'trống'),
(87, 39, 'đã đặt'),
(88, 39, 'trống'),
(89, 39, 'đã đặt'),
(90, 39, 'trống'),
(91, 39, 'đã đặt'),
(92, 39, 'trống'),
(93, 39, 'trống'),
(94, 39, 'trống'),
(95, 39, 'trống'),
(96, 39, 'trống'),
(97, 39, 'trống'),
(98, 39, 'trống'),
(99, 39, 'trống'),
(100, 39, 'trống'),
(101, 39, 'trống'),
(102, 39, 'trống'),
(103, 39, 'trống'),
(104, 39, 'trống'),
(105, 39, 'trống'),
(106, 39, 'trống'),
(1, 40, 'đã đặt'),
(2, 40, 'trống'),
(3, 40, 'đã đặt'),
(4, 40, 'trống'),
(5, 40, 'đã đặt'),
(6, 40, 'trống'),
(7, 40, 'đã đặt'),
(8, 40, 'trống'),
(9, 40, 'đã đặt'),
(10, 40, 'trống'),
(11, 40, 'đã đặt'),
(12, 40, 'trống'),
(13, 40, 'đã đặt'),
(14, 40, 'trống'),
(15, 40, 'đã đặt'),
(16, 40, 'trống'),
(17, 40, 'đã đặt'),
(18, 40, 'trống'),
(19, 40, 'đã đặt'),
(20, 40, 'trống'),
(21, 40, 'đã đặt'),
(22, 40, 'trống'),
(23, 40, 'đã đặt'),
(24, 40, 'trống'),
(25, 40, 'đã đặt'),
(26, 40, 'trống'),
(27, 40, 'đã đặt'),
(28, 40, 'trống'),
(29, 40, 'đã đặt'),
(30, 40, 'trống'),
(31, 40, 'đã đặt'),
(32, 40, 'trống'),
(33, 40, 'đã đặt'),
(34, 40, 'trống'),
(35, 40, 'đã đặt'),
(36, 40, 'trống'),
(37, 40, 'đã đặt'),
(38, 40, 'trống'),
(39, 40, 'đã đặt'),
(40, 40, 'trống'),
(41, 40, 'đã đặt'),
(42, 40, 'trống'),
(43, 40, 'đã đặt'),
(44, 40, 'trống'),
(45, 40, 'đã đặt'),
(46, 40, 'trống'),
(47, 40, 'đã đặt'),
(48, 40, 'trống'),
(49, 40, 'đã đặt'),
(50, 40, 'trống'),
(51, 40, 'đã đặt'),
(52, 40, 'trống'),
(53, 41, 'đã đặt'),
(54, 41, 'trống'),
(55, 41, 'đã đặt'),
(56, 41, 'trống'),
(57, 41, 'đã đặt'),
(58, 41, 'trống'),
(59, 41, 'đã đặt'),
(60, 41, 'trống'),
(61, 41, 'đã đặt'),
(62, 41, 'trống'),
(63, 41, 'đã đặt'),
(64, 41, 'trống'),
(65, 41, 'đã đặt'),
(66, 41, 'trống'),
(67, 41, 'đã đặt'),
(68, 41, 'trống'),
(69, 41, 'trống'),
(70, 41, 'trống'),
(71, 41, 'trống'),
(72, 41, 'trống'),
(73, 41, 'trống'),
(74, 41, 'trống'),
(75, 41, 'trống'),
(76, 41, 'trống'),
(107, 41, 'đã đặt'),
(108, 41, 'trống'),
(109, 41, 'đã đặt'),
(110, 41, 'trống'),
(111, 41, 'đã đặt'),
(112, 41, 'trống'),
(113, 41, 'đã đặt'),
(114, 41, 'trống'),
(1, 42, 'đã đặt'),
(2, 42, 'trống'),
(3, 42, 'đã đặt'),
(4, 42, 'trống'),
(5, 42, 'đã đặt'),
(6, 42, 'trống'),
(7, 42, 'đã đặt'),
(8, 42, 'trống'),
(9, 42, 'đã đặt'),
(10, 42, 'trống'),
(11, 42, 'đã đặt'),
(12, 42, 'trống'),
(13, 42, 'đã đặt'),
(14, 42, 'trống'),
(15, 42, 'đã đặt'),
(16, 42, 'trống'),
(17, 42, 'đã đặt'),
(18, 42, 'trống'),
(19, 42, 'đã đặt'),
(20, 42, 'trống'),
(21, 42, 'đã đặt'),
(22, 42, 'trống'),
(23, 42, 'đã đặt'),
(24, 42, 'trống'),
(25, 42, 'trống'),
(26, 42, 'trống'),
(27, 42, 'trống'),
(28, 42, 'trống'),
(29, 42, 'trống'),
(30, 42, 'trống'),
(31, 42, 'trống'),
(32, 42, 'trống'),
(33, 42, 'trống'),
(34, 42, 'trống'),
(35, 42, 'trống'),
(36, 42, 'trống'),
(37, 42, 'trống'),
(38, 42, 'trống'),
(39, 42, 'trống'),
(40, 42, 'trống'),
(41, 42, 'trống'),
(42, 42, 'trống'),
(43, 42, 'trống'),
(44, 42, 'trống'),
(45, 42, 'trống'),
(46, 42, 'trống'),
(47, 42, 'trống'),
(48, 42, 'trống'),
(49, 42, 'trống'),
(50, 42, 'trống'),
(51, 42, 'trống'),
(52, 42, 'trống'),
(1, 43, 'đã đặt'),
(2, 43, 'trống'),
(3, 43, 'đã đặt'),
(4, 43, 'trống'),
(5, 43, 'đã đặt'),
(6, 43, 'trống'),
(7, 43, 'đã đặt'),
(8, 43, 'trống'),
(9, 43, 'đã đặt'),
(10, 43, 'trống'),
(11, 43, 'đã đặt'),
(12, 43, 'trống'),
(13, 43, 'đã đặt'),
(14, 43, 'trống'),
(15, 43, 'đã đặt'),
(16, 43, 'trống'),
(17, 43, 'đã đặt'),
(18, 43, 'trống'),
(19, 43, 'đã đặt'),
(20, 43, 'trống'),
(21, 43, 'đã đặt'),
(22, 43, 'trống'),
(23, 43, 'đã đặt'),
(24, 43, 'trống'),
(25, 43, 'đã đặt'),
(26, 43, 'trống'),
(27, 43, 'trống'),
(28, 43, 'trống'),
(29, 43, 'trống'),
(30, 43, 'trống'),
(31, 43, 'trống'),
(32, 43, 'trống'),
(33, 43, 'trống'),
(34, 43, 'trống'),
(35, 43, 'trống'),
(36, 43, 'trống'),
(37, 43, 'trống'),
(38, 43, 'trống'),
(39, 43, 'trống'),
(40, 43, 'trống'),
(41, 43, 'trống'),
(42, 43, 'trống'),
(43, 43, 'trống'),
(44, 43, 'trống'),
(45, 43, 'trống'),
(46, 43, 'trống'),
(47, 43, 'trống'),
(48, 43, 'trống'),
(49, 43, 'trống'),
(50, 43, 'trống'),
(51, 43, 'trống'),
(52, 43, 'trống'),
(53, 44, 'đã đặt'),
(54, 44, 'trống'),
(55, 44, 'đã đặt'),
(56, 44, 'trống'),
(57, 44, 'đã đặt'),
(58, 44, 'trống'),
(59, 44, 'đã đặt'),
(60, 44, 'trống'),
(61, 44, 'đã đặt'),
(62, 44, 'trống'),
(63, 44, 'đã đặt'),
(64, 44, 'trống'),
(65, 44, 'đã đặt'),
(66, 44, 'trống'),
(67, 44, 'đã đặt'),
(68, 44, 'trống'),
(69, 44, 'đã đặt'),
(70, 44, 'trống'),
(71, 44, 'trống'),
(72, 44, 'trống'),
(73, 44, 'trống'),
(74, 44, 'trống'),
(75, 44, 'trống'),
(76, 44, 'trống'),
(107, 44, 'đã đặt'),
(108, 44, 'trống'),
(109, 44, 'đã đặt'),
(110, 44, 'trống'),
(111, 44, 'đã đặt'),
(112, 44, 'trống'),
(113, 44, 'đã đặt'),
(114, 44, 'trống'),
(77, 45, 'đã đặt'),
(78, 45, 'trống'),
(79, 45, 'đã đặt'),
(80, 45, 'trống'),
(81, 45, 'đã đặt'),
(82, 45, 'trống'),
(83, 45, 'đã đặt'),
(84, 45, 'trống'),
(85, 45, 'đã đặt'),
(86, 45, 'trống'),
(87, 45, 'đã đặt'),
(88, 45, 'trống'),
(89, 45, 'đã đặt'),
(90, 45, 'trống'),
(91, 45, 'trống'),
(92, 45, 'trống'),
(93, 45, 'trống'),
(94, 45, 'trống'),
(95, 45, 'trống'),
(96, 45, 'trống'),
(97, 45, 'trống'),
(98, 45, 'trống'),
(99, 45, 'trống'),
(100, 45, 'trống'),
(101, 45, 'trống'),
(102, 45, 'trống'),
(103, 45, 'trống'),
(104, 45, 'trống'),
(105, 45, 'trống'),
(106, 45, 'trống'),
(1, 46, 'đã đặt'),
(2, 46, 'trống'),
(3, 46, 'đã đặt'),
(4, 46, 'trống'),
(5, 46, 'đã đặt'),
(6, 46, 'trống'),
(7, 46, 'đã đặt'),
(8, 46, 'trống'),
(9, 46, 'đã đặt'),
(10, 46, 'trống'),
(11, 46, 'đã đặt'),
(12, 46, 'trống'),
(13, 46, 'đã đặt'),
(14, 46, 'trống'),
(15, 46, 'đã đặt'),
(16, 46, 'trống'),
(17, 46, 'đã đặt'),
(18, 46, 'trống'),
(19, 46, 'đã đặt'),
(20, 46, 'trống'),
(21, 46, 'đã đặt'),
(22, 46, 'trống'),
(23, 46, 'đã đặt'),
(24, 46, 'trống'),
(25, 46, 'đã đặt'),
(26, 46, 'trống'),
(27, 46, 'đã đặt'),
(28, 46, 'trống'),
(29, 46, 'đã đặt'),
(30, 46, 'trống'),
(31, 46, 'đã đặt'),
(32, 46, 'trống'),
(33, 46, 'đã đặt'),
(34, 46, 'trống'),
(35, 46, 'đã đặt'),
(36, 46, 'trống'),
(37, 46, 'đã đặt'),
(38, 46, 'trống'),
(39, 46, 'đã đặt'),
(40, 46, 'trống'),
(41, 46, 'đã đặt'),
(42, 46, 'trống'),
(43, 46, 'đã đặt'),
(44, 46, 'trống'),
(45, 46, 'đã đặt'),
(46, 46, 'trống'),
(47, 46, 'đã đặt'),
(48, 46, 'trống'),
(49, 46, 'đã đặt'),
(50, 46, 'trống'),
(51, 46, 'đã đặt'),
(52, 46, 'trống'),
(53, 47, 'đã đặt'),
(54, 47, 'trống'),
(55, 47, 'đã đặt'),
(56, 47, 'trống'),
(57, 47, 'đã đặt'),
(58, 47, 'trống'),
(59, 47, 'đã đặt'),
(60, 47, 'trống'),
(61, 47, 'đã đặt'),
(62, 47, 'trống'),
(63, 47, 'đã đặt'),
(64, 47, 'trống'),
(65, 47, 'đã đặt'),
(66, 47, 'trống'),
(67, 47, 'đã đặt'),
(68, 47, 'trống'),
(69, 47, 'trống'),
(70, 47, 'trống'),
(71, 47, 'trống'),
(72, 47, 'trống'),
(73, 47, 'trống'),
(74, 47, 'trống'),
(75, 47, 'trống'),
(76, 47, 'trống'),
(107, 47, 'đã đặt'),
(108, 47, 'trống'),
(109, 47, 'đã đặt'),
(110, 47, 'trống'),
(111, 47, 'đã đặt'),
(112, 47, 'trống'),
(113, 47, 'đã đặt'),
(114, 47, 'trống'),
(1, 48, 'đã đặt'),
(2, 48, 'trống'),
(3, 48, 'đã đặt'),
(4, 48, 'trống'),
(5, 48, 'đã đặt'),
(6, 48, 'trống'),
(7, 48, 'đã đặt'),
(8, 48, 'trống'),
(9, 48, 'đã đặt'),
(10, 48, 'trống'),
(11, 48, 'đã đặt'),
(12, 48, 'trống'),
(13, 48, 'đã đặt'),
(14, 48, 'trống'),
(15, 48, 'đã đặt'),
(16, 48, 'trống'),
(17, 48, 'đã đặt'),
(18, 48, 'trống'),
(19, 48, 'đã đặt'),
(20, 48, 'trống'),
(21, 48, 'đã đặt'),
(22, 48, 'trống'),
(23, 48, 'đã đặt'),
(24, 48, 'trống'),
(25, 48, 'trống'),
(26, 48, 'trống'),
(27, 48, 'trống'),
(28, 48, 'trống'),
(29, 48, 'trống'),
(30, 48, 'trống'),
(31, 48, 'trống'),
(32, 48, 'trống'),
(33, 48, 'trống'),
(34, 48, 'trống'),
(35, 48, 'trống'),
(36, 48, 'trống'),
(37, 48, 'trống'),
(38, 48, 'trống'),
(39, 48, 'trống'),
(40, 48, 'trống'),
(41, 48, 'trống'),
(42, 48, 'trống'),
(43, 48, 'trống'),
(44, 48, 'trống'),
(45, 48, 'trống'),
(46, 48, 'trống'),
(47, 48, 'trống'),
(48, 48, 'trống'),
(49, 48, 'trống'),
(50, 48, 'trống'),
(51, 48, 'trống'),
(52, 48, 'trống'),
(1, 49, 'đã đặt'),
(2, 49, 'trống'),
(3, 49, 'đã đặt'),
(4, 49, 'trống'),
(5, 49, 'đã đặt'),
(6, 49, 'trống'),
(7, 49, 'đã đặt'),
(8, 49, 'trống'),
(9, 49, 'đã đặt'),
(10, 49, 'trống'),
(11, 49, 'đã đặt'),
(12, 49, 'trống'),
(13, 49, 'đã đặt'),
(14, 49, 'trống'),
(15, 49, 'đã đặt'),
(16, 49, 'trống'),
(17, 49, 'đã đặt'),
(18, 49, 'trống'),
(19, 49, 'đã đặt'),
(20, 49, 'trống'),
(21, 49, 'đã đặt'),
(22, 49, 'trống'),
(23, 49, 'đã đặt'),
(24, 49, 'trống'),
(25, 49, 'trống'),
(26, 49, 'trống'),
(27, 49, 'trống'),
(28, 49, 'trống'),
(29, 49, 'trống'),
(30, 49, 'trống'),
(31, 49, 'trống'),
(32, 49, 'trống'),
(33, 49, 'trống'),
(34, 49, 'trống'),
(35, 49, 'trống'),
(36, 49, 'trống'),
(37, 49, 'trống'),
(38, 49, 'trống'),
(39, 49, 'trống'),
(40, 49, 'trống'),
(41, 49, 'trống'),
(42, 49, 'trống'),
(43, 49, 'trống'),
(44, 49, 'trống'),
(45, 49, 'trống'),
(46, 49, 'trống'),
(47, 49, 'trống'),
(48, 49, 'trống'),
(49, 49, 'trống'),
(50, 49, 'trống'),
(51, 49, 'trống'),
(52, 49, 'trống'),
(53, 50, 'đã đặt'),
(54, 50, 'trống'),
(55, 50, 'đã đặt'),
(56, 50, 'trống'),
(57, 50, 'đã đặt'),
(58, 50, 'trống'),
(59, 50, 'đã đặt'),
(60, 50, 'trống'),
(61, 50, 'đã đặt'),
(62, 50, 'trống'),
(63, 50, 'đã đặt'),
(64, 50, 'trống'),
(65, 50, 'đã đặt'),
(66, 50, 'trống'),
(67, 50, 'đã đặt'),
(68, 50, 'trống'),
(69, 50, 'đã đặt'),
(70, 50, 'trống'),
(71, 50, 'đã đặt'),
(72, 50, 'trống'),
(73, 50, 'trống'),
(74, 50, 'trống'),
(75, 50, 'trống'),
(76, 50, 'trống'),
(107, 50, 'đã đặt'),
(108, 50, 'trống'),
(109, 50, 'đã đặt'),
(110, 50, 'trống'),
(111, 50, 'đã đặt'),
(112, 50, 'trống'),
(113, 50, 'đã đặt'),
(114, 50, 'trống'),
(77, 51, 'đã đặt'),
(78, 51, 'trống'),
(79, 51, 'đã đặt'),
(80, 51, 'trống'),
(81, 51, 'đã đặt'),
(82, 51, 'trống'),
(83, 51, 'đã đặt'),
(84, 51, 'trống'),
(85, 51, 'đã đặt'),
(86, 51, 'trống'),
(87, 51, 'đã đặt'),
(88, 51, 'trống'),
(89, 51, 'đã đặt'),
(90, 51, 'trống'),
(91, 51, 'trống'),
(92, 51, 'trống'),
(93, 51, 'trống'),
(94, 51, 'trống'),
(95, 51, 'trống'),
(96, 51, 'trống'),
(97, 51, 'trống'),
(98, 51, 'trống'),
(99, 51, 'trống'),
(100, 51, 'trống'),
(101, 51, 'trống'),
(102, 51, 'trống'),
(103, 51, 'trống'),
(104, 51, 'trống'),
(105, 51, 'trống'),
(106, 51, 'trống'),
(1, 52, 'đã đặt'),
(2, 52, 'trống'),
(3, 52, 'đã đặt'),
(4, 52, 'trống'),
(5, 52, 'đã đặt'),
(6, 52, 'trống'),
(7, 52, 'đã đặt'),
(8, 52, 'trống'),
(9, 52, 'đã đặt'),
(10, 52, 'trống'),
(11, 52, 'đã đặt'),
(12, 52, 'trống'),
(13, 52, 'đã đặt'),
(14, 52, 'trống'),
(15, 52, 'đã đặt'),
(16, 52, 'trống'),
(17, 52, 'đã đặt'),
(18, 52, 'trống'),
(19, 52, 'đã đặt'),
(20, 52, 'trống'),
(21, 52, 'đã đặt'),
(22, 52, 'trống'),
(23, 52, 'đã đặt'),
(24, 52, 'trống'),
(25, 52, 'đã đặt'),
(26, 52, 'trống'),
(27, 52, 'đã đặt'),
(28, 52, 'trống'),
(29, 52, 'đã đặt'),
(30, 52, 'trống'),
(31, 52, 'đã đặt'),
(32, 52, 'trống'),
(33, 52, 'đã đặt'),
(34, 52, 'trống'),
(35, 52, 'đã đặt'),
(36, 52, 'trống'),
(37, 52, 'đã đặt'),
(38, 52, 'trống'),
(39, 52, 'đã đặt'),
(40, 52, 'trống'),
(41, 52, 'đã đặt'),
(42, 52, 'trống'),
(43, 52, 'đã đặt'),
(44, 52, 'trống'),
(45, 52, 'đã đặt'),
(46, 52, 'trống'),
(47, 52, 'đã đặt'),
(48, 52, 'trống'),
(49, 52, 'đã đặt'),
(50, 52, 'trống'),
(51, 52, 'đã đặt'),
(52, 52, 'trống'),
(53, 53, 'đã đặt'),
(54, 53, 'trống'),
(55, 53, 'đã đặt'),
(56, 53, 'trống'),
(57, 53, 'đã đặt'),
(58, 53, 'trống'),
(59, 53, 'đã đặt'),
(60, 53, 'trống'),
(61, 53, 'đã đặt'),
(62, 53, 'trống'),
(63, 53, 'đã đặt'),
(64, 53, 'trống'),
(65, 53, 'đã đặt'),
(66, 53, 'trống'),
(67, 53, 'đã đặt'),
(68, 53, 'trống'),
(69, 53, 'trống'),
(70, 53, 'trống'),
(71, 53, 'trống'),
(72, 53, 'trống'),
(73, 53, 'trống'),
(74, 53, 'trống'),
(75, 53, 'trống'),
(76, 53, 'trống'),
(107, 53, 'đã đặt'),
(108, 53, 'trống'),
(109, 53, 'đã đặt'),
(110, 53, 'trống'),
(111, 53, 'đã đặt'),
(112, 53, 'trống'),
(113, 53, 'đã đặt'),
(114, 53, 'trống'),
(1, 54, 'đã đặt'),
(2, 54, 'trống'),
(3, 54, 'đã đặt'),
(4, 54, 'trống'),
(5, 54, 'đã đặt'),
(6, 54, 'trống'),
(7, 54, 'đã đặt'),
(8, 54, 'trống'),
(9, 54, 'đã đặt'),
(10, 54, 'trống'),
(11, 54, 'đã đặt'),
(12, 54, 'trống'),
(13, 54, 'đã đặt'),
(14, 54, 'trống'),
(15, 54, 'đã đặt'),
(16, 54, 'trống'),
(17, 54, 'đã đặt'),
(18, 54, 'trống'),
(19, 54, 'đã đặt'),
(20, 54, 'trống'),
(21, 54, 'đã đặt'),
(22, 54, 'trống'),
(23, 54, 'đã đặt'),
(24, 54, 'trống'),
(25, 54, 'trống'),
(26, 54, 'trống'),
(27, 54, 'trống'),
(28, 54, 'trống'),
(29, 54, 'trống'),
(30, 54, 'trống'),
(31, 54, 'trống'),
(32, 54, 'trống'),
(33, 54, 'trống'),
(34, 54, 'trống'),
(35, 54, 'trống'),
(36, 54, 'trống'),
(37, 54, 'trống'),
(38, 54, 'trống'),
(39, 54, 'trống'),
(40, 54, 'trống'),
(41, 54, 'trống'),
(42, 54, 'trống'),
(43, 54, 'trống'),
(44, 54, 'trống'),
(45, 54, 'trống'),
(46, 54, 'trống'),
(47, 54, 'trống'),
(48, 54, 'trống'),
(49, 54, 'trống'),
(50, 54, 'trống'),
(51, 54, 'trống'),
(52, 54, 'trống'),
(1, 55, 'đã đặt'),
(2, 55, 'trống'),
(3, 55, 'đã đặt'),
(4, 55, 'trống'),
(5, 55, 'đã đặt'),
(6, 55, 'trống'),
(7, 55, 'đã đặt'),
(8, 55, 'trống'),
(9, 55, 'đã đặt'),
(10, 55, 'trống'),
(11, 55, 'đã đặt'),
(12, 55, 'trống'),
(13, 55, 'đã đặt'),
(14, 55, 'trống'),
(15, 55, 'đã đặt'),
(16, 55, 'trống'),
(17, 55, 'đã đặt'),
(18, 55, 'trống'),
(19, 55, 'đã đặt'),
(20, 55, 'trống'),
(21, 55, 'đã đặt'),
(22, 55, 'trống'),
(23, 55, 'đã đặt'),
(24, 55, 'trống'),
(25, 55, 'đã đặt'),
(26, 55, 'trống'),
(27, 55, 'trống'),
(28, 55, 'trống'),
(29, 55, 'trống'),
(30, 55, 'trống'),
(31, 55, 'trống'),
(32, 55, 'trống'),
(33, 55, 'trống'),
(34, 55, 'trống'),
(35, 55, 'trống'),
(36, 55, 'trống'),
(37, 55, 'trống'),
(38, 55, 'trống'),
(39, 55, 'trống'),
(40, 55, 'trống'),
(41, 55, 'trống'),
(42, 55, 'trống'),
(43, 55, 'trống'),
(44, 55, 'trống'),
(45, 55, 'trống'),
(46, 55, 'trống'),
(47, 55, 'trống'),
(48, 55, 'trống'),
(49, 55, 'trống'),
(50, 55, 'trống'),
(51, 55, 'trống'),
(52, 55, 'trống'),
(53, 56, 'đã đặt'),
(54, 56, 'trống'),
(55, 56, 'đã đặt'),
(56, 56, 'trống'),
(57, 56, 'đã đặt'),
(58, 56, 'trống'),
(59, 56, 'đã đặt'),
(60, 56, 'trống'),
(61, 56, 'đã đặt'),
(62, 56, 'trống'),
(63, 56, 'đã đặt'),
(64, 56, 'trống'),
(65, 56, 'đã đặt'),
(66, 56, 'trống'),
(67, 56, 'đã đặt'),
(68, 56, 'trống'),
(69, 56, 'đã đặt'),
(70, 56, 'trống'),
(71, 56, 'trống'),
(72, 56, 'trống'),
(73, 56, 'trống'),
(74, 56, 'trống'),
(75, 56, 'trống'),
(76, 56, 'trống'),
(107, 56, 'đã đặt'),
(108, 56, 'trống'),
(109, 56, 'đã đặt'),
(110, 56, 'trống'),
(111, 56, 'đã đặt'),
(112, 56, 'trống'),
(113, 56, 'đã đặt'),
(114, 56, 'trống'),
(77, 57, 'đã đặt'),
(78, 57, 'trống'),
(79, 57, 'đã đặt'),
(80, 57, 'trống'),
(81, 57, 'đã đặt'),
(82, 57, 'trống'),
(83, 57, 'đã đặt'),
(84, 57, 'trống'),
(85, 57, 'đã đặt'),
(86, 57, 'trống'),
(87, 57, 'đã đặt'),
(88, 57, 'trống'),
(89, 57, 'đã đặt'),
(90, 57, 'trống'),
(91, 57, 'trống'),
(92, 57, 'trống'),
(93, 57, 'trống'),
(94, 57, 'trống'),
(95, 57, 'trống'),
(96, 57, 'trống'),
(97, 57, 'trống'),
(98, 57, 'trống'),
(99, 57, 'trống'),
(100, 57, 'trống'),
(101, 57, 'trống'),
(102, 57, 'trống'),
(103, 57, 'trống'),
(104, 57, 'trống'),
(105, 57, 'trống'),
(106, 57, 'trống'),
(1, 58, 'đã đặt'),
(2, 58, 'trống'),
(3, 58, 'đã đặt'),
(4, 58, 'trống'),
(5, 58, 'đã đặt'),
(6, 58, 'trống'),
(7, 58, 'đã đặt'),
(8, 58, 'trống'),
(9, 58, 'đã đặt'),
(10, 58, 'trống'),
(11, 58, 'đã đặt'),
(12, 58, 'trống'),
(13, 58, 'đã đặt'),
(14, 58, 'trống'),
(15, 58, 'đã đặt'),
(16, 58, 'trống'),
(17, 58, 'đã đặt'),
(18, 58, 'trống'),
(19, 58, 'đã đặt'),
(20, 58, 'trống'),
(21, 58, 'đã đặt'),
(22, 58, 'trống'),
(23, 58, 'đã đặt'),
(24, 58, 'trống'),
(25, 58, 'trống'),
(26, 58, 'trống'),
(27, 58, 'trống'),
(28, 58, 'trống'),
(29, 58, 'trống'),
(30, 58, 'trống'),
(31, 58, 'trống'),
(32, 58, 'trống'),
(33, 58, 'trống'),
(34, 58, 'trống'),
(35, 58, 'trống'),
(36, 58, 'trống'),
(37, 58, 'trống'),
(38, 58, 'trống'),
(39, 58, 'trống'),
(40, 58, 'trống'),
(41, 58, 'trống'),
(42, 58, 'trống'),
(43, 58, 'trống'),
(44, 58, 'trống'),
(45, 58, 'trống'),
(46, 58, 'trống'),
(47, 58, 'trống'),
(48, 58, 'trống'),
(49, 58, 'trống'),
(50, 58, 'trống'),
(51, 58, 'trống'),
(52, 58, 'trống'),
(1, 59, 'đã đặt'),
(2, 59, 'trống'),
(3, 59, 'đã đặt'),
(4, 59, 'trống'),
(5, 59, 'đã đặt'),
(6, 59, 'trống'),
(7, 59, 'đã đặt'),
(8, 59, 'trống'),
(9, 59, 'đã đặt'),
(10, 59, 'trống'),
(11, 59, 'đã đặt'),
(12, 59, 'trống'),
(13, 59, 'đã đặt'),
(14, 59, 'trống'),
(15, 59, 'đã đặt'),
(16, 59, 'trống'),
(17, 59, 'đã đặt'),
(18, 59, 'trống'),
(19, 59, 'đã đặt'),
(20, 59, 'trống'),
(21, 59, 'đã đặt'),
(22, 59, 'trống'),
(23, 59, 'đã đặt'),
(24, 59, 'trống'),
(25, 59, 'đã đặt'),
(26, 59, 'trống'),
(27, 59, 'đã đặt'),
(28, 59, 'trống'),
(29, 59, 'đã đặt'),
(30, 59, 'trống'),
(31, 59, 'đã đặt'),
(32, 59, 'trống'),
(33, 59, 'đã đặt'),
(34, 59, 'trống'),
(35, 59, 'đã đặt'),
(36, 59, 'trống'),
(37, 59, 'đã đặt'),
(38, 59, 'trống'),
(39, 59, 'đã đặt'),
(40, 59, 'trống'),
(41, 59, 'đã đặt'),
(42, 59, 'trống'),
(43, 59, 'đã đặt'),
(44, 59, 'trống'),
(45, 59, 'đã đặt'),
(46, 59, 'trống'),
(47, 59, 'đã đặt'),
(48, 59, 'trống'),
(49, 59, 'đã đặt'),
(50, 59, 'trống'),
(51, 59, 'đã đặt'),
(52, 59, 'trống'),
(77, 60, 'đã đặt'),
(78, 60, 'trống'),
(79, 60, 'đã đặt'),
(80, 60, 'trống'),
(81, 60, 'đã đặt'),
(82, 60, 'trống'),
(83, 60, 'đã đặt'),
(84, 60, 'trống'),
(85, 60, 'đã đặt'),
(86, 60, 'trống'),
(87, 60, 'đã đặt'),
(88, 60, 'trống'),
(89, 60, 'đã đặt'),
(90, 60, 'trống'),
(91, 60, 'đã đặt'),
(92, 60, 'trống'),
(93, 60, 'trống'),
(94, 60, 'trống'),
(95, 60, 'trống'),
(96, 60, 'trống'),
(97, 60, 'trống'),
(98, 60, 'trống'),
(99, 60, 'trống'),
(100, 60, 'trống'),
(101, 60, 'trống'),
(102, 60, 'trống'),
(103, 60, 'trống'),
(104, 60, 'trống'),
(105, 60, 'trống'),
(106, 60, 'trống'),
(1, 61, 'đã đặt'),
(2, 61, 'trống'),
(3, 61, 'đã đặt'),
(4, 61, 'trống'),
(5, 61, 'đã đặt'),
(6, 61, 'trống'),
(7, 61, 'đã đặt'),
(8, 61, 'trống'),
(9, 61, 'đã đặt'),
(10, 61, 'trống'),
(11, 61, 'đã đặt'),
(12, 61, 'trống'),
(13, 61, 'đã đặt'),
(14, 61, 'trống'),
(15, 61, 'đã đặt'),
(16, 61, 'trống'),
(17, 61, 'đã đặt'),
(18, 61, 'trống'),
(19, 61, 'đã đặt'),
(20, 61, 'trống'),
(21, 61, 'đã đặt'),
(22, 61, 'trống'),
(23, 61, 'đã đặt'),
(24, 61, 'trống'),
(25, 61, 'trống'),
(26, 61, 'trống'),
(27, 61, 'trống'),
(28, 61, 'trống'),
(29, 61, 'trống'),
(30, 61, 'trống'),
(31, 61, 'trống'),
(32, 61, 'trống'),
(33, 61, 'trống'),
(34, 61, 'trống'),
(35, 61, 'trống'),
(36, 61, 'trống'),
(37, 61, 'trống'),
(38, 61, 'trống'),
(39, 61, 'trống'),
(40, 61, 'trống'),
(41, 61, 'trống'),
(42, 61, 'trống'),
(43, 61, 'trống'),
(44, 61, 'trống'),
(45, 61, 'trống'),
(46, 61, 'trống'),
(47, 61, 'trống'),
(48, 61, 'trống'),
(49, 61, 'trống'),
(50, 61, 'trống'),
(51, 61, 'trống'),
(52, 61, 'trống'),
(53, 62, 'đã đặt'),
(54, 62, 'trống'),
(55, 62, 'đã đặt'),
(56, 62, 'trống'),
(57, 62, 'đã đặt'),
(58, 62, 'trống'),
(59, 62, 'đã đặt'),
(60, 62, 'trống'),
(61, 62, 'đã đặt'),
(62, 62, 'trống'),
(63, 62, 'đã đặt'),
(64, 62, 'trống'),
(65, 62, 'đã đặt'),
(66, 62, 'trống'),
(67, 62, 'đã đặt'),
(68, 62, 'trống'),
(69, 62, 'đã đặt'),
(70, 62, 'trống'),
(71, 62, 'trống'),
(72, 62, 'trống'),
(73, 62, 'trống'),
(74, 62, 'trống'),
(75, 62, 'trống'),
(76, 62, 'trống'),
(107, 62, 'đã đặt'),
(108, 62, 'trống'),
(109, 62, 'đã đặt'),
(110, 62, 'trống'),
(111, 62, 'đã đặt'),
(112, 62, 'trống'),
(113, 62, 'đã đặt'),
(114, 62, 'trống'),
(77, 63, 'đã đặt'),
(78, 63, 'trống'),
(79, 63, 'đã đặt'),
(80, 63, 'trống'),
(81, 63, 'đã đặt'),
(82, 63, 'trống'),
(83, 63, 'đã đặt'),
(84, 63, 'trống'),
(85, 63, 'đã đặt'),
(86, 63, 'trống'),
(87, 63, 'đã đặt'),
(88, 63, 'trống'),
(89, 63, 'đã đặt'),
(90, 63, 'trống'),
(91, 63, 'đã đặt'),
(92, 63, 'trống'),
(93, 63, 'trống'),
(94, 63, 'trống'),
(95, 63, 'trống'),
(96, 63, 'trống'),
(97, 63, 'trống'),
(98, 63, 'trống'),
(99, 63, 'trống'),
(100, 63, 'trống'),
(101, 63, 'trống'),
(102, 63, 'trống'),
(103, 63, 'trống'),
(104, 63, 'trống'),
(105, 63, 'trống'),
(106, 63, 'trống'),
(1, 64, 'đã đặt'),
(2, 64, 'trống'),
(3, 64, 'đã đặt'),
(4, 64, 'trống'),
(5, 64, 'đã đặt'),
(6, 64, 'trống'),
(7, 64, 'đã đặt'),
(8, 64, 'trống'),
(9, 64, 'đã đặt'),
(10, 64, 'trống'),
(11, 64, 'đã đặt'),
(12, 64, 'trống'),
(13, 64, 'đã đặt'),
(14, 64, 'trống'),
(15, 64, 'đã đặt'),
(16, 64, 'trống'),
(17, 64, 'trống'),
(18, 64, 'trống'),
(19, 64, 'trống'),
(20, 64, 'trống'),
(21, 64, 'trống'),
(22, 64, 'trống'),
(23, 64, 'trống'),
(24, 64, 'trống'),
(25, 64, 'trống'),
(26, 64, 'trống'),
(27, 64, 'trống'),
(28, 64, 'trống'),
(29, 64, 'trống'),
(30, 64, 'trống'),
(31, 64, 'trống'),
(32, 64, 'trống'),
(33, 64, 'trống'),
(34, 64, 'trống'),
(35, 64, 'trống'),
(36, 64, 'trống'),
(37, 64, 'trống'),
(38, 64, 'trống'),
(39, 64, 'trống'),
(40, 64, 'trống'),
(41, 64, 'trống'),
(42, 64, 'trống'),
(43, 64, 'trống'),
(44, 64, 'trống'),
(45, 64, 'trống'),
(46, 64, 'trống'),
(47, 64, 'trống'),
(48, 64, 'trống'),
(49, 64, 'trống'),
(50, 64, 'trống'),
(51, 64, 'trống'),
(52, 64, 'trống'),
(53, 65, 'đã đặt'),
(54, 65, 'trống'),
(55, 65, 'trống'),
(56, 65, 'trống'),
(57, 65, 'đã đặt'),
(58, 65, 'trống'),
(59, 65, 'trống'),
(60, 65, 'trống'),
(61, 65, 'đã đặt'),
(62, 65, 'trống'),
(63, 65, 'trống'),
(64, 65, 'trống'),
(65, 65, 'đã đặt'),
(66, 65, 'trống'),
(67, 65, 'trống'),
(68, 65, 'trống'),
(69, 65, 'trống'),
(70, 65, 'trống'),
(71, 65, 'trống'),
(72, 65, 'trống'),
(73, 65, 'trống'),
(74, 65, 'trống'),
(75, 65, 'trống'),
(76, 65, 'trống'),
(107, 65, 'đã đặt'),
(108, 65, 'trống'),
(109, 65, 'đã đặt'),
(110, 65, 'trống'),
(111, 65, 'đã đặt'),
(112, 65, 'trống'),
(113, 65, 'đã đặt'),
(114, 65, 'trống'),
(77, 66, 'đã đặt'),
(78, 66, 'trống'),
(79, 66, 'trống'),
(80, 66, 'trống'),
(81, 66, 'đã đặt'),
(82, 66, 'trống'),
(83, 66, 'trống'),
(84, 66, 'trống'),
(85, 66, 'đã đặt'),
(86, 66, 'trống'),
(87, 66, 'trống'),
(88, 66, 'trống'),
(89, 66, 'đã đặt'),
(90, 66, 'trống'),
(91, 66, 'trống'),
(92, 66, 'trống'),
(93, 66, 'trống'),
(94, 66, 'trống'),
(95, 66, 'trống'),
(96, 66, 'trống'),
(97, 66, 'trống'),
(98, 66, 'trống'),
(99, 66, 'trống'),
(100, 66, 'trống'),
(101, 66, 'trống'),
(102, 66, 'trống'),
(103, 66, 'trống'),
(104, 66, 'trống'),
(105, 66, 'trống'),
(106, 66, 'trống'),
(1, 67, 'đã đặt'),
(2, 67, 'trống'),
(3, 67, 'đã đặt'),
(4, 67, 'trống'),
(5, 67, 'đã đặt'),
(6, 67, 'trống'),
(7, 67, 'đã đặt'),
(8, 67, 'trống'),
(9, 67, 'đã đặt'),
(10, 67, 'trống'),
(11, 67, 'đã đặt'),
(12, 67, 'trống'),
(13, 67, 'đã đặt'),
(14, 67, 'trống'),
(15, 67, 'đã đặt'),
(16, 67, 'trống'),
(17, 67, 'trống'),
(18, 67, 'trống'),
(19, 67, 'trống'),
(20, 67, 'trống'),
(21, 67, 'trống'),
(22, 67, 'trống'),
(23, 67, 'trống'),
(24, 67, 'trống'),
(25, 67, 'trống'),
(26, 67, 'trống'),
(27, 67, 'trống'),
(28, 67, 'trống'),
(29, 67, 'trống'),
(30, 67, 'trống'),
(31, 67, 'trống'),
(32, 67, 'trống'),
(33, 67, 'trống'),
(34, 67, 'trống'),
(35, 67, 'trống'),
(36, 67, 'trống'),
(37, 67, 'trống'),
(38, 67, 'trống'),
(39, 67, 'trống'),
(40, 67, 'trống'),
(41, 67, 'trống'),
(42, 67, 'trống'),
(43, 67, 'trống'),
(44, 67, 'trống'),
(45, 67, 'trống'),
(46, 67, 'trống'),
(47, 67, 'trống'),
(48, 67, 'trống'),
(49, 67, 'trống'),
(50, 67, 'trống'),
(51, 67, 'trống'),
(52, 67, 'trống'),
(53, 68, 'đã đặt'),
(54, 68, 'trống'),
(55, 68, 'trống'),
(56, 68, 'trống'),
(57, 68, 'đã đặt'),
(58, 68, 'trống'),
(59, 68, 'trống'),
(60, 68, 'trống'),
(61, 68, 'đã đặt'),
(62, 68, 'trống'),
(63, 68, 'trống'),
(64, 68, 'trống'),
(65, 68, 'đã đặt'),
(66, 68, 'trống'),
(67, 68, 'trống'),
(68, 68, 'trống'),
(69, 68, 'trống'),
(70, 68, 'trống'),
(71, 68, 'trống'),
(72, 68, 'trống'),
(73, 68, 'trống'),
(74, 68, 'trống'),
(75, 68, 'trống'),
(76, 68, 'trống'),
(107, 68, 'đã đặt'),
(108, 68, 'trống'),
(109, 68, 'đã đặt'),
(110, 68, 'trống'),
(111, 68, 'đã đặt'),
(112, 68, 'trống'),
(113, 68, 'đã đặt'),
(114, 68, 'trống'),
(77, 69, 'đã đặt'),
(78, 69, 'trống'),
(79, 69, 'trống'),
(80, 69, 'trống'),
(81, 69, 'đã đặt'),
(82, 69, 'trống'),
(83, 69, 'trống'),
(84, 69, 'trống'),
(85, 69, 'đã đặt'),
(86, 69, 'trống'),
(87, 69, 'trống'),
(88, 69, 'trống'),
(89, 69, 'đã đặt'),
(90, 69, 'trống'),
(91, 69, 'trống'),
(92, 69, 'trống'),
(93, 69, 'trống'),
(94, 69, 'trống'),
(95, 69, 'trống'),
(96, 69, 'trống'),
(97, 69, 'trống'),
(98, 69, 'trống'),
(99, 69, 'trống'),
(100, 69, 'trống'),
(101, 69, 'trống'),
(102, 69, 'trống'),
(103, 69, 'trống'),
(104, 69, 'trống'),
(105, 69, 'trống'),
(106, 69, 'trống'),
(53, 70, 'đã đặt'),
(54, 70, 'trống'),
(55, 70, 'trống'),
(56, 70, 'trống'),
(57, 70, 'đã đặt'),
(58, 70, 'trống'),
(59, 70, 'trống'),
(60, 70, 'trống'),
(61, 70, 'đã đặt'),
(62, 70, 'trống'),
(63, 70, 'trống'),
(64, 70, 'trống'),
(65, 70, 'đã đặt'),
(66, 70, 'trống'),
(67, 70, 'trống'),
(68, 70, 'trống'),
(69, 70, 'trống'),
(70, 70, 'trống'),
(71, 70, 'trống'),
(72, 70, 'trống'),
(73, 70, 'trống'),
(74, 70, 'trống'),
(75, 70, 'trống'),
(76, 70, 'trống'),
(107, 70, 'đã đặt'),
(108, 70, 'trống'),
(109, 70, 'đã đặt'),
(110, 70, 'trống'),
(111, 70, 'đã đặt'),
(112, 70, 'trống'),
(113, 70, 'đã đặt'),
(114, 70, 'trống'),
(1, 71, 'đã đặt'),
(2, 71, 'trống'),
(3, 71, 'đã đặt'),
(4, 71, 'trống'),
(5, 71, 'đã đặt'),
(6, 71, 'trống'),
(7, 71, 'đã đặt'),
(8, 71, 'trống'),
(9, 71, 'đã đặt'),
(10, 71, 'trống'),
(11, 71, 'đã đặt'),
(12, 71, 'trống'),
(13, 71, 'đã đặt'),
(14, 71, 'trống'),
(15, 71, 'đã đặt'),
(16, 71, 'trống'),
(17, 71, 'trống'),
(18, 71, 'trống'),
(19, 71, 'trống'),
(20, 71, 'trống'),
(21, 71, 'trống'),
(22, 71, 'trống'),
(23, 71, 'trống'),
(24, 71, 'trống'),
(25, 71, 'trống'),
(26, 71, 'trống'),
(27, 71, 'trống'),
(28, 71, 'trống'),
(29, 71, 'trống'),
(30, 71, 'trống'),
(31, 71, 'trống'),
(32, 71, 'trống');
INSERT INTO `seat_performance` (`seat_id`, `performance_id`, `status`) VALUES
(33, 71, 'trống'),
(34, 71, 'trống'),
(35, 71, 'trống'),
(36, 71, 'trống'),
(37, 71, 'trống'),
(38, 71, 'trống'),
(39, 71, 'trống'),
(40, 71, 'trống'),
(41, 71, 'trống'),
(42, 71, 'trống'),
(43, 71, 'trống'),
(44, 71, 'trống'),
(45, 71, 'trống'),
(46, 71, 'trống'),
(47, 71, 'trống'),
(48, 71, 'trống'),
(49, 71, 'trống'),
(50, 71, 'trống'),
(51, 71, 'trống'),
(52, 71, 'trống'),
(1, 72, 'đã đặt'),
(2, 72, 'trống'),
(3, 72, 'đã đặt'),
(4, 72, 'trống'),
(5, 72, 'đã đặt'),
(6, 72, 'trống'),
(7, 72, 'đã đặt'),
(8, 72, 'trống'),
(9, 72, 'đã đặt'),
(10, 72, 'trống'),
(11, 72, 'đã đặt'),
(12, 72, 'trống'),
(13, 72, 'đã đặt'),
(14, 72, 'trống'),
(15, 72, 'đã đặt'),
(16, 72, 'trống'),
(17, 72, 'trống'),
(18, 72, 'trống'),
(19, 72, 'trống'),
(20, 72, 'trống'),
(21, 72, 'trống'),
(22, 72, 'trống'),
(23, 72, 'trống'),
(24, 72, 'trống'),
(25, 72, 'trống'),
(26, 72, 'trống'),
(27, 72, 'trống'),
(28, 72, 'trống'),
(29, 72, 'trống'),
(30, 72, 'trống'),
(31, 72, 'trống'),
(32, 72, 'trống'),
(33, 72, 'trống'),
(34, 72, 'trống'),
(35, 72, 'trống'),
(36, 72, 'trống'),
(37, 72, 'trống'),
(38, 72, 'trống'),
(39, 72, 'trống'),
(40, 72, 'trống'),
(41, 72, 'trống'),
(42, 72, 'trống'),
(43, 72, 'trống'),
(44, 72, 'trống'),
(45, 72, 'trống'),
(46, 72, 'trống'),
(47, 72, 'trống'),
(48, 72, 'trống'),
(49, 72, 'trống'),
(50, 72, 'trống'),
(51, 72, 'trống'),
(52, 72, 'trống');

-- --------------------------------------------------------

--
-- Table structure for table `shows`
--

CREATE TABLE `shows` (
  `show_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `duration_minutes` int(11) DEFAULT NULL,
  `director` varchar(255) DEFAULT NULL,
  `poster_image_url` varchar(255) DEFAULT NULL,
  `status` enum('Sắp chiếu','Đang chiếu','Đã kết thúc') NOT NULL DEFAULT 'Sắp chiếu',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `shows`
--

INSERT INTO `shows` (`show_id`, `title`, `description`, `duration_minutes`, `director`, `poster_image_url`, `status`, `created_at`, `updated_at`) VALUES
(8, 'Đứt dây tơ chùng', 'Câu chuyện xoay quanh những giằng xé trong tình yêu, danh vọng và số phận. Sợi dây tình cảm tưởng chừng bền chặt nhưng lại mong manh trước thử thách của lòng người.', 120, 'Nguyễn Văn Khánh', 'assets/images/dut-day-to-chung-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-12-01 11:49:19'),
(9, 'Gánh Cỏ Sông Hàn', 'Lấy bối cảnh miền Trung những năm sau chiến tranh, vở kịch khắc họa số phận những con người mưu sinh bên bến sông Hàn, với tình người chan chứa giữa cuộc đời đầy nhọc nhằn.', 110, 'Trần Thị Mai', 'assets/images/ganh-co-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(10, 'Làng Song Sinh', 'Một ngôi làng kỳ bí nơi những cặp song sinh liên tục chào đời. Bí mật phía sau sự trùng hợp ấy dần hé lộ, để rồi đẩy người xem vào những tình huống ly kỳ và ám ảnh.', 100, 'Lê Hoàng Nam', 'assets/images/lang-song-sinh-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-26 04:15:26'),
(11, 'Lôi Vũ', 'Một trong những vở kịch nổi tiếng nhất thế kỷ XX, “Lôi Vũ” phơi bày những mâu thuẫn giai cấp, đạo đức và gia đình trong xã hội cũ. Vở diễn mang đến sự lay động mạnh mẽ và dư âm lâu dài.', 140, 'Phạm Quang Dũng', 'assets/images/loi-vu.jpg', 'Đang chiếu', '2025-08-01 00:00:00', '2025-11-29 19:56:21'),
(12, 'Ngôi Nhà Trong Mây', 'Một câu chuyện thơ mộng về tình yêu và khát vọng sống, nơi con người tìm đến “ngôi nhà trong mây” để trốn chạy thực tại. Nhưng rồi họ nhận ra: hạnh phúc thật sự chỉ đến khi dám đối diện với chính mình.', 104, 'Vũ Thảo My', 'assets/images/ngoi-nha-trong-may-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-26 14:12:14'),
(13, 'Tấm Cám Đại Chiến', 'Phiên bản hiện đại, vui nhộn và đầy sáng tạo của truyện cổ tích “Tấm Cám”. Với yếu tố gây cười, châm biếm và bất ngờ, vở diễn mang đến những phút giây giải trí thú vị cho cả gia đình.', 95, 'Hoàng Anh Tú', 'assets/images/tam-cam-poster.jpg', 'Đang chiếu', '2025-08-01 00:00:00', '2025-11-29 19:56:21'),
(14, 'Má ơi út dìa', 'Câu chuyện cảm động về tình mẫu tử và nỗi day dứt của người con xa quê. Những ký ức, những tiếng gọi “Má ơi” trở thành sợi dây kết nối quá khứ và hiện tại.', 110, 'Nguyễn Thị Thanh Hương', 'assets/images/ma-oi-ut-dia-poster.png', 'Đã kết thúc', '2025-11-04 12:37:19', '2025-11-30 14:34:45'),
(15, 'Tía ơi má dìa', 'Một vở kịch hài – tình cảm về những hiểu lầm, giận hờn và yêu thương trong một gia đình miền Tây. Tiếng cười và nước mắt đan xen tạo nên cảm xúc sâu lắng.', 100, 'Trần Hoài Phong', 'assets/images/tia-oi-ma-dia-poster.jpg', 'Đã kết thúc', '2025-11-04 12:40:24', '2025-11-24 07:07:01'),
(16, 'Đức Thượng Công Tả Quân Lê Văn Duyệt', 'Tái hiện hình tượng vị danh tướng Lê Văn Duyệt – người để lại dấu ấn sâu đậm trong lịch sử và lòng dân Nam Bộ. Một vở diễn lịch sử trang trọng, đầy khí phách.', 130, 'Phạm Hữu Tấn', 'assets/images/duc-thuong-cong-ta-quan-le-van-duyet-poster.jpg', 'Đã kết thúc', '2025-11-04 12:42:26', '2025-11-24 07:07:01'),
(17, 'Chuyến Đò Định Mệnh', 'Một câu chuyện đầy kịch tính xoay quanh chuyến đò cuối cùng của đời người lái đò, nơi tình yêu, tội lỗi và sự tha thứ gặp nhau trong một đêm giông bão.', 115, 'Vũ Ngọc Dũng', 'assets/images/chuyen-do-dinh-menh-poster.jpg', 'Đã kết thúc', '2025-11-04 12:43:35', '2025-12-07 11:30:19'),
(18, 'Một Ngày Làm Vua', 'Vở hài kịch xã hội châm biếm về một người bình thường bỗng được trao quyền lực. Từ đó, những tình huống oái oăm, dở khóc dở cười liên tục xảy ra.', 100, 'Nguyễn Hoàng Anh', 'assets/images/mot-ngay-lam-vua-poster.jpg', 'Đã kết thúc', '2025-11-04 12:44:58', '2025-11-22 11:47:10'),
(19, 'Xóm Vịt Trời', 'Một góc nhìn nhân văn và hài hước về cuộc sống mưu sinh của những người lao động nghèo trong một xóm nhỏ ven sông. Dù khốn khó, họ vẫn giữ niềm tin và tình người.', 105, 'Lê Thị Phương Loan', 'assets/images/xom-vit-troi-poster.jpg', 'Đã kết thúc', '2025-11-04 12:46:05', '2025-11-22 11:47:10'),
(20, 'Những con ma nhà hát', '“Những Con Ma Nhà Hát” là một câu chuyện rùng rợn nhưng cũng đầy tính châm biếm, xoay quanh những hiện tượng kỳ bí xảy ra tại một nhà hát cũ sắp bị phá bỏ. Khi đoàn kịch mới đến tập luyện, những bóng ma của các diễn viên quá cố bắt đầu xuất hiện, đưa người xem vào hành trình giằng co giữa nghệ thuật, danh vọng và quá khứ bị lãng quên.', 115, 'Nguyễn Khánh Trung', 'assets/images/nhung-con-ma-poster.jpg', 'Đã kết thúc', '2025-11-04 13:19:55', '2025-11-30 14:34:45');

-- --------------------------------------------------------

--
-- Table structure for table `show_actors`
--

CREATE TABLE `show_actors` (
  `show_id` int(11) NOT NULL,
  `actor_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `show_actors`
--

INSERT INTO `show_actors` (`show_id`, `actor_id`) VALUES
(8, 2),
(8, 4),
(8, 6),
(8, 9),
(8, 10),
(9, 2),
(9, 3),
(9, 5),
(10, 3),
(10, 8),
(10, 10),
(11, 1),
(11, 5),
(11, 6),
(12, 5),
(12, 6),
(12, 9),
(13, 5),
(13, 6),
(13, 7),
(14, 3),
(14, 5),
(14, 7),
(15, 2),
(15, 3),
(15, 4),
(16, 3),
(16, 4),
(16, 10),
(17, 1),
(17, 6),
(17, 8),
(17, 10),
(18, 2),
(18, 5),
(18, 7),
(19, 2),
(19, 3),
(19, 4),
(20, 4),
(20, 8),
(20, 10);

-- --------------------------------------------------------

--
-- Table structure for table `show_genres`
--

CREATE TABLE `show_genres` (
  `show_id` int(11) NOT NULL,
  `genre_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `show_genres`
--

INSERT INTO `show_genres` (`show_id`, `genre_id`) VALUES
(8, 6),
(8, 8),
(9, 8),
(9, 9),
(9, 10),
(10, 8),
(10, 13),
(11, 6),
(11, 8),
(11, 15),
(12, 11),
(12, 12),
(13, 7),
(13, 14),
(14, 6),
(14, 10),
(14, 16),
(15, 7),
(15, 10),
(15, 16),
(16, 15),
(16, 17),
(16, 18),
(17, 6),
(17, 8),
(17, 13),
(18, 7),
(18, 18),
(18, 19),
(19, 8),
(19, 9),
(19, 10),
(20, 8),
(20, 12),
(20, 13);

-- --------------------------------------------------------

--
-- Table structure for table `theaters`
--

CREATE TABLE `theaters` (
  `theater_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `total_seats` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` enum('Chờ xử lý','Đã hoạt động') NOT NULL DEFAULT 'Chờ xử lý'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `theaters`
--

INSERT INTO `theaters` (`theater_id`, `name`, `total_seats`, `created_at`, `status`) VALUES
(1, 'Main Hall', 52, '2025-10-03 16:14:11', 'Đã hoạt động'),
(2, 'Black Box', 32, '2025-10-03 16:14:22', 'Đã hoạt động'),
(3, 'Studio', 30, '2025-10-03 16:14:32', 'Đã hoạt động');

-- --------------------------------------------------------

--
-- Table structure for table `tickets`
--

CREATE TABLE `tickets` (
  `ticket_id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `seat_id` int(11) NOT NULL,
  `ticket_code` bigint(20) NOT NULL,
  `status` enum('Đang chờ','Hợp lệ','Đã sử dụng','Đã hủy') NOT NULL DEFAULT 'Đang chờ',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `tickets`
--

INSERT INTO `tickets` (`ticket_id`, `booking_id`, `seat_id`, `ticket_code`, `status`, `created_at`, `updated_at`) VALUES
(1, 1, 1, 1000000000000, 'Đã sử dụng', '2024-12-20 10:15:22', '2024-12-20 10:15:22'),
(2, 1, 3, 1000000000001, 'Đã sử dụng', '2024-12-20 10:15:22', '2024-12-20 10:15:22'),
(3, 1, 5, 1000000000002, 'Đã sử dụng', '2024-12-20 10:15:22', '2024-12-20 10:15:22'),
(4, 2, 7, 1000000000003, 'Đã sử dụng', '2024-12-20 15:33:11', '2024-12-20 15:33:11'),
(5, 2, 9, 1000000000004, 'Đã sử dụng', '2024-12-20 15:33:11', '2024-12-20 15:33:11'),
(6, 3, 11, 1000000000005, 'Đã sử dụng', '2024-12-21 09:44:55', '2024-12-21 09:44:55'),
(7, 3, 13, 1000000000006, 'Đã sử dụng', '2024-12-21 09:44:55', '2024-12-21 09:44:55'),
(8, 3, 15, 1000000000007, 'Đã sử dụng', '2024-12-21 09:44:55', '2024-12-21 09:44:55'),
(9, 4, 17, 1000000000008, 'Đã sử dụng', '2024-12-21 16:22:33', '2024-12-21 16:22:33'),
(10, 4, 19, 1000000000009, 'Đã sử dụng', '2024-12-21 16:22:33', '2024-12-21 16:22:33'),
(11, 5, 21, 1000000000010, 'Đã sử dụng', '2024-12-22 11:11:08', '2024-12-22 11:11:08'),
(12, 5, 23, 1000000000011, 'Đã sử dụng', '2024-12-22 11:11:08', '2024-12-22 11:11:08'),
(13, 5, 25, 1000000000012, 'Đã sử dụng', '2024-12-22 11:11:08', '2024-12-22 11:11:08'),
(14, 6, 27, 1000000000013, 'Đã sử dụng', '2024-12-22 19:55:19', '2024-12-22 19:55:19'),
(15, 6, 29, 1000000000014, 'Đã sử dụng', '2024-12-22 19:55:19', '2024-12-22 19:55:19'),
(16, 7, 31, 1000000000015, 'Đã sử dụng', '2024-12-23 08:33:44', '2024-12-23 08:33:44'),
(17, 7, 33, 1000000000016, 'Đã sử dụng', '2024-12-23 08:33:44', '2024-12-23 08:33:44'),
(18, 7, 35, 1000000000017, 'Đã sử dụng', '2024-12-23 08:33:44', '2024-12-23 08:33:44'),
(19, 8, 37, 1000000000018, 'Đã sử dụng', '2024-12-23 14:44:22', '2024-12-23 14:44:22'),
(20, 8, 39, 1000000000019, 'Đã sử dụng', '2024-12-23 14:44:22', '2024-12-23 14:44:22'),
(21, 8, 41, 1000000000020, 'Đã sử dụng', '2024-12-23 14:44:22', '2024-12-23 14:44:22'),
(22, 9, 43, 1000000000021, 'Đã sử dụng', '2024-12-24 10:55:11', '2024-12-24 10:55:11'),
(23, 9, 45, 1000000000022, 'Đã sử dụng', '2024-12-24 10:55:11', '2024-12-24 10:55:11'),
(24, 10, 47, 1000000000023, 'Đã sử dụng', '2024-12-24 17:22:55', '2024-12-24 17:22:55'),
(25, 10, 49, 1000000000024, 'Đã sử dụng', '2024-12-24 17:22:55', '2024-12-24 17:22:55'),
(26, 10, 51, 1000000000025, 'Đã sử dụng', '2024-12-24 17:22:55', '2024-12-24 17:22:55'),
(27, 12, 53, 1000000000026, 'Đã sử dụng', '2025-01-08 09:18:33', '2025-01-08 09:18:33'),
(28, 12, 55, 1000000000027, 'Đã sử dụng', '2025-01-08 09:18:33', '2025-01-08 09:18:33'),
(29, 12, 57, 1000000000028, 'Đã sử dụng', '2025-01-08 09:18:33', '2025-01-08 09:18:33'),
(30, 13, 59, 1000000000029, 'Đã sử dụng', '2025-01-08 15:29:11', '2025-01-08 15:29:11'),
(31, 13, 61, 1000000000030, 'Đã sử dụng', '2025-01-08 15:29:11', '2025-01-08 15:29:11'),
(32, 13, 63, 1000000000031, 'Đã sử dụng', '2025-01-08 15:29:11', '2025-01-08 15:29:11'),
(33, 14, 65, 1000000000032, 'Đã sử dụng', '2025-01-09 11:44:55', '2025-01-09 11:44:55'),
(34, 14, 67, 1000000000033, 'Đã sử dụng', '2025-01-09 11:44:55', '2025-01-09 11:44:55'),
(35, 15, 69, 1000000000034, 'Đã sử dụng', '2025-01-09 17:33:22', '2025-01-09 17:33:22'),
(36, 15, 71, 1000000000035, 'Đã sử dụng', '2025-01-09 17:33:22', '2025-01-09 17:33:22'),
(37, 16, 73, 1000000000036, 'Đã sử dụng', '2025-01-10 10:22:08', '2025-01-10 10:22:08'),
(38, 16, 75, 1000000000037, 'Đã sử dụng', '2025-01-10 10:22:08', '2025-01-10 10:22:08'),
(39, 16, 107, 1000000000038, 'Đã sử dụng', '2025-01-10 10:22:08', '2025-01-10 10:22:08'),
(40, 17, 109, 1000000000039, 'Đã sử dụng', '2025-01-10 19:11:44', '2025-01-10 19:11:44'),
(41, 17, 111, 1000000000040, 'Đã sử dụng', '2025-01-10 19:11:44', '2025-01-10 19:11:44'),
(42, 18, 113, 1000000000041, 'Đã sử dụng', '2025-01-11 13:55:33', '2025-01-11 13:55:33'),
(43, 18, 114, 1000000000042, 'Đã sử dụng', '2025-01-11 13:55:33', '2025-01-11 13:55:33'),
(44, 19, 2, 1000000000043, 'Đã sử dụng', '2024-12-21 10:18:22', '2024-12-21 10:18:22'),
(45, 19, 4, 1000000000044, 'Đã sử dụng', '2024-12-21 10:18:22', '2024-12-21 10:18:22'),
(46, 19, 6, 1000000000045, 'Đã sử dụng', '2024-12-21 10:18:22', '2024-12-21 10:18:22'),
(47, 20, 8, 1000000000046, 'Đã sử dụng', '2024-12-21 16:29:11', '2024-12-21 16:29:11'),
(48, 20, 10, 1000000000047, 'Đã sử dụng', '2024-12-21 16:29:11', '2024-12-21 16:29:11'),
(49, 20, 12, 1000000000048, 'Đã sử dụng', '2024-12-21 16:29:11', '2024-12-21 16:29:11'),
(50, 21, 14, 1000000000049, 'Đã sử dụng', '2024-12-22 09:44:55', '2024-12-22 09:44:55'),
(51, 21, 16, 1000000000050, 'Đã sử dụng', '2024-12-22 09:44:55', '2024-12-22 09:44:55'),
(52, 22, 18, 1000000000051, 'Đã sử dụng', '2024-12-22 14:33:33', '2024-12-22 14:33:33'),
(53, 22, 20, 1000000000052, 'Đã sử dụng', '2024-12-22 14:33:33', '2024-12-22 14:33:33'),
(54, 22, 22, 1000000000053, 'Đã sử dụng', '2024-12-22 14:33:33', '2024-12-22 14:33:33'),
(55, 23, 24, 1000000000054, 'Đã sử dụng', '2024-12-23 11:11:08', '2024-12-23 11:11:08'),
(56, 23, 26, 1000000000055, 'Đã sử dụng', '2024-12-23 11:11:08', '2024-12-23 11:11:08'),
(57, 24, 28, 1000000000056, 'Đã sử dụng', '2024-12-23 18:55:19', '2024-12-23 18:55:19'),
(58, 24, 30, 1000000000057, 'Đã sử dụng', '2024-12-23 18:55:19', '2024-12-23 18:55:19'),
(59, 25, 32, 1000000000058, 'Đã sử dụng', '2024-12-24 10:22:44', '2024-12-24 10:22:44'),
(60, 25, 34, 1000000000059, 'Đã sử dụng', '2024-12-24 10:22:44', '2024-12-24 10:22:44'),
(61, 26, 36, 1000000000060, 'Đã sử dụng', '2024-12-24 15:33:11', '2024-12-24 15:33:11'),
(62, 26, 38, 1000000000061, 'Đã sử dụng', '2024-12-24 15:33:11', '2024-12-24 15:33:11'),
(63, 27, 40, 1000000000062, 'Đã sử dụng', '2024-12-25 09:11:22', '2024-12-25 09:11:22'),
(64, 27, 42, 1000000000063, 'Đã sử dụng', '2024-12-25 09:11:22', '2024-12-25 09:11:22'),
(65, 27, 44, 1000000000064, 'Đã sử dụng', '2024-12-25 09:11:22', '2024-12-25 09:11:22'),
(66, 28, 46, 1000000000065, 'Đã sử dụng', '2024-12-25 14:44:55', '2024-12-25 14:44:55'),
(67, 28, 48, 1000000000066, 'Đã sử dụng', '2024-12-25 14:44:55', '2024-12-25 14:44:55'),
(68, 29, 50, 1000000000067, 'Đã sử dụng', '2024-12-25 19:22:33', '2024-12-25 19:22:33'),
(69, 29, 52, 1000000000068, 'Đã sử dụng', '2024-12-25 19:22:33', '2024-12-25 19:22:33'),
(70, 30, 77, 1000000000069, 'Đã sử dụng', '2025-01-10 10:25:44', '2025-01-10 10:25:44'),
(71, 30, 79, 1000000000070, 'Đã sử dụng', '2025-01-10 10:25:44', '2025-01-10 10:25:44'),
(72, 30, 81, 1000000000071, 'Đã sử dụng', '2025-01-10 10:25:44', '2025-01-10 10:25:44'),
(73, 31, 83, 1000000000072, 'Đã sử dụng', '2025-01-10 15:33:22', '2025-01-10 15:33:22'),
(74, 31, 85, 1000000000073, 'Đã sử dụng', '2025-01-10 15:33:22', '2025-01-10 15:33:22'),
(75, 31, 87, 1000000000074, 'Đã sử dụng', '2025-01-10 15:33:22', '2025-01-10 15:33:22'),
(76, 32, 89, 1000000000075, 'Đã sử dụng', '2025-01-11 09:55:11', '2025-01-11 09:55:11'),
(77, 32, 91, 1000000000076, 'Đã sử dụng', '2025-01-11 09:55:11', '2025-01-11 09:55:11'),
(78, 33, 93, 1000000000077, 'Đã sử dụng', '2025-01-11 14:22:44', '2025-01-11 14:22:44'),
(79, 33, 95, 1000000000078, 'Đã sử dụng', '2025-01-11 14:22:44', '2025-01-11 14:22:44'),
(80, 34, 97, 1000000000079, 'Đã sử dụng', '2025-01-12 11:33:55', '2025-01-12 11:33:55'),
(81, 34, 99, 1000000000080, 'Đã sử dụng', '2025-01-12 11:33:55', '2025-01-12 11:33:55'),
(82, 34, 101, 1000000000081, 'Đã sử dụng', '2025-01-12 11:33:55', '2025-01-12 11:33:55'),
(83, 35, 103, 1000000000082, 'Đã sử dụng', '2025-01-12 17:44:22', '2025-01-12 17:44:22'),
(84, 35, 105, 1000000000083, 'Đã sử dụng', '2025-01-12 17:44:22', '2025-01-12 17:44:22'),
(85, 36, 54, 1000000000084, 'Đã sử dụng', '2024-12-28 10:18:33', '2024-12-28 10:18:33'),
(86, 36, 56, 1000000000085, 'Đã sử dụng', '2024-12-28 10:18:33', '2024-12-28 10:18:33'),
(87, 36, 58, 1000000000086, 'Đã sử dụng', '2024-12-28 10:18:33', '2024-12-28 10:18:33'),
(88, 37, 60, 1000000000087, 'Đã sử dụng', '2024-12-28 15:29:11', '2024-12-28 15:29:11'),
(89, 37, 62, 1000000000088, 'Đã sử dụng', '2024-12-28 15:29:11', '2024-12-28 15:29:11'),
(90, 37, 64, 1000000000089, 'Đã sử dụng', '2024-12-28 15:29:11', '2024-12-28 15:29:11'),
(91, 38, 66, 1000000000090, 'Đã sử dụng', '2024-12-29 09:44:55', '2024-12-29 09:44:55'),
(92, 38, 68, 1000000000091, 'Đã sử dụng', '2024-12-29 09:44:55', '2024-12-29 09:44:55'),
(93, 39, 70, 1000000000092, 'Đã sử dụng', '2024-12-29 14:33:22', '2024-12-29 14:33:22'),
(94, 39, 72, 1000000000093, 'Đã sử dụng', '2024-12-29 14:33:22', '2024-12-29 14:33:22'),
(95, 40, 74, 1000000000094, 'Đã sử dụng', '2024-12-30 11:22:08', '2024-12-30 11:22:08'),
(96, 40, 76, 1000000000095, 'Đã sử dụng', '2024-12-30 11:22:08', '2024-12-30 11:22:08'),
(97, 40, 108, 1000000000096, 'Đã sử dụng', '2024-12-30 11:22:08', '2024-12-30 11:22:08'),
(98, 41, 110, 1000000000097, 'Đã sử dụng', '2024-12-30 18:55:44', '2024-12-30 18:55:44'),
(99, 41, 112, 1000000000098, 'Đã sử dụng', '2024-12-30 18:55:44', '2024-12-30 18:55:44'),
(100, 42, 114, 1000000000099, 'Đã sử dụng', '2024-12-31 12:33:19', '2024-12-31 12:33:19'),
(101, 43, 1, 1000000000100, 'Đã sử dụng', '2025-01-11 09:22:33', '2025-01-11 09:22:33'),
(102, 43, 3, 1000000000101, 'Đã sử dụng', '2025-01-11 09:22:33', '2025-01-11 09:22:33'),
(103, 43, 5, 1000000000102, 'Đã sử dụng', '2025-01-11 09:22:33', '2025-01-11 09:22:33'),
(104, 44, 7, 1000000000103, 'Đã sử dụng', '2025-01-11 14:44:11', '2025-01-11 14:44:11'),
(105, 44, 9, 1000000000104, 'Đã sử dụng', '2025-01-11 14:44:11', '2025-01-11 14:44:11'),
(106, 45, 11, 1000000000105, 'Đã sử dụng', '2025-01-12 10:55:22', '2025-01-12 10:55:22'),
(107, 45, 13, 1000000000106, 'Đã sử dụng', '2025-01-12 10:55:22', '2025-01-12 10:55:22'),
(108, 45, 15, 1000000000107, 'Đã sử dụng', '2025-01-12 10:55:22', '2025-01-12 10:55:22'),
(109, 46, 17, 1000000000108, 'Đã sử dụng', '2025-01-12 16:11:44', '2025-01-12 16:11:44'),
(110, 46, 19, 1000000000109, 'Đã sử dụng', '2025-01-12 16:11:44', '2025-01-12 16:11:44'),
(111, 47, 21, 1000000000110, 'Đã sử dụng', '2025-01-13 11:33:55', '2025-01-13 11:33:55'),
(112, 47, 23, 1000000000111, 'Đã sử dụng', '2025-01-13 11:33:55', '2025-01-13 11:33:55'),
(113, 47, 25, 1000000000112, 'Đã sử dụng', '2025-01-13 11:33:55', '2025-01-13 11:33:55'),
(114, 48, 27, 1000000000113, 'Đã sử dụng', '2025-01-13 19:22:08', '2025-01-13 19:22:08'),
(115, 48, 29, 1000000000114, 'Đã sử dụng', '2025-01-13 19:22:08', '2025-01-13 19:22:08'),
(116, 49, 31, 1000000000115, 'Đã sử dụng', '2025-01-14 09:11:33', '2025-01-14 09:11:33'),
(117, 49, 33, 1000000000116, 'Đã sử dụng', '2025-01-14 09:11:33', '2025-01-14 09:11:33'),
(118, 49, 35, 1000000000117, 'Đã sử dụng', '2025-01-14 09:11:33', '2025-01-14 09:11:33'),
(119, 50, 37, 1000000000118, 'Đã sử dụng', '2025-01-14 13:44:55', '2025-01-14 13:44:55'),
(120, 50, 39, 1000000000119, 'Đã sử dụng', '2025-01-14 13:44:55', '2025-01-14 13:44:55'),
(121, 50, 41, 1000000000120, 'Đã sử dụng', '2025-01-14 13:44:55', '2025-01-14 13:44:55'),
(122, 51, 43, 1000000000121, 'Đã sử dụng', '2025-01-14 17:22:22', '2025-01-14 17:22:22'),
(123, 51, 45, 1000000000122, 'Đã sử dụng', '2025-01-14 17:22:22', '2025-01-14 17:22:22'),
(124, 51, 47, 1000000000123, 'Đã sử dụng', '2025-01-14 17:22:22', '2025-01-14 17:22:22'),
(125, 52, 49, 1000000000124, 'Đã sử dụng', '2025-01-15 10:33:11', '2025-01-15 10:33:11'),
(126, 52, 51, 1000000000125, 'Đã sử dụng', '2025-01-15 10:33:11', '2025-01-15 10:33:11'),
(127, 53, 2, 1000000000126, 'Đã sử dụng', '2025-01-15 14:55:44', '2025-01-15 14:55:44'),
(128, 53, 4, 1000000000127, 'Đã sử dụng', '2025-01-15 14:55:44', '2025-01-15 14:55:44'),
(129, 54, 6, 1000000000128, 'Đã sử dụng', '2025-01-15 18:12:08', '2025-01-15 18:12:08'),
(130, 54, 8, 1000000000129, 'Đã sử dụng', '2025-01-15 18:12:08', '2025-01-15 18:12:08'),
(131, 55, 10, 1000000000130, 'Đã sử dụng', '2025-01-15 20:25:33', '2025-01-15 20:25:33'),
(132, 55, 12, 1000000000131, 'Đã sử dụng', '2025-01-15 20:25:33', '2025-01-15 20:25:33'),
(133, 55, 14, 1000000000132, 'Đã sử dụng', '2025-01-15 20:25:33', '2025-01-15 20:25:33'),
(134, 56, 77, 1000000000133, 'Đã sử dụng', '2025-01-03 09:22:11', '2025-01-03 09:22:11'),
(135, 56, 79, 1000000000134, 'Đã sử dụng', '2025-01-03 09:22:11', '2025-01-03 09:22:11'),
(136, 56, 81, 1000000000135, 'Đã sử dụng', '2025-01-03 09:22:11', '2025-01-03 09:22:11'),
(137, 57, 83, 1000000000136, 'Đã sử dụng', '2025-01-03 14:33:44', '2025-01-03 14:33:44'),
(138, 57, 85, 1000000000137, 'Đã sử dụng', '2025-01-03 14:33:44', '2025-01-03 14:33:44'),
(139, 57, 87, 1000000000138, 'Đã sử dụng', '2025-01-03 14:33:44', '2025-01-03 14:33:44'),
(140, 58, 89, 1000000000139, 'Đã sử dụng', '2025-01-04 10:55:22', '2025-01-04 10:55:22'),
(141, 58, 91, 1000000000140, 'Đã sử dụng', '2025-01-04 10:55:22', '2025-01-04 10:55:22'),
(142, 59, 93, 1000000000141, 'Đã sử dụng', '2025-01-04 17:11:33', '2025-01-04 17:11:33'),
(143, 59, 95, 1000000000142, 'Đã sử dụng', '2025-01-04 17:11:33', '2025-01-04 17:11:33'),
(144, 60, 97, 1000000000143, 'Đã sử dụng', '2025-01-05 11:44:55', '2025-01-05 11:44:55'),
(145, 60, 99, 1000000000144, 'Đã sử dụng', '2025-01-05 11:44:55', '2025-01-05 11:44:55'),
(146, 60, 101, 1000000000145, 'Đã sử dụng', '2025-01-05 11:44:55', '2025-01-05 11:44:55'),
(147, 61, 1, 1000000000146, 'Đã sử dụng', '2025-01-17 09:18:33', '2025-01-17 09:18:33'),
(148, 61, 3, 1000000000147, 'Đã sử dụng', '2025-01-17 09:18:33', '2025-01-17 09:18:33'),
(149, 61, 5, 1000000000148, 'Đã sử dụng', '2025-01-17 09:18:33', '2025-01-17 09:18:33'),
(150, 62, 7, 1000000000149, 'Đã sử dụng', '2025-01-17 15:29:11', '2025-01-17 15:29:11'),
(151, 62, 9, 1000000000150, 'Đã sử dụng', '2025-01-17 15:29:11', '2025-01-17 15:29:11'),
(152, 62, 11, 1000000000151, 'Đã sử dụng', '2025-01-17 15:29:11', '2025-01-17 15:29:11'),
(153, 63, 13, 1000000000152, 'Đã sử dụng', '2025-01-18 10:22:08', '2025-01-18 10:22:08'),
(154, 63, 15, 1000000000153, 'Đã sử dụng', '2025-01-18 10:22:08', '2025-01-18 10:22:08'),
(155, 63, 17, 1000000000154, 'Đã sử dụng', '2025-01-18 10:22:08', '2025-01-18 10:22:08'),
(156, 64, 19, 1000000000155, 'Đã sử dụng', '2025-01-18 16:33:44', '2025-01-18 16:33:44'),
(157, 64, 21, 1000000000156, 'Đã sử dụng', '2025-01-18 16:33:44', '2025-01-18 16:33:44'),
(158, 65, 23, 1000000000157, 'Đã sử dụng', '2025-01-19 11:55:22', '2025-01-19 11:55:22'),
(159, 65, 25, 1000000000158, 'Đã sử dụng', '2025-01-19 11:55:22', '2025-01-19 11:55:22'),
(160, 65, 27, 1000000000159, 'Đã sử dụng', '2025-01-19 11:55:22', '2025-01-19 11:55:22'),
(161, 66, 29, 1000000000160, 'Đã sử dụng', '2025-01-19 18:11:33', '2025-01-19 18:11:33'),
(162, 66, 31, 1000000000161, 'Đã sử dụng', '2025-01-19 18:11:33', '2025-01-19 18:11:33'),
(163, 67, 33, 1000000000162, 'Đã sử dụng', '2025-01-20 09:44:55', '2025-01-20 09:44:55'),
(164, 67, 35, 1000000000163, 'Đã sử dụng', '2025-01-20 09:44:55', '2025-01-20 09:44:55'),
(165, 67, 37, 1000000000164, 'Đã sử dụng', '2025-01-20 09:44:55', '2025-01-20 09:44:55'),
(166, 68, 39, 1000000000165, 'Đã sử dụng', '2025-01-20 14:22:11', '2025-01-20 14:22:11'),
(167, 68, 41, 1000000000166, 'Đã sử dụng', '2025-01-20 14:22:11', '2025-01-20 14:22:11'),
(168, 69, 53, 1000000000167, 'Đã sử dụng', '2025-01-04 10:18:22', '2025-01-04 10:18:22'),
(169, 69, 55, 1000000000168, 'Đã sử dụng', '2025-01-04 10:18:22', '2025-01-04 10:18:22'),
(170, 69, 57, 1000000000169, 'Đã sử dụng', '2025-01-04 10:18:22', '2025-01-04 10:18:22'),
(171, 70, 59, 1000000000170, 'Đã sử dụng', '2025-01-04 15:29:11', '2025-01-04 15:29:11'),
(172, 70, 61, 1000000000171, 'Đã sử dụng', '2025-01-04 15:29:11', '2025-01-04 15:29:11'),
(173, 70, 63, 1000000000172, 'Đã sử dụng', '2025-01-04 15:29:11', '2025-01-04 15:29:11'),
(174, 71, 65, 1000000000173, 'Đã sử dụng', '2025-01-05 09:44:55', '2025-01-05 09:44:55'),
(175, 71, 67, 1000000000174, 'Đã sử dụng', '2025-01-05 09:44:55', '2025-01-05 09:44:55'),
(176, 72, 69, 1000000000175, 'Đã sử dụng', '2025-01-05 14:33:22', '2025-01-05 14:33:22'),
(177, 72, 107, 1000000000176, 'Đã sử dụng', '2025-01-05 14:33:22', '2025-01-05 14:33:22'),
(178, 73, 109, 1000000000177, 'Đã sử dụng', '2025-01-06 11:22:08', '2025-01-06 11:22:08'),
(179, 73, 111, 1000000000178, 'Đã sử dụng', '2025-01-06 11:22:08', '2025-01-06 11:22:08'),
(180, 73, 113, 1000000000179, 'Đã sử dụng', '2025-01-06 11:22:08', '2025-01-06 11:22:08'),
(181, 75, 1, 1000000000180, 'Đã sử dụng', '2025-01-18 09:33:11', '2025-01-18 09:33:11'),
(182, 75, 3, 1000000000181, 'Đã sử dụng', '2025-01-18 09:33:11', '2025-01-18 09:33:11'),
(183, 75, 5, 1000000000182, 'Đã sử dụng', '2025-01-18 09:33:11', '2025-01-18 09:33:11'),
(184, 76, 7, 1000000000183, 'Đã sử dụng', '2025-01-18 14:44:55', '2025-01-18 14:44:55'),
(185, 76, 9, 1000000000184, 'Đã sử dụng', '2025-01-18 14:44:55', '2025-01-18 14:44:55'),
(186, 76, 11, 1000000000185, 'Đã sử dụng', '2025-01-18 14:44:55', '2025-01-18 14:44:55'),
(187, 77, 13, 1000000000186, 'Đã sử dụng', '2025-01-19 10:55:22', '2025-01-19 10:55:22'),
(188, 77, 15, 1000000000187, 'Đã sử dụng', '2025-01-19 10:55:22', '2025-01-19 10:55:22'),
(189, 77, 17, 1000000000188, 'Đã sử dụng', '2025-01-19 10:55:22', '2025-01-19 10:55:22'),
(190, 78, 19, 1000000000189, 'Đã sử dụng', '2025-01-19 17:11:33', '2025-01-19 17:11:33'),
(191, 78, 21, 1000000000190, 'Đã sử dụng', '2025-01-19 17:11:33', '2025-01-19 17:11:33'),
(192, 78, 23, 1000000000191, 'Đã sử dụng', '2025-01-19 17:11:33', '2025-01-19 17:11:33'),
(193, 79, 1, 1000000000192, 'Đã sử dụng', '2025-01-20 11:22:08', '2025-01-20 11:22:08'),
(194, 79, 3, 1000000000193, 'Đã sử dụng', '2025-01-20 11:22:08', '2025-01-20 11:22:08'),
(195, 80, 5, 1000000000194, 'Đã sử dụng', '2025-01-20 18:33:44', '2025-01-20 18:33:44'),
(196, 80, 7, 1000000000195, 'Đã sử dụng', '2025-01-20 18:33:44', '2025-01-20 18:33:44'),
(197, 80, 9, 1000000000196, 'Đã sử dụng', '2025-01-20 18:33:44', '2025-01-20 18:33:44'),
(198, 81, 11, 1000000000197, 'Đã sử dụng', '2025-01-21 09:44:55', '2025-01-21 09:44:55'),
(199, 82, 53, 1000000000198, 'Đã sử dụng', '2025-01-03 10:15:22', '2025-01-03 10:15:22'),
(200, 82, 55, 1000000000199, 'Đã sử dụng', '2025-01-03 10:15:22', '2025-01-03 10:15:22'),
(201, 82, 57, 1000000000200, 'Đã sử dụng', '2025-01-03 10:15:22', '2025-01-03 10:15:22'),
(202, 83, 59, 1000000000201, 'Đã sử dụng', '2025-01-03 15:33:11', '2025-01-03 15:33:11'),
(203, 83, 61, 1000000000202, 'Đã sử dụng', '2025-01-03 15:33:11', '2025-01-03 15:33:11'),
(204, 83, 63, 1000000000203, 'Đã sử dụng', '2025-01-03 15:33:11', '2025-01-03 15:33:11'),
(205, 84, 65, 1000000000204, 'Đã sử dụng', '2025-01-04 09:22:33', '2025-01-04 09:22:33'),
(206, 84, 67, 1000000000205, 'Đã sử dụng', '2025-01-04 09:22:33', '2025-01-04 09:22:33'),
(207, 85, 69, 1000000000206, 'Đã sử dụng', '2025-01-04 14:44:11', '2025-01-04 14:44:11'),
(208, 85, 71, 1000000000207, 'Đã sử dụng', '2025-01-04 14:44:11', '2025-01-04 14:44:11'),
(209, 86, 73, 1000000000208, 'Đã sử dụng', '2025-01-05 11:55:22', '2025-01-05 11:55:22'),
(210, 86, 107, 1000000000209, 'Đã sử dụng', '2025-01-05 11:55:22', '2025-01-05 11:55:22'),
(211, 86, 109, 1000000000210, 'Đã sử dụng', '2025-01-05 11:55:22', '2025-01-05 11:55:22'),
(212, 87, 111, 1000000000211, 'Đã sử dụng', '2025-01-05 17:22:44', '2025-01-05 17:22:44'),
(213, 87, 113, 1000000000212, 'Đã sử dụng', '2025-01-05 17:22:44', '2025-01-05 17:22:44'),
(214, 88, 1, 1000000000213, 'Đã sử dụng', '2025-01-17 09:11:33', '2025-01-17 09:11:33'),
(215, 88, 3, 1000000000214, 'Đã sử dụng', '2025-01-17 09:11:33', '2025-01-17 09:11:33'),
(216, 88, 5, 1000000000215, 'Đã sử dụng', '2025-01-17 09:11:33', '2025-01-17 09:11:33'),
(217, 89, 7, 1000000000216, 'Đã sử dụng', '2025-01-17 14:22:08', '2025-01-17 14:22:08'),
(218, 89, 9, 1000000000217, 'Đã sử dụng', '2025-01-17 14:22:08', '2025-01-17 14:22:08'),
(219, 89, 11, 1000000000218, 'Đã sử dụng', '2025-01-17 14:22:08', '2025-01-17 14:22:08'),
(220, 90, 13, 1000000000219, 'Đã sử dụng', '2025-01-18 10:33:55', '2025-01-18 10:33:55'),
(221, 90, 15, 1000000000220, 'Đã sử dụng', '2025-01-18 10:33:55', '2025-01-18 10:33:55'),
(222, 90, 17, 1000000000221, 'Đã sử dụng', '2025-01-18 10:33:55', '2025-01-18 10:33:55'),
(223, 91, 19, 1000000000222, 'Đã sử dụng', '2025-01-18 16:44:22', '2025-01-18 16:44:22'),
(224, 91, 21, 1000000000223, 'Đã sử dụng', '2025-01-18 16:44:22', '2025-01-18 16:44:22'),
(225, 91, 23, 1000000000224, 'Đã sử dụng', '2025-01-18 16:44:22', '2025-01-18 16:44:22'),
(226, 92, 1, 1000000000225, 'Đã sử dụng', '2025-01-19 11:55:33', '2025-01-19 11:55:33'),
(227, 92, 3, 1000000000226, 'Đã sử dụng', '2025-01-19 11:55:33', '2025-01-19 11:55:33'),
(228, 93, 5, 1000000000227, 'Đã sử dụng', '2025-01-19 18:11:44', '2025-01-19 18:11:44'),
(229, 93, 7, 1000000000228, 'Đã sử dụng', '2025-01-19 18:11:44', '2025-01-19 18:11:44'),
(230, 93, 9, 1000000000229, 'Đã sử dụng', '2025-01-19 18:11:44', '2025-01-19 18:11:44'),
(231, 94, 11, 1000000000230, 'Đã sử dụng', '2025-01-20 09:22:11', '2025-01-20 09:22:11'),
(232, 95, 1, 1000000000255, 'Đã sử dụng', '2025-02-15 09:11:22', '2025-02-15 09:11:22'),
(233, 95, 3, 1000000000256, 'Đã sử dụng', '2025-02-15 09:11:22', '2025-02-15 09:11:22'),
(234, 95, 5, 1000000000257, 'Đã sử dụng', '2025-02-15 09:11:22', '2025-02-15 09:11:22'),
(235, 96, 7, 1000000000258, 'Đã sử dụng', '2025-02-15 14:33:44', '2025-02-15 14:33:44'),
(236, 96, 9, 1000000000259, 'Đã sử dụng', '2025-02-15 14:33:44', '2025-02-15 14:33:44'),
(237, 96, 11, 1000000000260, 'Đã sử dụng', '2025-02-15 14:33:44', '2025-02-15 14:33:44'),
(238, 97, 13, 1000000000261, 'Đã sử dụng', '2025-02-16 10:22:08', '2025-02-16 10:22:08'),
(239, 97, 15, 1000000000262, 'Đã sử dụng', '2025-02-16 10:22:08', '2025-02-16 10:22:08'),
(240, 97, 17, 1000000000263, 'Đã sử dụng', '2025-02-16 10:22:08', '2025-02-16 10:22:08'),
(241, 98, 19, 1000000000264, 'Đã sử dụng', '2025-02-16 17:55:33', '2025-02-16 17:55:33'),
(242, 98, 21, 1000000000265, 'Đã sử dụng', '2025-02-16 17:55:33', '2025-02-16 17:55:33'),
(243, 98, 23, 1000000000266, 'Đã sử dụng', '2025-02-16 17:55:33', '2025-02-16 17:55:33'),
(244, 99, 1, 1000000000267, 'Đã sử dụng', '2025-02-17 11:44:55', '2025-02-17 11:44:55'),
(245, 99, 3, 1000000000268, 'Đã sử dụng', '2025-02-17 11:44:55', '2025-02-17 11:44:55'),
(246, 100, 5, 1000000000269, 'Đã sử dụng', '2025-02-17 18:22:11', '2025-02-17 18:22:11'),
(247, 100, 7, 1000000000270, 'Đã sử dụng', '2025-02-17 18:22:11', '2025-02-17 18:22:11'),
(248, 100, 9, 1000000000271, 'Đã sử dụng', '2025-02-17 18:22:11', '2025-02-17 18:22:11'),
(249, 101, 53, 1000000000272, 'Đã sử dụng', '2025-02-01 09:33:11', '2025-02-01 09:33:11'),
(250, 101, 55, 1000000000273, 'Đã sử dụng', '2025-02-01 09:33:11', '2025-02-01 09:33:11'),
(251, 101, 57, 1000000000274, 'Đã sử dụng', '2025-02-01 09:33:11', '2025-02-01 09:33:11'),
(252, 102, 59, 1000000000275, 'Đã sử dụng', '2025-02-01 15:44:55', '2025-02-01 15:44:55'),
(253, 102, 61, 1000000000276, 'Đã sử dụng', '2025-02-01 15:44:55', '2025-02-01 15:44:55'),
(254, 102, 63, 1000000000277, 'Đã sử dụng', '2025-02-01 15:44:55', '2025-02-01 15:44:55'),
(255, 103, 65, 1000000000278, 'Đã sử dụng', '2025-02-02 10:55:22', '2025-02-02 10:55:22'),
(256, 103, 67, 1000000000279, 'Đã sử dụng', '2025-02-02 10:55:22', '2025-02-02 10:55:22'),
(257, 104, 69, 1000000000280, 'Đã sử dụng', '2025-02-02 16:11:33', '2025-02-02 16:11:33'),
(258, 104, 107, 1000000000281, 'Đã sử dụng', '2025-02-02 16:11:33', '2025-02-02 16:11:33'),
(259, 105, 109, 1000000000282, 'Đã sử dụng', '2025-02-03 11:22:08', '2025-02-03 11:22:08'),
(260, 105, 111, 1000000000283, 'Đã sử dụng', '2025-02-03 11:22:08', '2025-02-03 11:22:08'),
(261, 105, 113, 1000000000284, 'Đã sử dụng', '2025-02-03 11:22:08', '2025-02-03 11:22:08'),
(262, 106, 77, 1000000000285, 'Đã sử dụng', '2025-02-22 09:18:33', '2025-02-22 09:18:33'),
(263, 106, 79, 1000000000286, 'Đã sử dụng', '2025-02-22 09:18:33', '2025-02-22 09:18:33'),
(264, 106, 81, 1000000000287, 'Đã sử dụng', '2025-02-22 09:18:33', '2025-02-22 09:18:33'),
(265, 107, 83, 1000000000288, 'Đã sử dụng', '2025-02-22 14:29:11', '2025-02-22 14:29:11'),
(266, 107, 85, 1000000000289, 'Đã sử dụng', '2025-02-22 14:29:11', '2025-02-22 14:29:11'),
(267, 107, 87, 1000000000290, 'Đã sử dụng', '2025-02-22 14:29:11', '2025-02-22 14:29:11'),
(268, 108, 89, 1000000000291, 'Đã sử dụng', '2025-02-23 10:44:55', '2025-02-23 10:44:55'),
(269, 108, 91, 1000000000292, 'Đã sử dụng', '2025-02-23 10:44:55', '2025-02-23 10:44:55'),
(270, 109, 77, 1000000000293, 'Đã sử dụng', '2025-02-23 17:33:22', '2025-02-23 17:33:22'),
(271, 109, 79, 1000000000294, 'Đã sử dụng', '2025-02-23 17:33:22', '2025-02-23 17:33:22'),
(272, 110, 1, 1000000000295, 'Đã sử dụng', '2025-02-08 09:22:33', '2025-02-08 09:22:33'),
(273, 110, 3, 1000000000296, 'Đã sử dụng', '2025-02-08 09:22:33', '2025-02-08 09:22:33'),
(274, 110, 5, 1000000000297, 'Đã sử dụng', '2025-02-08 09:22:33', '2025-02-08 09:22:33'),
(275, 111, 7, 1000000000298, 'Đã sử dụng', '2025-02-08 15:33:11', '2025-02-08 15:33:11'),
(276, 111, 9, 1000000000299, 'Đã sử dụng', '2025-02-08 15:33:11', '2025-02-08 15:33:11'),
(277, 111, 11, 1000000000300, 'Đã sử dụng', '2025-02-08 15:33:11', '2025-02-08 15:33:11'),
(278, 112, 13, 1000000000301, 'Đã sử dụng', '2025-02-09 10:55:22', '2025-02-09 10:55:22'),
(279, 112, 15, 1000000000302, 'Đã sử dụng', '2025-02-09 10:55:22', '2025-02-09 10:55:22'),
(280, 112, 17, 1000000000303, 'Đã sử dụng', '2025-02-09 10:55:22', '2025-02-09 10:55:22'),
(281, 113, 19, 1000000000304, 'Đã sử dụng', '2025-02-09 17:11:44', '2025-02-09 17:11:44'),
(282, 113, 21, 1000000000305, 'Đã sử dụng', '2025-02-09 17:11:44', '2025-02-09 17:11:44'),
(283, 114, 1, 1000000000306, 'Đã sử dụng', '2025-02-10 11:33:55', '2025-02-10 11:33:55'),
(284, 114, 3, 1000000000307, 'Đã sử dụng', '2025-02-10 11:33:55', '2025-02-10 11:33:55'),
(285, 115, 5, 1000000000308, 'Đã sử dụng', '2025-02-10 18:44:22', '2025-02-10 18:44:22'),
(286, 115, 7, 1000000000309, 'Đã sử dụng', '2025-02-10 18:44:22', '2025-02-10 18:44:22'),
(287, 116, 53, 1000000000310, 'Đã sử dụng', '2025-02-15 10:18:22', '2025-02-15 10:18:22'),
(288, 116, 55, 1000000000311, 'Đã sử dụng', '2025-02-15 10:18:22', '2025-02-15 10:18:22'),
(289, 116, 57, 1000000000312, 'Đã sử dụng', '2025-02-15 10:18:22', '2025-02-15 10:18:22'),
(290, 117, 59, 1000000000313, 'Đã sử dụng', '2025-02-15 15:29:11', '2025-02-15 15:29:11'),
(291, 117, 61, 1000000000314, 'Đã sử dụng', '2025-02-15 15:29:11', '2025-02-15 15:29:11'),
(292, 117, 63, 1000000000315, 'Đã sử dụng', '2025-02-15 15:29:11', '2025-02-15 15:29:11'),
(293, 118, 65, 1000000000316, 'Đã sử dụng', '2025-02-16 09:44:55', '2025-02-16 09:44:55'),
(294, 118, 67, 1000000000317, 'Đã sử dụng', '2025-02-16 09:44:55', '2025-02-16 09:44:55'),
(295, 118, 69, 1000000000318, 'Đã sử dụng', '2025-02-16 09:44:55', '2025-02-16 09:44:55'),
(296, 119, 71, 1000000000319, 'Đã sử dụng', '2025-02-16 14:33:22', '2025-02-16 14:33:22'),
(297, 119, 73, 1000000000320, 'Đã sử dụng', '2025-02-16 14:33:22', '2025-02-16 14:33:22'),
(298, 119, 107, 1000000000321, 'Đã sử dụng', '2025-02-16 14:33:22', '2025-02-16 14:33:22'),
(299, 120, 109, 1000000000322, 'Đã sử dụng', '2025-02-17 11:22:08', '2025-02-17 11:22:08'),
(300, 121, 111, 1000000000323, 'Đã sử dụng', '2025-02-17 17:55:44', '2025-02-17 17:55:44'),
(301, 122, 1, 1000000000324, 'Đã sử dụng', '2025-02-28 09:11:33', '2025-02-28 09:11:33'),
(302, 122, 3, 1000000000325, 'Đã sử dụng', '2025-02-28 09:11:33', '2025-02-28 09:11:33'),
(303, 122, 5, 1000000000326, 'Đã sử dụng', '2025-02-28 09:11:33', '2025-02-28 09:11:33'),
(304, 123, 7, 1000000000327, 'Đã sử dụng', '2025-02-28 14:22:08', '2025-02-28 14:22:08'),
(305, 123, 9, 1000000000328, 'Đã sử dụng', '2025-02-28 14:22:08', '2025-02-28 14:22:08'),
(306, 123, 11, 1000000000329, 'Đã sử dụng', '2025-02-28 14:22:08', '2025-02-28 14:22:08'),
(307, 124, 13, 1000000000330, 'Đã sử dụng', '2025-02-28 15:00:00', '2025-02-28 15:00:00'),
(308, 124, 15, 1000000000331, 'Đã sử dụng', '2025-02-28 15:00:00', '2025-02-28 15:00:00'),
(309, 124, 17, 1000000000332, 'Đã sử dụng', '2025-02-28 15:00:00', '2025-02-28 15:00:00'),
(310, 125, 19, 1000000000333, 'Đã sử dụng', '2025-02-28 15:30:00', '2025-02-28 15:30:00'),
(311, 125, 21, 1000000000334, 'Đã sử dụng', '2025-02-28 15:30:00', '2025-02-28 15:30:00'),
(312, 125, 23, 1000000000335, 'Đã sử dụng', '2025-02-28 15:30:00', '2025-02-28 15:30:00'),
(313, 126, 1, 1000000000336, 'Đã sử dụng', '2025-03-01 11:55:33', '2025-03-01 11:55:33'),
(314, 126, 3, 1000000000337, 'Đã sử dụng', '2025-03-01 11:55:33', '2025-03-01 11:55:33'),
(315, 127, 5, 1000000000338, 'Đã sử dụng', '2025-03-01 18:11:44', '2025-03-01 18:11:44'),
(316, 127, 7, 1000000000339, 'Đã sử dụng', '2025-03-01 18:11:44', '2025-03-01 18:11:44'),
(317, 127, 9, 1000000000340, 'Đã sử dụng', '2025-03-01 18:11:44', '2025-03-01 18:11:44'),
(318, 128, 11, 1000000000341, 'Đã sử dụng', '2025-03-02 09:22:11', '2025-03-02 09:22:11'),
(319, 129, 1, 1000000000376, 'Đã sử dụng', '2025-03-15 09:22:11', '2025-03-15 09:22:11'),
(320, 129, 3, 1000000000377, 'Đã sử dụng', '2025-03-15 09:22:11', '2025-03-15 09:22:11'),
(321, 129, 5, 1000000000378, 'Đã sử dụng', '2025-03-15 09:22:11', '2025-03-15 09:22:11'),
(322, 130, 7, 1000000000379, 'Đã sử dụng', '2025-03-15 14:33:44', '2025-03-15 14:33:44'),
(323, 130, 9, 1000000000380, 'Đã sử dụng', '2025-03-15 14:33:44', '2025-03-15 14:33:44'),
(324, 130, 11, 1000000000381, 'Đã sử dụng', '2025-03-15 14:33:44', '2025-03-15 14:33:44'),
(325, 131, 13, 1000000000382, 'Đã sử dụng', '2025-03-16 10:55:22', '2025-03-16 10:55:22'),
(326, 131, 15, 1000000000383, 'Đã sử dụng', '2025-03-16 10:55:22', '2025-03-16 10:55:22'),
(327, 131, 17, 1000000000384, 'Đã sử dụng', '2025-03-16 10:55:22', '2025-03-16 10:55:22'),
(328, 132, 19, 1000000000385, 'Đã sử dụng', '2025-03-16 17:11:33', '2025-03-16 17:11:33'),
(329, 132, 21, 1000000000386, 'Đã sử dụng', '2025-03-16 17:11:33', '2025-03-16 17:11:33'),
(330, 132, 23, 1000000000387, 'Đã sử dụng', '2025-03-16 17:11:33', '2025-03-16 17:11:33'),
(331, 133, 1, 1000000000388, 'Đã sử dụng', '2025-03-17 11:44:55', '2025-03-17 11:44:55'),
(332, 133, 3, 1000000000389, 'Đã sử dụng', '2025-03-17 11:44:55', '2025-03-17 11:44:55'),
(333, 134, 5, 1000000000390, 'Đã sử dụng', '2025-03-17 18:22:08', '2025-03-17 18:22:08'),
(334, 134, 7, 1000000000391, 'Đã sử dụng', '2025-03-17 18:22:08', '2025-03-17 18:22:08'),
(335, 134, 9, 1000000000392, 'Đã sử dụng', '2025-03-17 18:22:08', '2025-03-17 18:22:08'),
(336, 135, 53, 1000000000393, 'Đã sử dụng', '2025-03-01 09:18:33', '2025-03-01 09:18:33'),
(337, 135, 55, 1000000000394, 'Đã sử dụng', '2025-03-01 09:18:33', '2025-03-01 09:18:33'),
(338, 135, 57, 1000000000395, 'Đã sử dụng', '2025-03-01 09:18:33', '2025-03-01 09:18:33'),
(339, 136, 59, 1000000000396, 'Đã sử dụng', '2025-03-01 15:29:11', '2025-03-01 15:29:11'),
(340, 136, 61, 1000000000397, 'Đã sử dụng', '2025-03-01 15:29:11', '2025-03-01 15:29:11'),
(341, 136, 63, 1000000000398, 'Đã sử dụng', '2025-03-01 15:29:11', '2025-03-01 15:29:11'),
(342, 137, 65, 1000000000399, 'Đã sử dụng', '2025-03-02 10:44:55', '2025-03-02 10:44:55'),
(343, 137, 67, 1000000000400, 'Đã sử dụng', '2025-03-02 10:44:55', '2025-03-02 10:44:55'),
(344, 138, 69, 1000000000401, 'Đã sử dụng', '2025-03-02 16:33:22', '2025-03-02 16:33:22'),
(345, 138, 107, 1000000000402, 'Đã sử dụng', '2025-03-02 16:33:22', '2025-03-02 16:33:22'),
(346, 139, 109, 1000000000403, 'Đã sử dụng', '2025-03-03 11:55:33', '2025-03-03 11:55:33'),
(347, 139, 111, 1000000000404, 'Đã sử dụng', '2025-03-03 11:55:33', '2025-03-03 11:55:33'),
(348, 139, 113, 1000000000405, 'Đã sử dụng', '2025-03-03 11:55:33', '2025-03-03 11:55:33'),
(349, 140, 77, 1000000000406, 'Đã sử dụng', '2025-03-22 09:33:11', '2025-03-22 09:33:11'),
(350, 140, 79, 1000000000407, 'Đã sử dụng', '2025-03-22 09:33:11', '2025-03-22 09:33:11'),
(351, 140, 81, 1000000000408, 'Đã sử dụng', '2025-03-22 09:33:11', '2025-03-22 09:33:11'),
(352, 141, 83, 1000000000409, 'Đã sử dụng', '2025-03-22 14:44:55', '2025-03-22 14:44:55'),
(353, 141, 85, 1000000000410, 'Đã sử dụng', '2025-03-22 14:44:55', '2025-03-22 14:44:55'),
(354, 142, 87, 1000000000411, 'Đã sử dụng', '2025-03-23 10:22:08', '2025-03-23 10:22:08'),
(355, 142, 89, 1000000000412, 'Đã sử dụng', '2025-03-23 10:22:08', '2025-03-23 10:22:08'),
(356, 143, 77, 1000000000413, 'Đã sử dụng', '2025-03-23 17:11:33', '2025-03-23 17:11:33'),
(357, 143, 79, 1000000000414, 'Đã sử dụng', '2025-03-23 17:11:33', '2025-03-23 17:11:33'),
(358, 144, 1, 1000000000415, 'Đã sử dụng', '2025-03-08 09:11:22', '2025-03-08 09:11:22'),
(359, 144, 3, 1000000000416, 'Đã sử dụng', '2025-03-08 09:11:22', '2025-03-08 09:11:22'),
(360, 144, 5, 1000000000417, 'Đã sử dụng', '2025-03-08 09:11:22', '2025-03-08 09:11:22'),
(361, 145, 7, 1000000000418, 'Đã sử dụng', '2025-03-08 15:22:44', '2025-03-08 15:22:44'),
(362, 145, 9, 1000000000419, 'Đã sử dụng', '2025-03-08 15:22:44', '2025-03-08 15:22:44'),
(363, 145, 11, 1000000000420, 'Đã sử dụng', '2025-03-08 15:22:44', '2025-03-08 15:22:44'),
(364, 146, 13, 1000000000421, 'Đã sử dụng', '2025-03-09 10:33:55', '2025-03-09 10:33:55'),
(365, 146, 15, 1000000000422, 'Đã sử dụng', '2025-03-09 10:33:55', '2025-03-09 10:33:55'),
(366, 146, 17, 1000000000423, 'Đã sử dụng', '2025-03-09 10:33:55', '2025-03-09 10:33:55'),
(367, 147, 19, 1000000000424, 'Đã sử dụng', '2025-03-09 16:44:22', '2025-03-09 16:44:22'),
(368, 147, 21, 1000000000425, 'Đã sử dụng', '2025-03-09 16:44:22', '2025-03-09 16:44:22'),
(369, 147, 23, 1000000000426, 'Đã sử dụng', '2025-03-09 16:44:22', '2025-03-09 16:44:22'),
(370, 148, 25, 1000000000427, 'Đã sử dụng', '2025-03-10 11:55:33', '2025-03-10 11:55:33'),
(371, 148, 27, 1000000000428, 'Đã sử dụng', '2025-03-10 11:55:33', '2025-03-10 11:55:33'),
(372, 149, 29, 1000000000429, 'Đã sử dụng', '2025-03-10 18:11:44', '2025-03-10 18:11:44'),
(373, 149, 31, 1000000000430, 'Đã sử dụng', '2025-03-10 18:11:44', '2025-03-10 18:11:44'),
(374, 149, 33, 1000000000431, 'Đã sử dụng', '2025-03-10 18:11:44', '2025-03-10 18:11:44'),
(375, 150, 35, 1000000000432, 'Đã sử dụng', '2025-03-11 09:22:11', '2025-03-11 09:22:11'),
(376, 150, 37, 1000000000433, 'Đã sử dụng', '2025-03-11 09:22:11', '2025-03-11 09:22:11'),
(377, 151, 53, 1000000000434, 'Đã sử dụng', '2025-03-15 10:18:22', '2025-03-15 10:18:22'),
(378, 151, 55, 1000000000435, 'Đã sử dụng', '2025-03-15 10:18:22', '2025-03-15 10:18:22'),
(379, 151, 57, 1000000000436, 'Đã sử dụng', '2025-03-15 10:18:22', '2025-03-15 10:18:22'),
(380, 152, 59, 1000000000437, 'Đã sử dụng', '2025-03-15 15:29:11', '2025-03-15 15:29:11'),
(381, 152, 61, 1000000000438, 'Đã sử dụng', '2025-03-15 15:29:11', '2025-03-15 15:29:11'),
(382, 152, 63, 1000000000439, 'Đã sử dụng', '2025-03-15 15:29:11', '2025-03-15 15:29:11'),
(383, 153, 65, 1000000000440, 'Đã sử dụng', '2025-03-16 09:44:55', '2025-03-16 09:44:55'),
(384, 153, 67, 1000000000441, 'Đã sử dụng', '2025-03-16 09:44:55', '2025-03-16 09:44:55'),
(385, 154, 107, 1000000000442, 'Đã sử dụng', '2025-03-16 14:33:22', '2025-03-16 14:33:22'),
(386, 155, 1, 1000000000443, 'Đã sử dụng', '2025-03-29 09:11:33', '2025-03-29 09:11:33'),
(387, 155, 3, 1000000000444, 'Đã sử dụng', '2025-03-29 09:11:33', '2025-03-29 09:11:33'),
(388, 155, 5, 1000000000445, 'Đã sử dụng', '2025-03-29 09:11:33', '2025-03-29 09:11:33'),
(389, 156, 7, 1000000000446, 'Đã sử dụng', '2025-03-29 14:22:08', '2025-03-29 14:22:08'),
(390, 156, 9, 1000000000447, 'Đã sử dụng', '2025-03-29 14:22:08', '2025-03-29 14:22:08'),
(391, 156, 11, 1000000000448, 'Đã sử dụng', '2025-03-29 14:22:08', '2025-03-29 14:22:08'),
(392, 157, 13, 1000000000449, 'Đã sử dụng', '2025-03-30 10:33:55', '2025-03-30 10:33:55'),
(393, 157, 15, 1000000000450, 'Đã sử dụng', '2025-03-30 10:33:55', '2025-03-30 10:33:55'),
(394, 157, 17, 1000000000451, 'Đã sử dụng', '2025-03-30 10:33:55', '2025-03-30 10:33:55'),
(395, 158, 19, 1000000000452, 'Đã sử dụng', '2025-03-30 16:44:22', '2025-03-30 16:44:22'),
(396, 158, 21, 1000000000453, 'Đã sử dụng', '2025-03-30 16:44:22', '2025-03-30 16:44:22'),
(397, 158, 23, 1000000000454, 'Đã sử dụng', '2025-03-30 16:44:22', '2025-03-30 16:44:22'),
(398, 159, 1, 1000000000455, 'Đã sử dụng', '2025-03-31 11:55:33', '2025-03-31 11:55:33'),
(399, 159, 3, 1000000000456, 'Đã sử dụng', '2025-03-31 11:55:33', '2025-03-31 11:55:33'),
(400, 160, 5, 1000000000457, 'Đã sử dụng', '2025-03-31 18:11:44', '2025-03-31 18:11:44'),
(401, 160, 7, 1000000000458, 'Đã sử dụng', '2025-03-31 18:11:44', '2025-03-31 18:11:44'),
(402, 160, 9, 1000000000459, 'Đã sử dụng', '2025-03-31 18:11:44', '2025-03-31 18:11:44'),
(403, 161, 11, 1000000000460, 'Đã sử dụng', '2025-04-01 09:22:11', '2025-04-01 09:22:11'),
(404, 162, 1, 1000000000498, 'Đã sử dụng', '2025-04-17 09:11:33', '2025-04-17 09:11:33'),
(405, 162, 3, 1000000000499, 'Đã sử dụng', '2025-04-17 09:11:33', '2025-04-17 09:11:33'),
(406, 162, 5, 1000000000500, 'Đã sử dụng', '2025-04-17 09:11:33', '2025-04-17 09:11:33'),
(407, 163, 7, 1000000000501, 'Đã sử dụng', '2025-04-17 14:22:08', '2025-04-17 14:22:08'),
(408, 163, 9, 1000000000502, 'Đã sử dụng', '2025-04-17 14:22:08', '2025-04-17 14:22:08'),
(409, 163, 11, 1000000000503, 'Đã sử dụng', '2025-04-17 14:22:08', '2025-04-17 14:22:08'),
(410, 164, 13, 1000000000504, 'Đã sử dụng', '2025-04-18 10:33:55', '2025-04-18 10:33:55'),
(411, 164, 15, 1000000000505, 'Đã sử dụng', '2025-04-18 10:33:55', '2025-04-18 10:33:55'),
(412, 164, 17, 1000000000506, 'Đã sử dụng', '2025-04-18 10:33:55', '2025-04-18 10:33:55'),
(413, 165, 19, 1000000000507, 'Đã sử dụng', '2025-04-18 16:44:22', '2025-04-18 16:44:22'),
(414, 165, 21, 1000000000508, 'Đã sử dụng', '2025-04-18 16:44:22', '2025-04-18 16:44:22'),
(415, 165, 23, 1000000000509, 'Đã sử dụng', '2025-04-18 16:44:22', '2025-04-18 16:44:22'),
(416, 166, 25, 1000000000510, 'Đã sử dụng', '2025-04-19 11:55:33', '2025-04-19 11:55:33'),
(417, 166, 1, 1000000000511, 'Đã sử dụng', '2025-04-19 11:55:33', '2025-04-19 11:55:33'),
(418, 167, 3, 1000000000512, 'Đã sử dụng', '2025-04-19 18:11:44', '2025-04-19 18:11:44'),
(419, 167, 5, 1000000000513, 'Đã sử dụng', '2025-04-19 18:11:44', '2025-04-19 18:11:44'),
(420, 167, 7, 1000000000514, 'Đã sử dụng', '2025-04-19 18:11:44', '2025-04-19 18:11:44'),
(421, 168, 53, 1000000000515, 'Đã sử dụng', '2025-04-03 09:22:11', '2025-04-03 09:22:11'),
(422, 168, 55, 1000000000516, 'Đã sử dụng', '2025-04-04 09:22:11', '2025-04-04 09:22:11'),
(423, 168, 57, 1000000000517, 'Đã sử dụng', '2025-04-03 09:22:11', '2025-04-03 09:22:11'),
(424, 169, 59, 1000000000518, 'Đã sử dụng', '2025-04-03 15:33:44', '2025-04-03 15:33:44'),
(425, 169, 61, 1000000000519, 'Đã sử dụng', '2025-04-03 15:33:44', '2025-04-03 15:33:44'),
(426, 169, 63, 1000000000520, 'Đã sử dụng', '2025-04-03 15:33:44', '2025-04-03 15:33:44'),
(427, 170, 65, 1000000000521, 'Đã sử dụng', '2025-04-04 10:55:22', '2025-04-04 10:55:22'),
(428, 170, 67, 1000000000522, 'Đã sử dụng', '2025-04-04 10:55:22', '2025-04-04 10:55:22'),
(429, 170, 69, 1000000000523, 'Đã sử dụng', '2025-04-04 10:55:22', '2025-04-04 10:55:22'),
(430, 171, 107, 1000000000524, 'Đã sử dụng', '2025-04-04 17:11:33', '2025-04-04 17:11:33'),
(431, 171, 109, 1000000000525, 'Đã sử dụng', '2025-04-04 17:11:33', '2025-04-04 17:11:33'),
(432, 172, 77, 1000000000526, 'Đã sử dụng', '2025-04-24 09:18:33', '2025-04-24 09:18:33'),
(433, 172, 79, 1000000000527, 'Đã sử dụng', '2025-04-24 09:18:33', '2025-04-24 09:18:33'),
(434, 172, 81, 1000000000528, 'Đã sử dụng', '2025-04-24 09:18:33', '2025-04-24 09:18:33'),
(435, 173, 83, 1000000000529, 'Đã sử dụng', '2025-04-24 14:29:11', '2025-04-24 14:29:11'),
(436, 173, 85, 1000000000530, 'Đã sử dụng', '2025-04-24 14:29:11', '2025-04-24 14:29:11'),
(437, 173, 87, 1000000000531, 'Đã sử dụng', '2025-04-24 14:29:11', '2025-04-24 14:29:11'),
(438, 174, 89, 1000000000532, 'Đã sử dụng', '2025-04-25 10:44:55', '2025-04-25 10:44:55'),
(439, 174, 91, 1000000000533, 'Đã sử dụng', '2025-04-25 10:44:55', '2025-04-25 10:44:55'),
(440, 175, 77, 1000000000534, 'Đã sử dụng', '2025-04-25 17:33:22', '2025-04-25 17:33:22'),
(441, 175, 79, 1000000000535, 'Đã sử dụng', '2025-04-25 17:33:22', '2025-04-25 17:33:22'),
(442, 176, 1, 1000000000536, 'Đã sử dụng', '2025-04-10 09:33:11', '2025-04-10 09:33:11'),
(443, 176, 3, 1000000000537, 'Đã sử dụng', '2025-04-10 09:33:11', '2025-04-10 09:33:11'),
(444, 176, 5, 1000000000538, 'Đã sử dụng', '2025-04-10 09:33:11', '2025-04-10 09:33:11'),
(445, 177, 7, 1000000000539, 'Đã sử dụng', '2025-04-10 15:44:55', '2025-04-10 15:44:55'),
(446, 177, 9, 1000000000540, 'Đã sử dụng', '2025-04-10 15:44:55', '2025-04-10 15:44:55'),
(447, 177, 11, 1000000000541, 'Đã sử dụng', '2025-04-10 15:44:55', '2025-04-10 15:44:55'),
(448, 178, 13, 1000000000542, 'Đã sử dụng', '2025-04-11 10:22:08', '2025-04-11 10:22:08'),
(449, 178, 15, 1000000000543, 'Đã sử dụng', '2025-04-11 10:22:08', '2025-04-11 10:22:08'),
(450, 178, 17, 1000000000544, 'Đã sử dụng', '2025-04-11 10:22:08', '2025-04-11 10:22:08'),
(451, 179, 19, 1000000000545, 'Đã sử dụng', '2025-04-11 17:11:33', '2025-04-11 17:11:33'),
(452, 179, 21, 1000000000546, 'Đã sử dụng', '2025-04-11 17:11:33', '2025-04-11 17:11:33'),
(453, 180, 1, 1000000000547, 'Đã sử dụng', '2025-04-12 11:55:22', '2025-04-12 11:55:22'),
(454, 180, 3, 1000000000548, 'Đã sử dụng', '2025-04-12 11:55:22', '2025-04-12 11:55:22'),
(455, 181, 53, 1000000000549, 'Đã sử dụng', '2025-04-17 10:18:22', '2025-04-17 10:18:22'),
(456, 181, 55, 1000000000550, 'Đã sử dụng', '2025-04-17 10:18:22', '2025-04-17 10:18:22'),
(457, 181, 57, 1000000000551, 'Đã sử dụng', '2025-04-17 10:18:22', '2025-04-17 10:18:22'),
(458, 182, 59, 1000000000552, 'Đã sử dụng', '2025-04-17 15:29:11', '2025-04-17 15:29:11'),
(459, 182, 61, 1000000000553, 'Đã sử dụng', '2025-04-17 15:29:11', '2025-04-17 15:29:11'),
(460, 182, 63, 1000000000554, 'Đã sử dụng', '2025-04-17 15:29:11', '2025-04-17 15:29:11'),
(461, 183, 65, 1000000000555, 'Đã sử dụng', '2025-04-18 09:44:55', '2025-04-18 09:44:55'),
(462, 183, 67, 1000000000556, 'Đã sử dụng', '2025-04-18 09:44:55', '2025-04-18 09:44:55'),
(463, 183, 69, 1000000000557, 'Đã sử dụng', '2025-04-18 09:44:55', '2025-04-18 09:44:55'),
(464, 184, 71, 1000000000558, 'Đã sử dụng', '2025-04-18 14:33:22', '2025-04-18 14:33:22'),
(465, 184, 73, 1000000000559, 'Đã sử dụng', '2025-04-18 14:33:22', '2025-04-18 14:33:22'),
(466, 184, 107, 1000000000560, 'Đã sử dụng', '2025-04-18 14:33:22', '2025-04-18 14:33:22'),
(467, 185, 109, 1000000000561, 'Đã sử dụng', '2025-04-19 11:22:08', '2025-04-19 11:22:08'),
(468, 185, 111, 1000000000562, 'Đã sử dụng', '2025-04-19 11:22:08', '2025-04-19 11:22:08'),
(469, 186, 1, 1000000000563, 'Đã sử dụng', '2025-04-30 09:11:33', '2025-04-30 09:11:33'),
(470, 186, 3, 1000000000564, 'Đã sử dụng', '2025-04-30 09:11:33', '2025-04-30 09:11:33'),
(471, 186, 5, 1000000000565, 'Đã sử dụng', '2025-04-30 09:11:33', '2025-04-30 09:11:33'),
(472, 187, 7, 1000000000566, 'Đã sử dụng', '2025-04-30 14:22:08', '2025-04-30 14:22:08'),
(473, 187, 9, 1000000000567, 'Đã sử dụng', '2025-04-30 14:22:08', '2025-04-30 14:22:08'),
(474, 187, 11, 1000000000568, 'Đã sử dụng', '2025-04-30 14:22:08', '2025-04-30 14:22:08'),
(475, 188, 13, 1000000000569, 'Đã sử dụng', '2025-05-01 10:33:55', '2025-05-01 10:33:55'),
(476, 188, 15, 1000000000570, 'Đã sử dụng', '2025-05-01 10:33:55', '2025-05-01 10:33:55'),
(477, 188, 17, 1000000000571, 'Đã sử dụng', '2025-05-01 10:33:55', '2025-05-01 10:33:55'),
(478, 189, 19, 1000000000572, 'Đã sử dụng', '2025-05-01 16:44:22', '2025-05-01 16:44:22'),
(479, 189, 21, 1000000000573, 'Đã sử dụng', '2025-05-01 16:44:22', '2025-05-01 16:44:22'),
(480, 189, 23, 1000000000574, 'Đã sử dụng', '2025-05-01 16:44:22', '2025-05-01 16:44:22'),
(481, 190, 1, 1000000000575, 'Đã sử dụng', '2025-05-02 11:55:33', '2025-05-02 11:55:33'),
(482, 190, 3, 1000000000576, 'Đã sử dụng', '2025-05-02 11:55:33', '2025-05-02 11:55:33'),
(483, 191, 5, 1000000000577, 'Đã sử dụng', '2025-05-02 18:11:44', '2025-05-02 18:11:44'),
(484, 191, 7, 1000000000578, 'Đã sử dụng', '2025-05-02 18:11:44', '2025-05-02 18:11:44'),
(485, 191, 9, 1000000000579, 'Đã sử dụng', '2025-05-02 18:11:44', '2025-05-02 18:11:44'),
(486, 192, 1, 1000000000620, 'Đã sử dụng', '2025-05-14 09:22:11', '2025-05-14 09:22:11'),
(487, 192, 3, 1000000000621, 'Đã sử dụng', '2025-05-14 09:22:11', '2025-05-14 09:22:11'),
(488, 192, 5, 1000000000622, 'Đã sử dụng', '2025-05-14 09:22:11', '2025-05-14 09:22:11'),
(489, 193, 7, 1000000000623, 'Đã sử dụng', '2025-05-14 14:33:44', '2025-05-14 14:33:44'),
(490, 193, 9, 1000000000624, 'Đã sử dụng', '2025-05-14 14:33:44', '2025-05-14 14:33:44'),
(491, 193, 11, 1000000000625, 'Đã sử dụng', '2025-05-14 14:33:44', '2025-05-14 14:33:44'),
(492, 194, 13, 1000000000626, 'Đã sử dụng', '2025-05-15 10:55:22', '2025-05-15 10:55:22'),
(493, 194, 15, 1000000000627, 'Đã sử dụng', '2025-05-15 10:55:22', '2025-05-15 10:55:22'),
(494, 194, 17, 1000000000628, 'Đã sử dụng', '2025-05-15 10:55:22', '2025-05-15 10:55:22'),
(495, 195, 19, 1000000000629, 'Đã sử dụng', '2025-05-15 17:11:33', '2025-05-15 17:11:33'),
(496, 195, 21, 1000000000630, 'Đã sử dụng', '2025-05-15 17:11:33', '2025-05-15 17:11:33'),
(497, 195, 23, 1000000000631, 'Đã sử dụng', '2025-05-15 17:11:33', '2025-05-15 17:11:33'),
(498, 196, 1, 1000000000632, 'Đã sử dụng', '2025-05-16 11:44:55', '2025-05-16 11:44:55'),
(499, 196, 3, 1000000000633, 'Đã sử dụng', '2025-05-16 11:44:55', '2025-05-16 11:44:55'),
(500, 197, 5, 1000000000634, 'Đã sử dụng', '2025-05-16 18:22:08', '2025-05-16 18:22:08'),
(501, 197, 7, 1000000000635, 'Đã sử dụng', '2025-05-16 18:22:08', '2025-05-16 18:22:08'),
(502, 197, 9, 1000000000636, 'Đã sử dụng', '2025-05-16 18:22:08', '2025-05-16 18:22:08'),
(503, 198, 53, 1000000000637, 'Đã sử dụng', '2025-05-31 09:18:33', '2025-05-31 09:18:33'),
(504, 198, 55, 1000000000638, 'Đã sử dụng', '2025-05-31 09:18:33', '2025-05-31 09:18:33'),
(505, 198, 57, 1000000000639, 'Đã sử dụng', '2025-05-31 09:18:33', '2025-05-31 09:18:33'),
(506, 199, 59, 1000000000640, 'Đã sử dụng', '2025-05-31 15:29:11', '2025-05-31 15:29:11'),
(507, 199, 61, 1000000000641, 'Đã sử dụng', '2025-05-31 15:29:11', '2025-05-31 15:29:11'),
(508, 199, 63, 1000000000642, 'Đã sử dụng', '2025-05-31 15:29:11', '2025-05-31 15:29:11'),
(509, 200, 65, 1000000000643, 'Đã sử dụng', '2025-06-01 10:44:55', '2025-06-01 10:44:55'),
(510, 200, 67, 1000000000644, 'Đã sử dụng', '2025-06-01 10:44:55', '2025-06-01 10:44:55'),
(511, 201, 69, 1000000000645, 'Đã sử dụng', '2025-06-01 16:33:22', '2025-06-01 16:33:22'),
(512, 201, 107, 1000000000646, 'Đã sử dụng', '2025-06-01 16:33:22', '2025-06-01 16:33:22'),
(513, 202, 109, 1000000000647, 'Đã sử dụng', '2025-06-02 11:55:33', '2025-06-02 11:55:33'),
(514, 202, 111, 1000000000648, 'Đã sử dụng', '2025-06-02 11:55:33', '2025-06-02 11:55:33'),
(515, 202, 113, 1000000000649, 'Đã sử dụng', '2025-06-02 11:55:33', '2025-06-02 11:55:33'),
(516, 203, 77, 1000000000650, 'Đã sử dụng', '2025-05-21 09:33:11', '2025-05-21 09:33:11'),
(517, 203, 79, 1000000000651, 'Đã sử dụng', '2025-05-21 09:33:11', '2025-05-21 09:33:11'),
(518, 203, 81, 1000000000652, 'Đã sử dụng', '2025-05-21 09:33:11', '2025-05-21 09:33:11'),
(519, 204, 83, 1000000000653, 'Đã sử dụng', '2025-05-21 14:44:55', '2025-05-21 14:44:55'),
(520, 204, 85, 1000000000654, 'Đã sử dụng', '2025-05-21 14:44:55', '2025-05-21 14:44:55'),
(521, 205, 87, 1000000000655, 'Đã sử dụng', '2025-05-22 10:22:08', '2025-05-22 10:22:08'),
(522, 205, 89, 1000000000656, 'Đã sử dụng', '2025-05-22 10:22:08', '2025-05-22 10:22:08'),
(523, 206, 77, 1000000000657, 'Đã sử dụng', '2025-05-22 17:11:33', '2025-05-22 17:11:33'),
(524, 206, 79, 1000000000658, 'Đã sử dụng', '2025-05-22 17:11:33', '2025-05-22 17:11:33'),
(525, 207, 1, 1000000000659, 'Đã sử dụng', '2025-05-07 09:11:22', '2025-05-07 09:11:22'),
(526, 207, 3, 1000000000660, 'Đã sử dụng', '2025-05-07 09:11:22', '2025-05-07 09:11:22'),
(527, 207, 5, 1000000000661, 'Đã sử dụng', '2025-05-07 09:11:22', '2025-05-07 09:11:22'),
(528, 208, 7, 1000000000662, 'Đã sử dụng', '2025-05-07 15:22:44', '2025-05-07 15:22:44'),
(529, 208, 9, 1000000000663, 'Đã sử dụng', '2025-05-07 15:22:44', '2025-05-07 15:22:44'),
(530, 208, 11, 1000000000664, 'Đã sử dụng', '2025-05-07 15:22:44', '2025-05-07 15:22:44'),
(531, 209, 13, 1000000000665, 'Đã sử dụng', '2025-05-08 10:33:55', '2025-05-08 10:33:55'),
(532, 209, 15, 1000000000666, 'Đã sử dụng', '2025-05-08 10:33:55', '2025-05-08 10:33:55'),
(533, 209, 17, 1000000000667, 'Đã sử dụng', '2025-05-08 10:33:55', '2025-05-08 10:33:55'),
(534, 210, 19, 1000000000668, 'Đã sử dụng', '2025-05-08 16:44:22', '2025-05-08 16:44:22'),
(535, 210, 21, 1000000000669, 'Đã sử dụng', '2025-05-08 16:44:22', '2025-05-08 16:44:22'),
(536, 210, 23, 1000000000670, 'Đã sử dụng', '2025-05-08 16:44:22', '2025-05-08 16:44:22'),
(537, 211, 25, 1000000000671, 'Đã sử dụng', '2025-05-09 11:55:33', '2025-05-09 11:55:33'),
(538, 211, 27, 1000000000672, 'Đã sử dụng', '2025-05-09 11:55:33', '2025-05-09 11:55:33'),
(539, 212, 29, 1000000000673, 'Đã sử dụng', '2025-05-09 18:11:44', '2025-05-09 18:11:44'),
(540, 212, 31, 1000000000674, 'Đã sử dụng', '2025-05-09 18:11:44', '2025-05-09 18:11:44'),
(541, 212, 33, 1000000000675, 'Đã sử dụng', '2025-05-09 18:11:44', '2025-05-09 18:11:44'),
(542, 213, 35, 1000000000676, 'Đã sử dụng', '2025-05-10 09:22:11', '2025-05-10 09:22:11'),
(543, 213, 37, 1000000000677, 'Đã sử dụng', '2025-05-10 09:22:11', '2025-05-10 09:22:11'),
(544, 214, 53, 1000000000678, 'Đã sử dụng', '2025-05-28 10:18:22', '2025-05-28 10:18:22'),
(545, 214, 55, 1000000000679, 'Đã sử dụng', '2025-05-28 10:18:22', '2025-05-28 10:18:22'),
(546, 214, 57, 1000000000680, 'Đã sử dụng', '2025-05-28 10:18:22', '2025-05-28 10:18:22'),
(547, 215, 59, 1000000000681, 'Đã sử dụng', '2025-05-28 15:29:11', '2025-05-28 15:29:11'),
(548, 215, 61, 1000000000682, 'Đã sử dụng', '2025-05-28 15:29:11', '2025-05-28 15:29:11'),
(549, 215, 63, 1000000000683, 'Đã sử dụng', '2025-05-28 15:29:11', '2025-05-28 15:29:11'),
(550, 216, 65, 1000000000684, 'Đã sử dụng', '2025-05-29 09:44:55', '2025-05-29 09:44:55'),
(551, 216, 67, 1000000000685, 'Đã sử dụng', '2025-05-29 09:44:55', '2025-05-29 09:44:55'),
(552, 217, 107, 1000000000686, 'Đã sử dụng', '2025-05-29 14:33:22', '2025-05-29 14:33:22'),
(553, 218, 1, 1000000000687, 'Đã sử dụng', '2025-06-13 09:11:33', '2025-06-13 09:11:33'),
(554, 218, 3, 1000000000688, 'Đã sử dụng', '2025-06-13 09:11:33', '2025-06-13 09:11:33'),
(555, 218, 5, 1000000000689, 'Đã sử dụng', '2025-06-13 09:11:33', '2025-06-13 09:11:33'),
(556, 219, 7, 1000000000690, 'Đã sử dụng', '2025-06-13 14:22:08', '2025-06-13 14:22:08'),
(557, 219, 9, 1000000000691, 'Đã sử dụng', '2025-06-13 14:22:08', '2025-06-13 14:22:08'),
(558, 219, 11, 1000000000692, 'Đã sử dụng', '2025-06-13 14:22:08', '2025-06-13 14:22:08'),
(559, 220, 13, 1000000000693, 'Đã sử dụng', '2025-06-14 10:33:55', '2025-06-14 10:33:55'),
(560, 220, 15, 1000000000694, 'Đã sử dụng', '2025-06-14 10:33:55', '2025-06-14 10:33:55'),
(561, 220, 17, 1000000000695, 'Đã sử dụng', '2025-06-14 10:33:55', '2025-06-14 10:33:55'),
(562, 221, 19, 1000000000696, 'Đã sử dụng', '2025-06-14 16:44:22', '2025-06-14 16:44:22'),
(563, 221, 21, 1000000000697, 'Đã sử dụng', '2025-06-14 16:44:22', '2025-06-14 16:44:22'),
(564, 222, 1, 1000000000698, 'Đã sử dụng', '2025-06-15 11:55:33', '2025-06-15 11:55:33'),
(565, 222, 3, 1000000000699, 'Đã sử dụng', '2025-06-15 11:55:33', '2025-06-15 11:55:33');
INSERT INTO `tickets` (`ticket_id`, `booking_id`, `seat_id`, `ticket_code`, `status`, `created_at`, `updated_at`) VALUES
(566, 223, 1, 1000000000742, 'Đã sử dụng', '2025-06-15 09:22:11', '2025-06-15 09:22:11'),
(567, 223, 3, 1000000000743, 'Đã sử dụng', '2025-06-15 09:22:11', '2025-06-15 09:22:11'),
(568, 223, 5, 1000000000744, 'Đã sử dụng', '2025-06-15 09:22:11', '2025-06-15 09:22:11'),
(569, 224, 7, 1000000000745, 'Đã sử dụng', '2025-06-15 14:33:44', '2025-06-15 14:33:44'),
(570, 224, 9, 1000000000746, 'Đã sử dụng', '2025-06-15 14:33:44', '2025-06-15 14:33:44'),
(571, 224, 11, 1000000000747, 'Đã sử dụng', '2025-06-15 14:33:44', '2025-06-15 14:33:44'),
(572, 225, 13, 1000000000748, 'Đã sử dụng', '2025-06-16 10:55:22', '2025-06-16 10:55:22'),
(573, 225, 15, 1000000000749, 'Đã sử dụng', '2025-06-16 10:55:22', '2025-06-16 10:55:22'),
(574, 225, 17, 1000000000750, 'Đã sử dụng', '2025-06-16 10:55:22', '2025-06-16 10:55:22'),
(575, 226, 19, 1000000000751, 'Đã sử dụng', '2025-06-16 17:11:33', '2025-06-16 17:11:33'),
(576, 226, 21, 1000000000752, 'Đã sử dụng', '2025-06-16 17:11:33', '2025-06-16 17:11:33'),
(577, 226, 23, 1000000000753, 'Đã sử dụng', '2025-06-16 17:11:33', '2025-06-16 17:11:33'),
(578, 227, 1, 1000000000754, 'Đã sử dụng', '2025-06-17 11:44:55', '2025-06-17 11:44:55'),
(579, 227, 3, 1000000000755, 'Đã sử dụng', '2025-06-17 11:44:55', '2025-06-17 11:44:55'),
(580, 228, 5, 1000000000756, 'Đã sử dụng', '2025-06-17 18:22:08', '2025-06-17 18:22:08'),
(581, 228, 7, 1000000000757, 'Đã sử dụng', '2025-06-17 18:22:08', '2025-06-17 18:22:08'),
(582, 228, 9, 1000000000758, 'Đã sử dụng', '2025-06-17 18:22:08', '2025-06-17 18:22:08'),
(583, 229, 53, 1000000000759, 'Đã sử dụng', '2025-06-30 09:18:33', '2025-06-30 09:18:33'),
(584, 229, 55, 1000000000760, 'Đã sử dụng', '2025-06-30 09:18:33', '2025-06-30 09:18:33'),
(585, 229, 57, 1000000000761, 'Đã sử dụng', '2025-06-30 09:18:33', '2025-06-30 09:18:33'),
(586, 230, 59, 1000000000762, 'Đã sử dụng', '2025-06-30 15:29:11', '2025-06-30 15:29:11'),
(587, 230, 61, 1000000000763, 'Đã sử dụng', '2025-06-30 15:29:11', '2025-06-30 15:29:11'),
(588, 230, 63, 1000000000764, 'Đã sử dụng', '2025-06-30 15:29:11', '2025-06-30 15:29:11'),
(589, 231, 65, 1000000000765, 'Đã sử dụng', '2025-07-01 10:44:55', '2025-07-01 10:44:55'),
(590, 231, 67, 1000000000766, 'Đã sử dụng', '2025-07-01 10:44:55', '2025-07-01 10:44:55'),
(591, 232, 69, 1000000000767, 'Đã sử dụng', '2025-07-01 16:33:22', '2025-07-01 16:33:22'),
(592, 232, 107, 1000000000768, 'Đã sử dụng', '2025-07-01 16:33:22', '2025-07-01 16:33:22'),
(593, 233, 109, 1000000000769, 'Đã sử dụng', '2025-07-02 11:55:33', '2025-07-02 11:55:33'),
(594, 233, 111, 1000000000770, 'Đã sử dụng', '2025-07-02 11:55:33', '2025-07-02 11:55:33'),
(595, 233, 113, 1000000000771, 'Đã sử dụng', '2025-07-02 11:55:33', '2025-07-02 11:55:33'),
(596, 234, 77, 1000000000772, 'Đã sử dụng', '2025-06-23 09:33:11', '2025-06-23 09:33:11'),
(597, 234, 79, 1000000000773, 'Đã sử dụng', '2025-06-23 09:33:11', '2025-06-23 09:33:11'),
(598, 234, 81, 1000000000774, 'Đã sử dụng', '2025-06-23 09:33:11', '2025-06-23 09:33:11'),
(599, 235, 83, 1000000000775, 'Đã sử dụng', '2025-06-23 14:44:55', '2025-06-23 14:44:55'),
(600, 235, 85, 1000000000776, 'Đã sử dụng', '2025-06-23 14:44:55', '2025-06-23 14:44:55'),
(601, 235, 87, 1000000000777, 'Đã sử dụng', '2025-06-23 14:44:55', '2025-06-23 14:44:55'),
(602, 236, 89, 1000000000778, 'Đã sử dụng', '2025-06-24 10:22:08', '2025-06-24 10:22:08'),
(603, 236, 91, 1000000000779, 'Đã sử dụng', '2025-06-24 10:22:08', '2025-06-24 10:22:08'),
(604, 237, 77, 1000000000780, 'Đã sử dụng', '2025-06-24 17:11:33', '2025-06-24 17:11:33'),
(605, 237, 79, 1000000000781, 'Đã sử dụng', '2025-06-24 17:11:33', '2025-06-24 17:11:33'),
(606, 238, 1, 1000000000782, 'Đã sử dụng', '2025-06-09 09:11:22', '2025-06-09 09:11:22'),
(607, 238, 3, 1000000000783, 'Đã sử dụng', '2025-06-09 09:11:22', '2025-06-09 09:11:22'),
(608, 238, 5, 1000000000784, 'Đã sử dụng', '2025-06-09 09:11:22', '2025-06-09 09:11:22'),
(609, 239, 7, 1000000000785, 'Đã sử dụng', '2025-06-09 15:22:44', '2025-06-09 15:22:44'),
(610, 239, 9, 1000000000786, 'Đã sử dụng', '2025-06-09 15:22:44', '2025-06-09 15:22:44'),
(611, 239, 11, 1000000000787, 'Đã sử dụng', '2025-06-09 15:22:44', '2025-06-09 15:22:44'),
(612, 240, 13, 1000000000788, 'Đã sử dụng', '2025-06-10 10:33:55', '2025-06-10 10:33:55'),
(613, 240, 15, 1000000000789, 'Đã sử dụng', '2025-06-10 10:33:55', '2025-06-10 10:33:55'),
(614, 240, 17, 1000000000790, 'Đã sử dụng', '2025-06-10 10:33:55', '2025-06-10 10:33:55'),
(615, 241, 19, 1000000000791, 'Đã sử dụng', '2025-06-10 16:44:22', '2025-06-10 16:44:22'),
(616, 241, 21, 1000000000792, 'Đã sử dụng', '2025-06-10 16:44:22', '2025-06-10 16:44:22'),
(617, 241, 23, 1000000000793, 'Đã sử dụng', '2025-06-10 16:44:22', '2025-06-10 16:44:22'),
(618, 242, 25, 1000000000794, 'Đã sử dụng', '2025-06-11 11:55:33', '2025-06-11 11:55:33'),
(619, 242, 27, 1000000000795, 'Đã sử dụng', '2025-06-11 11:55:33', '2025-06-11 11:55:33'),
(620, 243, 29, 1000000000796, 'Đã sử dụng', '2025-06-11 18:11:44', '2025-06-11 18:11:44'),
(621, 243, 31, 1000000000797, 'Đã sử dụng', '2025-06-11 18:11:44', '2025-06-11 18:11:44'),
(622, 243, 33, 1000000000798, 'Đã sử dụng', '2025-06-11 18:11:44', '2025-06-11 18:11:44'),
(623, 244, 35, 1000000000799, 'Đã sử dụng', '2025-06-12 09:22:11', '2025-06-12 09:22:11'),
(624, 244, 37, 1000000000800, 'Đã sử dụng', '2025-06-12 09:22:11', '2025-06-12 09:22:11'),
(625, 245, 53, 1000000000801, 'Đã sử dụng', '2025-06-27 10:18:22', '2025-06-27 10:18:22'),
(626, 245, 55, 1000000000802, 'Đã sử dụng', '2025-06-27 10:18:22', '2025-06-27 10:18:22'),
(627, 245, 57, 1000000000803, 'Đã sử dụng', '2025-06-27 10:18:22', '2025-06-27 10:18:22'),
(628, 246, 59, 1000000000804, 'Đã sử dụng', '2025-06-27 15:29:11', '2025-06-27 15:29:11'),
(629, 246, 61, 1000000000805, 'Đã sử dụng', '2025-06-27 15:29:11', '2025-06-27 15:29:11'),
(630, 246, 63, 1000000000806, 'Đã sử dụng', '2025-06-27 15:29:11', '2025-06-27 15:29:11'),
(631, 247, 65, 1000000000807, 'Đã sử dụng', '2025-06-28 09:44:55', '2025-06-28 09:44:55'),
(632, 247, 67, 1000000000808, 'Đã sử dụng', '2025-06-28 09:44:55', '2025-06-28 09:44:55'),
(633, 248, 107, 1000000000809, 'Đã sử dụng', '2025-06-28 14:33:22', '2025-06-28 14:33:22'),
(634, 249, 1, 1000000000810, 'Đã sử dụng', '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(635, 249, 3, 1000000000811, 'Đã sử dụng', '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(636, 249, 5, 1000000000812, 'Đã sử dụng', '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(637, 250, 7, 1000000000813, 'Đã sử dụng', '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(638, 250, 9, 1000000000814, 'Đã sử dụng', '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(639, 250, 11, 1000000000815, 'Đã sử dụng', '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(640, 251, 13, 1000000000816, 'Đã sử dụng', '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(641, 251, 15, 1000000000817, 'Đã sử dụng', '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(642, 251, 17, 1000000000818, 'Đã sử dụng', '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(643, 252, 19, 1000000000819, 'Đã sử dụng', '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(644, 252, 21, 1000000000820, 'Đã sử dụng', '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(645, 252, 23, 1000000000821, 'Đã sử dụng', '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(646, 253, 1, 1000000000822, 'Đã sử dụng', '2025-07-16 11:55:33', '2025-07-16 11:55:33'),
(647, 253, 3, 1000000000823, 'Đã sử dụng', '2025-07-16 11:55:33', '2025-07-16 11:55:33'),
(648, 254, 5, 1000000000824, 'Đã sử dụng', '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(649, 254, 7, 1000000000825, 'Đã sử dụng', '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(650, 254, 9, 1000000000826, 'Đã sử dụng', '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(651, 255, 11, 1000000000827, 'Đã sử dụng', '2025-07-17 09:22:11', '2025-07-17 09:22:11'),
(652, 256, 1, 1000000000865, 'Đã sử dụng', '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(653, 256, 3, 1000000000866, 'Đã sử dụng', '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(654, 256, 5, 1000000000867, 'Đã sử dụng', '2025-07-14 09:11:33', '2025-07-14 09:11:33'),
(655, 257, 7, 1000000000868, 'Đã sử dụng', '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(656, 257, 9, 1000000000869, 'Đã sử dụng', '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(657, 257, 11, 1000000000870, 'Đã sử dụng', '2025-07-14 14:22:08', '2025-07-14 14:22:08'),
(658, 258, 13, 1000000000871, 'Đã sử dụng', '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(659, 258, 15, 1000000000872, 'Đã sử dụng', '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(660, 258, 17, 1000000000873, 'Đã sử dụng', '2025-07-15 10:33:55', '2025-07-15 10:33:55'),
(661, 259, 19, 1000000000874, 'Đã sử dụng', '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(662, 259, 21, 1000000000875, 'Đã sử dụng', '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(663, 259, 23, 1000000000876, 'Đã sử dụng', '2025-07-15 16:44:22', '2025-07-15 16:44:22'),
(664, 260, 25, 1000000000877, 'Đã sử dụng', '2025-07-16 11:55:33', '2025-07-16 11:55:33'),
(665, 260, 1, 1000000000878, 'Đã sử dụng', '2025-07-16 11:55:33', '2025-07-16 11:55:33'),
(666, 261, 3, 1000000000879, 'Đã sử dụng', '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(667, 261, 5, 1000000000880, 'Đã sử dụng', '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(668, 261, 7, 1000000000881, 'Đã sử dụng', '2025-07-16 18:11:44', '2025-07-16 18:11:44'),
(669, 262, 53, 1000000000882, 'Đã sử dụng', '2025-07-31 09:22:11', '2025-07-31 09:22:11'),
(670, 262, 55, 1000000000883, 'Đã sử dụng', '2025-07-31 09:22:11', '2025-07-31 09:22:11'),
(671, 262, 57, 1000000000884, 'Đã sử dụng', '2025-07-31 09:22:11', '2025-07-31 09:22:11'),
(672, 263, 59, 1000000000885, 'Đã sử dụng', '2025-07-31 15:33:44', '2025-07-31 15:33:44'),
(673, 263, 61, 1000000000886, 'Đã sử dụng', '2025-07-31 15:33:44', '2025-07-31 15:33:44'),
(674, 263, 63, 1000000000887, 'Đã sử dụng', '2025-07-31 15:33:44', '2025-07-31 15:33:44'),
(675, 264, 65, 1000000000888, 'Đã sử dụng', '2025-08-01 10:55:22', '2025-08-01 10:55:22'),
(676, 264, 67, 1000000000889, 'Đã sử dụng', '2025-08-01 10:55:22', '2025-08-01 10:55:22'),
(677, 264, 69, 1000000000890, 'Đã sử dụng', '2025-08-01 10:55:22', '2025-08-01 10:55:22'),
(678, 265, 107, 1000000000891, 'Đã sử dụng', '2025-08-01 17:11:33', '2025-08-01 17:11:33'),
(679, 265, 109, 1000000000892, 'Đã sử dụng', '2025-08-01 17:11:33', '2025-08-01 17:11:33'),
(680, 266, 77, 1000000000893, 'Đã sử dụng', '2025-07-21 09:18:33', '2025-07-21 09:18:33'),
(681, 266, 79, 1000000000894, 'Đã sử dụng', '2025-07-21 09:18:33', '2025-07-21 09:18:33'),
(682, 266, 81, 1000000000895, 'Đã sử dụng', '2025-07-21 09:18:33', '2025-07-21 09:18:33'),
(683, 267, 83, 1000000000896, 'Đã sử dụng', '2025-07-21 14:29:11', '2025-07-21 14:29:11'),
(684, 267, 85, 1000000000897, 'Đã sử dụng', '2025-07-21 14:29:11', '2025-07-21 14:29:11'),
(685, 268, 87, 1000000000898, 'Đã sử dụng', '2025-07-22 10:44:55', '2025-07-22 10:44:55'),
(686, 268, 89, 1000000000899, 'Đã sử dụng', '2025-07-22 10:44:55', '2025-07-22 10:44:55'),
(687, 269, 77, 1000000000900, 'Đã sử dụng', '2025-07-22 17:33:22', '2025-07-22 17:33:22'),
(688, 269, 79, 1000000000901, 'Đã sử dụng', '2025-07-22 17:33:22', '2025-07-22 17:33:22'),
(689, 270, 1, 1000000000902, 'Đã sử dụng', '2025-07-07 09:33:11', '2025-07-07 09:33:11'),
(690, 270, 3, 1000000000903, 'Đã sử dụng', '2025-07-07 09:33:11', '2025-07-07 09:33:11'),
(691, 270, 5, 1000000000904, 'Đã sử dụng', '2025-07-07 09:33:11', '2025-07-07 09:33:11'),
(692, 271, 7, 1000000000905, 'Đã sử dụng', '2025-07-07 15:44:55', '2025-07-07 15:44:55'),
(693, 271, 9, 1000000000906, 'Đã sử dụng', '2025-07-07 15:44:55', '2025-07-07 15:44:55'),
(694, 271, 11, 1000000000907, 'Đã sử dụng', '2025-07-07 15:44:55', '2025-07-07 15:44:55'),
(695, 272, 13, 1000000000908, 'Đã sử dụng', '2025-07-08 10:22:08', '2025-07-08 10:22:08'),
(696, 272, 15, 1000000000909, 'Đã sử dụng', '2025-07-08 10:22:08', '2025-07-08 10:22:08'),
(697, 272, 17, 1000000000910, 'Đã sử dụng', '2025-07-08 10:22:08', '2025-07-08 10:22:08'),
(698, 273, 19, 1000000000911, 'Đã sử dụng', '2025-07-08 17:11:33', '2025-07-08 17:11:33'),
(699, 273, 21, 1000000000912, 'Đã sử dụng', '2025-07-08 17:11:33', '2025-07-08 17:11:33'),
(700, 273, 23, 1000000000913, 'Đã sử dụng', '2025-07-08 17:11:33', '2025-07-08 17:11:33'),
(701, 274, 25, 1000000000914, 'Đã sử dụng', '2025-07-09 11:55:22', '2025-07-09 11:55:22'),
(702, 274, 27, 1000000000915, 'Đã sử dụng', '2025-07-09 11:55:22', '2025-07-09 11:55:22'),
(703, 275, 29, 1000000000916, 'Đã sử dụng', '2025-07-09 18:22:08', '2025-07-09 18:22:08'),
(704, 275, 31, 1000000000917, 'Đã sử dụng', '2025-07-09 18:22:08', '2025-07-09 18:22:08'),
(705, 275, 33, 1000000000918, 'Đã sử dụng', '2025-07-09 18:22:08', '2025-07-09 18:22:08'),
(706, 276, 35, 1000000000919, 'Đã sử dụng', '2025-07-10 09:22:11', '2025-07-10 09:22:11'),
(707, 276, 37, 1000000000920, 'Đã sử dụng', '2025-07-10 09:22:11', '2025-07-10 09:22:11'),
(708, 277, 53, 1000000000921, 'Đã sử dụng', '2025-07-28 10:18:22', '2025-07-28 10:18:22'),
(709, 277, 55, 1000000000922, 'Đã sử dụng', '2025-07-28 10:18:22', '2025-07-28 10:18:22'),
(710, 277, 57, 1000000000923, 'Đã sử dụng', '2025-07-28 10:18:22', '2025-07-28 10:18:22'),
(711, 278, 59, 1000000000924, 'Đã sử dụng', '2025-07-28 15:29:11', '2025-07-28 15:29:11'),
(712, 278, 61, 1000000000925, 'Đã sử dụng', '2025-07-28 15:29:11', '2025-07-28 15:29:11'),
(713, 278, 63, 1000000000926, 'Đã sử dụng', '2025-07-28 15:29:11', '2025-07-28 15:29:11'),
(714, 279, 65, 1000000000927, 'Đã sử dụng', '2025-07-29 09:44:55', '2025-07-29 09:44:55'),
(715, 279, 67, 1000000000928, 'Đã sử dụng', '2025-07-29 09:44:55', '2025-07-29 09:44:55'),
(716, 280, 107, 1000000000929, 'Đã sử dụng', '2025-07-29 14:33:22', '2025-07-29 14:33:22'),
(717, 281, 1, 1000000000930, 'Đã sử dụng', '2025-08-13 09:11:33', '2025-08-13 09:11:33'),
(718, 281, 3, 1000000000931, 'Đã sử dụng', '2025-08-13 09:11:33', '2025-08-13 09:11:33'),
(719, 281, 5, 1000000000932, 'Đã sử dụng', '2025-08-13 09:11:33', '2025-08-13 09:11:33'),
(720, 282, 7, 1000000000933, 'Đã sử dụng', '2025-08-13 14:22:08', '2025-08-13 14:22:08'),
(721, 282, 9, 1000000000934, 'Đã sử dụng', '2025-08-13 14:22:08', '2025-08-13 14:22:08'),
(722, 282, 11, 1000000000935, 'Đã sử dụng', '2025-08-13 14:22:08', '2025-08-13 14:22:08'),
(723, 283, 13, 1000000000936, 'Đã sử dụng', '2025-08-14 10:33:55', '2025-08-14 10:33:55'),
(724, 283, 15, 1000000000937, 'Đã sử dụng', '2025-08-14 10:33:55', '2025-08-14 10:33:55'),
(725, 283, 17, 1000000000938, 'Đã sử dụng', '2025-08-14 10:33:55', '2025-08-14 10:33:55'),
(726, 284, 19, 1000000000939, 'Đã sử dụng', '2025-08-14 16:44:22', '2025-08-14 16:44:22'),
(727, 284, 21, 1000000000940, 'Đã sử dụng', '2025-08-14 16:44:22', '2025-08-14 16:44:22'),
(728, 284, 23, 1000000000941, 'Đã sử dụng', '2025-08-14 16:44:22', '2025-08-14 16:44:22'),
(729, 285, 1, 1000000000942, 'Đã sử dụng', '2025-08-15 11:55:33', '2025-08-15 11:55:33'),
(730, 285, 3, 1000000000943, 'Đã sử dụng', '2025-08-15 11:55:33', '2025-08-15 11:55:33'),
(731, 286, 1, 1000000000988, 'Đã sử dụng', '2025-08-14 09:22:11', '2025-08-14 09:22:11'),
(732, 286, 3, 1000000000989, 'Đã sử dụng', '2025-08-14 09:22:11', '2025-08-14 09:22:11'),
(733, 286, 5, 1000000000990, 'Đã sử dụng', '2025-08-14 09:22:11', '2025-08-14 09:22:11'),
(734, 287, 7, 1000000000991, 'Đã sử dụng', '2025-08-14 14:33:44', '2025-08-14 14:33:44'),
(735, 287, 9, 1000000000992, 'Đã sử dụng', '2025-08-14 14:33:44', '2025-08-14 14:33:44'),
(736, 287, 11, 1000000000993, 'Đã sử dụng', '2025-08-14 14:33:44', '2025-08-14 14:33:44'),
(737, 288, 13, 1000000000994, 'Đã sử dụng', '2025-08-15 10:55:22', '2025-08-15 10:55:22'),
(738, 288, 15, 1000000000995, 'Đã sử dụng', '2025-08-15 10:55:22', '2025-08-15 10:55:22'),
(739, 288, 17, 1000000000996, 'Đã sử dụng', '2025-08-15 10:55:22', '2025-08-15 10:55:22'),
(740, 289, 19, 1000000000997, 'Đã sử dụng', '2025-08-15 17:11:33', '2025-08-15 17:11:33'),
(741, 289, 21, 1000000000998, 'Đã sử dụng', '2025-08-15 17:11:33', '2025-08-15 17:11:33'),
(742, 289, 23, 1000000000999, 'Đã sử dụng', '2025-08-15 17:11:33', '2025-08-15 17:11:33'),
(743, 290, 1, 1000000001000, 'Đã sử dụng', '2025-08-16 11:44:55', '2025-08-16 11:44:55'),
(744, 290, 3, 1000000001001, 'Đã sử dụng', '2025-08-16 11:44:55', '2025-08-16 11:44:55'),
(745, 291, 5, 1000000001002, 'Đã sử dụng', '2025-08-16 18:22:08', '2025-08-16 18:22:08'),
(746, 291, 7, 1000000001003, 'Đã sử dụng', '2025-08-16 18:22:08', '2025-08-16 18:22:08'),
(747, 291, 9, 1000000001004, 'Đã sử dụng', '2025-08-16 18:22:08', '2025-08-16 18:22:08'),
(748, 292, 53, 1000000001005, 'Đã sử dụng', '2025-08-30 09:18:33', '2025-08-30 09:18:33'),
(749, 292, 55, 1000000001006, 'Đã sử dụng', '2025-08-30 09:18:33', '2025-08-30 09:18:33'),
(750, 292, 57, 1000000001007, 'Đã sử dụng', '2025-08-30 09:18:33', '2025-08-30 09:18:33'),
(751, 293, 59, 1000000001008, 'Đã sử dụng', '2025-08-30 15:29:11', '2025-08-30 15:29:11'),
(752, 293, 61, 1000000001009, 'Đã sử dụng', '2025-08-30 15:29:11', '2025-08-30 15:29:11'),
(753, 293, 63, 1000000001010, 'Đã sử dụng', '2025-08-30 15:29:11', '2025-08-30 15:29:11'),
(754, 294, 65, 1000000001011, 'Đã sử dụng', '2025-08-31 10:44:55', '2025-08-31 10:44:55'),
(755, 294, 67, 1000000001012, 'Đã sử dụng', '2025-08-31 10:44:55', '2025-08-31 10:44:55'),
(756, 295, 69, 1000000001013, 'Đã sử dụng', '2025-08-31 16:33:22', '2025-08-31 16:33:22'),
(757, 295, 107, 1000000001014, 'Đã sử dụng', '2025-08-31 16:33:22', '2025-08-31 16:33:22'),
(758, 296, 109, 1000000001015, 'Đã sử dụng', '2025-09-01 11:55:33', '2025-09-01 11:55:33'),
(759, 296, 111, 1000000001016, 'Đã sử dụng', '2025-09-01 11:55:33', '2025-09-01 11:55:33'),
(760, 296, 113, 1000000001017, 'Đã sử dụng', '2025-09-01 11:55:33', '2025-09-01 11:55:33'),
(761, 297, 77, 1000000001018, 'Đã sử dụng', '2025-08-21 09:33:11', '2025-08-21 09:33:11'),
(762, 297, 79, 1000000001019, 'Đã sử dụng', '2025-08-21 09:33:11', '2025-08-21 09:33:11'),
(763, 297, 81, 1000000001020, 'Đã sử dụng', '2025-08-21 09:33:11', '2025-08-21 09:33:11'),
(764, 298, 83, 1000000001021, 'Đã sử dụng', '2025-08-21 14:44:55', '2025-08-21 14:44:55'),
(765, 298, 85, 1000000001022, 'Đã sử dụng', '2025-08-21 14:44:55', '2025-08-21 14:44:55'),
(766, 299, 87, 1000000001023, 'Đã sử dụng', '2025-08-22 10:22:08', '2025-08-22 10:22:08'),
(767, 299, 89, 1000000001024, 'Đã sử dụng', '2025-08-22 10:22:08', '2025-08-22 10:22:08'),
(768, 300, 77, 1000000001025, 'Đã sử dụng', '2025-08-22 17:11:33', '2025-08-22 17:11:33'),
(769, 300, 79, 1000000001026, 'Đã sử dụng', '2025-08-22 17:11:33', '2025-08-22 17:11:33'),
(770, 301, 1, 1000000001027, 'Đã sử dụng', '2025-08-07 09:11:22', '2025-08-07 09:11:22'),
(771, 301, 3, 1000000001028, 'Đã sử dụng', '2025-08-07 09:11:22', '2025-08-07 09:11:22'),
(772, 301, 5, 1000000001029, 'Đã sử dụng', '2025-08-07 09:11:22', '2025-08-07 09:11:22'),
(773, 302, 7, 1000000001030, 'Đã sử dụng', '2025-08-07 15:22:44', '2025-08-07 15:22:44'),
(774, 302, 9, 1000000001031, 'Đã sử dụng', '2025-08-07 15:22:44', '2025-08-07 15:22:44'),
(775, 302, 11, 1000000001032, 'Đã sử dụng', '2025-08-07 15:22:44', '2025-08-07 15:22:44'),
(776, 303, 13, 1000000001033, 'Đã sử dụng', '2025-08-08 10:33:55', '2025-08-08 10:33:55'),
(777, 303, 15, 1000000001034, 'Đã sử dụng', '2025-08-08 10:33:55', '2025-08-08 10:33:55'),
(778, 303, 17, 1000000001035, 'Đã sử dụng', '2025-08-08 10:33:55', '2025-08-08 10:33:55'),
(779, 304, 19, 1000000001036, 'Đã sử dụng', '2025-08-08 16:44:22', '2025-08-08 16:44:22'),
(780, 304, 21, 1000000001037, 'Đã sử dụng', '2025-08-08 16:44:22', '2025-08-08 16:44:22'),
(781, 304, 23, 1000000001038, 'Đã sử dụng', '2025-08-08 16:44:22', '2025-08-08 16:44:22'),
(782, 305, 25, 1000000001039, 'Đã sử dụng', '2025-08-09 11:55:33', '2025-08-09 11:55:33'),
(783, 305, 27, 1000000001040, 'Đã sử dụng', '2025-08-09 11:55:33', '2025-08-09 11:55:33'),
(784, 306, 29, 1000000001041, 'Đã sử dụng', '2025-08-09 18:11:44', '2025-08-09 18:11:44'),
(785, 306, 31, 1000000001042, 'Đã sử dụng', '2025-08-09 18:11:44', '2025-08-09 18:11:44'),
(786, 306, 33, 1000000001043, 'Đã sử dụng', '2025-08-09 18:11:44', '2025-08-09 18:11:44'),
(787, 307, 35, 1000000001044, 'Đã sử dụng', '2025-08-10 09:22:11', '2025-08-10 09:22:11'),
(788, 307, 37, 1000000001045, 'Đã sử dụng', '2025-08-10 09:22:11', '2025-08-10 09:22:11'),
(789, 308, 53, 1000000001046, 'Đã sử dụng', '2025-08-28 10:18:22', '2025-08-28 10:18:22'),
(790, 308, 55, 1000000001047, 'Đã sử dụng', '2025-08-28 10:18:22', '2025-08-28 10:18:22'),
(791, 308, 57, 1000000001048, 'Đã sử dụng', '2025-08-28 10:18:22', '2025-08-28 10:18:22'),
(792, 309, 59, 1000000001049, 'Đã sử dụng', '2025-08-28 15:29:11', '2025-08-28 15:29:11'),
(793, 309, 61, 1000000001050, 'Đã sử dụng', '2025-08-28 15:29:11', '2025-08-28 15:29:11'),
(794, 309, 63, 1000000001051, 'Đã sử dụng', '2025-08-28 15:29:11', '2025-08-28 15:29:11'),
(795, 310, 65, 1000000001052, 'Đã sử dụng', '2025-08-29 09:44:55', '2025-08-29 09:44:55'),
(796, 310, 67, 1000000001053, 'Đã sử dụng', '2025-08-29 09:44:55', '2025-08-29 09:44:55'),
(797, 311, 107, 1000000001054, 'Đã sử dụng', '2025-08-29 14:33:22', '2025-08-29 14:33:22'),
(798, 312, 1, 1000000001055, 'Đã sử dụng', '2025-09-13 09:11:33', '2025-09-13 09:11:33'),
(799, 312, 3, 1000000001056, 'Đã sử dụng', '2025-09-13 09:11:33', '2025-09-13 09:11:33'),
(800, 312, 5, 1000000001057, 'Đã sử dụng', '2025-09-13 09:11:33', '2025-09-13 09:11:33'),
(801, 313, 7, 1000000001058, 'Đã sử dụng', '2025-09-13 14:22:08', '2025-09-13 14:22:08'),
(802, 313, 9, 1000000001059, 'Đã sử dụng', '2025-09-13 14:22:08', '2025-09-13 14:22:08'),
(803, 313, 11, 1000000001060, 'Đã sử dụng', '2025-09-13 14:22:08', '2025-09-13 14:22:08'),
(804, 314, 13, 1000000001061, 'Đã sử dụng', '2025-09-14 10:33:55', '2025-09-14 10:33:55'),
(805, 314, 15, 1000000001062, 'Đã sử dụng', '2025-09-14 10:33:55', '2025-09-14 10:33:55'),
(806, 314, 17, 1000000001063, 'Đã sử dụng', '2025-09-14 10:33:55', '2025-09-14 10:33:55'),
(807, 315, 19, 1000000001064, 'Đã sử dụng', '2025-09-14 16:44:22', '2025-09-14 16:44:22'),
(808, 315, 21, 1000000001065, 'Đã sử dụng', '2025-09-14 16:44:22', '2025-09-14 16:44:22'),
(809, 315, 23, 1000000001066, 'Đã sử dụng', '2025-09-14 16:44:22', '2025-09-14 16:44:22'),
(810, 316, 1, 1000000001067, 'Đã sử dụng', '2025-09-15 11:55:33', '2025-09-15 11:55:33'),
(811, 316, 3, 1000000001068, 'Đã sử dụng', '2025-09-15 11:55:33', '2025-09-15 11:55:33'),
(812, 317, 5, 1000000001069, 'Đã sử dụng', '2025-09-15 18:11:44', '2025-09-15 18:11:44'),
(813, 317, 7, 1000000001070, 'Đã sử dụng', '2025-09-15 18:11:44', '2025-09-15 18:11:44'),
(814, 317, 9, 1000000001071, 'Đã sử dụng', '2025-09-15 18:11:44', '2025-09-15 18:11:44'),
(815, 318, 11, 1000000001072, 'Đã sử dụng', '2025-09-16 09:22:11', '2025-09-16 09:22:11'),
(816, 319, 1, 1000000001073, 'Đã sử dụng', '2025-09-10 09:15:22', '2025-09-10 09:15:22'),
(817, 319, 3, 1000000001074, 'Đã sử dụng', '2025-09-10 09:15:22', '2025-09-10 09:15:22'),
(818, 319, 5, 1000000001075, 'Đã sử dụng', '2025-09-10 09:15:22', '2025-09-10 09:15:22'),
(819, 320, 7, 1000000001076, 'Đã sử dụng', '2025-09-10 14:30:44', '2025-09-10 14:30:44'),
(820, 320, 9, 1000000001077, 'Đã sử dụng', '2025-09-10 14:30:44', '2025-09-10 14:30:44'),
(821, 320, 11, 1000000001078, 'Đã sử dụng', '2025-09-10 14:30:44', '2025-09-10 14:30:44'),
(822, 321, 13, 1000000001079, 'Đã sử dụng', '2025-09-11 10:22:11', '2025-09-11 10:22:11'),
(823, 321, 15, 1000000001080, 'Đã sử dụng', '2025-09-11 10:22:11', '2025-09-11 10:22:11'),
(824, 321, 17, 1000000001081, 'Đã sử dụng', '2025-09-11 10:22:11', '2025-09-11 10:22:11'),
(825, 322, 19, 1000000001082, 'Đã sử dụng', '2025-09-11 16:45:33', '2025-09-11 16:45:33'),
(826, 322, 21, 1000000001083, 'Đã sử dụng', '2025-09-11 16:45:33', '2025-09-11 16:45:33'),
(827, 322, 23, 1000000001084, 'Đã sử dụng', '2025-09-11 16:45:33', '2025-09-11 16:45:33'),
(828, 323, 25, 1000000001085, 'Đã sử dụng', '2025-09-12 11:11:55', '2025-09-12 11:11:55'),
(829, 324, 53, 1000000001086, 'Đã sử dụng', '2025-10-01 09:30:11', '2025-10-01 09:30:11'),
(830, 324, 55, 1000000001087, 'Đã sử dụng', '2025-10-01 09:30:11', '2025-10-01 09:30:11'),
(831, 324, 57, 1000000001088, 'Đã sử dụng', '2025-10-01 09:30:11', '2025-10-01 09:30:11'),
(832, 325, 59, 1000000001089, 'Đã sử dụng', '2025-10-01 15:18:44', '2025-10-01 15:18:44'),
(833, 325, 61, 1000000001090, 'Đã sử dụng', '2025-10-01 15:18:44', '2025-10-01 15:18:44'),
(834, 325, 63, 1000000001091, 'Đã sử dụng', '2025-10-01 15:18:44', '2025-10-01 15:18:44'),
(835, 326, 65, 1000000001092, 'Đã sử dụng', '2025-10-02 10:55:22', '2025-10-02 10:55:22'),
(836, 326, 67, 1000000001093, 'Đã sử dụng', '2025-10-02 10:55:22', '2025-10-02 10:55:22'),
(837, 326, 69, 1000000001094, 'Đã sử dụng', '2025-10-02 10:55:22', '2025-10-02 10:55:22'),
(838, 327, 107, 1000000001095, 'Đã sử dụng', '2025-10-02 17:33:11', '2025-10-02 17:33:11'),
(839, 327, 109, 1000000001096, 'Đã sử dụng', '2025-10-02 17:33:11', '2025-10-02 17:33:11'),
(840, 328, 77, 1000000001097, 'Đã sử dụng', '2025-09-08 09:22:33', '2025-09-08 09:22:33'),
(841, 328, 79, 1000000001098, 'Đã sử dụng', '2025-09-08 09:22:33', '2025-09-08 09:22:33'),
(842, 328, 81, 1000000001099, 'Đã sử dụng', '2025-09-08 09:22:33', '2025-09-08 09:22:33'),
(843, 329, 83, 1000000001100, 'Đã sử dụng', '2025-09-08 14:44:55', '2025-09-08 14:44:55'),
(844, 329, 85, 1000000001101, 'Đã sử dụng', '2025-09-08 14:44:55', '2025-09-08 14:44:55'),
(845, 329, 87, 1000000001102, 'Đã sử dụng', '2025-09-08 14:44:55', '2025-09-08 14:44:55'),
(846, 330, 89, 1000000001103, 'Đã sử dụng', '2025-09-09 11:11:22', '2025-09-09 11:11:22'),
(847, 331, 1, 1000000001104, 'Đã sử dụng', '2025-09-20 09:11:33', '2025-09-20 09:11:33'),
(848, 331, 3, 1000000001105, 'Đã sử dụng', '2025-09-20 09:11:33', '2025-09-20 09:11:33'),
(849, 331, 5, 1000000001106, 'Đã sử dụng', '2025-09-20 09:11:33', '2025-09-20 09:11:33'),
(850, 332, 7, 1000000001107, 'Đã sử dụng', '2025-09-20 14:22:08', '2025-09-20 14:22:08'),
(851, 332, 9, 1000000001108, 'Đã sử dụng', '2025-09-20 14:22:08', '2025-09-20 14:22:08'),
(852, 332, 11, 1000000001109, 'Đã sử dụng', '2025-09-20 14:22:08', '2025-09-20 14:22:08'),
(853, 333, 13, 1000000001110, 'Đã sử dụng', '2025-09-21 10:33:55', '2025-09-21 10:33:55'),
(854, 333, 15, 1000000001111, 'Đã sử dụng', '2025-09-21 10:33:55', '2025-09-21 10:33:55'),
(855, 333, 17, 1000000001112, 'Đã sử dụng', '2025-09-21 10:33:55', '2025-09-21 10:33:55'),
(856, 334, 19, 1000000001113, 'Đã sử dụng', '2025-09-21 16:44:22', '2025-09-21 16:44:22'),
(857, 334, 21, 1000000001114, 'Đã sử dụng', '2025-09-21 16:44:22', '2025-09-21 16:44:22'),
(858, 334, 23, 1000000001115, 'Đã sử dụng', '2025-09-21 16:44:22', '2025-09-21 16:44:22'),
(859, 335, 1, 1000000001116, 'Đã sử dụng', '2025-09-22 11:55:33', '2025-09-22 11:55:33'),
(860, 336, 1, 1000000001117, 'Đã sử dụng', '2025-09-05 09:18:22', '2025-09-05 09:18:22'),
(861, 336, 3, 1000000001118, 'Đã sử dụng', '2025-09-05 09:18:22', '2025-09-05 09:18:22'),
(862, 336, 5, 1000000001119, 'Đã sử dụng', '2025-09-05 09:18:22', '2025-09-05 09:18:22'),
(863, 336, 7, 1000000001120, 'Đã sử dụng', '2025-09-05 09:18:22', '2025-09-05 09:18:22'),
(864, 337, 9, 1000000001121, 'Đã sử dụng', '2025-09-05 15:29:11', '2025-09-05 15:29:11'),
(865, 337, 11, 1000000001122, 'Đã sử dụng', '2025-09-05 15:29:11', '2025-09-05 15:29:11'),
(866, 337, 13, 1000000001123, 'Đã sử dụng', '2025-09-05 15:29:11', '2025-09-05 15:29:11'),
(867, 338, 15, 1000000001124, 'Đã sử dụng', '2025-09-06 10:44:55', '2025-09-06 10:44:55'),
(868, 338, 17, 1000000001125, 'Đã sử dụng', '2025-09-06 10:44:55', '2025-09-06 10:44:55'),
(869, 338, 19, 1000000001126, 'Đã sử dụng', '2025-09-06 10:44:55', '2025-09-06 10:44:55'),
(870, 339, 21, 1000000001127, 'Đã sử dụng', '2025-09-06 17:11:33', '2025-09-06 17:11:33'),
(871, 339, 23, 1000000001128, 'Đã sử dụng', '2025-09-06 17:11:33', '2025-09-06 17:11:33'),
(872, 339, 25, 1000000001129, 'Đã sử dụng', '2025-09-06 17:11:33', '2025-09-06 17:11:33'),
(873, 340, 27, 1000000001130, 'Đã sử dụng', '2025-09-07 11:55:22', '2025-09-07 11:55:22'),
(874, 340, 29, 1000000001131, 'Đã sử dụng', '2025-09-07 11:55:22', '2025-09-07 11:55:22'),
(875, 341, 31, 1000000001132, 'Đã sử dụng', '2025-09-07 18:22:08', '2025-09-07 18:22:08'),
(876, 341, 33, 1000000001133, 'Đã sử dụng', '2025-09-07 18:22:08', '2025-09-07 18:22:08'),
(877, 342, 77, 1000000001134, 'Đã sử dụng', '2025-10-03 09:33:11', '2025-10-03 09:33:11'),
(878, 342, 79, 1000000001135, 'Đã sử dụng', '2025-10-03 09:33:11', '2025-10-03 09:33:11'),
(879, 342, 81, 1000000001136, 'Đã sử dụng', '2025-10-03 09:33:11', '2025-10-03 09:33:11'),
(880, 342, 83, 1000000001137, 'Đã sử dụng', '2025-10-03 09:33:11', '2025-10-03 09:33:11'),
(881, 343, 85, 1000000001138, 'Đã sử dụng', '2025-10-03 14:44:55', '2025-10-03 14:44:55'),
(882, 343, 87, 1000000001139, 'Đã sử dụng', '2025-10-03 14:44:55', '2025-10-03 14:44:55'),
(883, 343, 89, 1000000001140, 'Đã sử dụng', '2025-10-03 14:44:55', '2025-10-03 14:44:55'),
(884, 344, 91, 1000000001141, 'Đã sử dụng', '2025-10-04 10:22:08', '2025-10-04 10:22:08'),
(885, 344, 77, 1000000001142, 'Đã sử dụng', '2025-10-04 10:22:08', '2025-10-04 10:22:08'),
(886, 345, 79, 1000000001143, 'Đã sử dụng', '2025-10-04 16:33:22', '2025-10-04 16:33:22'),
(887, 346, 1, 1000000001144, 'Đã sử dụng', '2025-10-18 09:22:11', '2025-10-18 09:22:11'),
(888, 346, 3, 1000000001145, 'Đã sử dụng', '2025-10-18 09:22:11', '2025-10-18 09:22:11'),
(889, 346, 5, 1000000001146, 'Đã sử dụng', '2025-10-18 09:22:11', '2025-10-18 09:22:11'),
(890, 347, 7, 1000000001147, 'Đã sử dụng', '2025-10-18 15:33:44', '2025-10-18 15:33:44'),
(891, 347, 9, 1000000001148, 'Đã sử dụng', '2025-10-18 15:33:44', '2025-10-18 15:33:44'),
(892, 347, 11, 1000000001149, 'Đã sử dụng', '2025-10-18 15:33:44', '2025-10-18 15:33:44'),
(893, 348, 13, 1000000001150, 'Đã sử dụng', '2025-10-19 10:55:22', '2025-10-19 10:55:22'),
(894, 348, 15, 1000000001151, 'Đã sử dụng', '2025-10-19 10:55:22', '2025-10-19 10:55:22'),
(895, 348, 17, 1000000001152, 'Đã sử dụng', '2025-10-19 10:55:22', '2025-10-19 10:55:22'),
(896, 349, 19, 1000000001153, 'Đã sử dụng', '2025-10-19 17:11:33', '2025-10-19 17:11:33'),
(897, 349, 21, 1000000001154, 'Đã sử dụng', '2025-10-19 17:11:33', '2025-10-19 17:11:33'),
(898, 349, 23, 1000000001155, 'Đã sử dụng', '2025-10-19 17:11:33', '2025-10-19 17:11:33'),
(899, 350, 1, 1000000001156, 'Đã sử dụng', '2025-10-20 11:44:55', '2025-10-20 11:44:55'),
(900, 351, 53, 1000000001157, 'Đã sử dụng', '2025-10-31 09:18:33', '2025-10-31 09:18:33'),
(901, 351, 55, 1000000001158, 'Đã sử dụng', '2025-10-31 09:18:33', '2025-10-31 09:18:33'),
(902, 351, 57, 1000000001159, 'Đã sử dụng', '2025-10-31 09:18:33', '2025-10-31 09:18:33'),
(903, 352, 59, 1000000001160, 'Đã sử dụng', '2025-10-31 14:29:11', '2025-10-31 14:29:11'),
(904, 352, 61, 1000000001161, 'Đã sử dụng', '2025-10-31 14:29:11', '2025-10-31 14:29:11'),
(905, 352, 63, 1000000001162, 'Đã sử dụng', '2025-10-31 14:29:11', '2025-10-31 14:29:11'),
(906, 353, 65, 1000000001163, 'Đã sử dụng', '2025-11-01 10:44:55', '2025-11-01 10:44:55'),
(907, 353, 67, 1000000001164, 'Đã sử dụng', '2025-11-01 10:44:55', '2025-11-01 10:44:55'),
(908, 353, 69, 1000000001165, 'Đã sử dụng', '2025-11-01 10:44:55', '2025-11-01 10:44:55'),
(909, 354, 107, 1000000001166, 'Đã sử dụng', '2025-11-01 16:33:22', '2025-11-01 16:33:22'),
(910, 354, 109, 1000000001167, 'Đã sử dụng', '2025-11-01 16:33:22', '2025-11-01 16:33:22'),
(911, 354, 111, 1000000001168, 'Đã sử dụng', '2025-11-01 16:33:22', '2025-11-01 16:33:22'),
(912, 354, 113, 1000000001169, 'Đã sử dụng', '2025-11-01 16:33:22', '2025-11-01 16:33:22'),
(913, 355, 77, 1000000001170, 'Đã sử dụng', '2025-10-22 09:33:11', '2025-10-22 09:33:11'),
(914, 355, 79, 1000000001171, 'Đã sử dụng', '2025-10-22 09:33:11', '2025-10-22 09:33:11'),
(915, 355, 81, 1000000001172, 'Đã sử dụng', '2025-10-22 09:33:11', '2025-10-22 09:33:11'),
(916, 356, 83, 1000000001173, 'Đã sử dụng', '2025-10-22 14:44:55', '2025-10-22 14:44:55'),
(917, 356, 85, 1000000001174, 'Đã sử dụng', '2025-10-22 14:44:55', '2025-10-22 14:44:55'),
(918, 356, 87, 1000000001175, 'Đã sử dụng', '2025-10-22 14:44:55', '2025-10-22 14:44:55'),
(919, 357, 89, 1000000001176, 'Đã sử dụng', '2025-10-23 11:22:08', '2025-10-23 11:22:08'),
(920, 357, 91, 1000000001177, 'Đã sử dụng', '2025-10-23 11:22:08', '2025-10-23 11:22:08'),
(921, 358, 1, 1000000001178, 'Hợp lệ', '2025-11-10 09:22:11', '2025-11-10 09:22:11'),
(922, 358, 3, 1000000001179, 'Hợp lệ', '2025-11-11 10:00:00', '2025-11-11 10:00:00'),
(923, 358, 5, 1000000001180, 'Hợp lệ', '2025-11-10 09:22:11', '2025-11-10 09:22:11'),
(924, 359, 7, 1000000001181, 'Hợp lệ', '2025-11-10 14:33:44', '2025-11-10 14:33:44'),
(925, 359, 9, 1000000001182, 'Hợp lệ', '2025-11-10 14:33:44', '2025-11-10 14:33:44'),
(926, 359, 11, 1000000001183, 'Hợp lệ', '2025-11-10 14:33:44', '2025-11-10 14:33:44'),
(927, 360, 13, 1000000001184, 'Hợp lệ', '2025-11-11 10:55:22', '2025-11-11 10:55:22'),
(928, 360, 15, 1000000001185, 'Hợp lệ', '2025-11-11 10:55:22', '2025-11-11 10:55:22'),
(929, 361, 1, 1000000001186, 'Hợp lệ', '2025-11-11 16:11:33', '2025-11-11 16:11:33'),
(930, 362, 53, 1000000001187, 'Hợp lệ', '2025-11-15 09:30:22', '2025-11-15 09:30:22'),
(931, 362, 57, 1000000001188, 'Hợp lệ', '2025-11-15 09:30:22', '2025-11-15 09:30:22'),
(932, 362, 61, 1000000001189, 'Hợp lệ', '2025-11-15 09:30:22', '2025-11-15 09:30:22'),
(933, 363, 65, 1000000001190, 'Hợp lệ', '2025-11-15 15:18:44', '2025-11-15 15:18:44'),
(934, 363, 107, 1000000001191, 'Hợp lệ', '2025-11-15 15:18:44', '2025-11-15 15:18:44'),
(935, 363, 109, 1000000001192, 'Hợp lệ', '2025-11-15 15:18:44', '2025-11-15 15:18:44'),
(936, 364, 111, 1000000001193, 'Hợp lệ', '2025-11-16 11:44:55', '2025-11-16 11:44:55'),
(937, 364, 113, 1000000001194, 'Hợp lệ', '2025-11-16 11:44:55', '2025-11-16 11:44:55'),
(938, 365, 77, 1000000001195, 'Hợp lệ', '2025-11-20 09:11:33', '2025-11-20 09:11:33'),
(939, 365, 81, 1000000001196, 'Hợp lệ', '2025-11-20 09:11:33', '2025-11-20 09:11:33'),
(940, 365, 85, 1000000001197, 'Hợp lệ', '2025-11-20 09:11:33', '2025-11-20 09:11:33'),
(941, 366, 89, 1000000001198, 'Hợp lệ', '2025-11-20 14:22:08', '2025-11-20 14:22:08'),
(942, 366, 77, 1000000001199, 'Hợp lệ', '2025-11-20 14:22:08', '2025-11-20 14:22:08'),
(943, 367, 1, 1000000001200, 'Hợp lệ', '2025-11-25 09:11:33', '2025-11-25 09:11:33'),
(944, 367, 3, 1000000001201, 'Hợp lệ', '2025-11-25 09:11:33', '2025-11-25 09:11:33'),
(945, 367, 5, 1000000001202, 'Hợp lệ', '2025-11-25 09:11:33', '2025-11-25 09:11:33'),
(946, 368, 7, 1000000001203, 'Hợp lệ', '2025-11-25 14:22:08', '2025-11-25 14:22:08'),
(947, 368, 9, 1000000001204, 'Hợp lệ', '2025-11-25 14:22:08', '2025-11-25 14:22:08'),
(948, 368, 11, 1000000001205, 'Hợp lệ', '2025-11-25 14:22:08', '2025-11-25 14:22:08'),
(949, 369, 13, 1000000001317, 'Hợp lệ', '2025-11-26 10:33:55', '2025-11-26 10:33:55'),
(950, 369, 15, 1000000001318, 'Hợp lệ', '2025-11-26 10:33:55', '2025-11-26 10:33:55'),
(951, 370, 1, 1000000001319, 'Hợp lệ', '2025-11-26 16:44:22', '2025-11-26 16:44:22'),
(952, 371, 53, 1000000001320, 'Hợp lệ', '2025-11-28 09:22:11', '2025-11-28 09:22:11'),
(953, 371, 57, 1000000001321, 'Hợp lệ', '2025-11-28 09:22:11', '2025-11-28 09:22:11'),
(954, 371, 61, 1000000001322, 'Hợp lệ', '2025-11-28 09:22:11', '2025-11-28 09:22:11'),
(955, 372, 65, 1000000001323, 'Hợp lệ', '2025-11-28 15:18:44', '2025-11-28 15:18:44'),
(956, 372, 107, 1000000001324, 'Hợp lệ', '2025-11-28 15:18:44', '2025-11-28 15:18:44'),
(957, 372, 109, 1000000001325, 'Hợp lệ', '2025-11-28 15:18:44', '2025-11-28 15:18:44'),
(958, 373, 111, 1000000001326, 'Hợp lệ', '2025-11-29 11:44:55', '2025-11-29 11:44:55'),
(959, 373, 113, 1000000001327, 'Hợp lệ', '2025-11-29 11:44:55', '2025-11-29 11:44:55'),
(960, 374, 77, 1000000001328, 'Hợp lệ', '2025-11-20 09:33:22', '2025-11-20 09:33:22'),
(961, 374, 81, 1000000001329, 'Hợp lệ', '2025-11-20 09:33:22', '2025-11-20 09:33:22'),
(962, 374, 85, 1000000001330, 'Hợp lệ', '2025-11-20 09:33:22', '2025-11-20 09:33:22'),
(963, 375, 89, 1000000001331, 'Hợp lệ', '2025-11-20 14:55:11', '2025-11-20 14:55:11'),
(964, 375, 77, 1000000001332, 'Hợp lệ', '2025-11-20 14:55:11', '2025-11-20 14:55:11'),
(965, 376, 53, 1000000001333, 'Hợp lệ', '2025-12-01 09:18:33', '2025-12-01 09:18:33'),
(966, 376, 57, 1000000001334, 'Hợp lệ', '2025-12-01 09:18:33', '2025-12-01 09:18:33'),
(967, 376, 61, 1000000001335, 'Hợp lệ', '2025-12-01 09:18:33', '2025-12-01 09:18:33'),
(968, 377, 65, 1000000001336, 'Hợp lệ', '2025-12-01 15:29:11', '2025-12-01 15:29:11'),
(969, 377, 107, 1000000001337, 'Hợp lệ', '2025-12-01 15:29:11', '2025-12-01 15:29:11'),
(970, 377, 109, 1000000001338, 'Hợp lệ', '2025-12-01 15:29:11', '2025-12-01 15:29:11'),
(971, 378, 111, 1000000001339, 'Hợp lệ', '2025-12-02 10:44:55', '2025-12-02 10:44:55'),
(972, 378, 113, 1000000001340, 'Hợp lệ', '2025-12-02 10:44:55', '2025-12-02 10:44:55');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `user_type` enum('Nhân viên','Admin','Khách hàng') NOT NULL,
  `status` enum('hoạt động','khóa') NOT NULL DEFAULT 'hoạt động',
  `is_verified` tinyint(1) NOT NULL DEFAULT 0,
  `otp_code` varchar(10) DEFAULT NULL,
  `otp_expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `email`, `password`, `account_name`, `user_type`, `status`, `is_verified`, `otp_code`, `otp_expires_at`) VALUES
(1, 'staff@example.com', '$2a$11$9BeTi3ebcIhMErqHpJRxweJSqy1xpEtw3ITU00sHOlGuvLJWz011O', 'staff', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(2, 'trangltmt1509@gmail.com', '$2y$10$0doy81SVgcSvSwMD/VBK2OGfKf6yIVFEnCmzZYR15PjSq/yGz8p.C', 'trale', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(3, 'hoaithunguyen066@gmail.com', '$2y$10$6pjx5wsk.tW3icop/RZjWu0nMUqs61OhljS8NttNHqOxG2yP/sZdK', 'ht1123', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(4, 'nguyenthithuytrang2020bd@gmail.com', '$2y$10$qEOSBdHhLThH6gneJ2tki.YIdoFCGM7wsBScXYAZ7sgZpDUIuLKSW', 'nguyenna', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(6, 'trangle.31231026559@st.ueh.edu.vn', '$2a$11$eomc40N0cv3Ylmr2AA0tEu5DDSvkAc1BWdYVQLK8181DGbCo.7Hgq', 'trangle', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(7, 'admin@example.com', '$2a$11$4jiWZrbKvrU31h6lLhf8ze7.FYsF1RaHJD8k9EDFnH/2tPk0lSOG2', 'admin', 'Admin', 'hoạt động', 1, NULL, NULL),
(8, 'minarmy1509@gmail.com', '$2y$10$WmOFFFccY97IjoBtyNQvRufjZLc4MkquHvWOLCSjIn2EIgv.li3my', 'nana', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(9, 'nguyenhoaithu2019pm@gmail.com', '$2y$10$QVaUYDI.e5LWa6G6yqBcHOhHkIr8sez1ze2TMGPWYYMVe29/3caka', 'thele', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(10, 'thuytrang2020bd@gmail.com', '$2y$10$n5UURYh9PjaT9p/zhnD/XuRgILBxbsonGWch13ztBpOP8hjQm7IoG', 'hieunguyen', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(11, 'trangnguyen.31231026201@st.ueh.edu.vn', '$2a$11$ndW2z6oNM4zTpgdZ8Cri4.GbhGEIwnuT/OJZ/EnMMp1QIHxnc0lOO', 'thuytrang', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(12, 'thunguyen.31231026200@ueh.edu.vn', '$2a$11$qvmNfvCHabyYkC/DUPE1eOtlJkQhEUf0GfuxF.A0Gk5azhiZkiZ36', 'hoaithu', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(13, 'ngocduong.31231024139@st.ueh.edu.vn', '$2a$11$5VkZcBouRzHQVgs//GPuFeWf7UaWXdUlEnN2zA8FrNSvSsMddlg/i', 'thanhngoc', 'Nhân viên', 'hoạt động', 1, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `user_detail`
--

CREATE TABLE `user_detail` (
  `user_id` int(11) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `date_of_birth` date NOT NULL,
  `address` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `user_detail`
--

INSERT INTO `user_detail` (`user_id`, `full_name`, `date_of_birth`, `address`, `phone`) VALUES
(1, 'Dương Hà Thanh', '2005-08-12', NULL, NULL),
(2, 'Lê Minh Anh', '2005-09-10', NULL, NULL),
(3, 'Nguyễn Hà Thi', '2005-08-01', NULL, NULL),
(4, 'Nguyễn Thùy Trinh', '2005-03-12', NULL, NULL),
(6, 'Lê Thị Mỹ Trang', '2025-11-24', 'QN', ''),
(7, 'Lê Mỹ Phụng', '2025-11-22', 'BD', NULL),
(8, 'Nguyễn Thị Na', '2003-11-12', NULL, NULL),
(9, 'Lê Thùy Linh', '2001-12-12', NULL, NULL),
(10, 'Nguyễn Văn Hiếu', '2001-12-12', NULL, NULL),
(11, 'Nguyễn Thị Thùy Trang', '2005-03-12', '', ''),
(12, 'Nguyễn Hoài Thu', '2005-08-22', '', ''),
(13, 'Dương Thanh Ngọc', '2005-08-12', '', '');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `actors`
--
ALTER TABLE `actors`
  ADD PRIMARY KEY (`actor_id`);

--
-- Indexes for table `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`booking_id`),
  ADD KEY `idx_booking_user` (`user_id`),
  ADD KEY `idx_booking_performance` (`performance_id`),
  ADD KEY `idx_booking_created_by` (`created_by`);

--
-- Indexes for table `genres`
--
ALTER TABLE `genres`
  ADD PRIMARY KEY (`genre_id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`payment_id`),
  ADD KEY `idx_payment_booking` (`booking_id`);

--
-- Indexes for table `performances`
--
ALTER TABLE `performances`
  ADD PRIMARY KEY (`performance_id`),
  ADD KEY `idx_performance_show` (`show_id`),
  ADD KEY `idx_performance_theater` (`theater_id`);

--
-- Indexes for table `reviews`
--
ALTER TABLE `reviews`
  ADD PRIMARY KEY (`review_id`),
  ADD KEY `idx_review_show` (`show_id`),
  ADD KEY `idx_review_user` (`user_id`);

--
-- Indexes for table `seats`
--
ALTER TABLE `seats`
  ADD PRIMARY KEY (`seat_id`),
  ADD KEY `idx_seat_theater` (`theater_id`),
  ADD KEY `idx_seat_category` (`category_id`);

--
-- Indexes for table `seat_categories`
--
ALTER TABLE `seat_categories`
  ADD PRIMARY KEY (`category_id`);

--
-- Indexes for table `seat_performance`
--
ALTER TABLE `seat_performance`
  ADD KEY `idx_sp_performance` (`performance_id`),
  ADD KEY `idx_sp_seat` (`seat_id`);

--
-- Indexes for table `shows`
--
ALTER TABLE `shows`
  ADD PRIMARY KEY (`show_id`);

--
-- Indexes for table `show_actors`
--
ALTER TABLE `show_actors`
  ADD KEY `idx_sa_actor` (`actor_id`),
  ADD KEY `fk_sa_show` (`show_id`);

--
-- Indexes for table `show_genres`
--
ALTER TABLE `show_genres`
  ADD KEY `idx_sg_show` (`show_id`),
  ADD KEY `idx_sg_genre` (`genre_id`);

--
-- Indexes for table `theaters`
--
ALTER TABLE `theaters`
  ADD PRIMARY KEY (`theater_id`);

--
-- Indexes for table `tickets`
--
ALTER TABLE `tickets`
  ADD PRIMARY KEY (`ticket_id`),
  ADD UNIQUE KEY `unique_ticket_code` (`ticket_code`),
  ADD KEY `idx_ticket_booking` (`booking_id`),
  ADD KEY `idx_ticket_seat` (`seat_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `unique_email` (`email`),
  ADD UNIQUE KEY `unique_account` (`account_name`);

--
-- Indexes for table `user_detail`
--
ALTER TABLE `user_detail`
  ADD PRIMARY KEY (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `actors`
--
ALTER TABLE `actors`
  MODIFY `actor_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `booking_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=387;

--
-- AUTO_INCREMENT for table `genres`
--
ALTER TABLE `genres`
  MODIFY `genre_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `payment_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=394;

--
-- AUTO_INCREMENT for table `performances`
--
ALTER TABLE `performances`
  MODIFY `performance_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=74;

--
-- AUTO_INCREMENT for table `reviews`
--
ALTER TABLE `reviews`
  MODIFY `review_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `seats`
--
ALTER TABLE `seats`
  MODIFY `seat_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=144;

--
-- AUTO_INCREMENT for table `seat_categories`
--
ALTER TABLE `seat_categories`
  MODIFY `category_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `shows`
--
ALTER TABLE `shows`
  MODIFY `show_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `theaters`
--
ALTER TABLE `theaters`
  MODIFY `theater_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `tickets`
--
ALTER TABLE `tickets`
  MODIFY `ticket_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=991;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `user_detail`
--
ALTER TABLE `user_detail`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `fk_booking_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `fk_booking_performance` FOREIGN KEY (`performance_id`) REFERENCES `performances` (`performance_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_booking_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `fk_payment_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `performances`
--
ALTER TABLE `performances`
  ADD CONSTRAINT `fk_performance_show` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_performance_theater` FOREIGN KEY (`theater_id`) REFERENCES `theaters` (`theater_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `reviews`
--
ALTER TABLE `reviews`
  ADD CONSTRAINT `fk_review_show` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_review_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `seats`
--
ALTER TABLE `seats`
  ADD CONSTRAINT `fk_seat_category` FOREIGN KEY (`category_id`) REFERENCES `seat_categories` (`category_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_seat_theater` FOREIGN KEY (`theater_id`) REFERENCES `theaters` (`theater_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `seat_performance`
--
ALTER TABLE `seat_performance`
  ADD CONSTRAINT `fk_sp_performance` FOREIGN KEY (`performance_id`) REFERENCES `performances` (`performance_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_sp_seat` FOREIGN KEY (`seat_id`) REFERENCES `seats` (`seat_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `show_actors`
--
ALTER TABLE `show_actors`
  ADD CONSTRAINT `fk_sa_actor` FOREIGN KEY (`actor_id`) REFERENCES `actors` (`actor_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_sa_show` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE;

--
-- Constraints for table `show_genres`
--
ALTER TABLE `show_genres`
  ADD CONSTRAINT `fk_sg_genre` FOREIGN KEY (`genre_id`) REFERENCES `genres` (`genre_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_sg_show` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `tickets`
--
ALTER TABLE `tickets`
  ADD CONSTRAINT `fk_ticket_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ticket_seat` FOREIGN KEY (`seat_id`) REFERENCES `seats` (`seat_id`) ON UPDATE CASCADE;

--
-- Constraints for table `user_detail`
--
ALTER TABLE `user_detail`
  ADD CONSTRAINT `fk_user_detail` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
