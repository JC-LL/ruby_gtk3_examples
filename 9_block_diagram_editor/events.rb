require_relative 'vect'

module Bde
  class Event
    attr_accessor :pos
    def initialize gtk_event=nil
      @pos=Vect.new(gtk_event.x,gtk_event.y) if gtk_event
    end

    def inspect
      "(#{self.class.to_s.split("::").last.downcase} #{@pos.inspect})"
    end
  end

  class Motion < Event
  end

  class Click < Event
  end

  class Release  < Event
  end

  class RightClick < Event
  end

  class DoubleClick < Event
  end

  class ZoomClick < Event
    attr_accessor :click_pos,:center_pos
    def initialize click_pos,center_pos
      super(click_pos)
      @center_pos=center_pos
    end
  end

  class UnZoomClick < Event
    attr_accessor :click_pos,:center_pos
    def initialize click_pos,center_pos
      super(click_pos)
      @center_pos=center_pos
    end
  end

  class KeyPressed < Event
    attr_accessor :symbolic_key,:shift_l
    def initialize symbolic_key,shift_l=false
      super()
      @symbolic_key=symbolic_key
      @shift_l=shift_l
    end

    def inspect
      "keypressed key=#{symbolic_key} shift_l?=#{shift_l}"
    end
  end

  class KeyReleased < Event
    attr_accessor :symbolic_key,:shift_l
    def initialize symbolic_key,shift_l=false
      super()
      @symbolic_key=symbolic_key
      @shift_l=shift_l
    end

    def inspect
      "keyreleased key=#{symbolic_key} shift_l?=#{shift_l}"
    end
  end

end
