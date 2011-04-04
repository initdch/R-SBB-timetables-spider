DELETE FROM vehicle WHERE vehicle_id IN (
    SELECT vehicle_id FROM timetable GROUP BY vehicle_id HAVING COUNT(id) < 2
);
DELETE FROM timetable WHERE id IN (
    SELECT id FROM timetable WHERE vehicle_id IN (
        SELECT vehicle_id FROM timetable GROUP BY vehicle_id HAVING COUNT(id) < 2
    )
);

