CREATE SCHEMA chicago_parking;

CREATE TABLE parking_location (
    -- Unique identifier for each parking location.
    -- This will serve as the primary key for this table and a foreign key
    -- in other related tables (e.g., ParkingDetails, ParkingRates).
    LocationID SERIAL PRIMARY KEY,

    -- Name of the parking facility (e.g., "Grant Park North Garage", "ABC Parking Lot").
    -- This is a mandatory field to identify the location by name.
    Name VARCHAR(255) NOT NULL,

    -- GPS latitude coordinate for precise location-based queries.
    -- This field is mandatory and provides the north-south position.
    Latitude DECIMAL(9, 6) NOT NULL,

    -- GPS longitude coordinate for precise location-based queries.
    -- This field is mandatory and provides the east-west position.
    Longitude DECIMAL(9, 6) NOT NULL,

    -- PostGIS geometry column for efficient spatial operations.
    -- Stores geographic points (latitude, longitude) using SRID 4326 (WGS 84),
    -- which is standard for GPS data and allows for accurate distance calculations on the Earth's surface.
    geom GEOGRAPHY(Point, 4326)
);




SELECT *
FROM cta_parknride_temp

SELECT ST_SRID(geom) FROM cta_parknride_temp LIMIT 1;

DROP TABLE IF EXISTS cta_parknride_temp;

INSERT INTO parking_location (Name, latitude, longitude, geom)
SELECT
    "longname",  -- Use the "longname" column from the temporary table for our 'Name'
    ST_Y(ST_Transform(geom, 4326)),  -- Transform geom from 26915 to 4326, then extract latitude
    ST_X(ST_Transform(geom, 4326)),  -- Transform geom from 26915 to 4326, then extract longitude
    ST_Transform(geom, 4326)::geography -- Transform geom from 26915 to 4326, then cast to geography
FROM
    cta_parknride_temp;

SELECT *
FROM parking_location;


CREATE TABLE parking_attributes (
    -- Primary key for this table.
    cta_attribute_id SERIAL PRIMARY KEY,

    -- Foreign key linking to the ParkingCoreLocation table.
    -- This establishes a one-to-one or one-to-many relationship
    -- (depending on how CTA data is structured, usually one-to-one for this context).
    locationID INTEGER NOT NULL,

    -- The CTA transit lines serving this Park & Ride location.
    -- Using TEXT for flexibility, could be TEXT[] if multiple lines are listed.
    lines TEXT,

    -- Number of parking spaces available at this specific CTA facility.
    spaces INTEGER,

    -- Indicates if the facility is ADA (Americans with Disabilities Act) accessible.
    -- Assuming 'Y' or 'N' from shapefile, converting to BOOLEAN for consistency.
    ada_accessible BOOLEAN,

    -- Add a foreign key constraint to ensure data integrity.
    -- This links CTA attributes directly to a defined parking location.
    CONSTRAINT fk_location
        FOREIGN KEY (locationID)
        REFERENCES parking_location (locationID)
        ON DELETE CASCADE -- If a core location is deleted, its CTA attributes are also deleted.
);



INSERT INTO parking_attributes (locationID, lines, spaces, ada_accessible)
SELECT
    pl.locationID,
    cta.lines,
    cta.spaces,
    CASE WHEN cta.ada = 1 THEN TRUE ELSE FALSE END AS IsADAAccessible -- Convert 'Y'/'N' to BOOLEAN
FROM
    parking_location pl
JOIN
    cta_parknride_temp cta ON pl.Name = cta.longname; -- Join on the 'longname' column
	

CREATE TABLE spots_available (
    -- Primary key for this table.
    space_id SERIAL PRIMARY KEY,

    -- Foreign key linking to the ParkingCoreLocation table.
    -- This ensures each detail record corresponds to a known parking facility.
    locationid INTEGER NOT NULL,

    -- Total number of parking spaces at this facility.
    total_spaces INTEGER NOT NULL DEFAULT 0,

    -- Current number of available parking spaces.
    -- This will be updated by triggers on the ParkingTransaction table.
    avail_spaces INTEGER NOT NULL DEFAULT 0,

    -- Add a foreign key constraint to ensure data integrity.
    CONSTRAINT fk_core_location
        FOREIGN KEY (locationid)
        REFERENCES parking_location (locationid)
        ON DELETE CASCADE, -- If a core location is deleted, its details are also deleted.

    -- Ensure AvailableSpaces does not exceed TotalSpaces and is not negative.
    CONSTRAINT chk_available_spaces CHECK (avail_spaces >= 0 AND avail_spaces <= total_spaces)
);


INSERT INTO spots_available (locationid, total_spaces, avail_spaces)
SELECT
    pl.locationid,
    cta.spaces AS total_spaces,      -- Use 'spaces' from CTA attributes as total spaces
    cta.Spaces AS avail_spaces       -- Initially, set available spaces to total spaces
FROM
    parking_location pl
JOIN
    parking_attributes cta ON pl.LocationID = cta.LocationID;


