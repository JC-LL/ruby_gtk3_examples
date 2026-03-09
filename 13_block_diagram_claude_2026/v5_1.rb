# frozen_string_literal: false
# =============================================================================
# block_diagram_editor.rb  —  Éditeur de schémas-blocs
# Dépendance : gem 'gtk3'  (ruby-gnome)
#   gem install gtk3
# Lancement : ruby block_diagram_editor.rb [fichier.sxd]
#
# Fichier de types de ports  : port_types.json (même dossier, ou ~/.config/bde/)
# Fichier de coloration syntaxique : syntax.json  (même dossier, ou ~/.config/bde/)
# =============================================================================

require 'gtk3'
require 'gtksourceview4'
require 'json'
require 'tmpdir'
require 'fileutils'

# =============================================================================
# TYPES DE PORTS  — chargement depuis JSON
# =============================================================================

module PortTypes
  DEFAULT_TYPES = [
    { 'name' => 'float',   'color' => '#5599ff' },
    { 'name' => 'integer', 'color' => '#88cc44' },
    { 'name' => 'boolean', 'color' => '#ffaa33' },
    { 'name' => 'string',  'color' => '#cc88ff' },
    { 'name' => 'any',     'color' => '#aaaaaa' }
  ].freeze

  @types = DEFAULT_TYPES.dup

  def self.load_from_file(path = nil)
    candidates = [
      path,
      File.join(File.dirname(__FILE__), 'port_types.json'),
      File.expand_path('~/.config/bde/port_types.json')
    ].compact
    candidates.each do |f|
      next unless f && File.exist?(f)
      data = JSON.parse(File.read(f))
      @types = data['types'] if data['types'].is_a?(Array)
      return f
    end
    nil
  end

  def self.types = @types
  def self.names = @types.map { |t| t['name'] }

  def self.color_for(type_name)
    t = @types.find { |x| x['name'] == type_name.to_s }
    t ? t['color'] : '#aaaaaa'
  end

  def self.hex_to_rgb(hex)
    hex = hex.to_s.gsub('#', '')
    return [0.67, 0.67, 0.67] if hex.length != 6
    [hex[0,2].to_i(16) / 255.0,
     hex[2,2].to_i(16) / 255.0,
     hex[4,2].to_i(16) / 255.0]
  end
end

# =============================================================================
# MODÈLE DE DONNÉES
# =============================================================================

Port = Struct.new(:id, :name, :direction, :port_type, :block_id, keyword_init: true) do
  def input?  = direction == :in
  def output? = direction == :out
  def type_color_rgb = PortTypes.hex_to_rgb(PortTypes.color_for(port_type))
end

Connection = Struct.new(:from_port_id, :to_port_id, keyword_init: true)

class Block
  attr_accessor :id, :name, :x, :y, :width, :height, :ports, :is_diagram_port, :code, :language

  def initialize(id:, name:, x: 100, y: 100, is_diagram_port: false)
    @id = id; @name = name
    @x = x.to_f; @y = y.to_f
    @width = 140; @height = 80
    @ports = []; @is_diagram_port = is_diagram_port
    @code = +''
    @language = ''
  end

  def in_ports  = @ports.select(&:input?)
  def out_ports = @ports.select(&:output?)

  def resize_to_fit
    max_p = [in_ports.size, out_ports.size].max
    @height = [80, 30 + max_p * 24].max
    max_in  = in_ports.map  { |p| p.name.length }.max || 0
    max_out = out_ports.map { |p| p.name.length }.max || 0
    @width  = [140, name.length * 9 + 30, (max_in + max_out) * 7 + 50].max
  end

  def port_position(port)
    list    = port.input? ? in_ports : out_ports
    idx     = list.index(port) || 0
    spacing = @height.to_f / (list.size + 1)
    py      = @y + spacing * (idx + 1)
    px      = port.input? ? @x : @x + @width
    [px, py]
  end

  def hit_test(mx, my)
    mx.between?(@x, @x + @width) && my.between?(@y, @y + @height)
  end

  def port_at(mx, my, thr = 10)
    @ports.find { |p| px, py = port_position(p); (mx-px).abs <= thr && (my-py).abs <= thr }
  end
end

class DiagramModel
  attr_accessor :name, :blocks, :connections
  @@id_counter = 0

  def initialize(name: 'Nouveau diagramme')
    @name = name; @blocks = []; @connections = []
  end

  def self.next_id(prefix = 'id')
    @@id_counter += 1
    "#{prefix}_#{@@id_counter}"
  end

  def add_block(name: 'Bloc', x: 100, y: 100)
    b = Block.new(id: DiagramModel.next_id('b'), name: name, x: x, y: y)
    @blocks << b; b
  end

  def add_diagram_port(name: 'port', direction: :in, x: 50, y: 50)
    b = Block.new(id: DiagramModel.next_id('dp'), name: name, x: x, y: y, is_diagram_port: true)
    b.width = 110; b.height = 44
    inner = (direction == :in) ? :out : :in
    b.ports << Port.new(id: DiagramModel.next_id('p'), name: name,
                        direction: inner, port_type: 'any', block_id: b.id)
    @blocks << b; b
  end

  def remove_block(block)
    ids = block.ports.map(&:id)
    @connections.reject! { |c| ids.include?(c.from_port_id) || ids.include?(c.to_port_id) }
    @blocks.delete(block)
  end

  def add_port_to_block(block, name: 'p', direction: :in, port_type: 'any')
    p = Port.new(id: DiagramModel.next_id('p'), name: name,
                 direction: direction, port_type: port_type, block_id: block.id)
    block.ports << p; block.resize_to_fit; p
  end

  def remove_port(port)
    @connections.reject! { |c| c.from_port_id == port.id || c.to_port_id == port.id }
    b = block_of(port); b&.ports&.delete(port); b&.resize_to_fit
  end

  def connect(fp, tp)
    return if fp.nil? || tp.nil? || fp.id == tp.id
    return if connection_exists?(fp.id, tp.id)
    src, dst = if fp.output? && tp.input?   then [fp, tp]
               elsif fp.input? && tp.output? then [tp, fp]
               else return end
    @connections << Connection.new(from_port_id: src.id, to_port_id: dst.id)
  end

  def disconnect(fid, tid)
    @connections.reject! { |c| c.from_port_id == fid && c.to_port_id == tid }
  end

  def connection_exists?(fid, tid)
    @connections.any? { |c| c.from_port_id == fid && c.to_port_id == tid }
  end

  def find_port(id)
    @blocks.each { |b| b.ports.each { |p| return p if p.id == id } }; nil
  end

  def block_of(port)
    @blocks.find { |b| b.ports.include?(port) }
  end
end

# =============================================================================
# SÉRIALISATION S-EXPRESSIONS
# =============================================================================

