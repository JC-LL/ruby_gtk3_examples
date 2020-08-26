require 'gtk3'

require_relative 'canvas'
require_relative 'parser'
require_relative 'events'
require_relative 'ast_serialization'
module Bde
  class Window < Gtk::Window

    def initialize args={} # I want to show it's possible to pass some args
      super()              # mandatory parenthesis ! otherwise : wrong arguments: Gtk::Window#initialize({})
      set_title 'jcll_3'
      set_default_size 900,600
      set_border_width 10
      set_window_position :center
      set_destroy_callback

      hbox = Gtk::Box.new(:horizontal, spacing=6)
      add hbox
      @canvas = Canvas.new
      hbox.pack_start(@canvas,:expand=>true,:fill=> true)
      #...instead of :
      # hbox.add canvas

      vbox   = Gtk::Box.new(:vertical,spacing=6)
      hbox.add vbox

      button = Gtk::Button.new(label:"new")
      button.signal_connect("clicked"){on_new_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

      button = Gtk::Button.new(label:"open")
      button.signal_connect("clicked"){on_open_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

      button = Gtk::Button.new(label:"zoom+")
      button.signal_connect("clicked"){on_zoom_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

      button = Gtk::Button.new(label:"zoom-")
      button.signal_connect("clicked"){on_unzoom_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

      button = Gtk::Button.new(label:"fit")
      button.signal_connect("clicked"){on_fit_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

      button = Gtk::Button.new(:label => "save")
      button.signal_connect("clicked"){on_save_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

      button = Gtk::Button.new(:label => "save as")
      button.signal_connect("clicked"){on_save_as_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

      button = Gtk::Button.new(:label => "quit")
      button.signal_connect("clicked"){on_quit_clicked(button)}
      vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)
      show_all
    end

    def on_new_clicked button
      if @filename
        puts "warn : save before leaving ?"
      end
      @canvas.fsm=Bde::StateMachine.new
      @canvas.redraw
      @filename=nil
      set_title 'new'
    end

    def on_open_clicked button
      puts '"open" button was clicked'
      dialog=Gtk::FileChooserDialog.new(
               :title => "choose",
               :parent => self,
               :action => Gtk::FileChooserAction::OPEN,
  				     :buttons => [[Gtk::Stock::OPEN, Gtk::ResponseType::ACCEPT],
  				                  [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL]])
      filter_sexp = Gtk::FileFilter.new
      filter_sexp.name = "s-expr filter"
      filter_sexp.add_pattern("*.sexp")
      filter_sexp.add_pattern("*.sxp")
      dialog.add_filter(filter_sexp)

      filter_rb = Gtk::FileFilter.new
      filter_rb.name = "ruby filter"
      filter_rb.add_pattern("*.rb")
      dialog.add_filter(filter_rb)

      dialog.show_all

      case dialog.run
      when Gtk::ResponseType::ACCEPT
        @filename = dialog.filename
        diagram=Bde::Parser.new.parse(@filename)
        @canvas.fsm.diagram=diagram
        basename=File.basename(dialog.filename,'.sexp')
        set_title diagram.name=basename
        @canvas.redraw
        dialog.destroy
      else
        dialog.destroy
      end
    end

    def on_zoom_clicked button
      click_pos =Coord.new(0,0) # dummy
      center_pos=Coord.new(@canvas.window.width/2,@canvas.window.height/2)
      puts "zoom+ from #{center_pos.inspect}"
      @canvas.fsm.update Bde::ZoomClick.new(click_pos,center_pos)
      @canvas.redraw
    end

    def on_unzoom_clicked button
      click_pos =Coord.new(0,0) # dummy
      center_pos=Coord.new(@canvas.window.width/2,@canvas.window.height/2)
      puts "zoom- from #{center_pos.inspect}"
      @canvas.fsm.update Bde::UnZoomClick.new(click_pos,center_pos)
      @canvas.redraw
    end

    def on_fit_clicked button
      puts "fit"
    end

    def on_save_clicked button
      puts '"save" button was clicked'
      if @filename
        diagram=@canvas.fsm.diagram
        sexp=diagram.to_sexp
        File.open(@filename,'w'){|f| f.puts sexp}
      else
        on_save_as_clicked button
      end
    end

    def on_save_as_clicked button
      puts '"save as" button was clicked'
      dialog=Gtk::FileChooserDialog.new(
               :title => "choose",
               :parent => self,
               :action => Gtk::FileChooserAction::SAVE,
  				     :buttons => [[Gtk::Stock::SAVE, Gtk::ResponseType::ACCEPT],
  				                  [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL]])
      filter_sexp = Gtk::FileFilter.new
      filter_sexp.name = "s-expr filter"
      filter_sexp.add_pattern("*.sexp")
      filter_sexp.add_pattern("*.sxp")
      dialog.add_filter(filter_sexp)

      dialog.show_all

      case dialog.run
      when Gtk::ResponseType::ACCEPT
        puts "filename = #{dialog.filename}"
        @filename=dialog.filename
        diagram=@canvas.fsm.diagram
        sexp=diagram.to_sexp
        File.open(@filename,'w'){|f| f.puts sexp}
        basename=File.basename(@filename,'.sexp')
        set_title diagram.name=basename
        dialog.destroy
      else
        dialog.destroy
      end
    end

    def on_quit_clicked button
      puts "Closing application"
      Gtk.main_quit
    end

    def set_destroy_callback
      signal_connect("destroy"){Gtk.main_quit}
    end
  end #class
end #module

window=Bde::Window.new
Gtk.main
