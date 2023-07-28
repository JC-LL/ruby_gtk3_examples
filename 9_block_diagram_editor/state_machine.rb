require_relative 'ast'

module Bde

  class StateMachine

    attr_accessor :state
    attr_accessor :border
    attr_accessor :pointed
    attr_accessor :diagram #model

    def initialize
      @zoom_factor=1
      @shift=Vect.new(0,0)
      @state=:idle
      @mouse_pos=Vect.new(0,0)
    end

    def set_model model
      @model=model
    end

    def update event
      puts "state : #{state}".center(40,'-')

      case state

      when :idle
        @pointed=nil
        case event
        when Motion
          if @pointed=@model.grobs.find{|grob| grob.mouse_over?(event)}
            puts "mouse over #{@pointed.id}"
            next_state=:fly_over
            if @pointed.is_a?(Block) and @border=@pointed.mouse_on_border?(event)
              puts "mouse over BORDER #{@pointed} / #{@border}"
              next_state=:fly_over_border
            end
          end
          @mouse_pos=event.pos
        when Click
          next_state=:block_creation
          @init_click=event.pos
          @model.blocks << @pointed=create_block(event.pos,event.pos)
          @init_pos=event.pos #simplifies drawing when drawing from rigth->left + bottom->up.
        when KeyPressed
          case event.symbolic_key
          when "p" #port creation
            @model.ports << create_port(@mouse_pos)
          end
        end

      when :block_creation
        case event
        when Motion
          size=event.pos-@pointed.pos
          if size.x > 0 and size.y > 0
            @pointed.size=size
          else
            @pointed.pos=event.pos
            @pointed.size=@init_pos-event.pos
          end
        when Release
          @false_block=@pointed.size.x < MIN_BLOCK.x or @pointed.size.y < MIN_BLOCK.y
          if @false_block
            puts "block too small"
            @model.blocks.pop
            @pointed=nil
          end
          next_state=:idle
        end

      when :fly_over
        case event
        when KeyPressed # wire creation
          case event.symbolic_key
          when "i" #port creation
            @pointed.ports << create_block_port(nil,:left)
          when "o" #port creation
            @pointed.ports << create_block_port(nil,:right)
          when "Shift_L"
            @model.wires << @wire=create_wire(@pointed,@mouse_pos)
            next_state=:wiring
          end
        when Motion
          if @pointed=@model.grobs.find{|grob| grob.mouse_over?(event)}
            puts "mouse over #{@pointed.id}"
            next_state=:fly_over
            if @border=@pointed.mouse_on_border?(event)
              puts "mouse over BORDER #{@pointed} / #{@border}"
              next_state=:fly_over_border
            end
          else
            next_state=:idle
          end
          @mouse_pos=event.pos
        when Click
          next_state=:moving_block
          @shift=event.pos-@pointed.pos
        end

      when :fly_over_border
        case event
        when Motion
          if @pointed=@model.grobs.find{|grob| grob.mouse_over?(event)}
            puts "mouse over #{@pointed}"
            next_state=:fly_over
            if @border=@pointed.mouse_on_border?(event)
              puts "mouse over BORDER #{@pointed} / #{@border}"
              next_state=:fly_over_border
            end
          else
            @border=nil
            next_state=:idle
          end
        when Click
          next_state=:resizing_block
        when KeyPressed # wire creation
          case event.symbolic_key
          when "Shift_L"
            @model.wires << @wire=create_wire(@mouse_pos)
            next_state=:wiring
          end
        end

      when :moving_block
        case event
        when Motion
          @pointed.move_to(event.pos-@shift)
        when Release
          next_state=:idle
        end

      when :resizing_block
        case event
        when Motion
          resize_grob @pointed,@border,event
        when Release
          next_state=:idle
        end

      when :wiring
        case event
        when Motion
          @mouse_pos=event.pos

        when KeyReleased, Release
          puts "end of wiring"
          @wire.ports << @pointed=@model.grobs.find{|grob| grob.mouse_over?(event)}
          pp @wire
          @wire=nil
          next_state=:idle
        end

      else
        raise "unknown state #{state}"
      end
      return @state=next_state || @state
    end

    def create_block start,end_
      size=(end_-start).abs
      id="B#{@model.blocks.size}"
      Bde::Block.new(id,start,size)
    end

    def create_port pos
      id="p#{@model.ports.size}"
      size=Vect.new(30,20)
      Bde::Port.new(id,pos,size)
    end

    def create_block_port pos=nil,side
      side_pos=side==:left ? 0 : @pointed.size.x
      id="bp#{@model.ports.size}"
      size=Vect.new(20,20)
      pp @pointed.ports.size
      puts nbp_side=@pointed.ports.select{|p| p.side==side}.size
      pos||=@pointed.pos+Vect.new(side_pos-size.x/2,(1+2*nbp_side)*size.y)
      port=Bde::BlockPort.new(id,pos,size)
      port.side=side
      port
    end

    def create_wire pointed,pos
      case pointed
      when Port
        source=pointed
      when Block
        raise "NIY"
      end
      id="w#{@model.wires.size}"
      Bde::Wire.new(id,ports=[source])
    end

    def resize_grob grob,border,event
      cursor=event.pos
      v=cursor-grob.get_border(border)
      case border
      when :bottom_right_corner
        shift=ZERO
        grow =v
      when :bottom_left_corner
        shift=Vect.new(v.x,0)
        grow =Vect.new(-v.x,v.y)
      when :top_right_corner
        shift=Vect.new(0,v.y)
        grow =Vect.new(v.x,-v.y)
    	when :top_left_corner
        shift=v
        grow =v*-1
    	when :top_side
        shift=Vect.new(0,v.y)
        grow =Vect.new(0,-v.y)
    	when :bottom_side
        shift=ZERO
        grow=Vect.new(0,v.y)
      when :left_side
        shift=Vect.new(v.x,0)
        grow =Vect.new(-v.x,0)
    	when :right_side
        shift=ZERO
        grow=Vect.new(v.x,0)
      end
      grob.shift(shift)
      grob.grow(grow)
    end
  end
end
