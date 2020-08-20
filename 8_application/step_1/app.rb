require 'gtk3'

class ExampleAppWindow < Gtk::ApplicationWindow
  def open(file)
  end
end

class ExampleApp < Gtk::Application
  def initialize
    super("org.gtk.jcll_app", :flags_none)

    signal_connect "startup" do |application|
      puts "startup signal"
    end

    signal_connect "shutdown" do |application|
      puts "shutdown signal"
    end

    # activate : shows the default first window of the application
    signal_connect "activate" do |application|
      puts "activate signal"
      window = ExampleAppWindow.new(application)
      window.set_title 'app'
      window.present
    end

  end
end

app = ExampleApp.new

puts app.run
