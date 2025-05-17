-- 1. Customers Table
CREATE TABLE Customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    company_name VARCHAR(100), -- Optional for corporate customers
    contact_person VARCHAR(100), -- Optional for corporate customers
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    customer_type VARCHAR(10) NOT NULL CHECK (customer_type IN ('Individual', 'Corporate')),
    registration_date DATE NOT NULL DEFAULT GETDATE(),
    CONSTRAINT chk_customer_type_details CHECK (
        (customer_type = 'Individual' AND company_name IS NULL AND contact_person IS NULL) OR
        (customer_type = 'Corporate')
    )
);

-- 2. Employees Table
CREATE TABLE Employees (
    employee_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position VARCHAR(50) NOT NULL,
    salary DECIMAL(10,2) NOT NULL,
    ssn VARCHAR(9) UNIQUE NOT NULL,
    hire_date DATE NOT NULL DEFAULT GETDATE(),
    CONSTRAINT chk_salary_positive CHECK (salary > 0)
);

-- 3. Roles Table
CREATE TABLE Roles (
    role_id INT IDENTITY(1,1) PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description NVARCHAR(MAX)
);

-- Insert default roles including 'Driver'
INSERT INTO Roles (role_name, description) VALUES ('Driver', 'Employee who drives buses');

-- 4. Employee Roles Table
CREATE TABLE EmployeeRoles (
    employee_id INT NOT NULL,
    role_id INT NOT NULL,
    assigned_date DATE NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (employee_id, role_id),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES Roles(role_id) ON DELETE CASCADE
);

-- 5. Locations Table
CREATE TABLE Locations (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    services NVARCHAR(MAX),
    CONSTRAINT uq_location UNIQUE (location_name, address)
);

-- 6. Routes Table
CREATE TABLE Routes (
    route_id INT IDENTITY(1,1) PRIMARY KEY,
    origin_id INT NOT NULL,
    destination_id INT NOT NULL,
    distance DECIMAL(10,2) NOT NULL,
    estimated_duration INT NOT NULL, -- in minutes
    day_of_week VARCHAR(20) NOT NULL,
    scheduled_time TIME NOT NULL,
    FOREIGN KEY (origin_id) REFERENCES Locations(location_id),
    FOREIGN KEY (destination_id) REFERENCES Locations(location_id),
    CONSTRAINT chk_diff_locations CHECK (origin_id != destination_id),
    CONSTRAINT chk_distance_positive CHECK (distance > 0),
    CONSTRAINT chk_duration_positive CHECK (estimated_duration > 0)
);

-- 7. Buses Table
CREATE TABLE Buses (
    bus_id INT IDENTITY(1,1) PRIMARY KEY,
    model VARCHAR(100) NOT NULL,
    capacity INT NOT NULL,
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    purchase_date DATE NOT NULL,
    last_service_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Under Maintenance', 'Retired')),
    CONSTRAINT chk_capacity_positive CHECK (capacity > 0),
    CONSTRAINT chk_service_after_purchase CHECK (last_service_date IS NULL OR last_service_date >= purchase_date)
);

-- 8. Cabins Table
CREATE TABLE Cabins (
    cabin_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT NOT NULL,
    cabin_type VARCHAR(7) NOT NULL CHECK (cabin_type IN ('Economy', 'Premium', 'VIP')),
    seat_count INT NOT NULL,
    price_multiplier DECIMAL(3,2) NOT NULL DEFAULT 1.0,
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    CONSTRAINT chk_seat_count_positive CHECK (seat_count > 0),
    CONSTRAINT chk_price_multiplier_positive CHECK (price_multiplier > 0)
);

-- 9. Drivers Table
CREATE TABLE Drivers (
    driver_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL UNIQUE,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_expiration DATE NOT NULL,
    certification NVARCHAR(MAX),
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT chk_license_valid CHECK (license_expiration > GETDATE())
);

-- 10. Trips Table
CREATE TABLE Trips (
    trip_id INT IDENTITY(1,1) PRIMARY KEY,
    route_id INT NOT NULL,
    bus_id INT NOT NULL,
    trip_date DATE NOT NULL,
    departure_time TIME NOT NULL,
    arrival_time TIME NOT NULL,
    status VARCHAR(15) NOT NULL DEFAULT 'Scheduled' CHECK (status IN ('Scheduled', 'In Progress', 'Completed', 'Cancelled')),
    FOREIGN KEY (route_id) REFERENCES Routes(route_id),
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id),
    CONSTRAINT chk_arrival_after_departure CHECK (arrival_time > departure_time)
);

