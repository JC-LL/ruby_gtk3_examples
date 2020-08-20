require 'gtk3'

class Window < Gtk::Window
  def initialize args={} # I want to show it's possible to pass some args
    super()              # mandatory parenthesis ! otherwise : wrong arguments: Gtk::Window#initialize({})
    set_title 'jcll1'
    set_default_size 900,600
    signal_connect "destroy" do
      Gtk.main_quit
    end
    set_window_position :center
    show_all
  end
end

window=Window.new
Gtk.main
