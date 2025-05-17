
-- Query 1 
-- Generates a table with columns trip_id, capacity, quantity
SELECT tr.trip_id, bu.capacity, count(*) as quantity
FROM tickets ti
JOIN trips tr ON tr.trip_id = ti.trip_id
JOIN buses bu ON bu.bus_id = tr.bus_id
WHERE year(tr.date) = 2016 OR year(tr.date) = 2017
GROUP BY tr.trip_id, bu.capacity
HAVING count(*) >= 0.25 * bu.capacity AND count(*) <= 0.75 * bu.capacity
ORDER BY quantity DESC;
-- A total of 12,237 trips had buses departing with between 25% and 75% of their full capacity, in terms of sold tickets, in the years 2016 and 2017.

-- Query 2
SELECT TOP 10 SUM(ti.final_price) AS max_revenue, tr.trip_id
FROM tickets ti
JOIN trips tr ON ti.trip_id = tr.trip_id
WHERE year(tr.date) = 2016
  AND DATEPART(month, tr.date) IN (1,2,3)
  AND DATEPART(weekday, tr.date) IN (2,3,4,5,6)
GROUP BY tr.trip_id
ORDER BY max_revenue DESC;
/* This code gives as a result a table with the top 10 trips that generated the most revenue in the first 3 months of 2016. 
The table presents the total revenue in the 3 months, and the trip id of that trip. */
-- The trip_ids for the top 10 trips with the most revenue are 346, 1734, 369, 922, 1066, 204, 984, 931, 1337, and 600.

-- Query 3
;WITH route_revenue_2017 AS (
    SELECT r.route_id, SUM(tk.final_price) AS total_revenue
    FROM routes r
    JOIN trips t ON r.route_id = t.route_id
    JOIN tickets tk ON tk.trip_id = t.trip_id
    WHERE YEAR(tk.purchase_date) = 2017
    GROUP BY r.route_id
),
ranked_routes AS (
    SELECT route_id, total_revenue,
        PERCENT_RANK() OVER (ORDER BY total_revenue) AS revenue_percentile
    FROM route_revenue_2017
)
SELECT route_id, total_revenue,
    CASE 
        WHEN revenue_percentile >= 0.9 THEN 'Top 10%'
        WHEN revenue_percentile <= 0.1 THEN 'Bottom 10%'
    END AS revenue_category
FROM ranked_routes
WHERE revenue_percentile >= 0.9 OR revenue_percentile <= 0.1;
-- The route_id's that generated the bottom 10% are 114, 7, 79, 129, 62, 53, 28, 47, 18, 27, 94, 42, 89, 41 
-- and the bottom 10% are 96, 29, 44, 133, 132, 50, 116, 64, 45, 126, 97, 137, 131

-- Query 4
-- This generates a table with the columns as total_discounted_amount and tickets_with_discount.
SELECT
    SUM(t.final_price * d.percentage / 100.0) AS total_discounted_amount,
    COUNT(*) AS tickets_with_discount
FROM tickets t
JOIN customers c ON t.customer_id = c.customer_id
JOIN discounts d ON t.discount_id = d.discount_id
WHERE
    DATEPART(year, t.purchase_date) = 2017
    AND (
        DATEDIFF(year, c.birth_date, t.purchase_date) < 23
        OR DATEDIFF(year, c.birth_date, t.purchase_date) > 65
    );
-- The answer for the total_discounted amount is 125.0105 and the tickets_with_discount is 7895.

-- Query 5
-- This query makes a table with a column for Month, MonthNumber, Ratio_Refistered_To_NonRegistered
SELECT
    DATENAME(MONTH, t.date) AS [Month],
    MONTH(t.date) AS MonthNumber,
    1.0 * SUM(CASE WHEN tk.customer_id IS NOT NULL THEN 1 ELSE 0 END)
    / NULLIF(SUM(CASE WHEN tk.customer_id IS NULL THEN 1 ELSE 0 END), 0)
    AS Ratio_Registered_To_NonRegistered
FROM trips AS t
JOIN routes AS r ON t.route_id = r.route_id
JOIN weekdays AS w ON r.weekday_id = w.weekday_id
JOIN tickets AS tk ON t.trip_id = tk.trip_id
WHERE
    YEAR(t.date) = 2017
    AND w.name IN ('Saturday','Sunday')
    AND t.start_time_actual > '11:00:00'
GROUP BY
    DATENAME(MONTH, t.date),
    MONTH(t.date)
