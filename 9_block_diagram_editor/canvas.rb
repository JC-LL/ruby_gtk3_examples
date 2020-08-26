require_relative 'events'
require_relative 'state_machine'
require_relative 'ast_graphics'

class Canvas < Gtk::DrawingArea

  attr_accessor :fsm
  attr_accessor :zoom_factor
  def initialize
    super()
    set_size_request(800,100)
    create_callbacks
    @fsm=Bde::StateMachine.new
    @zoom_factor=1
  end

  def width
    window.width
  end

  def height
    window.height
  end

  def create_callbacks
    add_events      [:leave_notify_mask,
                     :button_press_mask,
                     :scroll_mask,
                     :button_release_mask,
                     :pointer_motion_mask,
                     :pointer_motion_hint_mask]

    signal_connect("draw") do |_,cr|
      puts "canvas : #{width}x#{height}"
      clear(cr)
      redraw
    end

    signal_connect("button-press-event") do |widget, event|
      bde_event=Bde::Click.new(event)
      @pressed=event

      @right_click=event.button==3
      bde_event=Bde::RightClick.new(event) if @right_click

      @double_click=event.event_type==Gdk::EventType::BUTTON2_PRESS
      bde_event=Bde::DoubleClick.new(event) if @double_click
      @fsm.update(bde_event)
      redraw
		end

    signal_connect("button-release-event") do |widget, event|
      pp bde_event=Bde::Release.new(event)
      @fsm.update(bde_event)
      redraw
		end

    signal_connect("motion-notify-event") do |widget, event|
      bde_event=Bde::Motion.new(event)
      state=@fsm.update(bde_event)

      change_cursor() if state.to_s.match(/over/) or state==:idle
      redraw
		end

    signal_connect('scroll-event') do |widget, event|
      puts "scroll event"
    end

    signal_connect('popup-menu') do  |widget, event|
      puts "popup"
    end

    signal_connect 'key-press-event' do |widget,event|
      puts "key press #{event}"
    end

    signal_connect("key-release-event") do |widget, event|
      puts "key release #{event}"
    end
  end

  def clear cr
    cr.set_source_rgb(0.1, 0.1, 0.1)
    cr.paint
  end

  def draw_current
    cr = window.create_cairo_context
    if grob=@fsm.pointed
      grob.draw(cr)
    end
  end

  def redraw
    cr = window.create_cairo_context
    clear cr
    @fsm.diagram.draw(cr)
  end

  def change_cursor()
    if @fsm.pointed
      case @fsm.border
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
