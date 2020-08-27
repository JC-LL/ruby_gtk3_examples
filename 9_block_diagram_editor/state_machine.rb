require_relative 'ast'

module Bde

  class StateMachine

    attr_accessor :state
    attr_accessor :border
    attr_accessor :pointed
    attr_accessor :diagram #model

    def initialize
      @zoom_factor=1
      @shift=Vector.new(0,0)
      @state=:idle
      @mouse_pos=Vector.new(0,0)
    end

    def set_model model
      @model=model
    end

    def update event
      puts " # blocks= #{@model.blocks.size}"
      puts "state : #{state}".center(40,'-')

      case state

      when :idle
        @pointed=nil
        case event
        when Motion
          if @pointed=@model.grobs.find{|grob| grob.mouse_over?(event)}
            puts "mouse over #{@pointed.name}"
            next_state=:fly_over
            if  @pointed.is_a?(Block) and @border=@pointed.mouse_on_border?(event)
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
          puts "fsm::pressed #{event} at #{@mouse_pos.to_sexp}"
          case event.symbolic_key
          when "p"
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
          puts "current size = #{@pointed.size.inspect}"
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
        when Motion
          if @pointed=@model.grobs.find{|grob| grob.mouse_over?(event)}
            puts "mouse over #{@pointed.name}"
            next_state=:fly_over
            if @border=@pointed.mouse_on_border?(event)
              puts "mouse over BORDER #{@pointed} / #{@border}"
              next_state=:fly_over_border
            end
          else
            next_state=:idle
          end
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
        end

      when :moving_block
        puts "moving block state :"
        case event
        when Motion
          puts "motion event : #{@shift.inspect}"
          @pointed.pos=event.pos-@shift
        when Release
          next_state=:idle
        end

      when :resizing_block
        case event
        when Motion
          resize_block event
        when Release
          next_state=:idle
        end

      else
        raise "unknown state #{state}"
      end
      return @state=next_state || @state
    end

    def create_block start,end_
      size=(end_-start).abs
      name="block #{@model.blocks.size}"
      Bde::Block.new(name,start,size)
    end

    def create_port pos
      name="port #{@model.ports.size}"
      size=Vector.new(30,20)
      Bde::Port.new(name,pos,size)
    end

    def resize_block event
      cursor=event.pos
  		case border
  		when :bottom_left_corner
  			@pointed.size.y=cursor.y-@pointed.pos.y
  			rect_x=@pointed.pos.x
  			dx=(rect_x-cursor.x)
  			@pointed.pos.x=cursor.x
  			@pointed.size.x+=dx if @pointed.size.x+dx > MIN_BLOCK.x

  		when :bottom_right_corner
  			@pointed.size.x=cursor.x-@pointed.pos.x if cursor.x-@pointed.pos.x > MIN_BLOCK.x
  			@pointed.size.y=cursor.y-@pointed.pos.y if cursor.y-@pointed.pos.y > MIN_BLOCK.y
  		when :top_left_corner
  			dy=(@pointed.pos.y-cursor.y)
  			@pointed.pos.y=cursor.y
  			@pointed.size.y+=dy if @pointed.size.y + dy > MIN_BLOCK.y
  			rect_x=@pointed.pos.x
  			dx=(rect_x-cursor.x)
  			@pointed.pos.x=cursor.x
  			@pointed.size.x+=dx if @pointed.size.x + dx > MIN_BLOCK.x
  		when :top_right_corner
  			@pointed.size.x=cursor.x-@pointed.pos.x if cursor.x-@pointed.pos.x > MIN_BLOCK.x
  			dy=(@pointed.pos.y-cursor.y)
  			@pointed.pos.y=cursor.y
  			@pointed.size.y+=dy if @pointed.size.y + dy > MIN_BLOCK.y
  		when :top_side
  			dy=(@pointed.pos.y-cursor.y)
  			@pointed.pos.y=cursor.y
  			@pointed.size.y+=dy if @pointed.size.y + dy > MIN_BLOCK.y
  		when :bottom_side
  			@pointed.size.y=cursor.y-@pointed.pos.y if cursor.y-@pointed.pos.y > MIN_BLOCK.y
  		when :right_side
  			@pointed.size.x=cursor.x-@pointed.pos.x if cursor.x-@pointed.pos.x > MIN_BLOCK.x
  		when :left_side
  			rect_x=@pointed.pos.x
  			dx=(rect_x-cursor.x)
  			@pointed.pos.x=cursor.x
  			@pointed.size.x+=dx if @pointed.size.x + dx > MIN_BLOCK.x
  		end
    end
  end
end