ORDER BY MonthNumber;
-- Monthly average ratio of sold tickets of registered passengers over non-registered passengers on weekends in 2017

-- Query 6
;WITH RouteRanks AS (
    SELECT
        r.route_id,
        w.name AS weekday_name,
        COUNT(tk.ticket_id) AS tickets_sold,
        ROW_NUMBER() OVER (PARTITION BY w.name ORDER BY COUNT(tk.ticket_id) DESC) AS rank
    FROM trips t
    JOIN tickets tk ON t.trip_id = tk.trip_id
    JOIN routes r ON t.route_id = r.route_id
    JOIN weekdays w ON r.weekday_id = w.weekday_id
    WHERE
        YEAR(t.date) = 2016
        AND MONTH(t.date) IN (6, 7, 8)
        AND CAST(t.start_time_actual AS TIME) BETWEEN '14:00:00' AND '20:00:00'
        AND w.name IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
    GROUP BY r.route_id, w.name
)
SELECT route_id, weekday_name, tickets_sold
FROM RouteRanks
WHERE rank = 1
ORDER BY weekday_name;
-- The most in-demand weekday routes from 2PM–8PM during summer 2016.

-- Query 7
;WITH DailyRevenue AS (
    SELECT 
        r.weekday_id,
        w.name AS weekday_name,
        r.scheduled_start_time, 
        SUM(t.final_price) AS Generated_Revenue,
        ROW_NUMBER() OVER (
            PARTITION BY r.weekday_id 
            ORDER BY SUM(t.final_price) DESC
        ) AS rn
    FROM routes r
    JOIN trips tr ON r.route_id = tr.route_id
    JOIN tickets t ON t.trip_id = tr.trip_id
    JOIN weekdays w ON r.weekday_id = w.weekday_id
    WHERE 
        r.city_state_id_origin = 1 AND w.weekday_id IN (1,2,3,4,5)
    GROUP BY r.weekday_id, w.name, r.scheduled_start_time
)
SELECT weekday_name, scheduled_start_time, Generated_Revenue
FROM DailyRevenue
WHERE rn = 1
ORDER BY weekday_id;
-- Shows peak revenue-generating hours per weekday for Tampa departures

-- Query 8
;WITH trip_ticket_counts AS (
    SELECT t.trip_id, t.date, t.bus_id, COUNT(tk.ticket_id) AS tickets_sold
    FROM trips t
    LEFT JOIN tickets tk ON tk.trip_id = t.trip_id
    WHERE YEAR(t.date) IN (2016, 2017)
    GROUP BY t.trip_id, t.date, t.bus_id
),
trip_with_capacity AS (
    SELECT
        tc.trip_id,
        tc.date,
        tc.bus_id,
        tc.tickets_sold,
        b.capacity,
        CEILING(b.capacity * 0.10) AS minimum_required_passengers
    FROM trip_ticket_counts tc
    JOIN buses b ON tc.bus_id = b.bus_id
)
SELECT trip_id, date, bus_id, tickets_sold, capacity, minimum_required_passengers
FROM trip_with_capacity
WHERE tickets_sold < minimum_required_passengers;
-- Shows trips from 2016–2017 that shouldn't have departed due to low ticket sales

-- Query 9
;WITH weekend_trips AS (
    SELECT
        DATEPART(WEEK, tr.date) AS week_number,
        tr.trip_id,
        b.capacity,
        COUNT(t.ticket_id) AS tickets_sold
    FROM trips tr
    JOIN tickets t ON t.trip_id = tr.trip_id
    JOIN buses b ON tr.bus_id = b.bus_id
    WHERE 
        YEAR(tr.date) = 2016
        AND DATENAME(WEEKDAY, tr.date) IN ('Saturday', 'Sunday')
    GROUP BY DATEPART(WEEK, tr.date), tr.trip_id, b.capacity
),
weekly_summary AS (
    SELECT
        week_number,
        SUM(tickets_sold) AS total_tickets,
        SUM(capacity) AS total_capacity,
        CAST(SUM(tickets_sold) AS FLOAT) / NULLIF(SUM(capacity), 0) AS load_ratio
    FROM weekend_trips
    GROUP BY week_number
)
SELECT week_number, load_ratio
FROM weekly_summary
WHERE load_ratio BETWEEN 0.10 AND 0.30
ORDER BY week_number;
-- Finds weeks in 2016 where weekend trips sold between 10% and 30% of capacity

-- More queries (10–20) will be appended next...

