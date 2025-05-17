/* ============================================================
   Q1 ─ AFTER‑INSERT/UPDATE trigger on trips.date (2016‑2017 only)
   ============================================================ */
IF OBJECT_ID('trg_trips_DateRange') IS NOT NULL DROP TRIGGER trg_trips_DateRange;
GO
CREATE TRIGGER trg_trips_DateRange
ON dbo.trips
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS ( SELECT 1
                FROM inserted
                WHERE YEAR([date]) NOT BETWEEN 2016 AND 2017 )
    BEGIN
        RAISERROR ('Trip date must be in calendar‑years 2016 or 2017.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

/* ■ TEST */
--INSERT INTO trips (trip_id, [date], route_id, bus_id) 
--VALUES (999999,'2020-01-01',5,1);   --raises error & rolls back
/* ---------------------------------------------------------------- */




/* ============================================================
   Q2 ─ INSTEAD OF trigger: absolutely no DML on buses
   ============================================================ */
IF OBJECT_ID('trg_buses_NoDML') IS NOT NULL DROP TRIGGER trg_buses_NoDML;
GO
CREATE TRIGGER trg_buses_NoDML
ON dbo.buses
INSTEAD OF INSERT, UPDATE, DELETE
AS
BEGIN
    RAISERROR ('Input, modification or deletion of rows not allowed', 16, 1);
END;
GO

/* ■ TEST */
--INSERT INTO buses (bus_id) VALUES (99999);   --raises error
/* ---------------------------------------------------------------- */




/* ============================================================
   Q3 ─ INSTEAD OF UPDATE trigger on tickets.final_price
   ============================================================ */
IF OBJECT_ID('trg_tickets_BlockPriceUpdate') IS NOT NULL DROP TRIGGER trg_tickets_BlockPriceUpdate;
GO
CREATE TRIGGER trg_tickets_BlockPriceUpdate
ON dbo.tickets
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows INT =
        ( SELECT COUNT(*) 
          FROM inserted i
          JOIN deleted  d ON i.ticket_id=d.ticket_id
          WHERE ISNULL(i.final_price,-1) <> ISNULL(d.final_price,-1) );

    IF @rows>0
        RAISERROR ('%d rows not updated in final_price column due to trigger.',16,1,@rows);

    /* apply every requested change EXCEPT final_price */
    UPDATE t
       SET trip_id             = i.trip_id,
           customer_id         = i.customer_id,
           customer_name       = i.customer_name,
           employee_id         = i.employee_id,
           purchase_date       = i.purchase_date,
           purchase_time       = i.purchase_time,
           boarding_date       = i.boarding_date,
           boarding_time       = i.boarding_time,
           purchase_location_id= i.purchase_location_id,
           cabin_type_id       = i.cabin_type_id,
           discount_id         = i.discount_id
    FROM dbo.tickets t
    JOIN inserted i ON i.ticket_id = t.ticket_id;
END;
GO

/* ■ TEST */
/*
SELECT * FROM tickets WHERE ticket_id IN (100,101);
UPDATE tickets SET final_price = 1400 WHERE ticket_id IN (100,101); --price unchanged, message shown
*/
/* ---------------------------------------------------------------- */




/* ============================================================
   Q4 ─ INSTEAD OF INSERT / UPDATE trigger on customers.first_name
   ============================================================ */
IF OBJECT_ID('trg_customers_FirstNameLen') IS NOT NULL DROP TRIGGER trg_customers_FirstNameLen;
GO
CREATE TRIGGER trg_customers_FirstNameLen
ON dbo.customers
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE LEN(first_name) > 20)
    BEGIN
        RAISERROR ('First‑name length may not exceed 20 characters.',16,1);
        RETURN;    
    END

    
    IF EXISTS (SELECT * FROM deleted)        --UPDATE
    BEGIN
        UPDATE c
           SET first_name      = i.first_name,
               last_name       = i.last_name,
               birth_date      = i.birth_date,
               registration_date = i.registration_date,
               email           = i.email,
               gender          = i.gender,
               phone1          = i.phone1,
               phone2          = i.phone2,
               address_line1   = i.address_line1,
               address_line2   = i.address_line2,
               city_state_id   = i.city_state_id
        FROM dbo.customers c
        JOIN inserted i ON i.customer_id = c.customer_id;
    END
    ELSE                                   --INSERT
    BEGIN
        INSERT INTO dbo.customers (customer_id, first_name, last_name, birth_date,
                                   registration_date, email, gender, phone1, phone2,
                                   address_line1, address_line2, city_state_id)
        SELECT customer_id, first_name, last_name, birth_date, registration_date, email, gender,
               phone1, phone2, address_line1, address_line2, city_state_id
        FROM inserted;
    END