module SexpSerializer
  def self.dump(model)
    out = ["(diagram\n  (meta (name #{q model.name}))\n  (blocks"]
    model.blocks.each { |b| out << dump_block(b) }
    out << "  )\n  (connections"
    model.connections.each do |c|
      out << "    (connection (from #{q c.from_port_id}) (to #{q c.to_port_id}))"
    end
    out << "  )\n)"
    out.join("\n")
  end

  def self.dump_block(b)
    flag = b.is_diagram_port ? ' (diagram_port true)' : ''
    s  = "    (block (id #{q b.id}) (name #{q b.name}) "
    s += "(x #{b.x.round}) (y #{b.y.round}) (w #{b.width}) (h #{b.height})#{flag}\n"
    s += "      (ports\n"
    b.ports.each do |p|
      s += "        (port (id #{q p.id}) (name #{q p.name}) "
      s += "(direction #{p.direction}) (type #{q p.port_type.to_s}))\n"
    end
    s += "      )\n"
    unless b.code.nil? || b.code.strip.empty?
      encoded = b.code.gsub('\\', '\\\\\\\\').gsub('"', '\\"').gsub("\n", "\\n").gsub("\r", '')
      s += "      (code \"#{encoded}\")\n"
    end
    s += "      (language #{SexpSerializer.q(b.language.to_s)})\n" unless b.language.to_s.empty?
    s + "    )"
  end

  def self.q(str)
    "\"#{str.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\""
  end

  def self.load(text)
    build_model(parse_expr(tokenize(text)))
  end

  def self.tokenize(text)
    toks = []; i = 0
    while i < text.length
      c = text[i]
      if    c =~ /\s/  then i += 1
      elsif c == '('   then toks << :lp; i += 1
      elsif c == ')'   then toks << :rp; i += 1
      elsif c == '"'
        j = i + 1; s = +''
        while j < text.length
          if text[j] == '\\' && j+1 < text.length && text[j+1] == '"'
            s << '"'; j += 2
          elsif text[j] == '"'
            j += 1; break
          else
            s << text[j]; j += 1
          end
        end
        toks << s; i = j
      else
        j = i; j += 1 while j < text.length && text[j] !~ /[\s()"]/
        toks << text[i...j]; i = j
      end
    end
    toks
  end

  def self.parse_expr(toks)
    tok = toks.shift
    return tok unless tok == :lp
    list = []
    list << parse_expr(toks) until toks.first == :rp
    toks.shift; list
  end

  def self.fc(list, key)
    list.each { |i| return i if i.is_a?(Array) && i.first == key.to_s }; nil
  end

  def self.v(list, key)
    c = fc(list, key); c ? c[1] : nil
  end

  def self.build_model(tree)
    model = DiagramModel.new
    meta  = fc(tree, 'meta')
    model.name = v(meta, 'name') if meta

    bn = fc(tree, 'blocks')
    if bn
      bn[1..].each do |bnode|
        next unless bnode.is_a?(Array) && bnode.first == 'block'
        b = Block.new(id:              v(bnode,'id')   || DiagramModel.next_id('b'),
                      name:            v(bnode,'name') || 'Bloc',
                      x:               (v(bnode,'x') || 100).to_f,
                      y:               (v(bnode,'y') || 100).to_f,
                      is_diagram_port: v(bnode,'diagram_port') == 'true')
        b.width  = (v(bnode,'w') || 140).to_i
        b.height = (v(bnode,'h') || 80).to_i
        pn = fc(bnode, 'ports')
        if pn
          pn[1..].each do |pnode|
            next unless pnode.is_a?(Array) && pnode.first == 'port'
            b.ports << Port.new(id:        v(pnode,'id')        || DiagramModel.next_id('p'),
                                name:      v(pnode,'name')      || 'p',
                                direction: (v(pnode,'direction') || 'in').to_sym,
                                port_type: v(pnode,'type')      || 'any',
                                block_id:  b.id)
          end
        end
        raw_code = v(bnode, 'code')
        b.code     = raw_code ? raw_code.gsub("\\n", "\n").gsub("\\\\", "\\") : +''
        b.language = v(bnode, 'language').to_s
        model.blocks << b
      end
    end

    cn = fc(tree, 'connections')
    if cn
      cn[1..].each do |cnode|
        next unless cnode.is_a?(Array) && cnode.first == 'connection'
        model.connections << Connection.new(from_port_id: v(cnode,'from'), to_port_id: v(cnode,'to'))
      end
    end
    model
  end
end

# =============================================================================
# COLORATION SYNTAXIQUE — GtkSourceView + fallback syntax.json
# =============================================================================

module SyntaxHighlighter
  # Retourne la liste triée de tous les langages disponibles dans GtkSourceView,
  # y compris ceux installés par l'utilisateur dans ~/.local/share/gtksourceview-4/
  def self.available_languages
    mgr = GtkSource::LanguageManager.default
    ids = mgr.respond_to?(:language_ids) ? mgr.language_ids : mgr.ids
    ids.sort
  rescue
    []
  end

  # Retourne un GtkSource::Language pour l'identifiant donné.
  def self.language_for_id(lang_id)
    return nil if lang_id.to_s.strip.empty?
    mgr = GtkSource::LanguageManager.default
    id  = lang_id.to_s.downcase
    if mgr.respond_to?(:get_language)
      mgr.get_language(id)
    elsif mgr.respond_to?(:[])
      mgr[id]
    end
  end

  # Retourne un StyleScheme sombre, avec fallbacks successifs.
  def self.dark_scheme
    mgr = GtkSource::StyleSchemeManager.default
    getter = mgr.respond_to?(:get_scheme) ? :get_scheme : :[]
    %w[oblivion solarized-dark monokai cobalt classic].each do |name|
      s = mgr.public_send(getter, name)
      return s if s
    end
    nil
  end

  def self.known_languages = available_languages
end

# =============================================================================
# ÉDITEUR DE CODE PAR BLOC  —  GtkSourceView
# =============================================================================

class CodeEditorDialog < Gtk::Dialog
  def initialize(parent, block)
    super(title: "Code — #{block.name}", parent: parent, flags: :destroy_with_parent)
    set_default_size(760, 560)
    add_button('Annuler',   Gtk::ResponseType::CANCEL)
    add_button('Appliquer', Gtk::ResponseType::APPLY)
    add_button('OK',        Gtk::ResponseType::OK)
    self.default_response = Gtk::ResponseType::OK

    @block = block
    build_content
    show_all
  end

  def edited_code     = @source_buffer.text
  def edited_language = @lang_combo.active_text.to_s.strip

  private

  def build_content
    vbox = Gtk::Box.new(:vertical, 0)

    # ---- Barre d'info + sélecteur de langage ----
    top = Gtk::Box.new(:horizontal, 8)
    top.margin_start = 8; top.margin_end = 8
    top.margin_top = 6;   top.margin_bottom = 4

    info = Gtk::Label.new
    ins  = @block.in_ports.map(&:name).join(', ').then  { |s| s.empty? ? '—' : s }
    outs = @block.out_ports.map(&:name).join(', ').then { |s| s.empty? ? '—' : s }
    info.markup = "<small><b>#{@block.name}</b>   IN: #{ins}   OUT: #{outs}</small>"
    info.xalign = 0.0
    top.pack_start(info, expand: true, fill: true, padding: 0)

    # Combo langage : langages connus + "(custom syntax.json)" + "(aucun)"
    top.pack_start(Gtk::Label.new('Langage :'), expand: false, fill: false, padding: 0)
    @lang_combo = Gtk::ComboBoxText.new
    @lang_combo.append_text('(aucun)')
    SyntaxHighlighter.known_languages.each { |l| @lang_combo.append_text(l) }

    current = @block.language.to_s.strip
    idx = if current.empty? || current == '(aucun)'
            0
          else
            pos = SyntaxHighlighter.known_languages.index(current)
            pos ? pos + 1 : 0
          end
    @lang_combo.active = idx
    @lang_combo.tooltip_text = "Langages custom : utilisez syntax_to_lang.rb --install"
    top.pack_start(@lang_combo, expand: false, fill: false, padding: 0)

    vbox.pack_start(top, expand: false, fill: false, padding: 0)
    vbox.pack_start(Gtk::Separator.new(:horizontal), expand: false, fill: false, padding: 0)

    # ---- GtkSource::Buffer + View ----
    @source_buffer = GtkSource::Buffer.new
    @source_buffer.text = @block.code || ''

    apply_language(@block.language.to_s)

    @source_view = GtkSource::View.new
    @source_view.buffer = @source_buffer
    @source_view.show_line_numbers        = true
    @source_view.highlight_current_line   = true
    @source_view.auto_indent              = true
    @source_view.indent_on_tab            = true
    @source_view.tab_width                = 4
    @source_view.insert_spaces_instead_of_tabs = false
    @source_view.smart_backspace          = true

    font_desc = Pango::FontDescription.new
    font_desc.family = 'Monospace'
    font_desc.size   = 11 * Pango::SCALE
    @source_view.override_font(font_desc)

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    sw.add(@source_view)
    vbox.pack_start(sw, expand: true, fill: true, padding: 0)

    # ---- Barre de statut ----
    @status_lbl = Gtk::Label.new
    @status_lbl.xalign = 0.0
    @status_lbl.margin_start = 8
    vbox.pack_start(@status_lbl, expand: false, fill: false, padding: 2)

    child.pack_start(vbox, expand: true, fill: true, padding: 0)

    # Changement de langage dans le combo
    @lang_combo.signal_connect('changed') { apply_language(@lang_combo.active_text.to_s) }

    # Mise à jour barre de statut
    @source_buffer.signal_connect('mark-set') { update_status }
    @source_buffer.signal_connect('changed')  { update_status }
    update_status
  end

  def apply_language(lang_id)
    scheme = SyntaxHighlighter.dark_scheme
    @source_buffer.style_scheme = scheme if scheme

    case lang_id.to_s.strip
    when '', '(aucun)'
      @source_buffer.language = nil
      @source_buffer.highlight_syntax = false
    else
      lang = SyntaxHighlighter.language_for_id(lang_id)
      if lang
        @source_buffer.language = lang
        @source_buffer.highlight_syntax = true
      else
        warn "Langage inconnu : '#{lang_id}'. Utilisez syntax_to_lang.rb --install pour l'enregistrer."
        @source_buffer.language = nil
        @source_buffer.highlight_syntax = false
      end
    end
  rescue => e
    warn "apply_language(#{lang_id.inspect}): #{e.message}"
  end

  def update_status
    iter  = @source_buffer.get_iter_at(mark: @source_buffer.get_mark('insert'))
    line  = iter.line + 1
    col   = iter.line_offset + 1
    lines = @source_buffer.line_count
    @status_lbl.markup = "<small>Ligne #{line} / #{lines}  —  Col #{col}</small>"
  end
end

# =============================================================================
# DIALOGUES
# =============================================================================

class BlockDialog < Gtk::Dialog
  attr_reader :block_name

  def initialize(parent, block)
    super(title: block.is_diagram_port ? 'Port du diagramme' : 'Éditer le bloc',
          parent: parent, flags: :destroy_with_parent)
    add_button('Annuler', Gtk::ResponseType::CANCEL)
    add_button('OK',      Gtk::ResponseType::OK)
    self.default_response = Gtk::ResponseType::OK

    grid = Gtk::Grid.new
    grid.column_spacing = 10; grid.row_spacing = 8
    grid.margin_start = 14; grid.margin_end = 14
    grid.margin_top = 14;   grid.margin_bottom = 14

    grid.attach(Gtk::Label.new('Nom :'), 0, 0, 1, 1)
    @name_entry = Gtk::Entry.new
    @name_entry.text = block.name
    @name_entry.activates_default = true
    @name_entry.width_chars = 28
    grid.attach(@name_entry, 1, 0, 1, 1)

    child.pack_start(grid, expand: true, fill: true, padding: 0)
    show_all
  end

  def block_name = @name_entry.text
end

class PortsDialog < Gtk::Dialog
  def initialize(parent, block, model)
    super(title: "Ports de « #{block.name} »", parent: parent, flags: :destroy_with_parent)
    set_default_size(540, 400)
    add_button('Fermer', Gtk::ResponseType::CLOSE)

    @block = block; @model = model

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin_start = 10; vbox.margin_end = 10
    vbox.margin_top = 10;   vbox.margin_bottom = 10

    # ---- Liste ----
    # Colonnes : 0=id(caché), 1=nom, 2=direction, 3=type
    @store = Gtk::ListStore.new(String, String, String, String)
    @tv    = Gtk::TreeView.new(@store)
    @tv.headers_visible = true

    [ ['Nom', 1], ['Direction', 2], ['Type', 3] ].each do |title, ci|
      rend = Gtk::CellRendererText.new
      rend.editable = (ci != 2)   # direction non éditable en place
      rend.signal_connect('edited') do |_r, path_str, new_text|
        iter = @store.get_iter(path_str)
        next unless iter
        port_id = iter[0]
        port    = @block.ports.find { |p| p.id == port_id }
        next unless port
        case ci
        when 1 then port.name      = new_text.strip unless new_text.strip.empty?
        when 3 then port.port_type = new_text.strip
        end
        iter[ci] = new_text.strip
        @block.resize_to_fit
      end
      col = Gtk::TreeViewColumn.new(title, rend, text: ci)
      col.min_width = (ci == 3 ? 160 : 100)
      @tv.append_column(col)
    end

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    sw.add(@tv)
    sw.set_size_request(-1, 190)
    vbox.pack_start(sw, expand: true, fill: true, padding: 0)

    # ---- Formulaire ajout ----
    frame = Gtk::Frame.new('Ajouter un port')
    grid  = Gtk::Grid.new
    grid.column_spacing = 8; grid.row_spacing = 6
    grid.margin_start = 8; grid.margin_end = 8
    grid.margin_top = 8;   grid.margin_bottom = 8

    grid.attach(Gtk::Label.new('Nom :'), 0, 0, 1, 1)
    @port_name = Gtk::Entry.new
    @port_name.placeholder_text = 'nom_port'
    @port_name.width_chars = 12
    grid.attach(@port_name, 1, 0, 1, 1)

    grid.attach(Gtk::Label.new('Direction :'), 2, 0, 1, 1)
    @dir_combo = Gtk::ComboBoxText.new
    ['in','out'].each { |d| @dir_combo.append_text(d) }
    @dir_combo.active = 0
    grid.attach(@dir_combo, 3, 0, 1, 1)

    grid.attach(Gtk::Label.new('Type :'), 0, 1, 1, 1)
    # ComboBox avec entrée libre
    @type_combo = Gtk::ComboBoxText.new(has_entry: true)
    PortTypes.names.each { |n| @type_combo.append_text(n) }
    default_idx = PortTypes.names.index('any') || 0
    @type_combo.active = default_idx
    @type_combo.set_size_request(180, -1)
    grid.attach(@type_combo, 1, 1, 3, 1)

    add_btn = Gtk::Button.new(label: '＋ Ajouter')
    add_btn.margin_start = 6
    grid.attach(add_btn, 4, 0, 1, 2)

    frame.add(grid)
    vbox.pack_start(frame, expand: false, fill: false, padding: 0)

    del_btn = Gtk::Button.new(label: '− Supprimer le port sélectionné')
    vbox.pack_start(del_btn, expand: false, fill: false, padding: 0)

    child.pack_start(vbox, expand: true, fill: true, padding: 0)

    add_btn.signal_connect('clicked') { on_add }
    del_btn.signal_connect('clicked') { on_delete }
    @port_name.signal_connect('activate') { on_add }

    refresh_list
    show_all
  end

  def refresh_list
    @store.clear
    @block.ports.each do |p|
      iter = @store.append
      iter[0] = p.id; iter[1] = p.name
      iter[2] = p.direction.to_s; iter[3] = p.port_type.to_s
    end
  end

  private

  def type_entry_text
    entry = @type_combo.child
    text  = entry.is_a?(Gtk::Entry) ? entry.text.strip : ''
    text.empty? ? (@type_combo.active_text || 'any') : text
  end

  def on_add
    name = @port_name.text.strip
    return if name.empty?
    dir  = @dir_combo.active_text.to_sym
    type = type_entry_text
    @model.add_port_to_block(@block, name: name, direction: dir, port_type: type)
    @port_name.text = ''
    refresh_list
  end

  def on_delete
    sel = @tv.selection.selected
    return unless sel
    port = @block.ports.find { |p| p.id == sel[0] }
    @model.remove_port(port) if port
    refresh_list
  end
end

class ConnectionsDialog < Gtk::Dialog
  def initialize(parent, model)
    super(title: 'Connexions du diagramme', parent: parent, flags: :destroy_with_parent)
    set_default_size(560, 340)
    add_button('Fermer', Gtk::ResponseType::CLOSE)

    @model = model

    vbox = Gtk::Box.new(:vertical, 6)
    vbox.margin_start = 10; vbox.margin_end = 10
    vbox.margin_top = 10;   vbox.margin_bottom = 10

    # 0:from_id, 1:from_lbl, 2:type, 3:to_id, 4:to_lbl
    @store = Gtk::ListStore.new(String, String, String, String, String)
    tv = Gtk::TreeView.new(@store)
    [['Source (bloc.port)', 1], ['Type', 2], ['Destination (bloc.port)', 4]].each do |t, ci|
      col = Gtk::TreeViewColumn.new(t, Gtk::CellRendererText.new, text: ci)
      col.min_width = (ci == 2 ? 80 : 200)
      tv.append_column(col)
    end
    @tv = tv

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    sw.add(tv)
    vbox.pack_start(sw, expand: true, fill: true, padding: 0)

    del = Gtk::Button.new(label: '− Supprimer la connexion sélectionnée')
    del.signal_connect('clicked') { on_delete }
    vbox.pack_start(del, expand: false, fill: false, padding: 4)

    child.pack_start(vbox, expand: true, fill: true, padding: 0)
    refresh_list; show_all
  end

  def refresh_list
    @store.clear
    @model.connections.each do |c|
      fp = @model.find_port(c.from_port_id)
      tp = @model.find_port(c.to_port_id)
      iter = @store.append
      iter[0] = c.from_port_id
      iter[1] = fp ? "#{@model.block_of(fp)&.name}.#{fp.name}" : c.from_port_id
      iter[2] = fp ? fp.port_type.to_s : ''
      iter[3] = c.to_port_id
      iter[4] = tp ? "#{@model.block_of(tp)&.name}.#{tp.name}" : c.to_port_id
    end
  end

  private

  def on_delete
    sel = @tv.selection.selected; return unless sel
    @model.disconnect(sel[0], sel[3])
    refresh_list
  end
end

class HelpDialog < Gtk::Dialog
  def initialize(parent)
    super(title: 'Aide — Éditeur de schémas-blocs', parent: parent, flags: :destroy_with_parent)
    set_default_size(500, 460)
    add_button('Fermer', Gtk::ResponseType::CLOSE)

    vbox = Gtk::Box.new(:vertical, 0)
    vbox.margin_start = 16; vbox.margin_end = 16
    vbox.margin_top = 12;   vbox.margin_bottom = 12

    title_lbl = Gtk::Label.new
    title_lbl.markup = '<b><big>Éditeur de schémas-blocs</big></b>  v1.1'
    title_lbl.margin_bottom = 12
    vbox.pack_start(title_lbl, expand: false, fill: false, padding: 0)

    text = <<~HELP
      <b>Navigation &amp; zoom</b>
        • Molette souris               Zoom avant / arrière (centré sur le curseur)
        • Touches  +  /  −             Zoom avant / arrière
        • Touche  0                    Réinitialiser zoom et position

      <b>Déplacement de la vue (pan)</b>
        • Bouton milieu + glisser      Déplacer la vue
        • Alt + clic gauche + glisser  Déplacer la vue (alternative)

      <b>Création</b>
        • Clic droit (canvas vide)     Nouveau bloc, port IN/OUT du diagramme
        • Clic droit (sur un bloc)     Renommer, gérer les ports, supprimer

      <b>Déplacement des blocs</b>
        • Clic gauche + glisser        Déplacer un bloc

      <b>Éditeur de code</b>
        • Double-clic sur un bloc      Ouvrir l'éditeur de code du bloc
        • Clic droit → "Éditer le code…"   Idem
        Le code est sauvegardé dans le fichier .sxd avec le bloc.
        La coloration syntaxique est configurable dans <tt>syntax.json</tt>.

      <b>Connexions</b>
        • Clic sur port OUT            Démarrer un câblage
        • Clic sur port IN             Terminer la connexion
        • Clic dans le vide / Échap    Annuler le câblage en cours
        • Menu Édition → Connexions    Lister et supprimer des connexions

      <b>Suppression</b>
        • Touche Suppr / Backspace     Supprimer le bloc sélectionné

      <b>Types de ports</b>
        Chargés depuis <tt>port_types.json</tt> (même dossier ou <tt>~/.config/bde/</tt>).
        Saisie libre également possible. La couleur du fil = type du port source.

      <b>Format de fichier (.sxd)</b>
        S-expressions texte, lisibles et traitables par d'autres outils.
    HELP

    lbl = Gtk::Label.new
    lbl.markup = text
    lbl.wrap   = true
    lbl.xalign = 0.0
    lbl.yalign = 0.0

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:never, :automatic)
    sw.add(lbl)

    child.pack_start(vbox, expand: false, fill: false, padding: 0)
    child.pack_start(sw,   expand: true,  fill: true,  padding: 0)
    show_all
  end
