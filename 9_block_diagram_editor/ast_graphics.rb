require_relative 'coord'
require_relative 'ast'
YELLOW = [0.89, 0.5,  0.0]
module Bde

  class Diagram
    def apply_zoom factor,center
      puts "applying zoom factor=#{factor} center=#{center}"
      blocks.each{|block| block.apply_zoom(factor,center)}
    end

    def draw cr
      blocks.each{|grob| grob.draw(cr)}
    end
  end

  class Block

    def apply_zoom factor,center
      puts "before zoom (x#{factor}): #{pos.inspect} #{size.inspect}"
      pos.x-=center.x
      pos.y-=center.y
      pos.x*=factor
      pos.y*=factor
      size.x*=factor
      size.y*=factor
      puts "after zoom : #{pos.inspect} #{size.inspect}"
    end

    def draw cr
      cr.set_source_rgb *YELLOW
      cr.set_line_width(2)
      x=pos.x
      y=pos.y
      sx=size.x
      sy=size.y
      cr.rectangle(x,y,sx,sy)
      #cr.fill
      cr.stroke
    end

    def mouse_over?(event)
      (event.pos.x > pos.x and event.pos.x < pos.x+size.x) and
      (event.pos.y > pos.y and event.pos.y < pos.y+size.y)
    end

    def mouse_on_border?(event)
      x,y=event.pos.x,event.pos.y
      west =(x-pos.x)              < BORDER.x
      east =(x-(pos.x+size.x)).abs < BORDER.x
      north=(y-pos.y)              < BORDER.y
      south=(y-(pos.y+size.y)).abs < BORDER.y
      west or east or north or south
      if west
				if north
					return :top_left_corner
				elsif south
					return :bottom_left_corner
				else
					return :left_side
				end
			elsif east
				if north
					return :top_right_corner
				elsif south
					return :bottom_right_corner
				else
					return :right_side
				end
			end
			if north
				return :top_side
			elsif south
				return :bottom_side
			end
      nil
    end

    def shift vector
      @pos=@pos+vector
    end
  end
end