END;
GO

/* ■ TEST */
/*
UPDATE customers SET first_name='123456789012345678901' WHERE customer_id=3; -- error
SELECT * FROM customers WHERE customer_id=3;
*/
/* ---------------------------------------------------------------- */




/* ============================================================
   Q5 ─ Full audit system for buses
   ============================================================ */
IF OBJECT_ID('tb_audit') IS NOT NULL DROP TABLE tb_audit;
GO
CREATE TABLE tb_audit
(
    audit_id     INT IDENTITY PRIMARY KEY,
    audit_type   CHAR(1),            -- I / U / D
    table_name   VARCHAR(50),
    column_name  VARCHAR(128),
    key_value    VARCHAR(100),       -- bus_id
    old_value    VARCHAR(MAX),
    new_value    VARCHAR(MAX),
    audit_date   DATETIME     DEFAULT GETDATE(),
    username     VARCHAR(128) DEFAULT SUSER_SNAME()
);
GO

IF OBJECT_ID('trg_buses_Audit') IS NOT NULL DROP TRIGGER trg_buses_Audit;
GO
CREATE TRIGGER trg_buses_Audit
ON dbo.buses
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    /* ========== INSERT ========== */
    INSERT tb_audit (audit_type,table_name,column_name,key_value,old_value,new_value)
    SELECT 'I','buses',c.name,CAST(i.bus_id AS VARCHAR(100)),NULL,
           CASE c.name
                WHEN 'bus_id'        THEN CAST(i.bus_id AS VARCHAR(100))
                WHEN 'brand'         THEN i.brand
                WHEN 'model'         THEN i.model
                WHEN 'license_plate' THEN i.license_plate
                WHEN 'capacity'      THEN CAST(i.capacity AS VARCHAR(100))
           END
    FROM inserted i
    CROSS APPLY (VALUES('bus_id'),('brand'),('model'),
                       ('license_plate'),('capacity')) c(name);

    /* ========== UPDATE ========== */
    INSERT tb_audit (audit_type,table_name,column_name,key_value,old_value,new_value)
    SELECT 'U','buses',c.name,CAST(d.bus_id AS VARCHAR(100)),
           CASE c.name
                WHEN 'bus_id'        THEN CAST(d.bus_id AS VARCHAR(100))
                WHEN 'brand'         THEN d.brand
                WHEN 'model'         THEN d.model
                WHEN 'license_plate' THEN d.license_plate
                WHEN 'capacity'      THEN CAST(d.capacity AS VARCHAR(100))
           END,
           CASE c.name
                WHEN 'bus_id'        THEN CAST(i.bus_id AS VARCHAR(100))
                WHEN 'brand'         THEN i.brand
                WHEN 'model'         THEN i.model
                WHEN 'license_plate' THEN i.license_plate
                WHEN 'capacity'      THEN CAST(i.capacity AS VARCHAR(100))
           END
    FROM inserted i
    JOIN   deleted  d ON d.bus_id=i.bus_id
    CROSS APPLY (VALUES('bus_id'),('brand'),('model'),
                       ('license_plate'),('capacity')) c(name)
    WHERE   (  (d.bus_id        <> i.bus_id)
            OR (d.brand         <> i.brand        OR (d.brand IS NULL AND i.brand IS NOT NULL) OR (d.brand IS NOT NULL AND i.brand IS NULL))
            OR (d.model         <> i.model        OR (d.model IS NULL AND i.model IS NOT NULL) OR (d.model IS NOT NULL AND i.model IS NULL))
            OR (d.license_plate <> i.license_plate OR (d.license_plate IS NULL AND i.license_plate IS NOT NULL) OR (d.license_plate IS NOT NULL AND i.license_plate IS NULL))
            OR (d.capacity      <> i.capacity) );

    /* ========== DELETE ========== */
    INSERT tb_audit (audit_type,table_name,column_name,key_value,old_value,new_value)
    SELECT 'D','buses',c.name,CAST(d.bus_id AS VARCHAR(100)),
           CASE c.name
                WHEN 'bus_id'        THEN CAST(d.bus_id AS VARCHAR(100))
                WHEN 'brand'         THEN d.brand
                WHEN 'model'         THEN d.model
                WHEN 'license_plate' THEN d.license_plate
                WHEN 'capacity'      THEN CAST(d.capacity AS VARCHAR(100))
           END,
           NULL
    FROM deleted d
    CROSS APPLY (VALUES('bus_id'),('brand'),('model'),
                       ('license_plate'),('capacity')) c(name);
