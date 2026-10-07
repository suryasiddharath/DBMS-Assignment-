-- Veterinary Clinic and Animal Treatment Management System
-- MySQL 8.0.16+ (CHECK constraints are enforced from this version)

DROP DATABASE IF EXISTS vet_clinic;
CREATE DATABASE vet_clinic;
USE vet_clinic;

-- =========================================================
-- 1. TABLES (3NF)
-- =========================================================

CREATE TABLE owner (
    owner_id    INT AUTO_INCREMENT PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    phone       VARCHAR(15)  NOT NULL UNIQUE,
    email       VARCHAR(100) UNIQUE,
    address     VARCHAR(200),
    CONSTRAINT chk_owner_phone CHECK (phone REGEXP '^[0-9]{10,15}$')
);

CREATE TABLE species (
    species_id   INT AUTO_INCREMENT PRIMARY KEY,
    species_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE breed (
    breed_id   INT AUTO_INCREMENT PRIMARY KEY,
    species_id INT NOT NULL,
    breed_name VARCHAR(80) NOT NULL,
    CONSTRAINT uq_breed UNIQUE (species_id, breed_name),
    CONSTRAINT fk_breed_species FOREIGN KEY (species_id) REFERENCES species(species_id)
);

-- Business rule: unique animal identity per owner -> UNIQUE (owner_id, name)
CREATE TABLE animal (
    animal_id     INT AUTO_INCREMENT PRIMARY KEY,
    owner_id      INT NOT NULL,
    breed_id      INT NOT NULL,
    name          VARCHAR(60) NOT NULL,
    gender        ENUM('Male','Female') NOT NULL,
    date_of_birth DATE,
    weight_kg     DECIMAL(6,2) NOT NULL,
    registered_on DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_animal_per_owner UNIQUE (owner_id, name),
    CONSTRAINT chk_animal_weight CHECK (weight_kg > 0),
    CONSTRAINT fk_animal_owner FOREIGN KEY (owner_id) REFERENCES owner(owner_id),
    CONSTRAINT fk_animal_breed FOREIGN KEY (breed_id) REFERENCES breed(breed_id)
);

CREATE TABLE veterinarian (
    vet_id           INT AUTO_INCREMENT PRIMARY KEY,
    full_name        VARCHAR(100) NOT NULL,
    specialization   VARCHAR(80),
    phone            VARCHAR(15) NOT NULL UNIQUE,
    consultation_fee DECIMAL(8,2) NOT NULL DEFAULT 300.00,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_vet_fee CHECK (consultation_fee >= 0)
);

CREATE TABLE appointment (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    animal_id      INT NOT NULL,
    vet_id         INT NOT NULL,
    appt_start     DATETIME NOT NULL,
    appt_end       DATETIME NOT NULL,
    reason         VARCHAR(200),
    status         ENUM('Scheduled','Completed','Cancelled') NOT NULL DEFAULT 'Scheduled',
    CONSTRAINT chk_appt_time CHECK (appt_end > appt_start),
    CONSTRAINT fk_appt_animal FOREIGN KEY (animal_id) REFERENCES animal(animal_id),
    CONSTRAINT fk_appt_vet FOREIGN KEY (vet_id) REFERENCES veterinarian(vet_id)
);

CREATE TABLE consultation (
    consultation_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id  INT NOT NULL UNIQUE,
    symptoms        VARCHAR(300),
    notes           VARCHAR(500),
    CONSTRAINT fk_cons_appt FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id)
);

CREATE TABLE diagnosis (
    diagnosis_id    INT AUTO_INCREMENT PRIMARY KEY,
    consultation_id INT NOT NULL,
    description     VARCHAR(200) NOT NULL,
    CONSTRAINT fk_diag_cons FOREIGN KEY (consultation_id) REFERENCES consultation(consultation_id)
);

CREATE TABLE treatment (
    treatment_id    INT AUTO_INCREMENT PRIMARY KEY,
    consultation_id INT NOT NULL,
    description     VARCHAR(200) NOT NULL,
    cost            DECIMAL(8,2) NOT NULL DEFAULT 0,
    CONSTRAINT chk_treat_cost CHECK (cost >= 0),
    CONSTRAINT fk_treat_cons FOREIGN KEY (consultation_id) REFERENCES consultation(consultation_id)
);