end

# =============================================================================
# CANVAS DE DESSIN  —  zoom molette, barre outils à droite
# =============================================================================

class DiagramCanvas < Gtk::DrawingArea
  BLOCK_RADIUS = 6.0
  PORT_RADIUS  = 5.0
  ARROW_SIZE   = 8.0
  ZOOM_STEP    = 0.12
  ZOOM_MIN     = 0.15
  ZOOM_MAX     = 5.0

  COLOR_BG        = [0.13, 0.13, 0.16].freeze
  COLOR_BLOCK     = [0.22, 0.26, 0.34].freeze
  COLOR_DIAG_PORT = [0.18, 0.34, 0.24].freeze
  COLOR_BORDER    = [0.50, 0.62, 0.80].freeze
  COLOR_SEL       = [0.92, 0.72, 0.18].freeze
  COLOR_TEXT      = [0.94, 0.94, 0.96].freeze
  COLOR_TEXT_TYPE = [0.60, 0.72, 0.88].freeze
  COLOR_WIRE_GHOST= [1.0,  0.85, 0.28].freeze

  attr_accessor :model, :on_model_changed

  def initialize(model)
    super()
    @model = model
    @selected = nil; @drag_offset = nil
    @wiring_port = nil
    @mouse_x = @mouse_y = 0
    @zoom = 1.0; @offset_x = 0.0; @offset_y = 0.0
    @pan_active = false; @pan_start_x = 0; @pan_start_y = 0
    @pan_origin_x = 0; @pan_origin_y = 0

    add_events(Gdk::EventMask::BUTTON_PRESS_MASK   |
               Gdk::EventMask::BUTTON_RELEASE_MASK |
               Gdk::EventMask::POINTER_MOTION_MASK |
               Gdk::EventMask::KEY_PRESS_MASK      |
               Gdk::EventMask::SCROLL_MASK)
    set_can_focus(true)

    signal_connect('draw')                 { |_w, cr| redraw(cr) }
    signal_connect('button-press-event')   { |_w, e|  on_button_press(e) }
    signal_connect('button-release-event') { |_w, e|  on_button_release(e) }
    signal_connect('motion-notify-event')  { |_w, e|  on_motion(e) }
    signal_connect('key-press-event')      { |_w, e|  on_key_press(e) }
    signal_connect('scroll-event')         { |_w, e|  on_scroll(e) }
  end

  def zoom = @zoom

  def zoom=(v)
    @zoom = v.clamp(ZOOM_MIN, ZOOM_MAX)
    queue_draw
  end

  def s2m(sx, sy)   # screen → model
    [(sx - @offset_x) / @zoom, (sy - @offset_y) / @zoom]
  end

  # ---- Rendu Cairo ----

  def redraw(cr)
    w = allocated_width; h = allocated_height
    cr.set_source_rgb(*COLOR_BG)
    cr.rectangle(0, 0, w, h); cr.fill

    cr.save
    cr.translate(@offset_x, @offset_y)
    cr.scale(@zoom, @zoom)

    # Grille
    gs = 20.0
    cr.set_source_rgba(1, 1, 1, 0.04)
    cr.set_line_width(0.5 / @zoom)
    x0 = (-@offset_x / @zoom).floor / gs * gs
    y0 = (-@offset_y / @zoom).floor / gs * gs
    xn = x0 + w / @zoom + gs * 2
    yn = y0 + h / @zoom + gs * 2
    x = x0; while x < xn; cr.move_to(x, y0); cr.line_to(x, yn); x += gs; end
    y = y0; while y < yn; cr.move_to(x0, y); cr.line_to(xn, y); y += gs; end
    cr.stroke

    @model.connections.each { |c| draw_connection(cr, c) }

    if @wiring_port && (bk = @model.block_of(@wiring_port))
      px, py = bk.port_position(@wiring_port)
      mx, my = s2m(@mouse_x, @mouse_y)
      cr.set_source_rgba(*COLOR_WIRE_GHOST, 0.8)
      cr.set_line_width(1.5 / @zoom)
      cr.set_dash([5.0 / @zoom, 4.0 / @zoom], 0)
      cr.move_to(px, py); cr.line_to(mx, my); cr.stroke
      cr.set_dash([], 0)
    end

    @model.blocks.each { |b| draw_block(cr, b) }
    cr.restore
  end

  def draw_block(cr, b)
    sel    = (b == @selected)
    bg     = b.is_diagram_port ? COLOR_DIAG_PORT : COLOR_BLOCK
    border = sel ? COLOR_SEL : COLOR_BORDER
    lw     = (sel ? 2.5 : 1.5) / @zoom

    rounded_rect(cr, b.x, b.y, b.width, b.height, BLOCK_RADIUS)
    cr.set_source_rgb(*bg); cr.fill_preserve
    cr.set_source_rgb(*border); cr.set_line_width(lw); cr.stroke

    cr.set_source_rgb(*COLOR_TEXT)
    cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL,
                        b.is_diagram_port ? Cairo::FONT_WEIGHT_BOLD : Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(12)
    e = cr.text_extents(b.name)
    cr.move_to(b.x + (b.width  - e.width)  / 2 - e.x_bearing,
               b.y + (b.height - e.height) / 2 - e.y_bearing)
    cr.show_text(b.name)

    # Indicateur visuel : petit disque vert si le bloc a du code
    if b.code && !b.code.strip.empty?
      cr.set_source_rgb(0.3, 0.85, 0.4)
      cr.arc(b.x + b.width - 7, b.y + 7, 4, 0, 2 * Math::PI)
      cr.fill
    end

    b.ports.each { |p| draw_port(cr, b, p) }
  end

  def draw_port(cr, _b, p)
    px, py  = @model.block_of(p).port_position(p)
    trgb    = p.type_color_rgb

    cr.set_source_rgb(*trgb)
    cr.move_to(px - PORT_RADIUS, py - PORT_RADIUS)
    cr.line_to(px + PORT_RADIUS, py)
    cr.line_to(px - PORT_RADIUS, py + PORT_RADIUS)
    cr.close_path; cr.fill

    if p == @wiring_port
      cr.set_source_rgba(1, 1, 0.3, 0.9)
      cr.arc(px, py, PORT_RADIUS + 3, 0, 2 * Math::PI)
      cr.set_line_width(2.0 / @zoom); cr.stroke
    end

    cr.select_font_face('Sans', Cairo::FONT_SLANT_NORMAL, Cairo::FONT_WEIGHT_NORMAL)
    cr.set_font_size(10)
    ne = cr.text_extents(p.name)
    type_s = p.port_type.to_s.empty? ? '' : ":#{p.port_type}"

    if p.input?
      tx = px + PORT_RADIUS + 4
      cr.set_source_rgb(*COLOR_TEXT)
      cr.move_to(tx, py - ne.y_bearing - ne.height / 2); cr.show_text(p.name)
      unless type_s.empty?
        cr.set_font_size(8); cr.set_source_rgb(*COLOR_TEXT_TYPE)
        te = cr.text_extents(type_s)
        cr.move_to(tx, py - ne.y_bearing - ne.height / 2 + ne.height + 1)
        cr.show_text(type_s); cr.set_font_size(10)
      end
    else
      cr.set_source_rgb(*COLOR_TEXT)
      cr.move_to(px - PORT_RADIUS - 4 - ne.width, py - ne.y_bearing - ne.height / 2)
      cr.show_text(p.name)
      unless type_s.empty?
        cr.set_font_size(8); cr.set_source_rgb(*COLOR_TEXT_TYPE)
        te = cr.text_extents(type_s)
        cr.move_to(px - PORT_RADIUS - 4 - te.width,
                   py - ne.y_bearing - ne.height / 2 + ne.height + 1)
        cr.show_text(type_s); cr.set_font_size(10)
      end
    end
  end

  def draw_connection(cr, conn)
    fp = @model.find_port(conn.from_port_id)
    tp = @model.find_port(conn.to_port_id)
    return unless fp && tp
    fb = @model.block_of(fp); tb = @model.block_of(tp)
    return unless fb && tb

    x1, y1 = fb.port_position(fp)
    x2, y2 = tb.port_position(tp)
    dx      = (x2 - x1).abs * 0.5 + 30

    cr.set_source_rgb(*fp.type_color_rgb)
    cr.set_line_width(1.8 / @zoom)
    cr.move_to(x1, y1)
    cr.curve_to(x1 + dx, y1, x2 - dx, y2, x2, y2)
    cr.stroke

    angle = Math.atan2(y2 - (y1 + y2) / 2.0, x2 - (x1 + x2) / 2.0)
    sz = ARROW_SIZE
    cr.move_to(x2, y2)
    cr.line_to(x2 - sz * Math.cos(angle - 0.38), y2 - sz * Math.sin(angle - 0.38))
    cr.line_to(x2 - sz * Math.cos(angle + 0.38), y2 - sz * Math.sin(angle + 0.38))
    cr.close_path; cr.fill
  end

  def rounded_rect(cr, x, y, w, h, r)
    cr.move_to(x+r, y)
    cr.line_to(x+w-r, y);   cr.arc(x+w-r, y+r,   r, -Math::PI/2, 0)
    cr.line_to(x+w, y+h-r); cr.arc(x+w-r, y+h-r, r, 0,           Math::PI/2)
    cr.line_to(x+r, y+h);   cr.arc(x+r,   y+h-r, r, Math::PI/2,  Math::PI)
    cr.line_to(x, y+r);     cr.arc(x+r,   y+r,   r, Math::PI,    3*Math::PI/2)
    cr.close_path
  end

  # ---- Événements ----

  def on_scroll(event)
    factor   = event.direction == :up ? (1.0 + ZOOM_STEP) : (1.0 - ZOOM_STEP)
    new_zoom = (@zoom * factor).clamp(ZOOM_MIN, ZOOM_MAX)
    @offset_x = event.x - (event.x - @offset_x) * (new_zoom / @zoom)
    @offset_y = event.y - (event.y - @offset_y) * (new_zoom / @zoom)
    @zoom = new_zoom
    @on_zoom_changed&.call(@zoom)
    queue_draw; true
  end

  attr_writer :on_zoom_changed

  def on_button_press(event)
    grab_focus
    mx, my = s2m(event.x, event.y)
    port   = find_port_at(mx, my)

    # ---- Pan : bouton milieu OU Alt + bouton gauche ----
    alt_held = event.state & Gdk::ModifierType::MOD1_MASK != 0
    if event.button == 2 || (event.button == 1 && alt_held)
      @pan_active   = true
      @pan_start_x  = event.x; @pan_start_y  = event.y
      @pan_origin_x = @offset_x; @pan_origin_y = @offset_y
      window&.cursor = Gdk::Cursor.new(:fleur)
      return
    end

    # ---- Double-clic gauche : ouvrir éditeur de code ----
    if event.button == 1 && event.event_type == Gdk::EventType::DOUBLE_BUTTON_PRESS
      block = find_block_at(mx, my)
      if block && !block.is_diagram_port
        open_code_editor(block)
        return
      end
    end

    if event.button == 1
      if port
        if @wiring_port.nil?
          @wiring_port = port if port.output? || @model.block_of(port)&.is_diagram_port
        else
          @model.connect(@wiring_port, port)
          @wiring_port = nil; notify_change
        end
        queue_draw; return
      end
      if @wiring_port
        @wiring_port = nil; queue_draw; return
      end
      @selected    = find_block_at(mx, my)
      @drag_offset = @selected ? [mx - @selected.x, my - @selected.y] : nil
      queue_draw

    elsif event.button == 3
      @wiring_port = nil
      show_context_menu(event, mx, my, find_block_at(mx, my), port)
    end
  end

  def on_button_release(event)
    if @pan_active && (event.button == 2 || event.button == 1)
      @pan_active = false
      window&.cursor = nil
    end
    @drag_offset = nil
  end

  def on_motion(event)
    @mouse_x, @mouse_y = event.x, event.y

    if @pan_active
      @offset_x = @pan_origin_x + (event.x - @pan_start_x)
      @offset_y = @pan_origin_y + (event.y - @pan_start_y)
      queue_draw
      return
    end

    if @drag_offset && @selected
      mx, my     = s2m(event.x, event.y)
      @selected.x = mx - @drag_offset[0]
      @selected.y = my - @drag_offset[1]
    end
    queue_draw
  end

  def on_key_press(event)
    case event.keyval
    when Gdk::Keyval::GDK_KEY_Delete, Gdk::Keyval::GDK_KEY_BackSpace
      if @selected
        @model.remove_block(@selected); @selected = nil
        notify_change; queue_draw
      end
    when Gdk::Keyval::GDK_KEY_Escape
      @wiring_port = nil; queue_draw
    when Gdk::Keyval::GDK_KEY_plus, Gdk::Keyval::GDK_KEY_equal
      self.zoom = @zoom * (1 + ZOOM_STEP)
      @on_zoom_changed&.call(@zoom)
    when Gdk::Keyval::GDK_KEY_minus
      self.zoom = @zoom * (1 - ZOOM_STEP)
      @on_zoom_changed&.call(@zoom)
    when Gdk::Keyval::GDK_KEY_0
      @zoom = 1.0; @offset_x = 0.0; @offset_y = 0.0
      @on_zoom_changed&.call(@zoom); queue_draw
    end
  end

  # ---- Menu contextuel ----

  def show_context_menu(event, mx, my, block, _port)
    menu = Gtk::Menu.new
    if block.nil?
      items = [
        ['➕  Nouveau bloc', -> {
          b = @model.add_block(name: 'Bloc', x: mx - 70, y: my - 40)
          edit_block_dialog(b)
        }],
        ['🔌  Port IN du diagramme', -> {
          @model.add_diagram_port(name: 'in', direction: :in, x: mx, y: my)
          notify_change; queue_draw
        }],
        ['🔌  Port OUT du diagramme', -> {
          @model.add_diagram_port(name: 'out', direction: :out, x: mx, y: my)
          notify_change; queue_draw
        }]
      ]
    else
      items = [
        ["✏️   Renommer « #{block.name} »", -> { edit_block_dialog(block) }],
        ['⚙️   Gérer les ports…',            -> { edit_ports_dialog(block) }],
        ['📝   Éditer le code…',             -> { open_code_editor(block) }],
        :sep,
        ['🗑️   Supprimer ce bloc', -> {
          @model.remove_block(block)
          @selected = nil if @selected == block
          notify_change; queue_draw
        }]
      ]
    end

    items.each do |item|
      if item == :sep
        menu.append(Gtk::SeparatorMenuItem.new)
      else
        label, action = item
        mi = Gtk::MenuItem.new(label: label)
        mi.signal_connect('activate') { action.call }
        menu.append(mi)
      end
    end

    menu.show_all
    menu.popup_at_pointer(event)
  end

  def edit_block_dialog(block)
    dlg = BlockDialog.new(toplevel, block)
    if dlg.run == Gtk::ResponseType::OK
      block.name = dlg.block_name unless dlg.block_name.strip.empty?
      block.resize_to_fit; notify_change; queue_draw
    end
    dlg.destroy
  end

  def edit_ports_dialog(block)
    dlg = PortsDialog.new(toplevel, block, @model)
    dlg.run; dlg.destroy
    notify_change; queue_draw
  end

  def open_code_editor(block)
    # Annule tout drag en cours — le button-release ne reviendra pas au canvas
    @drag_offset = nil
    @selected    = nil
    queue_draw
    dlg = CodeEditorDialog.new(toplevel, block)
    loop do
      response = dlg.run
      if response == Gtk::ResponseType::OK || response == Gtk::ResponseType::APPLY
        block.code     = dlg.edited_code
        block.language = dlg.edited_language
        notify_change
        queue_draw
      end
      break unless response == Gtk::ResponseType::APPLY
    end
    dlg.destroy
  end

  def find_block_at(mx, my)
    @model.blocks.reverse.find { |b| b.hit_test(mx, my) }
  end

  def find_port_at(mx, my, thr = 10)
    @model.blocks.each { |b| p = b.port_at(mx, my, thr); return p if p }; nil
  end

  def notify_change = @on_model_changed&.call
