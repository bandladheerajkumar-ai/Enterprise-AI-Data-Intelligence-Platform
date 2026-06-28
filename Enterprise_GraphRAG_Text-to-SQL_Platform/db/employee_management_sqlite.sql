-- Employee Management System for SQLite
-- Runs without modification in SQLite:
-- sqlite3 employee_management.db < employee_management_sqlite.sql

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

DROP TABLE IF EXISTS employee_assets;
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS employee_training;
DROP TABLE IF EXISTS training_programs;
DROP TABLE IF EXISTS performance_reviews;
DROP TABLE IF EXISTS payroll;
DROP TABLE IF EXISTS leave_requests;
DROP TABLE IF EXISTS attendance;
DROP TABLE IF EXISTS employee_skills;
DROP TABLE IF EXISTS skills;
DROP TABLE IF EXISTS employee_project_assignments;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS employee_managers;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS teams;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS designations;
DROP TABLE IF EXISTS offices;
DROP TABLE IF EXISTS locations;

CREATE TABLE locations (
    location_id INTEGER PRIMARY KEY,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    country TEXT NOT NULL DEFAULT 'India',
    postal_code TEXT NOT NULL CHECK (length(postal_code) = 6),
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    UNIQUE (city, state)
);

CREATE TABLE offices (
    office_id INTEGER PRIMARY KEY,
    location_id INTEGER NOT NULL,
    office_code TEXT NOT NULL UNIQUE,
    office_name TEXT NOT NULL,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    phone TEXT NOT NULL CHECK (length(phone) = 10),
    is_head_office INTEGER NOT NULL DEFAULT 0 CHECK (is_head_office IN (0,1)),
    FOREIGN KEY (location_id) REFERENCES locations(location_id) ON UPDATE CASCADE
);

CREATE TABLE designations (
    designation_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL UNIQUE,
    level_no INTEGER NOT NULL CHECK (level_no BETWEEN 1 AND 12),
    min_salary REAL NOT NULL CHECK (min_salary >= 0),
    max_salary REAL NOT NULL CHECK (max_salary >= min_salary)
);

CREATE TABLE departments (
    department_id INTEGER PRIMARY KEY,
    office_id INTEGER NOT NULL,
    department_code TEXT NOT NULL UNIQUE,
    department_name TEXT NOT NULL UNIQUE,
    budget REAL NOT NULL DEFAULT 0 CHECK (budget >= 0),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (office_id) REFERENCES offices(office_id) ON UPDATE CASCADE
);

CREATE TABLE teams (
    team_id INTEGER PRIMARY KEY,
    department_id INTEGER NOT NULL,
    team_code TEXT NOT NULL UNIQUE,
    team_name TEXT NOT NULL,
    UNIQUE (department_id, team_name),
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON UPDATE CASCADE
);

