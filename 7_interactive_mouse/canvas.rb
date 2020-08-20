require_relative 'vector'

class Canvas < Gtk::DrawingArea
  def initialize
    super()
    set_size_request(800,100)
    @shift=Vector.new(0,0)
    add_events      [:leave_notify_mask,
                     :button_press_mask,
                     :scroll_mask,
                     :button_release_mask,
                     :pointer_motion_mask,
                     :pointer_motion_hint_mask]

    signal_connect("draw") do |_,cr|
      clear(cr)
      redraw
    end

    signal_connect("button-press-event") do |widget, event|
      @pressed=event
      @right_click=event.button==3
      @double_click=event.event_type==Gdk::EventType::BUTTON2_PRESS
      click="right-click" if @right_click
      double_click="double-click" if @double_click
      puts "mouse button-press-event #{click} #{double_click}"
		end

    signal_connect("button-release-event") do |widget, event|
			puts "mouse button-release-event"
      @shift=Vector.new(event.x,event.y)
      redraw
		end

    signal_connect("motion-notify-event") do |widget, event|
      puts "motion-notify-event"
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

  def redraw
    cr = window.create_cairo_context
    cr.set_line_width(0.5)

    w = allocation.width
    h = allocation.height

    #cr.translate(w/2, h/2)
    cr.translate(@shift.x,@shift.y)

    #clear cr

    cr.set_source_rgb(0.4, 0.4, 0.4)

    cr.arc(0, 0, 120, 0, 2*Math::PI)
    cr.stroke

    for i in (1..36)
        cr.save
        cr.rotate(i*Math::PI/36)
        cr.scale(0.3, 1)
        cr.arc(0,0, 120,0, 2*Math::PI)
        cr.restore
        cr.stroke
    end
  end
end
