require "./scripts/crawler.rb"
require "./scripts/station.rb"
require "./scripts/departure.rb"
require "./scripts/timetable.rb"
require "./scripts/lookup_vehicle_types.rb"

crawlerDBPath = Dir.pwd + "/tmp/sbb.db"

desc "Creating enviroment needed for the script"
task :setup do
  cacheFolder = Dir.pwd + "/tmp/cache/station"
  if ! File.directory? cacheFolder
    puts "Creating cache folder " + cacheFolder
    FileUtils.mkdir_p cacheFolder
  end
  
  cacheFolder = Dir.pwd + "/tmp/cache/departure"
  if ! File.directory? cacheFolder
    puts "Creating cache folder " + cacheFolder
    FileUtils.mkdir_p cacheFolder
  end
  
  if ! File.file? crawlerDBPath
    puts "Creating crawler DB " + crawlerDBPath
    db = SQLite3::Database.new crawlerDBPath
    sql = IO.read(Dir.pwd + "/resources/sql/01-schema.sql")
    sql += IO.read(Dir.pwd + "/resources/sql/02-station.sql")
    db.execute_batch(sql)
    db.close
  end
end

namespace :db do
  desc "Optimizes db file"
  task :vacuum do
    db = SQLite3::Database.new crawlerDBPath
    db.execute('VACUUM')
    db.close
  end
end

namespace :station do
  desc "Empty SBB stations table"
  task :empty_table do
    db = SQLite3::Database.new crawlerDBPath
    db.execute_batch IO.read(Dir.pwd + "/resources/sql/02-station.sql")
    db.close
  end

  desc "Fetches SBB stations"
  task :fetch do
    s = Station.new
    s.fetch
    s.close
  end
  
  desc "Remove stations outside of Switzerland"
  task :geo_clean do
    s = Station.new
    s.clean_geo
    s.close
  end
  
  desc "Export stations as CSV"
  task :export do
    sh 'sqlite3 -header -csv tmp/sbb.db "SELECT * FROM station" > tmp/station.csv'
  end
  
  desc "Guess the type from timetables"
  task :parse_type do
    s = Station.new
    s.parse_type
    s.close
  end
end

namespace :departure do
  desc "Fetches departures"
  task :fetch do
    d = Departure.new
    d.fetch
    d.close
  end
  
  desc "Removed files cached files containing errors"
  task :files_clean do
    sh 'find tmp/cache/departure/ -name "*.html" -size -30k | xargs grep -l "Code: " | xargs rm'
  end
end

namespace :timetable do
  desc "Parse timetables"
  task :parse do
    t = Timetable.new
    t.parse
    t.close
  end
  
  desc "Empty timetables table"
  task :empty_table do
    db = SQLite3::Database.new crawlerDBPath
    db.execute_batch IO.read(Dir.pwd + "/resources/sql/03-timetable.sql")
    db.close
  end
  
  desc "Remove duplicates from the timetables"
  task :remove_duplicates do
    t = Timetable.new
    t.remove_duplicates
    t.close
  end
  
  desc "Remove stops of the not-known stations"
  task :remove_notknown_stations do
    db = SQLite3::Database.new crawlerDBPath
    db.execute_batch IO.read(Dir.pwd + "/resources/sql/03-timetable-remove-notknown.sql")
    db.close
  end
end

task :show_about do
    puts "For a list of the possible tasks please run 'rake -T'"
end

task :default => "show_about"