CREATE TABLE employees (
    employee_id INTEGER PRIMARY KEY,
    employee_code TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    gender TEXT NOT NULL CHECK (gender IN ('Female','Male','Non-binary','Prefer not to say')),
    date_of_birth TEXT NOT NULL CHECK (date(date_of_birth) <= date('2008-06-15')),
    email TEXT NOT NULL UNIQUE CHECK (email LIKE '%@%.%'),
    phone TEXT NOT NULL UNIQUE CHECK (length(phone) = 10),
    hire_date TEXT NOT NULL CHECK (date(hire_date) <= date('2026-06-15')),
    department_id INTEGER NOT NULL,
    team_id INTEGER NOT NULL,
    designation_id INTEGER NOT NULL,
    office_id INTEGER NOT NULL,
    employment_status TEXT NOT NULL DEFAULT 'Active' CHECK (employment_status IN ('Active','On Leave','Resigned','Terminated')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON UPDATE CASCADE,
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON UPDATE CASCADE,
    FOREIGN KEY (designation_id) REFERENCES designations(designation_id) ON UPDATE CASCADE,
    FOREIGN KEY (office_id) REFERENCES offices(office_id) ON UPDATE CASCADE
);

CREATE TABLE employee_managers (
    manager_relation_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    manager_id INTEGER NOT NULL,
    effective_from TEXT NOT NULL,
    effective_to TEXT,
    CHECK (employee_id <> manager_id),
    CHECK (effective_to IS NULL OR date(effective_to) >= date(effective_from)),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE RESTRICT
);

CREATE TABLE clients (
    client_id INTEGER PRIMARY KEY,
    client_code TEXT NOT NULL UNIQUE,
    client_name TEXT NOT NULL UNIQUE,
    industry TEXT NOT NULL,
    location_id INTEGER NOT NULL,
    contact_email TEXT NOT NULL UNIQUE CHECK (contact_email LIKE '%@%.%'),
    contact_phone TEXT NOT NULL CHECK (length(contact_phone) = 10),
    FOREIGN KEY (location_id) REFERENCES locations(location_id) ON UPDATE CASCADE
);

CREATE TABLE projects (
    project_id INTEGER PRIMARY KEY,
    client_id INTEGER NOT NULL,
    department_id INTEGER NOT NULL,
    project_code TEXT NOT NULL UNIQUE,
    project_name TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT,
    status TEXT NOT NULL DEFAULT 'Planned' CHECK (status IN ('Planned','Active','On Hold','Completed','Cancelled')),
    budget REAL NOT NULL DEFAULT 0 CHECK (budget >= 0),
    current_assignment_count INTEGER NOT NULL DEFAULT 0 CHECK (current_assignment_count >= 0),
    CHECK (end_date IS NULL OR date(end_date) >= date(start_date)),
    FOREIGN KEY (client_id) REFERENCES clients(client_id) ON UPDATE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON UPDATE CASCADE
);

CREATE TABLE employee_project_assignments (
    assignment_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    project_id INTEGER NOT NULL,
    role_on_project TEXT NOT NULL,
    allocation_percent REAL NOT NULL CHECK (allocation_percent > 0 AND allocation_percent <= 100),
    assigned_from TEXT NOT NULL,
    assigned_to TEXT,
    billable INTEGER NOT NULL DEFAULT 1 CHECK (billable IN (0,1)),
    CHECK (assigned_to IS NULL OR date(assigned_to) >= date(assigned_from)),
    UNIQUE (employee_id, project_id, assigned_from),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE
);

CREATE TABLE skills (
    skill_id INTEGER PRIMARY KEY,
    skill_name TEXT NOT NULL UNIQUE,
    skill_category TEXT NOT NULL
);

CREATE TABLE employee_skills (
    employee_skill_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    proficiency_level TEXT NOT NULL CHECK (proficiency_level IN ('Beginner','Intermediate','Advanced','Expert')),
    years_experience REAL NOT NULL DEFAULT 0 CHECK (years_experience >= 0),
    certified INTEGER NOT NULL DEFAULT 0 CHECK (certified IN (0,1)),
    UNIQUE (employee_id, skill_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills(skill_id) ON DELETE CASCADE
);

CREATE TABLE attendance (
    attendance_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    attendance_date TEXT NOT NULL,
    check_in TEXT,
    check_out TEXT,
    status TEXT NOT NULL CHECK (status IN ('Present','Absent','Half Day','Work From Home','Holiday')),
    total_hours REAL NOT NULL DEFAULT 0 CHECK (total_hours >= 0 AND total_hours <= 24),
    UNIQUE (employee_id, attendance_date),
    CHECK (check_out IS NULL OR check_in IS NULL OR time(check_out) >= time(check_in)),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

CREATE TABLE leave_requests (
    leave_request_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    approver_id INTEGER,
    leave_type TEXT NOT NULL CHECK (leave_type IN ('Casual','Sick','Earned','Maternity','Paternity','Bereavement','Unpaid')),
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending','Approved','Rejected','Cancelled')),
    requested_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (date(end_date) >= date(start_date)),
    CHECK (approver_id IS NULL OR approver_id <> employee_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (approver_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE TABLE payroll (
    payroll_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    payroll_month TEXT NOT NULL,
    basic_salary REAL NOT NULL CHECK (basic_salary >= 0),
    hra REAL NOT NULL DEFAULT 0 CHECK (hra >= 0),
    allowances REAL NOT NULL DEFAULT 0 CHECK (allowances >= 0),
    deductions REAL NOT NULL DEFAULT 0 CHECK (deductions >= 0),
    net_salary REAL NOT NULL CHECK (net_salary >= 0),
    payment_status TEXT NOT NULL DEFAULT 'Pending' CHECK (payment_status IN ('Pending','Paid','On Hold')),
    paid_on TEXT,
    UNIQUE (employee_id, payroll_month),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

CREATE TABLE performance_reviews (
    review_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    reviewer_id INTEGER NOT NULL,
    review_period_start TEXT NOT NULL,
    review_period_end TEXT NOT NULL,
    rating REAL NOT NULL CHECK (rating >= 1 AND rating <= 5),
    goals_met_percent REAL NOT NULL CHECK (goals_met_percent >= 0 AND goals_met_percent <= 100),
    comments TEXT,
    reviewed_at TEXT NOT NULL DEFAULT CURRENT_DATE,
    CHECK (date(review_period_end) >= date(review_period_start)),
    CHECK (employee_id <> reviewer_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (reviewer_id) REFERENCES employees(employee_id) ON DELETE RESTRICT
);

CREATE TABLE training_programs (
    training_program_id INTEGER PRIMARY KEY,
    department_id INTEGER NOT NULL,
    program_code TEXT NOT NULL UNIQUE,
    program_name TEXT NOT NULL,
    provider TEXT NOT NULL,
    duration_hours REAL NOT NULL CHECK (duration_hours > 0),
    mode TEXT NOT NULL CHECK (mode IN ('Online','Classroom','Hybrid')),
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON UPDATE CASCADE
);

CREATE TABLE employee_training (
    employee_training_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    training_program_id INTEGER NOT NULL,
    enrolled_on TEXT NOT NULL,
    completed_on TEXT,
    status TEXT NOT NULL DEFAULT 'Enrolled' CHECK (status IN ('Enrolled','In Progress','Completed','Dropped')),
    score REAL CHECK (score IS NULL OR (score >= 0 AND score <= 100)),
    CHECK (completed_on IS NULL OR date(completed_on) >= date(enrolled_on)),
    UNIQUE (employee_id, training_program_id, enrolled_on),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (training_program_id) REFERENCES training_programs(training_program_id) ON DELETE CASCADE
);

CREATE TABLE assets (
    asset_id INTEGER PRIMARY KEY,
    office_id INTEGER NOT NULL,
    asset_tag TEXT NOT NULL UNIQUE,
    asset_type TEXT NOT NULL,
    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    serial_number TEXT NOT NULL UNIQUE,
    purchase_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Available' CHECK (status IN ('Available','Assigned','Repair','Retired')),
    FOREIGN KEY (office_id) REFERENCES offices(office_id) ON UPDATE CASCADE
);

CREATE TABLE employee_assets (
    employee_asset_id INTEGER PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    asset_id INTEGER NOT NULL,
    assigned_on TEXT NOT NULL,
    returned_on TEXT,
    condition_on_issue TEXT NOT NULL CHECK (condition_on_issue IN ('New','Good','Fair')),
    condition_on_return TEXT CHECK (condition_on_return IS NULL OR condition_on_return IN ('Good','Fair','Damaged')),
    CHECK (returned_on IS NULL OR date(returned_on) >= date(assigned_on)),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX ux_employee_managers_current ON employee_managers(employee_id) WHERE effective_to IS NULL;
CREATE UNIQUE INDEX ux_employee_assets_current ON employee_assets(asset_id) WHERE returned_on IS NULL;
CREATE INDEX idx_offices_location_id ON offices(location_id);
CREATE INDEX idx_departments_office_id ON departments(office_id);
CREATE INDEX idx_teams_department_id ON teams(department_id);
CREATE INDEX idx_employees_department_id ON employees(department_id);
CREATE INDEX idx_employees_team_id ON employees(team_id);
CREATE INDEX idx_employees_designation_id ON employees(designation_id);
CREATE INDEX idx_employees_office_id ON employees(office_id);
CREATE INDEX idx_employees_name ON employees(last_name, first_name);
CREATE INDEX idx_clients_location_id ON clients(location_id);
CREATE INDEX idx_projects_client_id ON projects(client_id);
CREATE INDEX idx_projects_department_status ON projects(department_id, status);
CREATE INDEX idx_assignments_employee_id ON employee_project_assignments(employee_id);
CREATE INDEX idx_assignments_project_id ON employee_project_assignments(project_id);
CREATE INDEX idx_employee_skills_skill_id ON employee_skills(skill_id);
CREATE INDEX idx_attendance_employee_date ON attendance(employee_id, attendance_date);
CREATE INDEX idx_leave_employee_status ON leave_requests(employee_id, status);
CREATE INDEX idx_payroll_month ON payroll(payroll_month);
CREATE INDEX idx_reviews_employee_period ON performance_reviews(employee_id, review_period_start, review_period_end);
CREATE INDEX idx_training_employee_status ON employee_training(employee_id, status);
CREATE INDEX idx_assets_office_status ON assets(office_id, status);

INSERT INTO locations (location_id, city, state, country, postal_code, timezone) VALUES
(1,'Bengaluru','Karnataka','India','560001','Asia/Kolkata'),
(2,'Hyderabad','Telangana','India','500081','Asia/Kolkata'),
(3,'Pune','Maharashtra','India','411001','Asia/Kolkata'),
(4,'Chennai','Tamil Nadu','India','600001','Asia/Kolkata'),
(5,'Mumbai','Maharashtra','India','400001','Asia/Kolkata'),
(6,'Delhi','Delhi','India','110001','Asia/Kolkata'),
(7,'Gurugram','Haryana','India','122001','Asia/Kolkata'),
(8,'Noida','Uttar Pradesh','India','201301','Asia/Kolkata'),
(9,'Kolkata','West Bengal','India','700001','Asia/Kolkata'),
(10,'Ahmedabad','Gujarat','India','380001','Asia/Kolkata');

INSERT INTO offices VALUES
(1,1,'BLR-HQ','Bengaluru Head Office','MG Road Business Centre','Near Trinity Metro','8045678901',1),
(2,2,'HYD-TEC','Hyderabad Technology Office','HITEC City Main Road','Madhapur','8045678902',0),
(3,3,'PUN-DEV','Pune Development Centre','Baner Road','Balewadi','8045678903',0),
(4,4,'CHN-OPS','Chennai Operations Office','OMR IT Corridor','Thoraipakkam','8045678904',0),
(5,7,'GGN-SLS','Gurugram Sales Office','Cyber City Phase II','DLF','8045678905',0);

INSERT INTO designations VALUES
(1,'Associate Software Engineer',1,450000,800000),(2,'Software Engineer',2,700000,1400000),
(3,'Senior Software Engineer',3,1200000,2200000),(4,'Lead Engineer',4,2000000,3200000),
(5,'Engineering Manager',5,2800000,4500000),(6,'Product Manager',4,1800000,3500000),
(7,'QA Engineer',2,600000,1300000),(8,'HR Business Partner',3,800000,1800000),
(9,'Finance Analyst',2,700000,1600000),(10,'Sales Manager',4,1500000,3000000),
(11,'Data Analyst',2,700000,1500000),(12,'Data Scientist',3,1200000,2600000);

INSERT INTO departments (department_id, office_id, department_code, department_name, budget) VALUES
(1,1,'DEP01','Engineering',10000000),(2,1,'DEP02','Product',7500000),
(3,2,'DEP03','Quality Assurance',5000000),(4,4,'DEP04','Human Resources',3500000),
(5,5,'DEP05','Finance',5000000),(6,5,'DEP06','Sales',9000000),
(7,5,'DEP07','Marketing',6000000),(8,4,'DEP08','Customer Success',4500000),
(9,2,'DEP09','IT Operations',6500000),(10,3,'DEP10','Data Analytics',8000000);

INSERT INTO teams VALUES
(1,1,'TM01','Platform'),(2,1,'TM02','Backend Services'),(3,2,'TM03','Product Strategy'),(4,2,'TM04','UX Research'),
(5,3,'TM05','Automation QA'),(6,3,'TM06','Release QA'),(7,4,'TM07','People Ops'),(8,4,'TM08','Talent Acquisition'),
(9,5,'TM09','Accounting'),(10,5,'TM10','Compliance'),(11,6,'TM11','Enterprise Sales'),(12,6,'TM12','Inside Sales'),
(13,7,'TM13','Demand Generation'),(14,7,'TM14','Content'),(15,8,'TM15','Support Engineering'),(16,8,'TM16','Implementation'),
(17,9,'TM17','Infrastructure'),(18,9,'TM18','Security'),(19,10,'TM19','Business Intelligence'),(20,10,'TM20','Data Science');

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 200)
INSERT INTO employees (
    employee_id, employee_code, first_name, last_name, gender, date_of_birth, email, phone,
    hire_date, department_id, team_id, designation_id, office_id, employment_status
)
SELECT
    x,
    'EMP' || printf('%04d', x),
    CASE WHEN x % 2 = 0 THEN
        CASE x % 10 WHEN 0 THEN 'Ananya' WHEN 1 THEN 'Priya' WHEN 2 THEN 'Neha' WHEN 3 THEN 'Sneha' WHEN 4 THEN 'Aditi' WHEN 5 THEN 'Kavya' WHEN 6 THEN 'Meera' WHEN 7 THEN 'Riya' WHEN 8 THEN 'Pooja' ELSE 'Swati' END
    ELSE
        CASE x % 10 WHEN 0 THEN 'Aarav' WHEN 1 THEN 'Vivaan' WHEN 2 THEN 'Aditya' WHEN 3 THEN 'Arjun' WHEN 4 THEN 'Sai' WHEN 5 THEN 'Rohan' WHEN 6 THEN 'Rahul' WHEN 7 THEN 'Karan' WHEN 8 THEN 'Vikram' ELSE 'Siddharth' END
    END,
    CASE x % 10 WHEN 0 THEN 'Sharma' WHEN 1 THEN 'Verma' WHEN 2 THEN 'Iyer' WHEN 3 THEN 'Nair' WHEN 4 THEN 'Reddy' WHEN 5 THEN 'Rao' WHEN 6 THEN 'Patel' WHEN 7 THEN 'Mehta' WHEN 8 THEN 'Gupta' ELSE 'Singh' END,
    CASE WHEN x % 2 = 0 THEN 'Female' ELSE 'Male' END,
    date('1978-01-01', '+' || ((x * 53) % 9000) || ' days'),
    'employee' || x || '@bharatems.example.com',
    '9' || printf('%09d', 700000000 + x),
    date('2016-01-01', '+' || ((x * 29) % 3600) || ' days'),
    ((x - 1) % 10) + 1,
    (((x - 1) % 10) * 2) + CASE WHEN x % 2 = 0 THEN 2 ELSE 1 END,
    CASE
        WHEN x <= 10 THEN 5
        WHEN ((x - 1) % 10) + 1 = 2 THEN 6
        WHEN ((x - 1) % 10) + 1 = 3 THEN 7
        WHEN ((x - 1) % 10) + 1 = 4 THEN 8
        WHEN ((x - 1) % 10) + 1 = 5 THEN 9
        WHEN ((x - 1) % 10) + 1 = 6 THEN 10
        WHEN ((x - 1) % 10) + 1 = 10 THEN 11 + (x % 2)
        ELSE 1 + (x % 4)
    END,
    (SELECT office_id FROM departments WHERE department_id = ((x - 1) % 10) + 1),
    'Active'
FROM n;

WITH RECURSIVE n(x) AS (SELECT 2 UNION ALL SELECT x + 1 FROM n WHERE x < 200)
INSERT INTO employee_managers (manager_relation_id, employee_id, manager_id, effective_from)
SELECT x - 1, x, CASE WHEN x <= 20 THEN 1 ELSE ((x - 2) % 10) + 1 END, '2021-04-01'
FROM n;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 25)
INSERT INTO clients (client_id, client_code, client_name, industry, location_id, contact_email, contact_phone)
SELECT
    x,
    'CL' || printf('%03d', x),
    (CASE x WHEN 1 THEN 'Aarohan' WHEN 2 THEN 'Bharat' WHEN 3 THEN 'Crescent' WHEN 4 THEN 'Dakshin' WHEN 5 THEN 'Eastern' WHEN 6 THEN 'Fortune' WHEN 7 THEN 'Ganga' WHEN 8 THEN 'Horizon' WHEN 9 THEN 'Indus' WHEN 10 THEN 'Jeevan' WHEN 11 THEN 'Konark' WHEN 12 THEN 'Lotus' WHEN 13 THEN 'Meridian' WHEN 14 THEN 'Narmada' WHEN 15 THEN 'Orchid' WHEN 16 THEN 'Pragati' WHEN 17 THEN 'Quantum' WHEN 18 THEN 'Riverstone' WHEN 19 THEN 'Saffron' WHEN 20 THEN 'Triveni' WHEN 21 THEN 'Udaan' WHEN 22 THEN 'Vistaar' WHEN 23 THEN 'Western' WHEN 24 THEN 'Yukti' ELSE 'Zenith' END) ||
    ' ' || CASE x % 6 WHEN 0 THEN 'Technologies' WHEN 1 THEN 'Industries' WHEN 2 THEN 'Bank' WHEN 3 THEN 'Retail' WHEN 4 THEN 'Health' ELSE 'Logistics' END,
    CASE x % 12 WHEN 0 THEN 'Banking' WHEN 1 THEN 'Insurance' WHEN 2 THEN 'Retail' WHEN 3 THEN 'Healthcare' WHEN 4 THEN 'Education' WHEN 5 THEN 'Manufacturing' WHEN 6 THEN 'Telecom' WHEN 7 THEN 'Logistics' WHEN 8 THEN 'Energy' WHEN 9 THEN 'Government' WHEN 10 THEN 'FinTech' ELSE 'E-commerce' END,
    ((x - 1) % 10) + 1,
    'procurement' || printf('%03d', x) || '@client.example.in',
    '8' || printf('%09d', 600000000 + x)
FROM n;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 50)
INSERT INTO projects (project_id, client_id, department_id, project_code, project_name, start_date, end_date, status, budget)
SELECT
    x,
    ((x - 1) % 25) + 1,
    ((x - 1) % 10) + 1,
    'PRJ' || printf('%04d', x),
    CASE x % 10 WHEN 0 THEN 'Nova' WHEN 1 THEN 'Astra' WHEN 2 THEN 'Prism' WHEN 3 THEN 'Setu' WHEN 4 THEN 'Tejas' WHEN 5 THEN 'Mitra' WHEN 6 THEN 'Utsav' WHEN 7 THEN 'Nexus' WHEN 8 THEN 'Sparsh' ELSE 'Drishti' END ||
    ' ' || CASE x % 7 WHEN 0 THEN 'ERP' WHEN 1 THEN 'CRM' WHEN 2 THEN 'Analytics' WHEN 3 THEN 'Payments' WHEN 4 THEN 'Mobile' WHEN 5 THEN 'Cloud' ELSE 'Automation' END ||
    ' ' || printf('%02d', x),
    date('2024-01-01', '+' || (x * 11) || ' days'),
    CASE WHEN x % 5 = 4 THEN date('2024-01-01', '+' || ((x * 11) + 240) || ' days') ELSE NULL END,
    CASE x % 5 WHEN 0 THEN 'Planned' WHEN 1 THEN 'Active' WHEN 2 THEN 'Active' WHEN 3 THEN 'On Hold' ELSE 'Completed' END,
    (15 + (x % 100)) * 100000
FROM n;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 500)
INSERT INTO employee_project_assignments (assignment_id, employee_id, project_id, role_on_project, allocation_percent, assigned_from, assigned_to, billable)
SELECT
    x, ((x - 1) % 200) + 1, ((x * 7 - 1) % 50) + 1,
    CASE x % 10 WHEN 0 THEN 'Developer' WHEN 1 THEN 'QA Analyst' WHEN 2 THEN 'Scrum Master' WHEN 3 THEN 'Business Analyst' WHEN 4 THEN 'Data Engineer' WHEN 5 THEN 'DevOps Engineer' WHEN 6 THEN 'UI Designer' WHEN 7 THEN 'Tech Lead' WHEN 8 THEN 'Support Engineer' ELSE 'Product Owner' END,
    CASE x % 4 WHEN 0 THEN 25 WHEN 1 THEN 50 WHEN 2 THEN 75 ELSE 100 END,
    date('2025-01-01', '+' || ((x % 12) * 28) || ' days'),
    CASE WHEN x % 3 = 0 THEN date('2025-01-01', '+' || (((x % 12) * 28) + 120) || ' days') ELSE NULL END,
    CASE WHEN x % 6 = 0 THEN 0 ELSE 1 END
FROM n;

INSERT INTO skills VALUES
(1,'PostgreSQL','Database'),(2,'SQLite','Database'),(3,'Python','Programming'),(4,'Java','Programming'),(5,'React','Frontend'),
(6,'AWS','Cloud'),(7,'Azure','Cloud'),(8,'Docker','DevOps'),(9,'Kubernetes','DevOps'),(10,'Terraform','DevOps'),
(11,'Power BI','Analytics'),(12,'Tableau','Analytics'),(13,'Machine Learning','AI'),(14,'Manual Testing','QA'),(15,'Selenium','QA'),
(16,'JMeter','QA'),(17,'Product Discovery','Product'),(18,'Agile Coaching','Delivery'),(19,'Payroll Compliance','HR'),(20,'Recruiting','HR'),
(21,'Financial Reporting','Finance'),(22,'GST Compliance','Finance'),(23,'Enterprise Sales','Sales'),(24,'Digital Marketing','Marketing'),(25,'Customer Onboarding','Support'),
(26,'Cybersecurity','Security'),(27,'Linux Administration','IT'),(28,'Data Warehousing','Data'),(29,'API Design','Engineering'),(30,'Microservices','Engineering');

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 400)
INSERT INTO employee_skills (employee_skill_id, employee_id, skill_id, proficiency_level, years_experience, certified)
SELECT x, ((x - 1) % 200) + 1, ((((x - 1) / 200) * 7 + ((x - 1) % 30)) % 30) + 1,
       CASE x % 4 WHEN 0 THEN 'Beginner' WHEN 1 THEN 'Intermediate' WHEN 2 THEN 'Advanced' ELSE 'Expert' END,
       round(0.5 + ((x % 90) / 10.0), 1), CASE WHEN x % 3 = 0 THEN 1 ELSE 0 END
FROM n;

WITH RECURSIVE days(d) AS (SELECT 0 UNION ALL SELECT d + 1 FROM days WHERE d < 24),
employees_200(eid) AS (SELECT 1 UNION ALL SELECT eid + 1 FROM employees_200 WHERE eid < 200)
INSERT INTO attendance (attendance_id, employee_id, attendance_date, check_in, check_out, status, total_hours)
SELECT
    d * 200 + eid,
    eid,
    date('2026-01-01', '+' || d || ' days'),
    CASE WHEN strftime('%w', date('2026-01-01', '+' || d || ' days')) IN ('0','6') OR (eid + d) % 19 = 0 THEN NULL ELSE '09:30' END,
    CASE WHEN strftime('%w', date('2026-01-01', '+' || d || ' days')) IN ('0','6') OR (eid + d) % 19 = 0 THEN NULL WHEN (eid + d) % 11 = 0 THEN '13:30' ELSE '18:30' END,
    CASE WHEN strftime('%w', date('2026-01-01', '+' || d || ' days')) IN ('0','6') THEN 'Holiday'
         WHEN (eid + d) % 19 = 0 THEN 'Absent'
         WHEN (eid + d) % 13 = 0 THEN 'Work From Home'
         WHEN (eid + d) % 11 = 0 THEN 'Half Day'
         ELSE 'Present' END,
    CASE WHEN strftime('%w', date('2026-01-01', '+' || d || ' days')) IN ('0','6') OR (eid + d) % 19 = 0 THEN 0 WHEN (eid + d) % 11 = 0 THEN 4 ELSE 9 END
FROM days CROSS JOIN employees_200;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 500)
INSERT INTO leave_requests (leave_request_id, employee_id, approver_id, leave_type, start_date, end_date, reason, status)
SELECT x, ((x - 1) % 200) + 1, CASE WHEN ((x - 1) % 200) + 1 = 1 THEN 2 ELSE 1 END,
       CASE x % 7 WHEN 0 THEN 'Casual' WHEN 1 THEN 'Sick' WHEN 2 THEN 'Earned' WHEN 3 THEN 'Maternity' WHEN 4 THEN 'Paternity' WHEN 5 THEN 'Bereavement' ELSE 'Unpaid' END,
       date('2025-01-01', '+' || (x % 300) || ' days'),
       date('2025-01-01', '+' || ((x % 300) + (x % 5)) || ' days'),
       CASE x % 6 WHEN 0 THEN 'Personal work' WHEN 1 THEN 'Medical appointment' WHEN 2 THEN 'Family function' WHEN 3 THEN 'Travel' WHEN 4 THEN 'Health rest' ELSE 'Emergency' END,
       CASE x % 5 WHEN 0 THEN 'Pending' WHEN 1 THEN 'Approved' WHEN 2 THEN 'Approved' WHEN 3 THEN 'Rejected' ELSE 'Cancelled' END
FROM n;

INSERT INTO payroll (payroll_id, employee_id, payroll_month, basic_salary, hra, allowances, deductions, net_salary, payment_status, paid_on)
SELECT employee_id, employee_id, '2026-01-01',
       45000 + (designation_id * 9000) + (employee_id % 20) * 1000,
       (45000 + (designation_id * 9000) + (employee_id % 20) * 1000) * 0.40,
       5000 + (employee_id % 10) * 1500,
       2500 + (employee_id % 8) * 900,
       (45000 + (designation_id * 9000) + (employee_id % 20) * 1000) +
       ((45000 + (designation_id * 9000) + (employee_id % 20) * 1000) * 0.40) +
       (5000 + (employee_id % 10) * 1500) - (2500 + (employee_id % 8) * 900),
       CASE WHEN employee_id % 12 = 0 THEN 'Pending' ELSE 'Paid' END,
       CASE WHEN employee_id % 12 = 0 THEN NULL ELSE '2026-01-31' END
FROM employees;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 300)
INSERT INTO performance_reviews (review_id, employee_id, reviewer_id, review_period_start, review_period_end, rating, goals_met_percent, comments, reviewed_at)
SELECT x, ((x - 1) % 199) + 2, 1,
       CASE WHEN x % 2 = 0 THEN '2025-07-01' ELSE '2025-01-01' END,
       CASE WHEN x % 2 = 0 THEN '2025-12-31' ELSE '2025-06-30' END,
       round(2.5 + ((x % 25) / 10.0), 2), 60 + (x % 40),
       CASE x % 4 WHEN 0 THEN 'Consistently delivers strong outcomes.' WHEN 1 THEN 'Shows good ownership and collaboration.' WHEN 2 THEN 'Needs deeper focus on documentation.' ELSE 'Ready for higher responsibility.' END,
       '2026-01-15'
FROM n;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 30)
INSERT INTO training_programs (training_program_id, department_id, program_code, program_name, provider, duration_hours, mode)
SELECT x, ((x - 1) % 10) + 1, 'TRN' || printf('%03d', x),
       CASE x % 4 WHEN 0 THEN 'Advanced' WHEN 1 THEN 'Applied' WHEN 2 THEN 'Foundation' ELSE 'Professional' END || ' ' ||
       CASE x % 10 WHEN 0 THEN 'SQLite' WHEN 1 THEN 'Python' WHEN 2 THEN 'Cloud Architecture' WHEN 3 THEN 'Agile Delivery' WHEN 4 THEN 'Data Analytics' WHEN 5 THEN 'Leadership' WHEN 6 THEN 'Security' WHEN 7 THEN 'Testing' WHEN 8 THEN 'Finance Controls' ELSE 'Customer Success' END,
       CASE x % 5 WHEN 0 THEN 'Infosys Springboard' WHEN 1 THEN 'NPTEL' WHEN 2 THEN 'Coursera' WHEN 3 THEN 'UpGrad' ELSE 'Internal Academy' END,
       CASE x % 6 WHEN 0 THEN 8 WHEN 1 THEN 12 WHEN 2 THEN 16 WHEN 3 THEN 24 WHEN 4 THEN 32 ELSE 40 END,
       CASE x % 3 WHEN 0 THEN 'Online' WHEN 1 THEN 'Classroom' ELSE 'Hybrid' END
FROM n;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 300)
INSERT INTO employee_training (employee_training_id, employee_id, training_program_id, enrolled_on, completed_on, status, score)
SELECT x, ((x - 1) % 200) + 1, ((x * 7 - 1) % 30) + 1,
       date('2025-01-01', '+' || (x % 300) || ' days'),
       CASE WHEN x % 4 IN (0,1) THEN date('2025-01-01', '+' || ((x % 300) + 30) || ' days') ELSE NULL END,
       CASE x % 5 WHEN 0 THEN 'Completed' WHEN 1 THEN 'Completed' WHEN 2 THEN 'In Progress' WHEN 3 THEN 'Enrolled' ELSE 'Dropped' END,
       CASE WHEN x % 4 IN (0,1) THEN 60 + (x % 39) ELSE NULL END
