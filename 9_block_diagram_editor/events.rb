require_relative 'coord'
module Bde
  class Event
    attr_accessor :pos
    def initialize gtk_event
      @pos=Coord.new(gtk_event.x,gtk_event.y)
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

end