END;
GO


/* ■ TEST */

/*SELECT * FROM buses;
INSERT INTO buses(bus_id) VALUES (99999);     -- blocked by trigger Q2 no row, no audit
UPDATE buses SET brand='', license_plate='' WHERE bus_id=99999;   -- blocked by Q2 trigger
DELETE FROM buses WHERE bus_id=99999;                             -- blocked by Q2 trigger

-- To see the audit rows that *would* be captured remove / comment the Q2 trigger,
-- repeat the three statements, then:
SELECT * FROM tb_audit ORDER BY audit_id;
*/
/* ---------------------------------------------------------------- */



/* ============================================================
   Q6 ─ View: customer summary (Top‑50 by # tickets)
   ============================================================ */
IF OBJECT_ID('vw_customer_ticket_summary') IS NOT NULL DROP VIEW vw_customer_ticket_summary;
GO
CREATE VIEW vw_customer_ticket_summary
AS
WITH cte AS (
    SELECT c.customer_id,
           c.first_name,
           c.last_name,
           c.birth_date,
           COUNT(t.ticket_id) AS tickets_bought
    FROM dbo.customers c
    LEFT JOIN dbo.tickets  t ON t.customer_id=c.customer_id
    GROUP BY c.customer_id,c.first_name,c.last_name,c.birth_date
)
SELECT TOP 50
       customer_id,
       first_name,
       last_name,
       birth_date,
       CASE
         WHEN DATEADD(year,DATEDIFF(year,birth_date,GETDATE()),birth_date) > GETDATE()
              THEN DATEDIFF(year,birth_date,GETDATE())-1
         ELSE DATEDIFF(year,birth_date,GETDATE())
       END AS age,
       tickets_bought
FROM cte
ORDER BY tickets_bought DESC;
GO
/* ---------------------------------------------------------------- */




/* ============================================================
   Q7 ─ View: TOP‑5 routes per weekday (trips made in 2016)
   ============================================================ */
IF OBJECT_ID('vw_top_routes_by_weekday_2016') IS NOT NULL DROP VIEW vw_top_routes_by_weekday_2016;
GO
CREATE VIEW vw_top_routes_by_weekday_2016
AS
WITH trips2016 AS (
    SELECT r.route_id,
           r.weekday_id,
           COUNT(*) AS trip_count
    FROM dbo.trips   tr
    JOIN dbo.routes  r  ON r.route_id = tr.route_id
    WHERE tr.[date] BETWEEN '2016-01-01' AND '2016-12-31'
    GROUP BY r.route_id,r.weekday_id
), ranked AS (
    SELECT t.route_id,
           cs.name          AS origin_city,
           t.weekday_id,
           w.name           AS weekday_name,
           t.trip_count,
           ROW_NUMBER() OVER(PARTITION BY t.weekday_id ORDER BY t.trip_count DESC) AS rn
    FROM trips2016 t
    JOIN dbo.routes       r  ON r.route_id           = t.route_id
    JOIN dbo.cities_states cs ON cs.city_state_id    = r.city_state_id_origin
    JOIN dbo.weekdays      w  ON w.weekday_id        = t.weekday_id
)
SELECT route_id,
       origin_city,
       weekday_id,
       weekday_name,
       trip_count