FROM n;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 250)
INSERT INTO assets (asset_id, office_id, asset_tag, asset_type, brand, model, serial_number, purchase_date, status)
SELECT x, ((x - 1) % 5) + 1, 'AST' || printf('%05d', x),
       CASE x % 8 WHEN 0 THEN 'Laptop' WHEN 1 THEN 'Monitor' WHEN 2 THEN 'Keyboard' WHEN 3 THEN 'Mouse' WHEN 4 THEN 'Headset' WHEN 5 THEN 'Phone' WHEN 6 THEN 'ID Card' ELSE 'Docking Station' END,
       CASE x % 8 WHEN 0 THEN 'Dell' WHEN 1 THEN 'HP' WHEN 2 THEN 'Lenovo' WHEN 3 THEN 'Apple' WHEN 4 THEN 'Samsung' WHEN 5 THEN 'Logitech' WHEN 6 THEN 'Jabra' ELSE 'OnePlus' END,
       'Model-' || printf('%04d', x), 'SN2026' || printf('%06d', x),
       date('2023-01-01', '+' || (x % 900) || ' days'),
       CASE WHEN x <= 200 THEN 'Assigned' WHEN x % 7 = 0 THEN 'Repair' ELSE 'Available' END
FROM n;

WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 200)
INSERT INTO employee_assets (employee_asset_id, employee_id, asset_id, assigned_on, returned_on, condition_on_issue, condition_on_return)
SELECT x, x, x, date('2025-01-01', '+' || (x % 300) || ' days'), NULL,
       CASE x % 3 WHEN 0 THEN 'New' WHEN 1 THEN 'Good' ELSE 'Fair' END, NULL
