require 'gtk3'
require_relative 'open_array'

window=Gtk::Window.new
window.set_title 'test'
window.show_all

Gtk.main
