require 'gtk3'

class Window < Gtk::Window
  def initialize args={} # I want to show it's possible to pass some args
    super()              # mandatory parenthesis ! otherwise : wrong arguments: Gtk::Window#initialize({})
    set_title 'jcll_2'
    set_default_size 900,600
    set_destroy_callback
    mb = Gtk::MenuBar.new

    filemenu = Gtk::Menu.new
    file_item = Gtk::MenuItem.new :label=> "File"
    file_item.set_submenu filemenu

    filemenu.append load = Gtk::MenuItem.new(:label => "Load")
    load.signal_connect "activate" do
      on_load
    end

    filemenu.append save = Gtk::MenuItem.new(:label => "save")
    save.signal_connect "activate" do
      on_save
    end

    filemenu.append exit = Gtk::MenuItem.new(:label => "Exit")
    exit.signal_connect "activate" do
        Gtk.main_quit
    end

    mb.append file_item

    add vbox = Gtk::Box.new(:vertical, 2)

    vbox.pack_start mb, :expand => false, :fill => false, :padding => 0

    set_default_size 800, 600
    set_window_position :center
    show_all
  end

  def set_destroy_callback
    signal_connect("destroy"){Gtk.main_quit}
  end

  def on_load
    dialog=Gtk::FileChooserDialog.new(
             :title => "choose",
             :parent => self,
             :action => Gtk::FileChooserAction::OPEN,
				     :buttons => [[Gtk::Stock::OPEN, Gtk::ResponseType::ACCEPT],
				                  [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL]])
    dialog.show_all
    case dialog.run
    when Gtk::ResponseType::ACCEPT
      puts "LOAD filename = #{dialog.filename}"
      #puts "uri = #{dialog.uri}"
      dialog.destroy
    else
      dialog.destroy
    end
  end

  def on_save
    dialog=Gtk::FileChooserDialog.new(
             :title => "save",
             :parent => self,
             :action => Gtk::FileChooserAction::SAVE,
				     :buttons => [[Gtk::Stock::OPEN, Gtk::ResponseType::ACCEPT],
				                  [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL]])
    dialog.show_all
    case dialog.run
    when Gtk::ResponseType::ACCEPT
      puts "SAVE filename = #{dialog.filename}"
      #puts "uri = #{dialog.uri}"
      dialog.destroy
    else
      dialog.destroy
    end
  end


end

window=Window.new
Gtk.main