-- 11. Driver Assignments Table
CREATE TABLE DriverAssignments (
    assignment_id INT IDENTITY(1,1) PRIMARY KEY,
    driver_id INT NOT NULL,
    trip_id INT NOT NULL,
    assigned_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (driver_id) REFERENCES Drivers(driver_id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE CASCADE,
    CONSTRAINT uq_driver_trip UNIQUE (driver_id, trip_id)
);

-- 12. Payment Methods Table
CREATE TABLE PaymentMethods (
    method_id INT IDENTITY(1,1) PRIMARY KEY,
    method_name VARCHAR(50) NOT NULL UNIQUE,
    description NVARCHAR(MAX),
    active BIT NOT NULL DEFAULT 1
);

-- Insert default payment methods
INSERT INTO PaymentMethods (method_name, description) VALUES 
('Credit Card', 'Payment via credit card'),
('Debit Card', 'Payment via debit card'),
('Cash', 'Payment in cash'),
('Bank Transfer', 'Payment via bank transfer');

-- 13. Tickets Table
CREATE TABLE Tickets (
    ticket_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    trip_id INT NOT NULL,
    cabin_id INT NOT NULL,
    seat_number VARCHAR(10) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    purchase_date DATE NOT NULL DEFAULT GETDATE(),
    status VARCHAR(10) NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Used', 'Cancelled', 'Refunded', 'Exchanged')),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE CASCADE,
    FOREIGN KEY (cabin_id) REFERENCES Cabins(cabin_id),
    CONSTRAINT chk_price_positive CHECK (price > 0),
    CONSTRAINT uq_seat_trip UNIQUE (trip_id, cabin_id, seat_number)
);

-- 14. Payments Table
CREATE TABLE Payments (
    payment_id INT IDENTITY(1,1) PRIMARY KEY,
    ticket_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATE NOT NULL DEFAULT GETDATE(),
    method_id INT NOT NULL,
    transaction_id VARCHAR(100) UNIQUE,
    status VARCHAR(8) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Completed', 'Failed', 'Refunded')),
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id) ON DELETE CASCADE,
    FOREIGN KEY (method_id) REFERENCES PaymentMethods(method_id),
    CONSTRAINT chk_payment_amount_positive CHECK (amount > 0)
);

-- 15. Discounts Table
CREATE TABLE Discounts (
    discount_id INT IDENTITY(1,1) PRIMARY KEY,
    description VARCHAR(255) NOT NULL,
    discount_type VARCHAR(15) NOT NULL CHECK (discount_type IN ('Percentage', 'Fixed Amount')),
    discount_value DECIMAL(10,2) NOT NULL,
    applicable_to VARCHAR(10) NOT NULL CHECK (applicable_to IN ('Ticket', 'Luggage', 'Bundle', 'Other')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CONSTRAINT chk_discount_value_positive CHECK (discount_value > 0),
    CONSTRAINT chk_discount_dates CHECK (end_date >= start_date)
);

-- 16. Ticket Discounts Table (connecting tickets and discounts)
CREATE TABLE TicketDiscounts (
    ticket_id INT NOT NULL,
    discount_id INT NOT NULL,
    applied_value DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (ticket_id, discount_id),
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id) ON DELETE CASCADE,
    FOREIGN KEY (discount_id) REFERENCES Discounts(discount_id) ON DELETE CASCADE,
    CONSTRAINT chk_applied_value_positive CHECK (applied_value > 0)
);

-- 17. Cancellations Table (Fixed Foreign Key)
CREATE TABLE Cancellations (
    cancellation_id INT IDENTITY(1,1) PRIMARY KEY,
    trip_id INT,
    ticket_id INT,
    customer_id INT,
    reason NVARCHAR(MAX),
    cancellation_date DATE NOT NULL DEFAULT GETDATE(),
    initiated_by VARCHAR(8) NOT NULL CHECK (initiated_by IN ('Customer', 'Company')),
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE SET NULL,
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id) ON DELETE NO ACTION, -- FIXED
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE SET NULL,
    CONSTRAINT chk_cancellation_refs CHECK ((trip_id IS NOT NULL) OR (ticket_id IS NOT NULL))
);

