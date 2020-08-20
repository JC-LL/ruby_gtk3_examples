require 'gtk3'

def not_yet_implemented(object)
  puts "#{object.class.name} sent a signal!"
end

def on_main_window_destroy(object)
  Gtk.main_quit()
end

def on_key_pressed object
  puts "pressed"
end

def on_key_released object
  puts "released"
end

main_window_res = 'canvas_buttons.glade'

builder = Gtk::Builder.new
builder.add_from_file(main_window_res)

# Attach signals handlers
builder.connect_signals do |handler|
  begin
    method(handler)
  rescue
    puts "#{handler} not yet implemented!"
    method('not_yet_implemented')
  end
end

main_window = builder.get_object('fenetre')
main_window.show_all()

Gtk.main
