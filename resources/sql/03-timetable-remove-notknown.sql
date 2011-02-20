DELETE FROM timetable WHERE id IN (
    SELECT timetable.id 
        FROM timetable 
        LEFT JOIN station ON timetable.station_id = station.id 
        WHERE station.id IS NULL
);