-- 18. Exchanges Table (Fixed Foreign Key)
CREATE TABLE Exchanges (
    exchange_id INT IDENTITY(1,1) PRIMARY KEY,
    old_ticket_id INT NOT NULL,
    new_ticket_id INT NOT NULL,
    exchange_date DATE NOT NULL DEFAULT GETDATE(),
    fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (old_ticket_id) REFERENCES Tickets(ticket_id) ON DELETE NO ACTION, -- FIXED
    FOREIGN KEY (new_ticket_id) REFERENCES Tickets(ticket_id) ON DELETE NO ACTION, -- FIXED
    CONSTRAINT chk_diff_tickets CHECK (old_ticket_id != new_ticket_id),
    CONSTRAINT chk_exchange_fee_non_negative CHECK (fee >= 0)
);

-- 19. Refunds Table (Fixed Foreign Key)
CREATE TABLE Refunds (
    refund_id INT IDENTITY(1,1) PRIMARY KEY,
    ticket_id INT NOT NULL,
    payment_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    refund_date DATE NOT NULL DEFAULT GETDATE(),
    reason NVARCHAR(MAX),
    status VARCHAR(9) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Processed', 'Rejected')),
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id) ON DELETE NO ACTION, -- FIXED
    FOREIGN KEY (payment_id) REFERENCES Payments(payment_id) ON DELETE CASCADE,
    CONSTRAINT chk_refund_amount_positive CHECK (amount > 0)
);

-- 20. Salaries Table
CREATE TABLE Salaries (
    salary_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_period VARCHAR(50) NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id) ON DELETE CASCADE,
    CONSTRAINT chk_salary_amount_positive CHECK (amount > 0)
);

-- 21. Maintenance Logs Table
CREATE TABLE MaintenanceLogs (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT NOT NULL,
    maintenance_date DATE NOT NULL,
    description NVARCHAR(MAX) NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    performed_by VARCHAR(100) NOT NULL,
    next_maintenance_date DATE,
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    CONSTRAINT chk_maintenance_cost_positive CHECK (cost >= 0),
    CONSTRAINT chk_next_maintenance_date CHECK (next_maintenance_date IS NULL OR next_maintenance_date > maintenance_date)
);

-- 22. Safety Metrics Table (Fixed Foreign Key)
CREATE TABLE SafetyMetrics (
    metric_id INT IDENTITY(1,1) PRIMARY KEY,
    trip_id INT NOT NULL,
    driver_id INT NOT NULL,
    report NVARCHAR(MAX),
    safety_score INT NOT NULL,
    report_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE CASCADE,
    FOREIGN KEY (driver_id) REFERENCES Drivers(driver_id) ON DELETE CASCADE,
    CONSTRAINT chk_safety_score_range CHECK (safety_score BETWEEN 1 AND 100)
);

-- 23. Luggage Table
CREATE TABLE Luggage (
    luggage_id INT IDENTITY(1,1) PRIMARY KEY,
    ticket_id INT NOT NULL,
    weight DECIMAL(10,2) NOT NULL,
    additional_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tracking_number VARCHAR(50) UNIQUE,
    FOREIGN KEY (ticket_id) REFERENCES Tickets(ticket_id) ON DELETE CASCADE,
    CONSTRAINT chk_weight_positive CHECK (weight > 0),
    CONSTRAINT chk_additional_fee_non_negative CHECK (additional_fee >= 0)
);

-- 24. Damages Table
CREATE TABLE Damages (
    damage_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT,
    luggage_id INT,
    description NVARCHAR(MAX) NOT NULL,
    report_date DATE NOT NULL DEFAULT GETDATE(),
    cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    repaired BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    FOREIGN KEY (luggage_id) REFERENCES Luggage(luggage_id) ON DELETE CASCADE,
    CONSTRAINT chk_damage_refs CHECK (
        (bus_id IS NOT NULL) OR (luggage_id IS NOT NULL)
    ),
    CONSTRAINT chk_damage_cost_non_negative CHECK (cost >= 0)
);

-- 25. Cleaning Logs Table
CREATE TABLE CleaningLogs (
    cleaning_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT NOT NULL,
    cleaning_date DATE NOT NULL DEFAULT GETDATE(),
    cleaner_name VARCHAR(100) NOT NULL,
    cleaning_type VARCHAR(9) NOT NULL DEFAULT 'Regular' CHECK (cleaning_type IN ('Regular', 'Deep', 'Emergency')),
    cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    CONSTRAINT chk_cleaning_cost_non_negative CHECK (cost >= 0)
);

