-- SALESTORM logical SQL schema
CREATE TABLE customer (
    customer_id BIGINT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE product (
    product_id BIGINT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(12,2) NOT NULL,
    sale_id BIGINT,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE inventory (
    inventory_id BIGINT PRIMARY KEY,
    product_id BIGINT NOT NULL UNIQUE,
    available_quantity INT NOT NULL CHECK (available_quantity >= 0),
    reserved_quantity INT NOT NULL CHECK (reserved_quantity >= 0),
    sold_quantity INT NOT NULL CHECK (sold_quantity >= 0),
    version BIGINT NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    FOREIGN KEY (product_id) REFERENCES product(product_id)
);

CREATE TABLE inventory_reservation (
    reservation_id VARCHAR(64) PRIMARY KEY,
    product_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status VARCHAR(32) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (product_id) REFERENCES product(product_id),
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
);

CREATE TABLE orders (
    order_id VARCHAR(64) PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    reservation_id VARCHAR(64) NOT NULL UNIQUE,
    status VARCHAR(32) NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE payment (
    payment_id VARCHAR(64) PRIMARY KEY,
    order_id VARCHAR(64) NOT NULL UNIQUE,
    provider_reference VARCHAR(128) UNIQUE,
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    status VARCHAR(32) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE outbox_event (
    event_id VARCHAR(64) PRIMARY KEY,
    aggregate_id VARCHAR(64) NOT NULL,
    event_type VARCHAR(128) NOT NULL,
    payload TEXT NOT NULL,
    published BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_reservation_expiry ON inventory_reservation(status, expires_at);
CREATE INDEX idx_outbox_unpublished ON outbox_event(published, created_at);
CREATE INDEX idx_order_customer ON orders(customer_id);
CREATE INDEX idx_payment_status ON payment(status);

-- Critical atomic reservation operation:
UPDATE inventory
SET available_quantity = available_quantity - :qty,
    reserved_quantity = reserved_quantity + :qty,
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE product_id = :product_id
  AND available_quantity >= :qty;