-- Query 10
-- PART A: Top 5 employees with most tickets sold without discount (Q4 2017)
SELECT TOP 5
    e.employee_id,
    e.first_name,
    e.last_name,
    COUNT(tk.ticket_id) AS TicketsSold
FROM tickets AS tk
JOIN employees AS e ON tk.employee_id = e.employee_id
WHERE
    tk.discount_id IS NULL
    AND tk.purchase_date BETWEEN '2017-10-01' AND '2017-12-31'
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY TicketsSold DESC;

-- PART B: Top 5 employees with most revenue from discounted tickets on weekdays in 2017
SELECT TOP 5
    e.employee_id,
    e.first_name,
    e.last_name,
    SUM(tk.final_price) AS TotalRevenue
FROM tickets AS tk
JOIN employees AS e ON tk.employee_id = e.employee_id
JOIN trips AS t ON tk.trip_id = t.trip_id
JOIN routes AS r ON t.route_id = r.route_id
JOIN weekdays AS w ON r.weekday_id = w.weekday_id
WHERE
    tk.discount_id IS NOT NULL
    AND w.name NOT IN ('Saturday','Sunday')
    AND YEAR(tk.purchase_date) = 2017
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY TotalRevenue DESC;
-- Wren, Korie, Sandra, Denise, Robena sold the most tickets without discounts; 
-- Robena, Mord, Korie, Bryon, Ardeen generated the most revenue with discounted tickets.

-- Query 11
-- Yields most sold cabin type among registered customers without discount
SELECT TOP 1
    cb.name AS cabin_type,
    COUNT(tk.ticket_id) AS tickets_sold
FROM tickets tk
JOIN cabin_types cb ON tk.cabin_type_id = cb.cabin_type_id
WHERE
    tk.customer_id IS NOT NULL
    AND tk.discount_id IS NULL
    AND YEAR(tk.purchase_date) = 2017
    AND MONTH(tk.purchase_date) IN (1, 2, 3)
GROUP BY cb.name
ORDER BY tickets_sold DESC;
-- Most demanded cabin type: Second Class

-- Query 12
-- Finds top purchase location per weekday for non-registered customers in Q1–Q2 of 2016
SELECT weekday_id, weekday_name, purchase_location, total_tickets
FROM (
    SELECT 
        w.weekday_id,
        w.name AS weekday_name,
        l.name AS purchase_location,
        COUNT(*) AS total_tickets,
        ROW_NUMBER() OVER (PARTITION BY w.name ORDER BY COUNT(*) DESC) AS rn
    FROM tickets t
    JOIN trips tr ON t.trip_id = tr.trip_id
    JOIN routes r ON tr.route_id = r.route_id
    JOIN weekdays w ON r.weekday_id = w.weekday_id
    JOIN locations l ON t.purchase_location_id = l.location_id
    WHERE 
        t.customer_id IS NULL
        AND t.purchase_date BETWEEN '2016-01-01' AND '2016-06-30'
        AND w.weekday_id IN (1,2,3,4,5)
    GROUP BY w.name, l.name, w.weekday_id
) ranked
WHERE rn = 1
ORDER BY weekday_id;
-- Returns top ticket-selling location per weekday for non-registered users in early 2016

-- Query 13
;WITH ticket_classification AS (
    SELECT
        t.trip_id,
        CASE WHEN tk.customer_id IS NOT NULL THEN 'registered' ELSE 'non_registered' END AS customer_type
    FROM trips t
    JOIN tickets tk ON t.trip_id = tk.trip_id
    WHERE YEAR(t.date) = 2017 AND MONTH(t.date) BETWEEN 7 AND 12
),
ticket_counts AS (
    SELECT
        trip_id,
        SUM(CASE WHEN customer_type = 'registered' THEN 1 ELSE 0 END) AS registered_count,
        SUM(CASE WHEN customer_type = 'non_registered' THEN 1 ELSE 0 END) AS non_registered_count
    FROM ticket_classification
    GROUP BY trip_id
)
SELECT trip_id, registered_count, non_registered_count
FROM ticket_counts
WHERE registered_count > non_registered_count;
-- 2,154 trips had more registered passengers than non-registered in Q3–Q4 of 2017

-- Query 14
-- Most common location type for registered ticket sales in Jan–Feb of 2016 and 2017
SELECT TOP 3
    l.location_type_id,
    COUNT(*) AS tickets_sold
FROM tickets t
JOIN customers c ON t.customer_id = c.customer_id
JOIN locations l ON t.purchase_location_id = l.location_id
WHERE
    DATEPART(year, t.purchase_date) IN (2016, 2017)
    AND DATEPART(month, t.purchase_date) IN (1, 2)