end

# =============================================================================
# BARRE D'OUTILS VERTICALE
# =============================================================================

class SideToolbar < Gtk::Box
  def initialize(canvas)
    super(:vertical, 2)
    @canvas = canvas
    self.margin_start = 3; self.margin_end = 3
    self.margin_top = 6;   self.margin_bottom = 6
    self.width_request = 54

    # Séparateur visuel gauche
    pack_start(Gtk::Separator.new(:horizontal), expand: false, fill: false, padding: 0)
  end

  def add_btn(icon, tip, &blk)
    btn = Gtk::Button.new
    img = begin
      Gtk::Image.new(icon_name: icon, icon_size: :button)
    rescue
      Gtk::Label.new(tip[0, 1])
    end
    btn.add(img)
    btn.tooltip_text = tip
    btn.relief = :none
    btn.set_size_request(46, 38)
    btn.signal_connect('clicked') { blk.call }
    pack_start(btn, expand: false, fill: false, padding: 1)
    btn
  end

  def add_sep
    s = Gtk::Separator.new(:horizontal)
    s.margin_top = 4; s.margin_bottom = 4
    pack_start(s, expand: false, fill: false, padding: 0)
  end

  def add_zoom_display
    @zoom_lbl = Gtk::Label.new
    @zoom_lbl.markup = zoom_markup(1.0)
    @zoom_lbl.set_size_request(46, -1)
    pack_start(@zoom_lbl, expand: false, fill: false, padding: 2)
  end

  def update_zoom(z)
    @zoom_lbl&.markup = zoom_markup(z)
  end

  private

  def zoom_markup(z)
    "<small>#{(z * 100).round}%</small>"
  end
