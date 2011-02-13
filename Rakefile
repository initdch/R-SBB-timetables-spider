require "scripts/crawler.rb"
require "scripts/station.rb"
require "scripts/departure.rb"
require "scripts/timetable.rb"

crawlerDBPath = Dir.pwd + "/tmp/sbb.db"

desc "Creating enviroment needed for the script"
task :setup do
  stationCacheFolder = Dir.pwd + "/tmp/cache/station"
  if ! File.directory? stationCacheFolder
    puts "Creating cache folders " + stationCacheFolder
    File.makedirs stationCacheFolder
  end
  
  if ! File.file? crawlerDBPath
    puts "Creating crawler DB " + stationCacheFolder
    db = SQLite3::Database.new crawlerDBPath
    sql = IO.read(Dir.pwd + "/resources/sql/01-schema.sql")
    sql += IO.read(Dir.pwd + "/resources/sql/02-station.sql")
    db.execute_batch(sql)
    db.close
  end
end

namespace :station do
  desc "Empty SBB stations table"
  task :empty_db do
    db = SQLite3::Database.new crawlerDBPath
    db.execute_batch IO.read(Dir.pwd + "/resources/sql/02-station.sql")
    db.close
  end

  desc "Fetches SBB stations"
  task :fetch do
    s = StationPool.new
    s.fetch
    s.close
  end
  
  desc "Remove stations outside of Switzerland"
  task :geo_clean do
    s = StationPool.new
    s.clean_geo
    s.close
  end
  
  desc "Export stations as CSV"
  task :export do
    sh 'sqlite3 -header -csv tmp/sbb.db "SELECT * FROM station" > tmp/station.csv'
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
    sh 'find tmp/cache/departure/ -name "*.html" -size -20k | xargs grep -l "Code: " | xargs rm'
  end
end

namespace :timetable do
  desc "Parse timetables"
  task :parse do
    d = Timetable.new
    d.parse
    d.close
  end
end

task :show_about do
    puts "For a list of the possible tasks please run 'rake -T'"
end

task :default => "show_about"