CREATE TABLE medicine (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    unit_price  DECIMAL(8,2) NOT NULL,
    CONSTRAINT chk_med_price CHECK (unit_price >= 0)
);

-- Business rule: positive dosages
CREATE TABLE prescription (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    consultation_id INT NOT NULL,
    medicine_id     INT NOT NULL,
    dosage_mg       DECIMAL(8,2) NOT NULL,
    frequency       VARCHAR(50) NOT NULL,
    duration_days   INT NOT NULL,
    quantity        INT NOT NULL DEFAULT 1,
    CONSTRAINT chk_presc_dosage CHECK (dosage_mg > 0),
    CONSTRAINT chk_presc_days CHECK (duration_days > 0),
    CONSTRAINT chk_presc_qty CHECK (quantity > 0),
    CONSTRAINT fk_presc_cons FOREIGN KEY (consultation_id) REFERENCES consultation(consultation_id),
    CONSTRAINT fk_presc_med FOREIGN KEY (medicine_id) REFERENCES medicine(medicine_id)
);

CREATE TABLE vaccine (
    vaccine_id    INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE,
    validity_days INT NOT NULL,
    CONSTRAINT chk_vaccine_validity CHECK (validity_days > 0)
);

-- Business rule: valid vaccination dates (next due after given; given not in future -> trigger)
CREATE TABLE vaccination (
    vaccination_id INT AUTO_INCREMENT PRIMARY KEY,
    animal_id      INT NOT NULL,
    vaccine_id     INT NOT NULL,
    vet_id         INT NOT NULL,
    given_date     DATE NOT NULL,
    next_due_date  DATE NOT NULL,
    CONSTRAINT chk_vacc_dates CHECK (next_due_date > given_date),
    CONSTRAINT fk_vacc_animal FOREIGN KEY (animal_id) REFERENCES animal(animal_id),
    CONSTRAINT fk_vacc_vaccine FOREIGN KEY (vaccine_id) REFERENCES vaccine(vaccine_id),
    CONSTRAINT fk_vacc_vet FOREIGN KEY (vet_id) REFERENCES veterinarian(vet_id)
);

CREATE TABLE test_type (
    test_type_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name    VARCHAR(100) NOT NULL UNIQUE,
    price        DECIMAL(8,2) NOT NULL,
    CONSTRAINT chk_test_price CHECK (price >= 0)
);

CREATE TABLE animal_test (
    animal_test_id  INT AUTO_INCREMENT PRIMARY KEY,
    consultation_id INT NOT NULL,
    test_type_id    INT NOT NULL,
    test_date       DATE NOT NULL,
    result          VARCHAR(200),
    status          ENUM('Pending','Completed') NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_atest_cons FOREIGN KEY (consultation_id) REFERENCES consultation(consultation_id),
    CONSTRAINT fk_atest_type FOREIGN KEY (test_type_id) REFERENCES test_type(test_type_id)
);

CREATE TABLE bill (
    bill_id         INT AUTO_INCREMENT PRIMARY KEY,
    consultation_id INT NOT NULL UNIQUE,
    bill_date       DATE NOT NULL DEFAULT (CURRENT_DATE),
    total_amount    DECIMAL(10,2) NOT NULL,
    status          ENUM('Unpaid','Partial','Paid') NOT NULL DEFAULT 'Unpaid',
    CONSTRAINT chk_bill_total CHECK (total_amount >= 0),
    CONSTRAINT fk_bill_cons FOREIGN KEY (consultation_id) REFERENCES consultation(consultation_id)
);

CREATE TABLE payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    bill_id    INT NOT NULL,
    amount     DECIMAL(10,2) NOT NULL,
    method     ENUM('Cash','Card','UPI') NOT NULL,
    paid_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_pay_amount CHECK (amount > 0),
    CONSTRAINT fk_pay_bill FOREIGN KEY (bill_id) REFERENCES bill(bill_id)
);