FROM n;

UPDATE projects
SET current_assignment_count = (
    SELECT COUNT(*)
    FROM employee_project_assignments epa
    WHERE epa.project_id = projects.project_id
      AND (epa.assigned_to IS NULL OR date(epa.assigned_to) >= date('now'))
);

CREATE VIEW vw_employee_directory AS
SELECT e.employee_id, e.employee_code, e.first_name || ' ' || e.last_name AS employee_name,
       e.email, e.phone, d.department_name, t.team_name, g.title AS designation,
       o.office_name, l.city, l.state, e.employment_status
FROM employees e
JOIN departments d ON d.department_id = e.department_id
JOIN teams t ON t.team_id = e.team_id
JOIN designations g ON g.designation_id = e.designation_id
JOIN offices o ON o.office_id = e.office_id
JOIN locations l ON l.location_id = o.location_id;

CREATE VIEW vw_employee_hierarchy AS
SELECT e.employee_id, e.employee_code, e.first_name || ' ' || e.last_name AS employee_name,
       m.employee_id AS manager_employee_id, m.employee_code AS manager_code,
       m.first_name || ' ' || m.last_name AS manager_name, em.effective_from
FROM employee_managers em
JOIN employees e ON e.employee_id = em.employee_id
JOIN employees m ON m.employee_id = em.manager_id
WHERE em.effective_to IS NULL;

