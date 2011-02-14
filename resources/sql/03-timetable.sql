DELETE FROM timetable;
UPDATE station SET status = NULL WHERE status = 'timetable_done';
VACUUM;