CREATE TABLE parking_transaction (
    -- Unique identifier for each parking transaction.
    transactionid SERIAL PRIMARY KEY,

    -- Foreign key linking to the ParkingCoreLocation table,
    -- indicating which parking facility this transaction occurred at.
    locationid INTEGER NOT NULL,

    -- A unique identifier for the vehicle (e.g., license plate number).
    -- This could also be a foreign key to a 'Vehicles' or 'Users' table if more detail is needed.
    vehicleid VARCHAR(50) NOT NULL,

    -- Timestamp when the vehicle entered the parking facility.
    entry_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,

    -- Timestamp when the vehicle exited the parking facility.
    -- This will be NULL initially and updated upon exit.
    exit_time TIMESTAMP WITH TIME ZONE,

    -- Optional: Cost incurred for the parking session.
    parking_cost DECIMAL(8, 2),

    -- Add a foreign key constraint to ensure data integrity.
    CONSTRAINT fk_transaction_location
        FOREIGN KEY (locationid)
        REFERENCES parking_location (locationid)
        ON DELETE RESTRICT, -- Prevent deleting a location if active transactions exist.

    -- Ensure exit_time is not before entry_time if both are present.
    CONSTRAINT chk_timestamps CHECK (exit_time IS NULL OR exit_time >= entry_time)
);


INSERT INTO parking_transaction (locationid, vehicleid, entry_time)
VALUES (
    3, -- Cumberland (LocationID 3)
    'ABC1234',
    '2025-07-24 10:00:00 -05:00' -- Example entry time (Chicago timezone offset)
);

-- Mock Transaction 2: Vehicle enters and exits (completed transaction)
INSERT INTO parking_transaction (locationid, vehicleid, entry_time, exit_time, parking_cost)
VALUES (
    4, -- Midway Airport (LocationID 4)
    'XYZ5678',
    '2025-07-24 08:30:00 -05:00',
    '2025-07-24 12:45:00 -05:00',
    15.75
);

-- Mock Transaction 3: Another vehicle enters, still parked
INSERT INTO parking_transaction (locationid, vehicleid, entry_time)
VALUES (
    3, -- Cumberland (LocationID 3) again
    'DEF9012',
    '2025-07-24 11:15:00 -05:00'
);

-- Mock Transaction 4: Vehicle enters and exits (another completed transaction)
INSERT INTO parking_transaction (locationid, vehicleid, entry_time, exit_time, parking_cost)
VALUES (
    5, -- Garfield-South Elevated (LocationID 5)
    'GHI3456',
    '2025-07-23 14:00:00 -05:00',
    '2025-07-23 18:30:00 -05:00',
    22.50
);

-- Mock Transaction 5: Vehicle enters, still parked
INSERT INTO parking_transaction (locationid, vehicleid, entry_time)
VALUES (
    4, -- Midway Airport (LocationID 4) again
    'JKL7890',
    '2025-07-24 13:00:00 -05:00'
);

CREATE EXTENSION postgis;
-- Add the geom column to ParkingCoreLocation
ALTER TABLE parking_location ADD COLUMN geom GEOGRAPHY(Point, 4326);

-- Populate the geom column from existing Latitude and Longitude
UPDATE parking_location
SET geom = ST_SetSRID(ST_MakePoint(Longitude, Latitude), 4326)::geography
WHERE geom IS NULL; -- Only update if geom is not already set

-- Create a GiST index on the geom column for efficient spatial queries
CREATE INDEX parkingcorelocation_geom_idx ON ParkingCoreLocation USING GIST (geom);


SELECT
    pcl.locationid,
    pcl.name,
    cta.lines,
    sa.total_spaces,
    sa.avail_spaces,
    ST_Distance(
        pcl.geom,
        ST_SetSRID(ST_MakePoint(-87.6298, 41.8818), 4326)::geography -- Downtown Chicago coordinates (Longitude, Latitude)
    ) AS distance_meters,
    (ST_Distance(
        pcl.geom,
        ST_SetSRID(ST_MakePoint(-87.6298, 41.8818), 4326)::geography
    ) / 1609.34) AS distance_miles -- Convert meters to miles (1 mile = 1609.34 meters)
FROM
    parking_location pcl
JOIN
    parking_attributes cta ON pcl.locationid = cta.locationid
JOIN
    spots_available sa ON cta.locationid = sa.locationid
WHERE
    -- Filter by distance: within 5 miles (convert 5 miles to meters)
    ST_DWithin(
        pcl.geom,
        ST_SetSRID(ST_MakePoint(-87.6298, 41.8818), 4326)::geography,
        5 * 1609.34 -- 5 miles converted to meters
    )
    AND sa.avail_spaces > 0 -- Filter for locations with at least one available space
ORDER BY
    distance_miles ASC; -- Order by distance, closest first


SELECT
    pcl.locationid,
    pcl.name,
    cta.lines,
    sa.total_spaces,
    sa.avail_spaces,
    (ST_Distance(
        pcl.geom,
        ST_SetSRID(ST_MakePoint(-87.6298, 41.8818), 4326)::geography
    ) / 1609.34) AS distance_miles
FROM
    ParkingCoreLocation pcl
