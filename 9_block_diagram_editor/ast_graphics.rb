require_relative 'vector'
require_relative 'ast'

YELLOW = [0.89, 0.5,  0.0]

module Bde

  class Diagram

    def draw cr
      grobs.each{|e| e.draw(cr)}
    end

    def zoom zoom_center,factor
      grobs.each do |e|
        e.pos=zoom_center+(e.pos-zoom_center)*factor
        e.size=e.size*factor
      end
    end

    def shift vector
      grobs.each do |e|
        e.pos=e.pos+vector
      end
    end

    def zoom_fit view
      if grobs.any?
        width,height=view.window.width,view.window.height
        max_x=grobs.map{|e| e.pos.x+e.size.x}.max
        min_x=grobs.map{|e| e.pos.x}.min
        max_y=grobs.map{|e| e.pos.y+e.size.y}.max
        min_y=grobs.map{|e| e.pos.y}.min
        size_x=max_x-min_x
        size_y=max_y-min_y
        ratios=[width/size_x,height/size_y]
        factor=ratios.min
        factor*=0.8
        zoom_center=Vector.new(width/2,height/2)
        zoom(zoom_center,factor)
        model_center=Vector.new(min_x+size_x/2,min_y+size_y/2)
        shift_vector=zoom_center-model_center
        shift(shift_vector)
      end
    end
  end

  class Grob #GraphicalObject

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

  class Block < Grob
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
  end


  class Port < Grob
    def draw cr
      cr.set_source_rgb *YELLOW
      cr.set_line_width(2)
      x=pos.x
      y=pos.y
      sx=size.x
      sy=size.y
      points=[]
      points << Vector.new(x,y)
      points << Vector.new(x+sx*2/3,y)
      points << Vector.new(x+sx    ,y+0.5*sy)
      points << Vector.new(x+sx*2/3,y+sy)
      points << Vector.new(x,y+sy)
      cr.move_to *(start=points.shift).to_a
      points.each do |point|
        cr.line_to *point.to_a
      end
      cr.line_to *start.to_a
      cr.stroke
    end
  end

  class Wire < Grob
    def draw cr
      cr.set_source_rgb *YELLOW
      cr.set_line_width(2)
      cr.move_to *points.first.to_a
      points[1..-1].each do |point|
        cr.line_to *point.to_a
      end
      cr.stroke
    end

    def mouse_over?(event)
      false
    end
  end
end
