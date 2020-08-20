require 'gtk3'

YELLOW = [0.89, 0.5,  0.0] #?
GREY  =  [0.1,0.1,0.1]
BLACK =  [0.0,0.0,0.0]

class App
  def initialize
    create_window
  end

  def create_window
    builder = Gtk::Builder.new
    builder.add_from_file('canvas_buttons.glade')
    @window = builder['fenetre']
    @drawing = builder['canvas']
    @drawing.add_events [:leave_notify_mask,
                         :button_press_mask,
                         :pointer_motion_mask,
                         :pointer_motion_hint_mask,
                         ]

    @window.show_all
    create_callbacks
  end

  def create_callbacks
    @window.signal_connect("destroy"){Gtk.main_quit}

    @drawing.signal_connect("draw") do |_,cr|
      cr.set_source_rgb *GREY
      cr.paint
    end

    @drawing.signal_connect("button-press-event") do |widget, event|
      @pressed=event
      @right_click=event.button==3
      @double_click=event.event_type==Gdk::EventType::BUTTON2_PRESS
      click="right-click" if @right_click
      double_click="double-click" if @double_click
      puts "mouse pressed #{click} #{double_click}"
		end

    @drawing.signal_connect("motion-notify-event") do |widget, event|
      puts "motion-notify-event"
			@moved=true
		end

    @drawing.signal_connect("button-release-event") do |widget, event|
			@mouse_released=true
      puts "mouse button released"
		end
    @drawing.signal_connect("key-press-event"){|widget, event| on_key_press_event(event)}
    @drawing.signal_connect("key-release-event"){|widget, event| on_key_release_event(event)}
    @drawing.signal_connect('scroll-event'){ |widget, event| scroll_event}
		@drawing.signal_connect('popup-menu'){ |widget, event| popup }
  end

  def on_key_press_event event
    keyval = event.keyval
    symbolic_key=Gdk::Keyval.to_name(keyval)
    @shift_l_pressed=(symbolic_key=="Shift_L") ? true : nil
    puts "key pressed : (#{keyval}) #{symbolic_key} @shift_l_pressed=#{@shift_l_event}"
  end

  def on_key_release_event event
    keyval = event.keyval
    symbolic_key=Gdk::Keyval.to_name(keyval)
    @shift_l_released=(symbolic_key=="Shift_L") ? true : nil
    puts "key released : (#{keyval}) #{symbolic_key} @shift_l_released=#{@shift_l_released}"
  end
end

App.new
Gtk.main