CREATE VIEW vw_project_allocation_summary AS
SELECT p.project_id, p.project_code, p.project_name, c.client_name, d.department_name,
       p.status, COUNT(epa.assignment_id) AS assignment_count,
       COALESCE(SUM(epa.allocation_percent),0) AS total_allocation_percent
FROM projects p
JOIN clients c ON c.client_id = p.client_id
JOIN departments d ON d.department_id = p.department_id
LEFT JOIN employee_project_assignments epa ON epa.project_id = p.project_id
GROUP BY p.project_id, p.project_code, p.project_name, c.client_name, d.department_name, p.status;

CREATE VIEW vw_monthly_attendance_summary AS
SELECT e.employee_id, e.employee_code, e.first_name || ' ' || e.last_name AS employee_name,
       substr(a.attendance_date, 1, 7) || '-01' AS attendance_month,
       SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) AS present_days,
       SUM(CASE WHEN a.status = 'Work From Home' THEN 1 ELSE 0 END) AS wfh_days,
       SUM(CASE WHEN a.status = 'Absent' THEN 1 ELSE 0 END) AS absent_days,
       SUM(CASE WHEN a.status = 'Half Day' THEN 1 ELSE 0 END) AS half_days,
       SUM(a.total_hours) AS total_hours
FROM attendance a
JOIN employees e ON e.employee_id = a.employee_id
GROUP BY e.employee_id, e.employee_code, employee_name, substr(a.attendance_date, 1, 7);