GROUP BY l.location_type_id
ORDER BY COUNT(*) DESC;
-- Top location type ID: 1, with 8,334 tickets sold

-- Query 15
;WITH HourlySales AS (
    SELECT
        w.name AS WeekdayName,
        DATEPART(HOUR, t.start_time_actual) AS DepartureHour,
        COUNT(*) AS TicketsSold,
        ROW_NUMBER() OVER (PARTITION BY w.name ORDER BY COUNT(*) DESC) AS rn
    FROM tickets tk
    JOIN trips t ON tk.trip_id = t.trip_id
    JOIN routes r ON t.route_id = r.route_id
    JOIN weekdays w ON r.weekday_id = w.weekday_id
    WHERE
        YEAR(t.date) = 2017
        AND w.name NOT IN ('Saturday','Sunday')
        AND t.start_time_actual > '11:00:00'
        AND tk.customer_id IS NULL
    GROUP BY w.name, DATEPART(HOUR, t.start_time_actual)
)
SELECT WeekdayName, DepartureHour, TicketsSold
FROM HourlySales
WHERE rn = 1
ORDER BY WeekdayName;
-- Peak post-11am departure hour for each weekday (non-registered)

-- Query 16
;WITH non_registered_discounts AS (
    SELECT
        d.discount_id,
        d.name AS discount_name,
        COUNT(*) AS discount_count,
        SUM(t.final_price * d.percentage / 100.0) AS total_discount
    FROM tickets t
    JOIN discounts d ON t.discount_id = d.discount_id
    LEFT JOIN customers c ON t.customer_id = c.customer_id
    WHERE
        c.customer_id IS NULL
        AND YEAR(t.purchase_date) = 2017
        AND MONTH(t.purchase_date) % 2 = 0
    GROUP BY d.discount_id, d.name
)
SELECT TOP 2 *
FROM non_registered_discounts
ORDER BY discount_count DESC;
-- Most used discounts by non-registered customers in even months: IDs 2 and 4

-- Query 17
SELECT 
    DATEPART(HOUR, purchase_time) AS purchase_hour,
    COUNT(*) AS missed_tickets_count
FROM tickets
WHERE 
    customer_id IS NULL
    AND (boarding_date IS NULL OR boarding_time IS NULL)
GROUP BY DATEPART(HOUR, purchase_time)
ORDER BY missed_tickets_count DESC;
-- Peak hour for missed trips (non-registered customers): 12th hour

-- Query 18
SELECT TOP 3
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(*) AS tickets_bought,
    SUM(t.final_price) AS total_revenue
FROM tickets t
JOIN customers c ON t.customer_id = c.customer_id
JOIN trips tr ON t.trip_id = tr.trip_id
WHERE
    DATEPART(year, t.boarding_date) = 2016
    AND DATEPART(month, t.boarding_date) BETWEEN 1 AND 4
    AND CAST(tr.start_time_actual AS time) > '11:00:00'
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY tickets_bought DESC;
-- Top 3 customers (registered) in early 2016 with most tickets after 11AM: Jobie, Cele, Ric

-- Query 19
SELECT TOP 3
    r.route_id,
    SUM(
        CASE
            WHEN DATEDIFF(MINUTE, r.scheduled_start_time, t.start_time_actual) > 0
            THEN DATEDIFF(MINUTE, r.scheduled_start_time, t.start_time_actual)
            ELSE 0
        END
    ) AS TotalDelayedMinutes
FROM trips t
JOIN routes r ON t.route_id = r.route_id
JOIN weekdays w ON r.weekday_id = w.weekday_id
WHERE
    YEAR(t.date) = 2017
    AND w.name IN ('Saturday','Sunday')
GROUP BY r.route_id
ORDER BY TotalDelayedMinutes DESC;
-- Most delayed weekend routes in 2017: 57, 134, 69

-- Query 20
SELECT TOP 3
    r.route_id,
    COUNT(*) AS missed_trips
FROM tickets t
JOIN trips tr ON t.trip_id = tr.trip_id
JOIN routes r ON tr.route_id = r.route_id
WHERE
    t.customer_id IS NOT NULL
    AND YEAR(tr.date) = 2017
    AND MONTH(tr.date) BETWEEN 1 AND 6
    AND (t.boarding_date IS NULL OR t.boarding_time IS NULL)
GROUP BY r.route_id
ORDER BY missed_trips ASC;
-- Top 3 routes with fewest missed trips by registered customers: 132, 21, 85
