class Timetable < Crawler
  def parse
    sql = "SELECT * FROM station"
    rows = @db.execute(sql)

    rows.each do |r|
      p r
      break
    end
  end
end