CREATE VIEW vw_payroll_cost_by_department AS
SELECT d.department_id, d.department_name, p.payroll_month,
       COUNT(p.payroll_id) AS employees_paid,
       SUM(p.basic_salary) AS total_basic,
       SUM(p.hra + p.allowances) AS total_benefits,
       SUM(p.deductions) AS total_deductions,
       SUM(p.net_salary) AS total_net_salary
FROM payroll p
JOIN employees e ON e.employee_id = p.employee_id
JOIN departments d ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name, p.payroll_month;

CREATE TRIGGER trg_set_employee_updated_at
AFTER UPDATE ON employees
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
    UPDATE employees SET updated_at = CURRENT_TIMESTAMP WHERE employee_id = NEW.employee_id;
END;

CREATE TRIGGER trg_validate_leave_request_insert
BEFORE INSERT ON leave_requests
FOR EACH ROW
BEGIN
    SELECT CASE WHEN date(NEW.end_date) < date(NEW.start_date) THEN RAISE(ABORT, 'Leave end date cannot be earlier than start date') END;
    SELECT CASE WHEN NEW.approver_id IS NOT NULL AND NEW.approver_id = NEW.employee_id THEN RAISE(ABORT, 'Employee cannot approve their own leave request') END;
END;

CREATE TRIGGER trg_validate_leave_request_update
BEFORE UPDATE ON leave_requests
FOR EACH ROW
BEGIN
    SELECT CASE WHEN date(NEW.end_date) < date(NEW.start_date) THEN RAISE(ABORT, 'Leave end date cannot be earlier than start date') END;
    SELECT CASE WHEN NEW.approver_id IS NOT NULL AND NEW.approver_id = NEW.employee_id THEN RAISE(ABORT, 'Employee cannot approve their own leave request') END;
