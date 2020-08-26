require_relative 'vector'
require_relative 'ast'

YELLOW = [0.89, 0.5,  0.0]

module Bde

  class Diagram

    def draw cr
      blocks.each{|block| block.draw(cr)}
    end

    def zoom zoom_center,factor
      blocks.each do |rec|
        rec.pos=zoom_center+(rec.pos-zoom_center)*factor
        rec.size=rec.size*factor
      end
    end

    def shift vector
      blocks.each do |rec|
        rec.pos=rec.pos+vector
      end
    end

    def zoom_fit view
      puts "zoom fit"
      if blocks.any?
        width,height=view.window.width,view.window.height
        max_x=blocks.map{|e| e.pos.x+e.size.x}.max
        min_x=blocks.map{|e| e.pos.x}.min
        max_y=blocks.map{|e| e.pos.y+e.size.y}.max
        min_y=blocks.map{|e| e.pos.y}.min
        size_x=max_x-min_x
        size_y=max_y-min_y
        ratios=[width/size_x,height/size_y]
        factor=ratios.min
        factor*=0.8
        puts "fit factor = #{factor}"
        zoom_center=Vector.new(width/2,height/2)
        zoom(zoom_center,factor)
        model_center=Vector.new(min_x+size_x/2,min_y+size_y/2)
        shift_vector=zoom_center-model_center
        shift(shift_vector)
      end
    end
  end

  class Block

    def draw cr
      cr.set_source_rgb *YELLOW
      cr.set_line_width(2)
      x=pos.x
      y=pos.y
      sx=size.x
      sy=size.y
      cr.rectangle(x,y,sx,sy)
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

  end
end
