require 'gtk3'

require_relative 'canvas'
require_relative 'parser'
require_relative 'model_builder'
require_relative 'events'
require_relative 'ast_serialization'

$counter=0

module Bde
  class Window < Gtk::Window

    def initialize args={} # I want to show it's possible to pass some args
      super()              # mandatory parenthesis ! otherwise : wrong arguments: Gtk::Window#initialize({})
      set_title 'block diagram editor'
      set_default_size 900,600
      set_border_width 10
      set_window_position :center
      set_destroy_callback

      init_mvc

      hbox = Gtk::Box.new(:horizontal, spacing=6)
      add hbox

      hbox.pack_start(@view,:expand=>true,:fill=> true)
      #...instead of :
      # hbox.add canvas


      # I cannot manage to "see" key press event, from DrawingArea itself.
      # I understand I need to "capture" this event at the window level and
      # propagate the action in the DrawingArea (aka "view" heure),
      # where I think it should reside.
      signal_connect("key-press-event"){|w,e| on_key_press(w,e)}

      signal_connect("key-release-event"){|w,e| on_key_release(w,e)}

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

    def init_mvc
      @model      = Bde::Diagram.new(nil,[])
      @controler  = Bde::StateMachine.new
      @view       = Bde::Canvas.new
      @view.set_model      @model
      @view.set_controler  @controler
      @controler.set_model @model
      @filename=nil
    end

    def on_new_clicked button
      if @model.blocks.any?
        puts "warn : save before leaving ?"
      end
      @model = Bde::Diagram.new(nil,[])
      @view.set_model      @model
      @controler.set_model @model
      @view.redraw
      set_title 'new'
    end

    def on_open_clicked button
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

      dialog.show_all

      case dialog.run
      when Gtk::ResponseType::ACCEPT
        @filename = dialog.filename
        ast=Bde::Parser.new.parse(@filename)
        @model=Bde::ModelBuilder.new.build_from(ast)
        @view.set_model      @model
        @controler.set_model @model
        basename=File.basename(dialog.filename,'.sexp')
        set_title @model.name=basename
        @view.redraw
        dialog.destroy
      else
        dialog.destroy
      end
    end

    def on_zoom_clicked button
      zoom_position=Vect.new(@view.window.width/2,@view.window.height/2)
      zoom_factor=1.2
      @model.zoom zoom_position,zoom_factor
      @view.redraw
    end

    def on_unzoom_clicked button
      zoom_position=Vect.new(@view.window.width/2,@view.window.height/2)
      zoom_factor=0.8
      @model.zoom zoom_position,zoom_factor
      @view.redraw
    end

    def on_fit_clicked button
      @model.zoom_fit @view
      @view.redraw
    end

    def on_save_clicked button
      if @filename
        sexp=@model.to_sexp
        File.open(@filename,'w'){|f| f.puts sexp}
      else
        on_save_as_clicked button
      end
    end

    def on_save_as_clicked button
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
        sexp=@model.to_sexp
        File.open(@filename,'w'){|f| f.puts sexp}
        basename=File.basename(@filename,'.sexp')
        set_title @model.name=basename
        dialog.destroy
      else
        dialog.destroy
      end
    end

    def on_quit_clicked button
      Gtk.main_quit
    end

    def on_key_press widget,event
      @view.on_key_press(widget,event)
    end

    def on_key_release widget,event
      @view.on_key_release(widget,event)
    end

    def set_destroy_callback
      signal_connect("destroy"){Gtk.main_quit}
    end
  end #class
end #module

window=Bde::Window.new
Gtk.main