FROM ranked
WHERE rn<=5;
GO
/* ---------------------------------------------------------------- */




/* ============================================================
   Q8 ─ View: City trips in 2016 split by gender (Top‑10)
   ============================================================ */
IF OBJECT_ID('vw_city_trip_gender_2016') IS NOT NULL DROP VIEW vw_city_trip_gender_2016;
GO
CREATE VIEW vw_city_trip_gender_2016
AS
WITH trip2016 AS (
    SELECT c.city_state_id,
           c.gender,
           t.ticket_id
    FROM dbo.tickets t
    JOIN dbo.trips   tr ON tr.trip_id = t.trip_id
    JOIN dbo.customers c  ON c.customer_id = t.customer_id
    WHERE tr.[date] BETWEEN '2016-01-01' AND '2016-12-31'
), agg AS (
    SELECT cs.name,
           COUNT(*)                                           AS trips_total,
           SUM(CASE WHEN gender='M' THEN 1 ELSE 0 END)       AS trips_male,
           SUM(CASE WHEN gender='F' THEN 1 ELSE 0 END)       AS trips_female
    FROM trip2016 t
    JOIN dbo.cities_states cs ON cs.city_state_id = t.city_state_id
    GROUP BY cs.name
)
SELECT TOP 10
       name,
       trips_total,
       trips_male,
       trips_female
FROM agg
ORDER BY trips_total DESC;
GO
/* ---------------------------------------------------------------- */




/* ============================================================
   Q9 ─ View: Age‑group stats (Top‑2 cities per group)
   ============================================================ */
IF OBJECT_ID('vw_city_agegroup_2016') IS NOT NULL DROP VIEW vw_city_agegroup_2016;
GO
CREATE VIEW vw_city_agegroup_2016
AS
WITH tripdata AS (
    SELECT DISTINCT
           c.customer_id,
           cs.name,
           DATEDIFF(year,c.birth_date,'2016-12-31') AS age2016
    FROM dbo.tickets t
    JOIN dbo.trips   tr ON tr.trip_id=t.trip_id
    JOIN dbo.customers c  ON c.customer_id=t.customer_id
    JOIN dbo.cities_states cs ON cs.city_state_id=c.city_state_id
    WHERE tr.[date] BETWEEN '2016-01-01' AND '2016-12-31'
), allrows AS (
    SELECT td.name,
           CASE
             WHEN age2016<=20              THEN '20 or younger'
             WHEN age2016 BETWEEN 21 AND 35 THEN '21 to 35'
             WHEN age2016 BETWEEN 36 AND 65 THEN '36 to 65'
             ELSE                             '65 or older'
           END AS age_group,
           td.customer_id
    FROM tripdata td
), cust_cnt AS (
    SELECT name,age_group,
           COUNT(DISTINCT customer_id) AS customers_cnt
    FROM allrows
    GROUP BY name,age_group
), trip_cnt AS (
    SELECT cs.name,
           CASE
             WHEN DATEDIFF(year,c.birth_date,'2016-12-31')<=20              THEN '20 or younger'
             WHEN DATEDIFF(year,c.birth_date,'2016-12-31') BETWEEN 21 AND 35 THEN '21 to 35'
             WHEN DATEDIFF(year,c.birth_date,'2016-12-31') BETWEEN 36 AND 65 THEN '36 to 65'
             ELSE                                                             '65 or older'
           END AS age_group,
           COUNT(*) AS trip_cnt
    FROM dbo.tickets t
    JOIN dbo.trips   tr ON tr.trip_id=t.trip_id
    JOIN dbo.customers c  ON c.customer_id=t.customer_id
    JOIN dbo.cities_states cs ON cs.city_state_id=c.city_state_id
    WHERE tr.[date] BETWEEN '2016-01-01' AND '2016-12-31'
    GROUP BY cs.name,
             CASE
               WHEN DATEDIFF(year,c.birth_date,'2016-12-31')<=20              THEN '20 or younger'
               WHEN DATEDIFF(year,c.birth_date,'2016-12-31') BETWEEN 21 AND 35 THEN '21 to 35'
               WHEN DATEDIFF(year,c.birth_date,'2016-12-31') BETWEEN 36 AND 65 THEN '36 to 65'
               ELSE                                                             '65 or older'
             END
), combined AS (
    SELECT c.name,
           c.age_group,
           c.customers_cnt,
           t.trip_cnt
    FROM cust_cnt c
    JOIN trip_cnt t ON t.name=c.name AND t.age_group=c.age_group
), ranked AS (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY age_group ORDER BY customers_cnt DESC, trip_cnt DESC) AS rn
    FROM combined
)
SELECT name,
       customers_cnt,
       trip_cnt,
       age_group
