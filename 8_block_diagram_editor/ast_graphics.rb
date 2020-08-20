require_relative 'coord'
require_relative 'ast'

module Bde
  class Block

    def draw cr
      cr.set_source_rgb(0.6, 0.6, 0.6)
      cr.set_line_width(2)
      cr.rectangle(pos.x,pos.y,size.x,size.y)
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
