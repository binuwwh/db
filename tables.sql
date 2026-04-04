
CREATE TABLE room (
    id_room SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL CHECK (type IN ('VIP', 'Hall', 'Open')),
    address VARCHAR(200) NOT NULL,
    area INT NOT NULL CHECK (area > 0),
    name VARCHAR(100) NOT NULL
);

CREATE TABLE employee (
    id_employee SERIAL PRIMARY KEY,
    passport_number VARCHAR(50) UNIQUE NOT NULL,
    iin VARCHAR(20) UNIQUE NOT NULL,
    fio VARCHAR(150) NOT NULL,

    birth_date DATE NOT NULL CHECK (birth_date < CURRENT_DATE),

    gender VARCHAR(20) NOT NULL CHECK (gender IN ('M', 'F')),

    phone VARCHAR(30),

    login VARCHAR(50) NOT NULL,
    password VARCHAR(100) NOT NULL,

    hire_date DATE NOT NULL CHECK (hire_date <= CURRENT_DATE),

    dismissal_date DATE,

    CHECK (
        dismissal_date IS NULL 
        OR dismissal_date > hire_date
    )
);

CREATE TABLE position (
    id_position SERIAL PRIMARY KEY,
    position_name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE history_position (
    id_employee INT NOT NULL,
    id_position INT NOT NULL,

    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,

    PRIMARY KEY (id_employee, id_position, start_date),

    FOREIGN KEY (id_employee) REFERENCES employee(id_employee),
    FOREIGN KEY (id_position) REFERENCES position(id_position),

    CHECK (end_date IS NULL OR end_date > start_date)
);

CREATE TABLE service_price (
    id_service SERIAL PRIMARY KEY,
    service_name VARCHAR(150) UNIQUE NOT NULL,
    description VARCHAR(200),
    cost DECIMAL(10,2) NOT NULL CHECK (cost > 0)
);

CREATE TABLE celebrity (
    id_celebrity SERIAL PRIMARY KEY,
    stage_name VARCHAR(150) UNIQUE NOT NULL,
    fee DECIMAL(10,2) CHECK (fee > 0),
    contacts VARCHAR(200),
    performance_profile VARCHAR(200)
);

CREATE TABLE client (
    id_client SERIAL PRIMARY KEY,
    passport_number VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    organization_name VARCHAR(150),
    address VARCHAR(200),
    fio VARCHAR(150) NOT NULL
);

CREATE TABLE contract (
    id_contract SERIAL PRIMARY KEY,
    id_client INT NOT NULL,

    contract_number VARCHAR(50) UNIQUE NOT NULL,
    contract_type VARCHAR(50) NOT NULL CHECK (contract_type IN ('std', 'premium')),

    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),

    conclusion_date DATE NOT NULL,
    termination_date DATE,

    FOREIGN KEY (id_client) REFERENCES client(id_client),

    CHECK (
        termination_date IS NULL 
        OR termination_date > conclusion_date
    )
);

CREATE TABLE event (
    id_event SERIAL PRIMARY KEY,
    id_contract INT NOT NULL,
    id_room INT NOT NULL,
    id_employee INT NOT NULL,

    name VARCHAR(150) NOT NULL,
    description VARCHAR(250),

    event_date DATE NOT NULL CHECK (event_date >= CURRENT_DATE),

    FOREIGN KEY (id_contract) REFERENCES contract(id_contract),
    FOREIGN KEY (id_room) REFERENCES room(id_room),
    FOREIGN KEY (id_employee) REFERENCES employee(id_employee)
);

CREATE TABLE selected_services (
    id_event INT NOT NULL,
    id_service INT NOT NULL,

    quantity INT NOT NULL CHECK (quantity > 0),

    PRIMARY KEY (id_event, id_service),

    FOREIGN KEY (id_event) REFERENCES event(id_event),
    FOREIGN KEY (id_service) REFERENCES service_price(id_service)
);

CREATE TABLE payment_document (
    id_payment SERIAL PRIMARY KEY,
    id_contract INT NOT NULL,

    document_number VARCHAR(50) UNIQUE NOT NULL,
    type VARCHAR(50) NOT NULL,

    payment_date DATE NOT NULL,
    FOREIGN KEY (id_contract) REFERENCES contract(id_contract)
);

CREATE TABLE performance (
    id_celebrity INT NOT NULL,
    id_contract INT NOT NULL,

    PRIMARY KEY (id_celebrity, id_contract),

    FOREIGN KEY (id_celebrity) REFERENCES celebrity(id_celebrity),
    FOREIGN KEY (id_contract) REFERENCES contract(id_contract)
);