-- 26. Fuel Consumption Table (Fixed Computed Column)
CREATE TABLE Fuel_Gas (
    fuel_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT NOT NULL,
    amount DECIMAL(10,2),
    cost_per_gallon DECIMAL(10,2),
    fuel_used DECIMAL(10,2),
    total_cost AS (fuel_used * cost_per_gallon) PERSISTED, -- FIXED Computed Column
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id),
    CONSTRAINT chk_fuel_used_positive CHECK (fuel_used > 0),
    CONSTRAINT chk_cost_per_gallon_positive CHECK (cost_per_gallon > 0)
);

-- 27. Mileage Table (Fixed Foreign Key)
CREATE TABLE Mileage (
    mileage_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT NOT NULL,
    trip_id INT,
    miles_traveled DECIMAL(10,2) NOT NULL,
    record_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE SET NULL,
    CONSTRAINT chk_miles_traveled_positive CHECK (miles_traveled > 0)
);

-- 28. Insurance Table
CREATE TABLE Insurance (
    insurance_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT NOT NULL,
    provider VARCHAR(100) NOT NULL,
    policy_number VARCHAR(50) UNIQUE NOT NULL,
    coverage_amount DECIMAL(15,2) NOT NULL,
    premium_amount DECIMAL(10,2) NOT NULL,
    start_date DATE NOT NULL,
    expiration_date DATE NOT NULL,
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    CONSTRAINT chk_insurance_dates CHECK (expiration_date > start_date),
    CONSTRAINT chk_coverage_amount_positive CHECK (coverage_amount > 0),
    CONSTRAINT chk_premium_amount_positive CHECK (premium_amount > 0)
);

-- 29. Costs Table
CREATE TABLE Costs (
    cost_id INT IDENTITY(1,1) PRIMARY KEY,
    trip_id INT NOT NULL,
    total_cost DECIMAL(10,2) NOT NULL,
    cost_breakdown NVARCHAR(MAX),
    calculation_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE CASCADE,
    CONSTRAINT chk_total_cost_positive CHECK (total_cost >= 0)
);

-- 30. Lifetime Bus Cost Table
CREATE TABLE LifetimeBusCost (
    bus_id INT PRIMARY KEY,
    total_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    last_updated DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    CONSTRAINT chk_lifetime_cost_non_negative CHECK (total_cost >= 0)
);

-- 31. Customer Reviews Table (Fixed Foreign Key)
CREATE TABLE CustomerReviews (
    review_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    trip_id INT NOT NULL,
    rating INT NOT NULL,
    review_text NVARCHAR(MAX),
    review_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE CASCADE,
    CONSTRAINT chk_rating_range CHECK (rating BETWEEN 1 AND 5)
);

-- 32. Lost and Found Table
CREATE TABLE LostAndFound (
    lost_id INT IDENTITY(1,1) PRIMARY KEY,
    bus_id INT NOT NULL,
    trip_id INT,
    description NVARCHAR(MAX) NOT NULL,
    found_date DATE NOT NULL DEFAULT GETDATE(),
    claimed VARCHAR(3) DEFAULT 'No' CHECK (claimed IN ('Yes', 'No')),
    claimed_by INT,
    claimed_date DATE,
    FOREIGN KEY (bus_id) REFERENCES Buses(bus_id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES Trips(trip_id) ON DELETE SET NULL,
    FOREIGN KEY (claimed_by) REFERENCES Customers(customer_id) ON DELETE SET NULL,
    CONSTRAINT chk_claimed_date CHECK (claimed_date IS NULL OR claimed_date >= found_date)
);

-- 33. Rewards Program Table (Fixed Foreign Key)
CREATE TABLE Rewards (
    reward_id INT PRIMARY KEY,
    reward_name VARCHAR(255) NOT NULL
);


-- 34. Miles Redeemed Table
CREATE TABLE MilesRedeemed (
    redemption_id INT PRIMARY KEY,
    reward_id INT NOT NULL,
    miles_used INT NOT NULL,
	cid INT NOT NULL,
    FOREIGN KEY (reward_id) REFERENCES Rewards(reward_id),
	FOREIGN KEY (cid) REFERENCES Customers (customer_id)
    ON DELETE NO ACTION 
    ON UPDATE NO ACTION
);

-- 35. Travel Bundles Table
CREATE TABLE TravelBundles (
    bundle_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description NVARCHAR(MAX) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    max_tickets INT NOT NULL DEFAULT 1,
    CONSTRAINT chk_bundle_price_positive CHECK (price > 0),
    CONSTRAINT chk_bundle_dates CHECK (valid_to >= valid_from),
    CONSTRAINT chk_max_tickets_positive CHECK (max_tickets > 0)
);

-- 36. Bundle Details Table (to connect bundles with trips)
CREATE TABLE BundleDetails (
    bundle_detail_id INT IDENTITY(1,1) PRIMARY KEY,
    bundle_id INT NOT NULL,
    route_id INT NOT NULL,
    FOREIGN KEY (bundle_id) REFERENCES TravelBundles(bundle_id) ON DELETE CASCADE,
    FOREIGN KEY (route_id) REFERENCES Routes(route_id) ON DELETE CASCADE
);

-- 37. Promotions Table
CREATE TABLE Promotions (
    promo_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description NVARCHAR(MAX) NOT NULL,
    discount_percentage DECIMAL(5,2) NOT NULL,
    promo_code VARCHAR(20) UNIQUE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    usage_limit INT,
    current_usage INT NOT NULL DEFAULT 0,
	cid INT NOT NULL,
	FOREIGN KEY (cid) REFERENCES Customers (customer_id),
    CONSTRAINT chk_discount_percentage_range CHECK (discount_percentage BETWEEN 0 AND 100),
    CONSTRAINT chk_promo_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_usage_limit_positive CHECK (usage_limit IS NULL OR usage_limit > 0),
    CONSTRAINT chk_current_usage_non_negative CHECK (current_usage >= 0)
);

-- 38. Suppliers Table
CREATE TABLE Suppliers (
    supplier_id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100) NOT NULL,
    contact_phone VARCHAR(20) NOT NULL,
    contact_email VARCHAR(100) UNIQUE NOT NULL,
    address VARCHAR(255) NOT NULL,
    category VARCHAR(8) NOT NULL CHECK (category IN ('Parts', 'Fuel', 'Cleaning', 'Other')),
    active BIT NOT NULL DEFAULT 1
);