end

# =============================================================================
# FENÊTRE PRINCIPALE
# =============================================================================

class MainWindow < Gtk::ApplicationWindow
  def initialize(app, filepath = nil)
    super(app)
    @filepath = filepath; @modified = false

    PortTypes.load_from_file

    @model = if filepath && File.exist?(filepath)
               SexpSerializer.load(File.read(filepath))
             else
               DiagramModel.new
             end

    set_title_from_file
    set_default_size(1100, 720)
    build_ui
    show_all
  end

  private

  def build_ui
    vbox = Gtk::Box.new(:vertical, 0)
    add(vbox)
    vbox.pack_start(build_menubar, expand: false, fill: false, padding: 0)

    # Zone centrale : canvas + barre latérale droite
    hbox = Gtk::Box.new(:horizontal, 0)

    @canvas = DiagramCanvas.new(@model)
    @canvas.on_model_changed = method(:on_model_changed)

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    sw.add(@canvas)
    @canvas.set_size_request(2000, 1600)
    hbox.pack_start(sw, expand: true, fill: true, padding: 0)

    # Séparateur + barre verticale
    hbox.pack_start(Gtk::Separator.new(:vertical), expand: false, fill: false, padding: 0)
    @sidebar = build_sidebar
    hbox.pack_start(@sidebar, expand: false, fill: false, padding: 0)

    vbox.pack_start(hbox, expand: true, fill: true, padding: 0)

    @statusbar = Gtk::Statusbar.new
    @ctx = @statusbar.get_context_id('main')
    vbox.pack_start(@statusbar, expand: false, fill: false, padding: 0)

    # Liaison zoom → label sidebar et barre de statut
    @canvas.on_zoom_changed = ->(z) { @sidebar.update_zoom(z); update_status }

    update_status
  end

  def build_sidebar
    sb = SideToolbar.new(@canvas)

    sb.add_btn('document-new',  'Nouveau diagramme (Ctrl+N)')     { action_new }
    sb.add_btn('document-open', 'Ouvrir… (Ctrl+O)')               { action_open }
    sb.add_btn('document-save', 'Enregistrer (Ctrl+S)')           { action_save }
    sb.add_sep

    sb.add_btn('zoom-in',        'Zoom avant (+)')   { @canvas.zoom = @canvas.zoom * 1.15; sb.update_zoom(@canvas.zoom); update_status }
    sb.add_btn('zoom-out',       'Zoom arrière (−)') { @canvas.zoom = @canvas.zoom / 1.15; sb.update_zoom(@canvas.zoom); update_status }
    sb.add_btn('zoom-fit-best',  'Zoom 100% (0)')    { @canvas.zoom = 1.0; sb.update_zoom(1.0); update_status }
    sb.add_zoom_display
    sb.add_sep

    sb.add_btn('preferences-system', 'Gérer les connexions…')  { action_connections }
    sb.add_sep

    sb.add_btn('help-about', 'Aide / À propos')  { action_help }

    sb
  end

  def build_menubar
    menubar = Gtk::MenuBar.new

    file_entries = [
      ['Nouveau',           -> { action_new }],
      ['Ouvrir…',           -> { action_open }],
      ['Enregistrer',       -> { action_save }],
      ['Enregistrer sous…', -> { action_save_as }],
      nil,
      ['Quitter',           -> { action_quit }]
    ]
    menubar.append(make_menu('Fichier', file_entries))

    edit_entries = [['Connexions…', -> { action_connections }]]
    menubar.append(make_menu('Édition', edit_entries))

    view_entries = [
      ['Zoom avant',   -> { @canvas.zoom = @canvas.zoom * 1.15; @sidebar.update_zoom(@canvas.zoom) }],
      ['Zoom arrière', -> { @canvas.zoom = @canvas.zoom / 1.15; @sidebar.update_zoom(@canvas.zoom) }],
      ['Zoom 100%',    -> { @canvas.zoom = 1.0; @sidebar.update_zoom(1.0) }]
    ]
    menubar.append(make_menu('Vue', view_entries))

    help_entries = [['Aide / À propos…', -> { action_help }]]
    menubar.append(make_menu('Aide', help_entries))

    menubar
  end

  def make_menu(label, entries)
    menu = Gtk::Menu.new
    entries.each do |entry|
      if entry.nil?
        menu.append(Gtk::SeparatorMenuItem.new)
      else
        lbl, action = entry
        mi = Gtk::MenuItem.new(label: lbl)
        mi.signal_connect('activate') { action.call }
        menu.append(mi)
      end
    end
    mi = Gtk::MenuItem.new(label: label)
    mi.submenu = menu
    mi
  end

  # ---- Actions ----

  def action_new
    return if @modified && !confirm_discard?
    @model = DiagramModel.new
    @filepath = nil; @modified = false
    @canvas.model = @model; @canvas.queue_draw
    set_title_from_file; update_status
  end

  def action_open
    return if @modified && !confirm_discard?
    dlg = Gtk::FileChooserDialog.new(title: 'Ouvrir', parent: self, action: :open)
    dlg.add_button('Annuler', Gtk::ResponseType::CANCEL)
    dlg.add_button('Ouvrir',  Gtk::ResponseType::ACCEPT)
    add_sxd_filter(dlg)
    if dlg.run == Gtk::ResponseType::ACCEPT
      path = dlg.filename; dlg.destroy; load_file(path)
    else
      dlg.destroy
    end
  end

  def action_save
    @filepath ? save_to(@filepath) : action_save_as
  end

  def action_save_as
    dlg = Gtk::FileChooserDialog.new(title: 'Enregistrer sous…', parent: self, action: :save)
    dlg.add_button('Annuler',     Gtk::ResponseType::CANCEL)
    dlg.add_button('Enregistrer', Gtk::ResponseType::ACCEPT)
    dlg.do_overwrite_confirmation = true
    add_sxd_filter(dlg)
    dlg.current_name = File.basename(@filepath || 'diagramme.sxd')
    if dlg.run == Gtk::ResponseType::ACCEPT
      @filepath = dlg.filename
      @filepath += '.sxd' unless @filepath.end_with?('.sxd')
      dlg.destroy; save_to(@filepath)
    else
      dlg.destroy
    end
  end

  def action_connections
    dlg = ConnectionsDialog.new(self, @model)
    dlg.run; dlg.destroy; @canvas.queue_draw
  end

  def action_help
    dlg = HelpDialog.new(self)
    dlg.run; dlg.destroy
  end

  def action_quit
    return if @modified && !confirm_discard?
    destroy
  end

  # ---- Fichiers ----

  def load_file(path)
    @model = SexpSerializer.load(File.read(path))
    @filepath = path; @modified = false
    @canvas.model = @model; @canvas.queue_draw
    set_title_from_file; update_status
  rescue => e
    error_dialog("Erreur de chargement :\n#{e.message}")
  end

  def save_to(path)
    File.write(path, SexpSerializer.dump(@model))
    @modified = false
    set_title_from_file; update_status("Enregistré : #{path}")
  rescue => e
    error_dialog("Erreur d'enregistrement :\n#{e.message}")
  end

  def add_sxd_filter(dlg)
    f = Gtk::FileFilter.new
    f.name = 'Diagrammes S-expr (*.sxd)'
    f.add_pattern('*.sxd')
    dlg.add_filter(f)
    f2 = Gtk::FileFilter.new; f2.name = 'Tous les fichiers'; f2.add_pattern('*')
    dlg.add_filter(f2)
  end

  def confirm_discard?
    dlg = Gtk::MessageDialog.new(parent: self, flags: :destroy_with_parent,
                                 type: :warning, buttons: :yes_no,
                                 message: "Le diagramme a été modifié.\nAbandonner les modifications ?")
    res = dlg.run == Gtk::ResponseType::YES; dlg.destroy; res
  end

  def error_dialog(msg)
    dlg = Gtk::MessageDialog.new(parent: self, flags: :destroy_with_parent,
                                 type: :error, buttons: :close, message: msg)
    dlg.run; dlg.destroy
  end

  def on_model_changed
    @modified = true; set_title_from_file; update_status
  end

  def set_title_from_file
    base = @filepath ? File.basename(@filepath) : 'Sans titre'
    self.title = "#{@model.name}  —  #{base}#{@modified ? ' *' : ''}  —  Éditeur de schémas-blocs"
  end

  def update_status(msg = nil)
    @statusbar.pop(@ctx)
    text = msg || begin
      nb = @model.blocks.count { |b| !b.is_diagram_port }
      nd = @model.blocks.count(&:is_diagram_port)
      nc = @model.connections.size
      z  = @canvas ? "  |  Zoom #{(@canvas.zoom * 100).round}%" : ''
      "#{nb} bloc(s)  |  #{nd} port(s) diagramme  |  #{nc} connexion(s)#{z}"
    end
    @statusbar.push(@ctx, text)
  end
end

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

app = Gtk::Application.new('org.example.BlockDiagramEditor', :flags_none)

app.signal_connect('activate') do |application|
  win = MainWindow.new(application, ARGV[0])
  win.signal_connect('delete-event') { application.quit; false }
end

app.run([])