FROM ranked
WHERE rn<=2;
GO
/* ---------------------------------------------------------------- */





/* ============================================================  
   Q10 — Adding constraints to satisfy current data (with safe drops)
   ============================================================ */

/* ---------------------------- 
   employees (14 columns) — 6 constraints 
   ---------------------------- */
-- Drop constraints if they already exist
IF EXISTS (SELECT * FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID('dbo.employees') AND name = 'DF_employees_hire_date')
    ALTER TABLE dbo.employees DROP CONSTRAINT DF_employees_hire_date;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_employees_gender')
    ALTER TABLE dbo.employees DROP CONSTRAINT chk_employees_gender;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'uq_employees_email')
    ALTER TABLE dbo.employees DROP CONSTRAINT uq_employees_email;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_employees_birthdate')
    ALTER TABLE dbo.employees DROP CONSTRAINT chk_employees_birthdate;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_employees_phone')
    ALTER TABLE dbo.employees DROP CONSTRAINT chk_employees_phone;

-- Add constraints
ALTER TABLE dbo.employees
ADD CONSTRAINT chk_employees_gender CHECK (gender IN ('M', 'F')),
    CONSTRAINT def_employees_hiredate DEFAULT GETDATE() FOR hire_date,
    CONSTRAINT uq_employees_email UNIQUE (email),
    CONSTRAINT chk_employees_birthdate CHECK (birth_date < hire_date),
    CONSTRAINT chk_employees_phone CHECK (LEN(phone1) >= 10 OR LEN(phone2) >= 10);

/* ---------------------------- 
   customers (12 columns) — 5 constraints 
   ---------------------------- */
IF EXISTS (SELECT * FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID('dbo.customers') AND name = 'DF_customers_registration_date')
    ALTER TABLE dbo.customers DROP CONSTRAINT DF_customers_registration_date;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_customers_gender')
    ALTER TABLE dbo.customers DROP CONSTRAINT chk_customers_gender;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'def_customers_reg_date')
    ALTER TABLE dbo.customers DROP CONSTRAINT def_customers_reg_date;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'uq_customers_email')
    ALTER TABLE dbo.customers DROP CONSTRAINT uq_customers_email;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_customers_birth')
    ALTER TABLE dbo.customers DROP CONSTRAINT chk_customers_birth;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_customers_firstname')
    ALTER TABLE dbo.customers DROP CONSTRAINT chk_customers_firstname;

ALTER TABLE dbo.customers
ADD CONSTRAINT chk_customers_gender CHECK (gender IN ('M', 'F')),
    CONSTRAINT def_customers_reg_date DEFAULT GETDATE() FOR registration_date,
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT chk_customers_birth CHECK (birth_date < registration_date),
    CONSTRAINT chk_customers_firstname CHECK (LEN(first_name) > 0);

/* ---------------------------- 
   tickets (13 columns) — 5 constraints 
   ---------------------------- */
IF EXISTS (SELECT * FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID('dbo.tickets') AND name = 'DF_tickets_purchase_date')
    ALTER TABLE dbo.tickets DROP CONSTRAINT DF_tickets_purchase_date;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_tickets_price')
    ALTER TABLE dbo.tickets DROP CONSTRAINT chk_tickets_price;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_tickets_purchase_date')
    ALTER TABLE dbo.tickets DROP CONSTRAINT chk_tickets_purchase_date;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'def_tickets_purchase_date')
    ALTER TABLE dbo.tickets DROP CONSTRAINT def_tickets_purchase_date;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_tickets_time')
    ALTER TABLE dbo.tickets DROP CONSTRAINT chk_tickets_time;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_tickets_boarding_time')
    ALTER TABLE dbo.tickets DROP CONSTRAINT chk_tickets_boarding_time;

