-- ============================================================
-- Graph-Based Travel Planner : complete MySQL 8.0+ script
-- Run: mysql -u root -p < travel_planner.sql
-- ============================================================

DROP DATABASE IF EXISTS travel_planner;
CREATE DATABASE travel_planner CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE travel_planner;

-- ------------------------------------------------------------
-- 1. NODES : cities
-- ------------------------------------------------------------
CREATE TABLE cities (
    id    INT AUTO_INCREMENT PRIMARY KEY,
    name  VARCHAR(60)    NOT NULL UNIQUE,
    state VARCHAR(40)    NOT NULL,
    lat   DECIMAL(9,6)   NOT NULL,
    lng   DECIMAL(9,6)   NOT NULL,
    CONSTRAINT chk_lat CHECK (lat BETWEEN -90  AND 90),
    CONSTRAINT chk_lng CHECK (lng BETWEEN -180 AND 180)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 2. EDGES : routes (stored once, treated as undirected)
-- ------------------------------------------------------------
CREATE TABLE routes (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    from_city   INT           NOT NULL,
    to_city     INT           NOT NULL,
    mode        ENUM('road','rail','flight') NOT NULL DEFAULT 'road',
    distance_km DECIMAL(8,2)  NOT NULL,
    cost_inr    DECIMAL(10,2) NOT NULL,
    time_hr     DECIMAL(5,2)  NOT NULL,
    CONSTRAINT fk_route_from FOREIGN KEY (from_city) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_route_to   FOREIGN KEY (to_city)   REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT chk_no_self_loop CHECK (from_city <> to_city),
    CONSTRAINT chk_positive CHECK (distance_km > 0 AND cost_inr >= 0 AND time_hr > 0),
    UNIQUE KEY uq_route (from_city, to_city, mode),
    INDEX idx_from (from_city),
    INDEX idx_to   (to_city)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 3. Optional: saved trips (multi-stop planning history)
-- ------------------------------------------------------------
CREATE TABLE trips (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    criterion    ENUM('distance','cost','time') NOT NULL,
    total_value  DECIMAL(12,2) NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE trip_stops (
    trip_id   INT NOT NULL,
    stop_no   INT NOT NULL,
    city_id   INT NOT NULL,
    PRIMARY KEY (trip_id, stop_no),
    FOREIGN KEY (trip_id) REFERENCES trips(id)  ON DELETE CASCADE,
    FOREIGN KEY (city_id) REFERENCES cities(id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 4. SEED : cities (26th city is intentionally isolated,
--    useful for testing disconnected-graph handling)
-- ------------------------------------------------------------
INSERT INTO cities (name, state, lat, lng) VALUES
('Kolkata',       'West Bengal',    22.572600, 88.363900),
('Delhi',         'Delhi',          28.613900, 77.209000),
('Mumbai',        'Maharashtra',    19.076000, 72.877700),
('Chennai',       'Tamil Nadu',     13.082700, 80.270700),
('Bengaluru',     'Karnataka',      12.971600, 77.594600),
('Hyderabad',     'Telangana',      17.385000, 78.486700),
('Pune',          'Maharashtra',    18.520400, 73.856700),
('Ahmedabad',     'Gujarat',        23.022500, 72.571400),
('Jaipur',        'Rajasthan',      26.912400, 75.787300),
('Lucknow',       'Uttar Pradesh',  26.846700, 80.946200),
('Patna',         'Bihar',          25.594100, 85.137600),
('Bhubaneswar',   'Odisha',         20.296100, 85.824500),
('Guwahati',      'Assam',          26.144500, 91.736200),
('Varanasi',      'Uttar Pradesh',  25.317600, 82.973900),
('Agra',          'Uttar Pradesh',  27.176700, 78.008100),
('Bhopal',        'Madhya Pradesh', 23.259900, 77.412600),
('Nagpur',        'Maharashtra',    21.145800, 79.088200),
('Kochi',         'Kerala',          9.931200, 76.267300),
('Panaji',        'Goa',            15.490900, 73.827800),
('Chandigarh',    'Chandigarh',     30.733300, 76.779400),
('Amritsar',      'Punjab',         31.634000, 74.872300),
('Visakhapatnam', 'Andhra Pradesh', 17.686800, 83.218500),
('Siliguri',      'West Bengal',    26.727100, 88.395300),
('Ranchi',        'Jharkhand',      23.344100, 85.309600),
('Indore',        'Madhya Pradesh', 22.719600, 75.857700),
('Port Blair',    'Andaman & Nicobar', 11.623400, 92.726500);

-- ------------------------------------------------------------
-- 5. SEED : routes (approximate road/rail figures; cost in INR)
--    Cities referenced by name so ids never go out of sync.
-- ------------------------------------------------------------
INSERT INTO routes (from_city, to_city, mode, distance_km, cost_inr, time_hr)
SELECT a.id, b.id, r.mode, r.dist, r.cost, r.hrs
FROM (
    SELECT 'Kolkata' f, 'Bhubaneswar' t, 'road' mode, 440 dist,  700 cost,  7.5 hrs UNION ALL
    SELECT 'Kolkata','Ranchi','road',400,600,7.0 UNION ALL
    SELECT 'Kolkata','Patna','road',590,850,10.0 UNION ALL
    SELECT 'Kolkata','Siliguri','road',560,800,10.0 UNION ALL
    SELECT 'Kolkata','Visakhapatnam','road',1030,1400,17.0 UNION ALL
    SELECT 'Siliguri','Guwahati','road',460,700,9.0 UNION ALL
    SELECT 'Patna','Varanasi','road',250,400,4.5 UNION ALL
    SELECT 'Patna','Ranchi','road',330,500,6.0 UNION ALL
    SELECT 'Varanasi','Lucknow','road',300,450,5.5 UNION ALL
    SELECT 'Lucknow','Agra','road',330,500,5.0 UNION ALL
    SELECT 'Lucknow','Delhi','road',530,750,8.0 UNION ALL
    SELECT 'Agra','Delhi','road',230,350,3.5 UNION ALL
    SELECT 'Agra','Jaipur','road',240,380,4.0 UNION ALL
    SELECT 'Agra','Bhopal','road',570,780,9.0 UNION ALL
    SELECT 'Delhi','Jaipur','road',280,420,5.0 UNION ALL
    SELECT 'Delhi','Chandigarh','road',250,380,4.5 UNION ALL
    SELECT 'Delhi','Amritsar','road',450,650,7.5 UNION ALL
    SELECT 'Chandigarh','Amritsar','road',230,350,4.0 UNION ALL
    SELECT 'Jaipur','Ahmedabad','road',670,900,11.0 UNION ALL
    SELECT 'Jaipur','Bhopal','road',580,800,10.0 UNION ALL
    SELECT 'Bhopal','Indore','road',190,300,3.5 UNION ALL
    SELECT 'Bhopal','Nagpur','road',350,520,6.0 UNION ALL
    SELECT 'Indore','Ahmedabad','road',400,600,7.0 UNION ALL
    SELECT 'Indore','Mumbai','road',590,850,10.0 UNION ALL
    SELECT 'Ahmedabad','Mumbai','road',530,800,8.5 UNION ALL
    SELECT 'Mumbai','Pune','road',150,250,3.0 UNION ALL
    SELECT 'Mumbai','Panaji','road',590,850,10.0 UNION ALL
    SELECT 'Pune','Panaji','road',450,650,8.0 UNION ALL
    SELECT 'Pune','Hyderabad','road',560,800,9.0 UNION ALL
    SELECT 'Pune','Bengaluru','road',840,1100,13.0 UNION ALL
    SELECT 'Panaji','Bengaluru','road',560,800,9.5 UNION ALL
    SELECT 'Nagpur','Hyderabad','road',500,720,8.0 UNION ALL
    SELECT 'Hyderabad','Bengaluru','road',570,800,8.5 UNION ALL
    SELECT 'Hyderabad','Chennai','road',630,900,9.5 UNION ALL
    SELECT 'Hyderabad','Visakhapatnam','road',620,880,10.0 UNION ALL
    SELECT 'Bengaluru','Chennai','road',350,550,6.0 UNION ALL
    SELECT 'Bengaluru','Kochi','road',550,800,9.0 UNION ALL
    SELECT 'Chennai','Kochi','road',690,950,11.0 UNION ALL
    SELECT 'Visakhapatnam','Bhubaneswar','road',440,650,8.0 UNION ALL
    SELECT 'Visakhapatnam','Chennai','road',800,1100,13.0 UNION ALL
    -- a few flights (faster, costlier) to show multi-criteria trade-offs
    SELECT 'Kolkata','Delhi','flight',1500,4500,2.5 UNION ALL
    SELECT 'Delhi','Mumbai','flight',1150,4000,2.2 UNION ALL
    SELECT 'Mumbai','Bengaluru','flight',840,3500,1.8 UNION ALL
    SELECT 'Kolkata','Chennai','flight',1350,4200,2.3 UNION ALL
    SELECT 'Chennai','Port Blair','flight',1330,6500,2.3
) r
JOIN cities a ON a.name = r.f
JOIN cities b ON b.name = r.t;

-- ------------------------------------------------------------
-- 6. VIEW : bidirectional edge list (what your Graph loader reads)
--    Load this once into an adjacency list in Java/Python.
-- ------------------------------------------------------------
CREATE VIEW v_edges AS
SELECT r.from_city AS src, r.to_city   AS dst, r.mode, r.distance_km, r.cost_inr, r.time_hr FROM routes r
UNION ALL
SELECT r.to_city,   r.from_city,                r.mode, r.distance_km, r.cost_inr, r.time_hr FROM routes r;

CREATE VIEW v_edges_named AS
SELECT cs.name AS from_name, cd.name AS to_name, e.mode,
       e.distance_km, e.cost_inr, e.time_hr
FROM v_edges e
JOIN cities cs ON cs.id = e.src
JOIN cities cd ON cd.id = e.dst;

-- ------------------------------------------------------------
-- 7. USEFUL QUERIES
-- ------------------------------------------------------------

-- 7a. All cities (nodes) for the map
-- SELECT id, name, lat, lng FROM cities;

-- 7b. Full edge list to build the adjacency list
-- SELECT src, dst, mode, distance_km, cost_inr, time_hr FROM v_edges;

-- 7c. Neighbours of one city, cheapest first
-- SELECT to_name, mode, distance_km, cost_inr, time_hr
-- FROM v_edges_named WHERE from_name = 'Delhi' ORDER BY cost_inr;

-- 7d. Reachability (BFS in SQL) with a cycle guard.
--     Returns every city reachable from Kolkata. Port Blair is reachable
--     only via the Chennai flight; delete that route to test "unreachable".
-- WITH RECURSIVE reach (city_id, path) AS (
--     SELECT id, CAST(id AS CHAR(500)) FROM cities WHERE name = 'Kolkata'
--     UNION ALL
--     SELECT e.dst, CONCAT(r.path, ',', e.dst)
--     FROM reach r
--     JOIN v_edges e ON e.src = r.city_id
--     WHERE FIND_IN_SET(e.dst, r.path) = 0
-- )
-- SELECT DISTINCT c.name FROM reach r JOIN cities c ON c.id = r.city_id ORDER BY c.name;

-- 7e. Cities with no routes at all (isolated nodes)
-- SELECT c.name FROM cities c
-- LEFT JOIN v_edges e ON e.src = c.id
-- WHERE e.src IS NULL;

-- 7f. Cheapest direct link between two cities
-- SELECT mode, distance_km, cost_inr, time_hr FROM v_edges_named
-- WHERE from_name = 'Mumbai' AND to_name = 'Bengaluru'
-- ORDER BY cost_inr LIMIT 1;

-- 7g. Save a computed trip (your backend inserts these after running TSP/Dijkstra)
-- INSERT INTO trips (criterion, total_value) VALUES ('cost', 4350.00);
-- INSERT INTO trip_stops (trip_id, stop_no, city_id)
-- VALUES (LAST_INSERT_ID(), 1, 1), (LAST_INSERT_ID(), 2, 11), (LAST_INSERT_ID(), 3, 14);

-- 7h. Sanity checks
-- SELECT COUNT(*) AS cities FROM cities;   -- expect 26
-- SELECT COUNT(*) AS routes FROM routes;   -- expect 45
-- SELECT COUNT(*) AS directed_edges FROM v_edges;  -- expect 90