-- 39. Part Suppliers Table (specialized suppliers for parts)
CREATE TABLE PartSuppliers (
    part_supplier_id INT IDENTITY(1,1) PRIMARY KEY,
    supplier_id INT NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    lead_time INT NOT NULL, -- in days
    quality_rating INT,
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id) ON DELETE CASCADE,
    CONSTRAINT chk_lead_time_positive CHECK (lead_time > 0),
    CONSTRAINT chk_quality_rating_range CHECK (quality_rating IS NULL OR quality_rating BETWEEN 1 AND 10)
);

-- 40. Part Inventory Table
CREATE TABLE PartInventory (
    part_id INT IDENTITY(1,1) PRIMARY KEY,
    part_supplier_id INT NOT NULL,
    part_name VARCHAR(100) NOT NULL,
    part_number VARCHAR(50) NOT NULL,
    quantity INT NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    reorder_level INT NOT NULL,
    last_order_date DATE,
    FOREIGN KEY (part_supplier_id) REFERENCES PartSuppliers(part_supplier_id) ON DELETE CASCADE,
    CONSTRAINT chk_quantity_non_negative CHECK (quantity >= 0),
    CONSTRAINT chk_unit_cost_positive CHECK (unit_cost > 0),
    CONSTRAINT chk_reorder_level_positive CHECK (reorder_level > 0)
);

-- 41. Parts Used Table (to connect maintenance logs with parts)
CREATE TABLE PartsUsed (
    usage_id INT IDENTITY(1,1) PRIMARY KEY,
    maintenance_id INT NOT NULL,
    part_id INT NOT NULL,
    quantity INT NOT NULL,
    usage_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (maintenance_id) REFERENCES MaintenanceLogs(log_id) ON DELETE CASCADE,
    FOREIGN KEY (part_id) REFERENCES PartInventory(part_id) ON DELETE CASCADE,
    CONSTRAINT chk_parts_used_quantity_positive CHECK (quantity > 0)
);

-- 42. Corporate Customers Table (for specialized corporate customer data)
CREATE TABLE CorporateCustomers (
    corporate_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL UNIQUE,
    industry VARCHAR(100) NOT NULL,
    annual_revenue DECIMAL(15,2),
    contract_start_date DATE NOT NULL,
    contract_end_date DATE,
    discount_percentage DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    payment_terms VARCHAR(100) NOT NULL DEFAULT 'Net 30',
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT chk_corporate_contract_dates CHECK (
        contract_end_date IS NULL OR contract_end_date >= contract_start_date
    ),
    CONSTRAINT chk_corporate_discount_range CHECK (discount_percentage BETWEEN 0 AND 100)
);