ALTER TABLE dbo.tickets
ADD CONSTRAINT chk_tickets_price CHECK (final_price >= 0),
    CONSTRAINT chk_tickets_purchase_date CHECK (purchase_date <= boarding_date),
    CONSTRAINT def_tickets_purchase_date DEFAULT GETDATE() FOR purchase_date,
    CONSTRAINT chk_tickets_time CHECK (purchase_time <= '23:59:59'),
    CONSTRAINT chk_tickets_boarding_time CHECK (boarding_time <= '23:59:59');

/* ---------------------------- 
   locations (7 columns) — 3 constraints 
   ---------------------------- */
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'uq_locations_name')
    ALTER TABLE dbo.locations DROP CONSTRAINT uq_locations_name;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_locations_name')
    ALTER TABLE dbo.locations DROP CONSTRAINT chk_locations_name;

ALTER TABLE dbo.locations
ADD CONSTRAINT uq_locations_name UNIQUE (name),
    CONSTRAINT chk_locations_name CHECK (LEN(name) > 0);

/* ---------------------------- 
   trips (6 columns) — 3 constraints 
   ---------------------------- */
UPDATE dbo.trips
SET [date] = '2016-01-01'
WHERE YEAR([date]) NOT BETWEEN 2016 AND 2017;

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_trips_date_range')
    ALTER TABLE dbo.trips DROP CONSTRAINT chk_trips_date_range;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_trips_bus')
    ALTER TABLE dbo.trips DROP CONSTRAINT chk_trips_bus;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_trips_route')
    ALTER TABLE dbo.trips DROP CONSTRAINT chk_trips_route;

ALTER TABLE dbo.trips
ADD CONSTRAINT chk_trips_date_range CHECK (YEAR([date]) BETWEEN 2016 AND 2017),
    CONSTRAINT chk_trips_bus CHECK (bus_id IS NOT NULL),
    CONSTRAINT chk_trips_route CHECK (route_id IS NOT NULL);

/* ---------------------------- 
   routes (6 columns) — 3 constraints 
   ---------------------------- */
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_routes_times')
    ALTER TABLE dbo.routes DROP CONSTRAINT chk_routes_times;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_routes_weekday')
    ALTER TABLE dbo.routes DROP CONSTRAINT chk_routes_weekday;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_routes_origin_destination')
    ALTER TABLE dbo.routes DROP CONSTRAINT chk_routes_origin_destination;

ALTER TABLE dbo.routes
ADD CONSTRAINT chk_routes_times CHECK (scheduled_start_time < scheduled_end_time),
    CONSTRAINT chk_routes_weekday CHECK (weekday_id IS NOT NULL),
    CONSTRAINT chk_routes_origin_destination CHECK (city_state_id_origin != city_state_id_destination);

/* ---------------------------- 
   buses (5 columns) — 2 constraints 
   ---------------------------- */
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'chk_buses_capacity')
    ALTER TABLE dbo.buses DROP CONSTRAINT chk_buses_capacity;
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'uq_buses_license')
    ALTER TABLE dbo.buses DROP CONSTRAINT uq_buses_license;

ALTER TABLE dbo.buses
ADD CONSTRAINT chk_buses_capacity CHECK (capacity > 0),
    CONSTRAINT uq_buses_license UNIQUE (license_plate);

/* ---------------------------- 
  Foreign Key for locations table 
   ---------------------------- */
IF EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'fk_locations_location_types')
    ALTER TABLE dbo.locations DROP CONSTRAINT fk_locations_location_types;

ALTER TABLE dbo.locations
ADD CONSTRAINT fk_locations_location_types FOREIGN KEY (location_type_id) REFERENCES location_types (location_type_id);




