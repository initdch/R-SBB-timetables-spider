CREATE TABLE station (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255),
    x REAL,
    y REAL,
    status VARCHAR(255)
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
