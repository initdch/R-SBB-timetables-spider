require "rubygems"

require "sqlite3"
require "nokogiri"
require "open-uri"
require "htmlentities"

class Crawler
  def initialize
    # TODO: db path - global scope ?
    @db = SQLite3::Database.open(Dir.pwd + "/tmp/sbb.db")
    @db.results_as_hash = true
  end
  
  def close
    @db.close
  end
end