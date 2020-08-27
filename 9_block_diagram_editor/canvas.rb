require_relative 'events'
require_relative 'state_machine'
require_relative 'ast_graphics'

module Bde

  class Canvas < Gtk::DrawingArea

    def initialize
      super()
      set_size_request(800,100)
      create_callbacks
    end


    def create_callbacks
      add_events      [:leave_notify_mask,
                       :button_release_mask,
                       :button_press_mask,
                       :scroll_mask,
                       :key_press_mask,
                       :pointer_motion_mask,
                       :pointer_motion_hint_mask,
                      ]

      signal_connect("draw") do |_,cr|
        redraw
      end

      signal_connect("size-allocate") do |_,cr|
        @model.zoom_fit self
        redraw
      end

      signal_connect("button-press-event") do |widget, event|
        bde_event=Bde::Click.new(event)
        @pressed=event

        @right_click=event.button==3
        bde_event=Bde::RightClick.new(event) if @right_click

        @double_click=event.event_type==Gdk::EventType::BUTTON2_PRESS
        bde_event=Bde::DoubleClick.new(event) if @double_click
        @controler.update(bde_event)
        redraw
  		end

      signal_connect("button-release-event") do |widget, event|
        bde_event=Bde::Release.new(event)
        @controler.update(bde_event)
        redraw
  		end

      signal_connect("motion-notify-event") do |widget, event|
        bde_event=Bde::Motion.new(event)
        state=@controler.update(bde_event)

        change_cursor() if state.to_s.match(/over/) or state==:idle
        redraw
  		end

      signal_connect('scroll-event') do |widget, event|
        puts "scroll event"
      end

      signal_connect('popup-menu') do  |widget, event|
        puts "popup"
      end

    end

    def set_model model
      @model=model
    end

    def set_controler controler
      @controler=controler
    end

    def pos event
      [event.x,event.y]
    end

    def clear cr
      cr.set_source_rgb(0.1, 0.1, 0.1)
      cr.paint
    end

    def redraw
      if window
        cr = window.create_cairo_context
        clear cr
        @model.draw(cr)
      end
    end

    def on_key_press widget,event
      keyval = event.keyval
      symbolic_key=Gdk::Keyval.to_name(keyval)
      @shift_l_pressed=(symbolic_key=="Shift_L") ? true : nil
      puts "key pressed : (#{keyval}) #{symbolic_key} @shift_l_pressed=#{@shift_l_pressed}"
      bde_event=Bde::KeyPressed.new(symbolic_key,@shift_l_pressed)
      @controler.update(bde_event)
      redraw
    end

    def on_key_release widget,event
      keyval = event.keyval
      symbolic_key=Gdk::Keyval.to_name(keyval)
      @shift_l_released=(symbolic_key=="Shift_L") ? true : nil
      puts "key released : (#{keyval}) #{symbolic_key} @shift_l_released=#{@shift_l_released}"
      bde_event=Bde::KeyReleased.new(symbolic_key,@shift_l_pressed)
      @controler.update(bde_event)
      redraw
    end

    def change_cursor()
      if @controler.pointed
        case @controler.border
        when :bottom_left_corner
          cursor=Gdk::CursorType::BOTTOM_LEFT_CORNER
        when :bottom_right_corner
          cursor=Gdk::CursorType::BOTTOM_RIGHT_CORNER
        when :top_left_corner
          cursor=Gdk::CursorType::TOP_LEFT_CORNER
        when :top_right_corner
          cursor=Gdk::CursorType::TOP_RIGHT_CORNER
        when :bottom_side
          cursor=Gdk::CursorType::BOTTOM_SIDE
        when :right_side
          cursor=Gdk::CursorType::RIGHT_SIDE
        when :left_side
          cursor=Gdk::CursorType::LEFT_SIDE
        when :top_side
          cursor=Gdk::CursorType::TOP_SIDE
        else
          cursor=Gdk::CursorType::HAND1 #HAND2
        end
      else
        cursor=Gdk::CursorType::ARROW
      end
      window.set_cursor(Gdk::Cursor.new(cursor))
    end

    def default_cursor
      cursor=Gdk::CursorType::ARROW
      window.set_cursor(Gdk::Cursor.new(cursor))
    end
  end
end