END;

CREATE TRIGGER trg_prevent_overlapping_asset_assignment_insert
BEFORE INSERT ON employee_assets
FOR EACH ROW
WHEN NEW.returned_on IS NULL
BEGIN
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM employee_assets ea
        WHERE ea.asset_id = NEW.asset_id
          AND ea.returned_on IS NULL
    ) THEN RAISE(ABORT, 'Asset is already assigned') END;
END;

CREATE TRIGGER trg_prevent_overlapping_asset_assignment_update
BEFORE UPDATE ON employee_assets
FOR EACH ROW
WHEN NEW.returned_on IS NULL
BEGIN
    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM employee_assets ea
        WHERE ea.asset_id = NEW.asset_id
          AND ea.employee_asset_id <> NEW.employee_asset_id
          AND ea.returned_on IS NULL
    ) THEN RAISE(ABORT, 'Asset is already assigned') END;
END;

CREATE TRIGGER trg_update_project_assignment_count_insert
AFTER INSERT ON employee_project_assignments
FOR EACH ROW
BEGIN
    UPDATE projects
    SET current_assignment_count = (
        SELECT COUNT(*) FROM employee_project_assignments
        WHERE project_id = NEW.project_id
          AND (assigned_to IS NULL OR date(assigned_to) >= date('now'))
    )
    WHERE project_id = NEW.project_id;
