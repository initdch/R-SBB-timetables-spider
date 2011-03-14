CREATE TABLE station (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255),
    x REAL,
    y REAL,
    type VARCHAR(25)
);

CREATE TABLE timetable (
    id INTEGER PRIMARY KEY,
    station_id INTEGER,
    vehicle_id VARCHAR(255),
    departure_time VARCHAR(5),
    vehicle_type VARCHAR(255),
    vehicle_name VARCHAR(255),
    vehicle_notes TEXT
);
CREATE INDEX station_id ON timetable(station_id);
CREATE INDEX vehicle_id ON timetable(vehicle_id);
CREATE INDEX departure_time ON timetable(departure_time);
CREATE INDEX vehicle_type ON timetable(vehicle_type);
CREATE INDEX vehicle_name ON timetable(vehicle_name);

CREATE TABLE settings (
    key VARCHAR(25) PRIMARY KEY,
    value VARCHAR(255)
);

CREATE TABLE vehicle (
    vehicle_id VARCHAR(255) PRIMARY KEY,
    vehicle_type VARCHAR(255),
    vehicle_name VARCHAR(255),
    time_start VARCHAR(5),
    time_end VARCHAR(5),
    station_start INTEGER,
    station_end INTEGER
);
CREATE INDEX vehicle_type ON vehicle(vehicle_type);
CREATE INDEX time_start ON vehicle(time_start);
CREATE INDEX time_end ON vehicle(time_end);
CREATE INDEX station_start ON vehicle(station_start);
CREATE INDEX station_end ON vehicle(station_end);
