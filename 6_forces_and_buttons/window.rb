require 'gtk3'

require_relative 'force_directed_graph_drawer'
require_relative 'canvas'
require_relative 'my_vector'
class Window < Gtk::Window

  def initialize args={} # I want to show it's possible to pass some args
    super()              # mandatory parenthesis ! otherwise : wrong arguments: Gtk::Window#initialize({})
    set_title 'jcll_3'
    set_default_size 900,600
    set_border_width 10
    set_window_position :center
    set_destroy_callback

    @algorithm=ForceDirectedGraphDrawer.new
    @zoom_factor=1
    @shift=MyVector.new(0,0)

    hbox = Gtk::Box.new(:horizontal, spacing=6)
    add hbox
    @canvas = Canvas.new
    hbox.pack_start(@canvas,:expand=>true,:fill=> true)
    #...instead of :
    # hbox.add canvas

    vbox   = Gtk::Box.new(:vertical,spacing=6)
    hbox.add vbox

    button = Gtk::Button.new(label:"open")
    button.signal_connect("clicked"){on_open_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(label:"random graph")
    button.signal_connect("clicked"){on_random_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    label = Gtk::Label.new("number of nodes : ")

    vbox.pack_start(label,:expand => false, :fill => false, :padding => 0)

    spinner = Gtk::SpinButton.new(1,100,1)
    spinner.value= @nb_value || 20
    spinner.signal_connect("value-changed"){on_spin_changed(spinner)}
    vbox.pack_start(spinner,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "run")
    button.signal_connect("clicked"){on_run_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "stop")
    button.signal_connect("clicked"){on_stop_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "step")
    button.signal_connect("clicked"){on_step_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "shuffle")
    button.signal_connect("clicked"){on_shuffle_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "center")
    button.signal_connect("clicked"){on_center_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "zoom+")
    button.signal_connect("clicked"){on_zoom_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "zoom-")
    button.signal_connect("clicked"){on_unzoom_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "zoom fit")
    button.signal_connect("clicked"){on_fit_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "save")
    button.signal_connect("clicked"){on_save_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => "quit")
    button.signal_connect("clicked"){on_quit_clicked(button)}
    vbox.pack_start(button,:expand => false, :fill => false, :padding => 0)
    show_all
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

    dialog.show_all

    case dialog.run
    when Gtk::ResponseType::ACCEPT
      puts "filename = #{dialog.filename}"
      #puts "uri = #{dialog.uri}"
      @graph=Graph.read_file dialog.filename
      @canvas.redraw @graph
      set_title @graph.id
      dialog.destroy
    else
      dialog.destroy
    end
  end

  def on_random_clicked button
    puts 'button "random" clicked'
    set_title "random"
    @graph=Graph.random(@nb_nodes || 20)
    @canvas.running=true
    @canvas.redraw @graph,@zoom_factor,@shift
  end

  def on_spin_changed spinbutton
    value=spinbutton.value
    puts "spin button modified #{value}"
    @nb_nodes=value.to_i
    @graph=Graph.random(value.to_i)
    @canvas.running=true
    @canvas.redraw @graph
  end

  def on_run_clicked button
    puts 'button "run" clicked'
    @canvas.running=true
    @algorithm.stop=false
    @algorithm.graph=@graph
    @algorithm.run(iter=1000){@canvas.redraw @graph,@zoom_factor,@shift}
  end

  def on_stop_clicked button
    puts 'button "stop" clicked'
    @algorithm.stop=true
  end

  def on_step_clicked button
    puts 'button "step" clicked'
    @algorithm.run(iter=1){@canvas.redraw @graph,@zoom_factor,@shift}
  end

  def on_shuffle_clicked button
    puts 'button "shuffle" clicked'
    if @graph
      @graph.shuffle
      @canvas.redraw @graph,@zoom_factor,@shift
    end
  end

  def on_center_clicked button
    puts 'button "center" clicked'
    if @graph
      compute_shift get_enclosing_rect
      @canvas.redraw @graph,@zoom_factor,@shift
    end
  end

  def on_zoom_clicked button
    puts 'button "zoom" clicked'
    if @graph
      @zoom_factor*=1.2
      @canvas.redraw @graph,@zoom_factor,@shift
    end
  end

  def on_unzoom_clicked button
    puts 'button "unzoom" clicked'
    if @graph
      @zoom_factor/=1.2
      @canvas.redraw @graph,@zoom_factor,@shift
    end
  end

  def on_fit_clicked button
    puts 'button "fit" clicked'
    if @graph
      compute_zoom_and_shift
      @canvas.redraw @graph,@zoom_factor,@shift
    end
  end

  def get_enclosing_rect
    min_x=@graph.nodes.min_by{|node| node.x}.x
    min_y=@graph.nodes.min_by{|node| node.y}.y
    max_x=@graph.nodes.max_by{|node| node.x}.x
    max_y=@graph.nodes.max_by{|node| node.y}.y
    [MyVector.new(min_x,min_y),MyVector.new(max_x,max_y)]
  end

  def compute_zoom_and_shift
    enclosing_rect=get_enclosing_rect()
    compute_zoom(enclosing_rect)
    compute_shift(enclosing_rect)
  end

  def compute_zoom enclosing_rect
    min_x=enclosing_rect.first.x
    min_y=enclosing_rect.first.y
    max_x=enclosing_rect.last.x
    max_y=enclosing_rect.last.y

    graph_size=[(max_x-min_x).abs,(max_y-min_y).abs]
    canvas_size=[@canvas.allocation.width,@canvas.allocation.height]
    ratios=[(canvas_size.first.to_f)/graph_size.first,(canvas_size.last.to_f)/graph_size.last]
    @zoom_factor=ratios.min*0.8
    puts "zoom=#{@zoom_factor}"
  end

  def compute_shift enclosing_rect
    rect_center_x=(enclosing_rect.first.x+enclosing_rect.last.x)/2.0
    rect_center_y=(enclosing_rect.first.y+enclosing_rect.last.y)/2.0
    @shift=MyVector.new(-rect_center_x,-rect_center_y)
  end

  def on_save_clicked button
    puts 'button "save" clicked'

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
      #puts "uri = #{dialog.uri}"
      @graph.id=File.basename(dialog.filename,'.sexp')
      @graph.write_file dialog.filename
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

end

window=Window.new
Gtk.main
