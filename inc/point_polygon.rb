require "csv"

class Polygon
  def initialize
    @vertices = []
  end

  def load_from_file(file)
    CSV.foreach(file) do |row|
      p = {"x" => row[0].to_f, "y" => row[1].to_f}
      @vertices.push(p)
    end
  end

  def contains_point?(point)
    px = point['x']
    py = point['y']
    
    inPolygon = false
    i = 0
    j = @vertices.length - 1
    @vertices.each do |v|
      v1x = v['x']
      v1y = v['y']
      v2x = @vertices[j]['x']
      v2y = @vertices[j]['y']
      
      if (((v1y > py) != (v2y > py)) && (px < (v2x - v1x) * (py - v1y) / (v2y - v1y) + v1x))
        inPolygon = ! inPolygon
      end
      
      j = i
      i = i + 1
    end
    
    return inPolygon
  end
end