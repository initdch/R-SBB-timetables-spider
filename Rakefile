# coding: utf-8

require "./scripts/crawler.rb"
require "./scripts/station.rb"
require "./scripts/departure.rb"
require "./scripts/timetable.rb"
require "./scripts/lookup_vehicle_types.rb"
require './scripts/vehicle.rb'

crawlerDBPath = Dir.pwd + "/tmp/sbb.db"

namespace :setup do
  def create_db path
    puts "Creating crawler DB " + path

    db = SQLite3::Database.new path
    sql = IO.read(Dir.pwd + "/resources/sql/01-schema.sql")
    db.execute_batch sql
    db.close
    
    Rake::Task['station:set_bounds'].execute
  end

  desc "Creating enviroment needed for the script"
  task :init do
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
      create_db crawlerDBPath
    end
  end
  
  desc "Create DB"
  task :create_db do
    if File.file? crawlerDBPath
      puts "Do you want to overwrite " + crawlerDBPath + " ?\nyes/no"
      userYN = STDIN.gets.chomp

      if userYN == 'yes'
        FileUtils.rm crawlerDBPath
      else
        abort 'Still using the current DB'
      end
    end

    create_db crawlerDBPath
  end
  
  desc "Remove temporarely folder"
  task :clean do
    puts "The folder " + Dir.pwd + "/tmp will be deleted !\nContinue ? yes/no"
    userYN = STDIN.gets.chomp
    if userYN == 'yes'
      FileUtils.rm_rf Dir.pwd + "/tmp"
    end
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
  
  desc "Set the area bounds (optional parameter: bounds = SW, NE corners in long/lat)"
  task :set_bounds do
    # TODO - create a Bounds object to decouple the code from Rake
    if ENV['bounds'] == nil
      bounds = '5.85,45.75,10.7,47.8'
    else
      bounds = ENV['bounds']
    end
    
    db = SQLite3::Database.new crawlerDBPath
    
    sql = "DELETE FROM settings WHERE key = 'bounds'"
    db.execute sql
    sql = "INSERT INTO settings (key, value) VALUES ('bounds', ?)"
    db.execute sql, bounds
    
    s = Station.new

    if ENV['bounds'] == nil
      station = {
        'id'    => '8503000',
        'name'  => 'Zürich HB',
        'x'     => 8.540192,
        'y'     => 47.378177
      }
    else
      station = s.findStationsInArea(bounds)
    end
    
    sql = "DELETE FROM station"
    db.execute sql
    
    s.insertStation(station)

    db.close
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
    p 'Removing files ... please rerun departure:fetch task if any files are shown '
    sh 'find tmp/cache/departure/ -name "*.html" -size -30k | xargs grep -l "Code: "'
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

namespace :vehicle do
  desc 'Create vehicles from timetables'
  task :insert do
    db = SQLite3::Database.new crawlerDBPath
    db.execute_batch IO.read(Dir.pwd + '/resources/sql/04-vehicle-insert.sql')
    db.close
  end
  
  desc 'Build vehicles'
  task :build do
    v = Vehicle.new
    v.build
    v.close
  end
  
  desc 'Reset vehicles and arrivals'
  task :reset do
    db = SQLite3::Database.new crawlerDBPath
    db.execute_batch IO.read(Dir.pwd + '/resources/sql/04-vehicle-empty.sql')
    db.close
  end
  
  desc 'Remove one-stopper vehicles'
  task :remove_onestopper do
    db = SQLite3::Database.new crawlerDBPath
    db.execute_batch IO.read(Dir.pwd + '/resources/sql/04-vehicle-remove-onestopper.sql')
    db.close
  end
  
  desc 'Detect vehicles with duplicate stations'
  task :check_duplicate_stations do
    v = Vehicle.new
    v.check_duplicate_stations
    v.close
  end
end

task :show_about do
    puts "For a list of the possible tasks please run 'rake -T'"
end

task :default => "show_about"