-- =========================================================
-- 2. INDEXES on frequently searched columns
-- =========================================================
CREATE INDEX idx_owner_name      ON owner(full_name);
CREATE INDEX idx_animal_name     ON animal(name);
CREATE INDEX idx_appt_vet_time   ON appointment(vet_id, appt_start, appt_end);
CREATE INDEX idx_vacc_due        ON vaccination(next_due_date);
CREATE INDEX idx_payment_bill    ON payment(bill_id);

-- =========================================================
-- 3. TRIGGERS (business rules a CHECK cannot express)
-- =========================================================
DELIMITER $$

-- No overlapping appointments for the same veterinarian
CREATE TRIGGER trg_appt_no_overlap_ins BEFORE INSERT ON appointment
FOR EACH ROW
BEGIN
    IF NEW.status <> 'Cancelled' AND EXISTS (
        SELECT 1 FROM appointment a
        WHERE a.vet_id = NEW.vet_id
          AND a.status <> 'Cancelled'
          AND NEW.appt_start < a.appt_end
          AND NEW.appt_end   > a.appt_start
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Veterinarian already has an overlapping appointment';
    END IF;
END$$

CREATE TRIGGER trg_appt_no_overlap_upd BEFORE UPDATE ON appointment
FOR EACH ROW
BEGIN
    IF NEW.status <> 'Cancelled' AND EXISTS (
        SELECT 1 FROM appointment a
        WHERE a.vet_id = NEW.vet_id
          AND a.status <> 'Cancelled'
          AND a.appointment_id <> NEW.appointment_id
          AND NEW.appt_start < a.appt_end
          AND NEW.appt_end   > a.appt_start
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Veterinarian already has an overlapping appointment';
    END IF;
END$$

-- Vaccination cannot be recorded in the future
CREATE TRIGGER trg_vacc_date BEFORE INSERT ON vaccination
FOR EACH ROW
BEGIN
    IF NEW.given_date > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vaccination date cannot be in the future';
    END IF;
END$$

-- Payment limit: total payments cannot exceed the bill amount
CREATE TRIGGER trg_payment_limit BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_paid  DECIMAL(10,2);
    SELECT total_amount INTO v_total FROM bill WHERE bill_id = NEW.bill_id;
    SELECT COALESCE(SUM(amount), 0) INTO v_paid FROM payment WHERE bill_id = NEW.bill_id;
    IF v_paid + NEW.amount > v_total THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment exceeds the outstanding bill amount';
    END IF;
END$$

-- Keep bill status in sync after each payment
CREATE TRIGGER trg_payment_status AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_paid  DECIMAL(10,2);
    SELECT total_amount INTO v_total FROM bill WHERE bill_id = NEW.bill_id;
    SELECT SUM(amount) INTO v_paid FROM payment WHERE bill_id = NEW.bill_id;
    UPDATE bill
       SET status = IF(v_paid >= v_total, 'Paid', 'Partial')
     WHERE bill_id = NEW.bill_id;
END$$

-- =========================================================
-- 4. STORED PROCEDURE (transaction): generate or refresh a bill
-- =========================================================
CREATE PROCEDURE generate_bill(IN p_consultation_id INT)
BEGIN
    DECLARE v_total DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT
        v.consultation_fee
        + COALESCE((SELECT SUM(t.cost) FROM treatment t
                     WHERE t.consultation_id = p_consultation_id), 0)
        + COALESCE((SELECT SUM(m.unit_price * pr.quantity)
                      FROM prescription pr JOIN medicine m ON m.medicine_id = pr.medicine_id
                     WHERE pr.consultation_id = p_consultation_id), 0)
        + COALESCE((SELECT SUM(tt.price)
                      FROM animal_test at JOIN test_type tt ON tt.test_type_id = at.test_type_id
                     WHERE at.consultation_id = p_consultation_id), 0)
    INTO v_total
    FROM consultation c
    JOIN appointment a  ON a.appointment_id = c.appointment_id
    JOIN veterinarian v ON v.vet_id = a.vet_id
    WHERE c.consultation_id = p_consultation_id;

    INSERT INTO bill (consultation_id, total_amount)
    VALUES (p_consultation_id, v_total)
    ON DUPLICATE KEY UPDATE total_amount = v_total;

    COMMIT;
END$$

DELIMITER ;

-- =========================================================
-- 5. SAMPLE DATA
-- =========================================================
INSERT INTO owner (full_name, phone, email, address) VALUES
('Ravi Kumar',     '9876543210', 'ravi@example.com',   'Banjara Hills, Hyderabad'),
('Anita Sharma',   '9876543211', 'anita@example.com',  'Madhapur, Hyderabad'),
('Suresh Reddy',   '9876543212', 'suresh@example.com', 'Kukatpally, Hyderabad'),
('Priya Nair',     '9876543213', 'priya@example.com',  'Gachibowli, Hyderabad'),
('Mohammed Imran', '9876543214', 'imran@example.com',  'Secunderabad');

INSERT INTO species (species_name) VALUES ('Dog'), ('Cat'), ('Rabbit'), ('Bird');

INSERT INTO breed (species_id, breed_name) VALUES
(1,'Labrador Retriever'), (1,'German Shepherd'), (1,'Indian Pariah'),
(2,'Persian'), (2,'Siamese'),
(3,'Holland Lop'),
(4,'Budgerigar');

INSERT INTO animal (owner_id, breed_id, name, gender, date_of_birth, weight_kg) VALUES
(1, 1, 'Bruno',  'Male',   '2021-03-12', 28.50),
(1, 4, 'Misty',  'Female', '2022-07-01',  4.20),
(2, 2, 'Rocky',  'Male',   '2020-11-20', 32.00),
(3, 3, 'Tiger',  'Male',   '2023-01-15', 18.30),
(4, 5, 'Luna',   'Female', '2021-09-09',  3.80),
(5, 6, 'Snowy',  'Female', '2024-02-02',  1.60),
(2, 7, 'Kiwi',   'Male',   '2024-05-05',  0.04);

INSERT INTO veterinarian (full_name, specialization, phone, consultation_fee) VALUES
('Dr. Meera Iyer',   'Small animals', '9000000001', 400.00),
('Dr. Arjun Rao',    'Surgery',       '9000000002', 600.00),
('Dr. Sana Fathima', 'Exotic pets',   '9000000003', 500.00);

INSERT INTO appointment (animal_id, vet_id, appt_start, appt_end, reason, status) VALUES
(1, 1, '2026-09-20 10:00:00', '2026-09-20 10:30:00', 'Skin allergy',      'Completed'),
(3, 2, '2026-09-21 11:00:00', '2026-09-21 11:30:00', 'Limping',           'Completed'),
(2, 1, '2026-09-25 09:00:00', '2026-09-25 09:30:00', 'Loss of appetite',  'Completed'),
(4, 3, '2026-09-28 15:00:00', '2026-09-28 15:45:00', 'Annual check-up',   'Completed'),
(5, 2, '2026-10-05 10:00:00', '2026-10-05 10:30:00', 'Vomiting',          'Completed'),
(6, 1, '2026-10-09 10:00:00', '2026-10-09 10:30:00', 'Dental check',      'Scheduled'),
(1, 3, '2026-10-10 12:00:00', '2026-10-10 12:30:00', 'Follow-up',         'Scheduled');

INSERT INTO consultation (appointment_id, symptoms, notes) VALUES
(1, 'Itching, red patches',       'Likely food allergy'),
(2, 'Limps on right hind leg',    'No fracture on exam'),
(3, 'Not eating for 2 days',      'Mild dehydration'),
(4, 'None, routine visit',        'Healthy'),
(5, 'Vomiting twice daily',       'Gastric upset suspected');

INSERT INTO diagnosis (consultation_id, description) VALUES
(1, 'Allergic dermatitis'),
(2, 'Muscle sprain'),
(3, 'Gastroenteritis'),
(5, 'Gastritis');

INSERT INTO treatment (consultation_id, description, cost) VALUES
(1, 'Medicated bath',        350.00),
(2, 'Bandage and rest plan', 200.00),
(3, 'IV fluids',             500.00),
(4, 'General examination',     0.00);

INSERT INTO medicine (name, unit_price) VALUES
('Cetirizine 10mg',     8.00),
('Meloxicam 1.5mg',    15.00),
('Ondansetron 4mg',    12.00),
('Amoxicillin 250mg',  10.00);

INSERT INTO prescription (consultation_id, medicine_id, dosage_mg, frequency, duration_days, quantity) VALUES
(1, 1, 10.00,  'Once daily',  7,  7),
(2, 2,  1.50,  'Once daily',  5,  5),
(3, 3,  4.00,  'Twice daily', 3,  6),
(3, 4, 250.00, 'Twice daily', 5, 10),
(5, 3,  4.00,  'Twice daily', 3,  6);

INSERT INTO vaccine (name, validity_days) VALUES
('Rabies', 365), ('DHPP', 365), ('FVRCP', 365);

INSERT INTO vaccination (animal_id, vaccine_id, vet_id, given_date, next_due_date) VALUES
(1, 1, 1, '2025-10-20', '2026-10-20'),
(1, 2, 1, '2025-09-01', '2026-09-01'),
(3, 1, 2, '2025-12-01', '2026-12-01'),
(4, 2, 3, '2026-09-28', '2027-09-28'),
(2, 3, 1, '2025-10-15', '2026-10-15'),
(5, 3, 2, '2026-01-10', '2027-01-10');

INSERT INTO test_type (test_name, price) VALUES
('Blood test (CBC)', 600.00), ('X-ray', 900.00), ('Skin scraping', 300.00);

INSERT INTO animal_test (consultation_id, test_type_id, test_date, result, status) VALUES
(1, 3, '2026-09-20', 'No mites found',        'Completed'),
(2, 2, '2026-09-21', 'No fracture',           'Completed'),
(3, 1, '2026-09-25', 'Mild elevated WBC',     'Completed'),
(5, 1, '2026-10-05', NULL,                    'Pending');

CALL generate_bill(1);
CALL generate_bill(2);
CALL generate_bill(3);
CALL generate_bill(4);
CALL generate_bill(5);

-- Bill 1 fully paid, bill 2 half paid, bill 4 fully paid, bills 3 and 5 unpaid
SELECT bill_id, total_amount INTO @b1, @t1 FROM bill WHERE consultation_id = 1;
SELECT bill_id, total_amount INTO @b2, @t2 FROM bill WHERE consultation_id = 2;
SELECT bill_id, total_amount INTO @b4, @t4 FROM bill WHERE consultation_id = 4;

INSERT INTO payment (bill_id, amount, method) VALUES (@b1, @t1, 'UPI');
INSERT INTO payment (bill_id, amount, method) VALUES (@b2, @t2 / 2, 'Cash');
INSERT INTO payment (bill_id, amount, method) VALUES (@b4, @t4, 'Card');

-- =========================================================
-- 6. VIEWS (reports used by the application)
-- =========================================================

CREATE VIEW v_animal_history AS
SELECT an.animal_id, an.name AS animal, o.full_name AS owner,
       a.appt_start AS visit_date, v.full_name AS vet,
       c.symptoms, d.description AS diagnosis
FROM animal an
JOIN owner o ON o.owner_id = an.owner_id
JOIN appointment a ON a.animal_id = an.animal_id
JOIN veterinarian v ON v.vet_id = a.vet_id
LEFT JOIN consultation c ON c.appointment_id = a.appointment_id
LEFT JOIN diagnosis d ON d.consultation_id = c.consultation_id;

CREATE VIEW v_vaccination_due AS
SELECT an.name AS animal, o.full_name AS owner, o.phone,
       vc.name AS vaccine, vx.next_due_date,
       DATEDIFF(vx.next_due_date, CURRENT_DATE) AS days_left
FROM vaccination vx
JOIN animal an  ON an.animal_id = vx.animal_id
JOIN owner o    ON o.owner_id = an.owner_id
JOIN vaccine vc ON vc.vaccine_id = vx.vaccine_id
WHERE vx.next_due_date <= DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY)
  AND vx.next_due_date = (SELECT MAX(v2.next_due_date) FROM vaccination v2
                           WHERE v2.animal_id = vx.animal_id AND v2.vaccine_id = vx.vaccine_id);

CREATE VIEW v_doctor_schedule AS
SELECT v.full_name AS vet, a.appt_start, a.appt_end, an.name AS animal,
       o.full_name AS owner, a.reason, a.status
FROM appointment a
JOIN veterinarian v ON v.vet_id = a.vet_id
JOIN animal an ON an.animal_id = a.animal_id
JOIN owner o ON o.owner_id = an.owner_id;

CREATE VIEW v_prescriptions AS
SELECT an.name AS animal, m.name AS medicine, p.dosage_mg, p.frequency,
       p.duration_days, c.consultation_id
FROM prescription p
JOIN medicine m ON m.medicine_id = p.medicine_id
JOIN consultation c ON c.consultation_id = p.consultation_id
JOIN appointment a ON a.appointment_id = c.appointment_id
JOIN animal an ON an.animal_id = a.animal_id;

CREATE VIEW v_tests AS
SELECT an.name AS animal, tt.test_name, t.test_date, t.status, t.result
FROM animal_test t
JOIN test_type tt ON tt.test_type_id = t.test_type_id
JOIN consultation c ON c.consultation_id = t.consultation_id
JOIN appointment a ON a.appointment_id = c.appointment_id
JOIN animal an ON an.animal_id = a.animal_id;

CREATE VIEW v_outstanding_bills AS
SELECT b.bill_id, o.full_name AS owner, an.name AS animal, b.total_amount,
       COALESCE(SUM(p.amount), 0) AS paid,
       b.total_amount - COALESCE(SUM(p.amount), 0) AS balance, b.status
FROM bill b
JOIN consultation c ON c.consultation_id = b.consultation_id
JOIN appointment a ON a.appointment_id = c.appointment_id
JOIN animal an ON an.animal_id = a.animal_id
JOIN owner o ON o.owner_id = an.owner_id
LEFT JOIN payment p ON p.bill_id = b.bill_id
GROUP BY b.bill_id, o.full_name, an.name, b.total_amount, b.status
HAVING balance > 0;

CREATE VIEW v_revenue_by_month AS
SELECT DATE_FORMAT(paid_at, '%Y-%m') AS month, COUNT(*) AS payments, SUM(amount) AS revenue
FROM payment
GROUP BY DATE_FORMAT(paid_at, '%Y-%m');

-- =========================================================
-- 7. DEMO QUERIES
-- =========================================================
SELECT * FROM v_animal_history   WHERE animal = 'Bruno';
SELECT * FROM v_vaccination_due;
SELECT * FROM v_doctor_schedule  ORDER BY vet, appt_start;
SELECT * FROM v_prescriptions;
SELECT * FROM v_tests WHERE status = 'Pending';
SELECT * FROM v_outstanding_bills;
SELECT * FROM v_revenue_by_month;

-- Subquery: animals that have never been vaccinated
SELECT name FROM animal WHERE animal_id NOT IN (SELECT animal_id FROM vaccination);

-- Aggregate + join: number of appointments and revenue potential per vet
SELECT v.full_name, COUNT(a.appointment_id) AS appointments
FROM veterinarian v LEFT JOIN appointment a ON a.vet_id = v.vet_id
GROUP BY v.vet_id, v.full_name;

-- =========================================================
-- 8. RULE TESTS (each of these should FAIL with an error)
-- =========================================================
-- Duplicate animal name for the same owner:
--   INSERT INTO animal (owner_id, breed_id, name, gender, weight_kg) VALUES (1, 1, 'Bruno', 'Male', 10);
-- Overlapping appointment for Dr. Meera Iyer:
--   INSERT INTO appointment (animal_id, vet_id, appt_start, appt_end) VALUES (4, 1, '2026-10-09 10:15:00', '2026-10-09 10:45:00');
-- Future vaccination date:
--   INSERT INTO vaccination (animal_id, vaccine_id, vet_id, given_date, next_due_date) VALUES (1, 1, 1, '2030-01-01', '2031-01-01');
-- Zero dosage:
--   INSERT INTO prescription (consultation_id, medicine_id, dosage_mg, frequency, duration_days) VALUES (1, 1, 0, 'Daily', 3);
-- Overpayment:
--   INSERT INTO payment (bill_id, amount, method) VALUES (1, 99999, 'Cash');