END;

CREATE TRIGGER trg_update_project_assignment_count_update
AFTER UPDATE ON employee_project_assignments
FOR EACH ROW
BEGIN
    UPDATE projects
    SET current_assignment_count = (
        SELECT COUNT(*) FROM employee_project_assignments
        WHERE project_id = NEW.project_id
          AND (assigned_to IS NULL OR date(assigned_to) >= date('now'))
    )
    WHERE project_id = NEW.project_id;
    UPDATE projects
    SET current_assignment_count = (
        SELECT COUNT(*) FROM employee_project_assignments
        WHERE project_id = OLD.project_id
          AND (assigned_to IS NULL OR date(assigned_to) >= date('now'))
    )
    WHERE project_id = OLD.project_id AND OLD.project_id <> NEW.project_id;
END;

CREATE TRIGGER trg_update_project_assignment_count_delete
AFTER DELETE ON employee_project_assignments
FOR EACH ROW
BEGIN
    UPDATE projects
    SET current_assignment_count = (
        SELECT COUNT(*) FROM employee_project_assignments
        WHERE project_id = OLD.project_id
          AND (assigned_to IS NULL OR date(assigned_to) >= date('now'))
    )
    WHERE project_id = OLD.project_id;
END;

CREATE TRIGGER trg_compute_attendance_hours_insert
AFTER INSERT ON attendance
FOR EACH ROW
WHEN NEW.check_in IS NOT NULL AND NEW.check_out IS NOT NULL
BEGIN
    UPDATE attendance
    SET total_hours = round((strftime('%s', NEW.check_out) - strftime('%s', NEW.check_in)) / 3600.0, 2)
    WHERE attendance_id = NEW.attendance_id;
END;

CREATE TRIGGER trg_compute_attendance_hours_update
AFTER UPDATE OF check_in, check_out, status ON attendance
FOR EACH ROW
BEGIN
    UPDATE attendance
    SET total_hours = CASE
        WHEN NEW.check_in IS NOT NULL AND NEW.check_out IS NOT NULL THEN round((strftime('%s', NEW.check_out) - strftime('%s', NEW.check_in)) / 3600.0, 2)
        WHEN NEW.status IN ('Absent','Holiday') THEN 0
        ELSE NEW.total_hours
    END
    WHERE attendance_id = NEW.attendance_id;
END;

CREATE TRIGGER trg_calculate_payroll_net_salary_insert
AFTER INSERT ON payroll
FOR EACH ROW
BEGIN
    UPDATE payroll
    SET net_salary = NEW.basic_salary + NEW.hra + NEW.allowances - NEW.deductions
    WHERE payroll_id = NEW.payroll_id;
END;

CREATE TRIGGER trg_calculate_payroll_net_salary_update
AFTER UPDATE OF basic_salary, hra, allowances, deductions ON payroll
FOR EACH ROW
BEGIN
    UPDATE payroll
    SET net_salary = NEW.basic_salary + NEW.hra + NEW.allowances - NEW.deductions
    WHERE payroll_id = NEW.payroll_id;
END;

COMMIT;