JOIN
    ParkingCTAAttributes cta ON pcl.locationid = cta.locationid
JOIN
    spots_available sa ON cta.locationid = sa.locationid
WHERE
    ST_DWithin(
        pcl.geom,
        ST_SetSRID(ST_MakePoint(-87.6298, 41.8818), 4326)::geography,
        10 * 1609.34 -- Increased to 10 miles
    )
    AND sa.avail_spaces > 0
ORDER BY
    distance_miles ASC;

DROP TABLE IF EXISTS cta_parknride_temp;


-- Delete all data from ParkingCTAAttributes, spots_available, and ParkingCoreLocation.
-- **WARNING: This will delete all existing data in these tables.**
DELETE FROM parking_attributes;
DELETE FROM spots_available;
DELETE FROM parking_location;
DELETE FROM parking_transaction;

ALTER SEQUENCE parking_location_locationid_seq RESTART WITH 1;
ALTER SEQUENCE parking_attributes_cta_attribute_id_seq RESTART WITH 1;
ALTER SEQUENCE spots_available_space_id_seq RESTART WITH 1;


-- Insert the core location data from the temporary CTA table
-- into the ParkingCoreLocation table. The geom column is already transformed by shp2pgsql.
INSERT INTO parking_location (Name, latitude, longitude, geom)
SELECT
    "longname",  -- Use the "longname" column from the temporary table for our 'Name'
    ST_Y(geom),  -- Extract latitude directly from the correctly transformed geom
    ST_X(geom),  -- Extract longitude directly from the correctly transformed geom
    geom::geography -- Cast the geometry to geography type (ensures spherical calculations)
FROM
    cta_parknride_temp;


INSERT INTO parking_attributes (locationid, lines, spaces, ada_accessible)
SELECT
    pcl.locationid,
    cpt.lines,
    cpt.spaces,
    CASE WHEN cpt.ada = 1 THEN TRUE ELSE FALSE END AS ada_accessible
FROM
    parking_location pcl
JOIN
    cta_parknride_temp cpt ON pcl.name = cpt."longname";


INSERT INTO spots_available (locationid, total_spaces, avail_spaces)
SELECT
    pcl.locationid,
    cta.spaces AS total_spaces,
    cta.spaces AS avail_spaces
FROM
    parking_location pcl
JOIN
    parking_attributes cta ON pcl.locationid = cta.locationid;


SET timezone TO 'America/Chicago';

-- Generate 200 mock transactions
DO $$
DECLARE
    i INT := 0;
    random_location_id INT;
    random_vehicle_id VARCHAR(50);
    entry_ts TIMESTAMP WITH TIME ZONE;
    exit_ts TIMESTAMP WITH TIME ZONE;
    parking_cost_val DECIMAL(8, 2);
    -- Array of your 17 CTA station LocationIDs (1 to 17)
    cta_location_ids INT[] := ARRAY[1,2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];
BEGIN
    FOR i IN 1..200 LOOP
        -- Randomly select a location ID from your CTA stations
        random_location_id := cta_location_ids[1 + floor(random() * array_length(cta_location_ids, 1))];

        -- Generate a unique vehicle ID
        random_vehicle_id := 'VEHICLE_' || lpad(i::text, 3, '0') || '_' || md5(random()::text);

        -- Generate a random entry timestamp within the last 30 days
        entry_ts := NOW() - (random() * 30 * INTERVAL '1 day');

        -- Randomly decide if it's an exit (70% chance of exit)
        IF random() < 0.7 THEN
            -- Generate exit timestamp after entry timestamp, within 8 hours
            exit_ts := entry_ts + (random() * 8 * INTERVAL '1 hour');
            -- Calculate a mock parking cost (e.g., $3-$25)
            parking_cost_val := round((3 + random() * 22)::numeric, 2);
        ELSE
            -- Vehicle is still parked
            exit_ts := NULL;
            parking_cost_val := NULL;
        END IF;

        -- Insert the transaction
        INSERT INTO parking_transaction (locationid, vehicleid, entry_time, exit_time, parking_cost)
        VALUES (random_location_id, random_vehicle_id, entry_ts, exit_ts, parking_cost_val);
    END LOOP;

    RAISE NOTICE 'Inserted 200 mock parking transactions.';
END $$;

-- Reset timezone (optional, but good practice)
SET timezone TO DEFAULT;


SELECT
    pcl.locationid,
    pcl.name,
    cta.lines,
    sa.total_spaces,
    sa.avail_spaces,
    (ST_Distance(
        pcl.geom,
        ST_SetSRID(ST_MakePoint(-87.6298, 41.8818), 4326)::geography
    ) / 5280) AS distance_miles
FROM
    parking_location pcl
JOIN
    parking_attributes cta ON pcl.locationid = cta.locationid
JOIN
    spots_available sa ON cta.locationid = sa.locationid
WHERE
    ST_DWithin(
        pcl.geom,
        ST_SetSRID(ST_MakePoint(-87.6298, 41.8818), 4326)::geography,
        1.5 * 5280 -- Increased to 10 miles
    )
    AND sa.avail_spaces > 0
ORDER BY
    distance_miles ASC;
