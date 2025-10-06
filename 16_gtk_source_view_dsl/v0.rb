#!/usr/bin/env ruby

require 'gtk3'
require 'gtksourceview3'

class CodeEditor < Gtk::Window
  def initialize
    super(:toplevel)

    set_title("Éditeur de Code Python avec SourceView")
    set_default_size(800, 600)

    # Configuration de la fenêtre principale
    box = Gtk::Box.new(:vertical, 5)
    add(box)

    # Création de la barre d'outils
    create_toolbar(box)

    # Création du widget SourceView
    create_source_view(box)

    # Configuration de la langue Python
    setup_python_language

    # Exemple de code Python
    load_example_code

    signal_connect("destroy") { Gtk.main_quit }
  end

  def create_toolbar(box)
    toolbar = Gtk::Toolbar.new
    box.pack_start(toolbar, expand: false, fill: false, padding: 0)

    # Bouton pour changer le thème
    theme_button = Gtk::ToolButton.new(label: "Changer le thème")
    theme_button.signal_connect("clicked") { toggle_theme }
    toolbar.insert(theme_button, 0)

    # Bouton pour afficher les informations
    info_button = Gtk::ToolButton.new(label: "Info")
    info_button.signal_connect("clicked") { show_language_info }
    toolbar.insert(info_button, 1)
  end

  def create_source_view(box)
    # Création du buffer source
    @buffer = GtkSource::Buffer.new

    # Création de la vue - CORRECTION ICI
    @source_view = GtkSource::View.new
    @source_view.buffer = @buffer

    # Configuration de la vue
    @source_view.show_line_numbers = true
    @source_view.highlight_current_line = true
    @source_view.auto_indent = true
    @source_view.tab_width = 4
    @source_view.indent_width = 4
    @source_view.insert_spaces_instead_of_tabs = true
    @source_view.smart_home_end = :after

    # Ajout dans un ScrolledWindow
    scrolled_window = Gtk::ScrolledWindow.new
    scrolled_window.set_policy(:automatic, :automatic)
    scrolled_window.add(@source_view)

    box.pack_start(scrolled_window, expand: true, fill: true, padding: 0)
  end

  def setup_python_language
    # Récupération du gestionnaire de langages
    language_manager = GtkSource::LanguageManager.default

    # Recherche du langage Python
    @language = language_manager.get_language("python")

    if @language
      @buffer.language = @language
      puts "Langage Python chargé avec succès"
    else
      puts "Langage Python non trouvé"
      # Liste des langages disponibles pour debug
      puts "Langages disponibles:"
      language_manager.language_ids.each { |id| puts "  - #{id}" }
    end

    # Configuration du style
    style_manager = GtkSource::StyleSchemeManager.default
    @style = style_manager.get_scheme("classic")
    if @style
      @buffer.style_scheme = @style
    else
      # Fallback vers le premier schéma disponible
      available_schemes = style_manager.scheme_ids
      if available_schemes.any?
        @buffer.style_scheme = style_manager.get_scheme(available_schemes.first)
        puts "Utilisation du thème: #{available_schemes.first}"
      end
    end
  end

  def load_example_code
    example_code = <<~PYTHON
      #!/usr/bin/env python3
      # Exemple de code Python avec coloration syntaxique

      class Calculatrice:
          """Une classe simple pour faire des calculs"""

          def __init__(self):
              self.historique = []

          def addition(self, a, b):
              """Additionne deux nombres"""
              resultat = a + b
              self.historique.append(f"{a} + {b} = {resultat}")
              return resultat

          def factorielle(self, n):
              """Calcule la factorielle d'un nombre"""
              if n == 0:
                  return 1
              else:
                  return n * self.factorielle(n - 1)

      def main():
          # Création d'une instance
          calc = Calculatrice()

          # Quelques calculs
          print("Addition:", calc.addition(5, 3))
          print("Factorielle de 5:", calc.factorielle(5))

          # Affichage de l'historique
          print("\\nHistorique des calculs:")
          for operation in calc.historique:
              print(f"  - {operation}")

      if __name__ == "__main__":
          main()
    PYTHON

    @buffer.text = example_code
  end

  def toggle_theme
    style_manager = GtkSource::StyleSchemeManager.default
    current_theme = @buffer.style_scheme&.name || "inconnu"

    new_theme = if current_theme == "classic"
      style_manager.get_scheme("solarized-dark") || style_manager.get_scheme("tango")
    else
      style_manager.get_scheme("classic")
    end

    if new_theme
      @buffer.style_scheme = new_theme
      puts "Thème changé pour: #{new_theme.name}"
    end
  end

  def show_language_info
    if @language
      dialog = Gtk::MessageDialog.new(
        parent: self,
        flags: :modal,
        type: :info,
        buttons: :ok,
        message: "Langage: #{@language.name}\nID: #{@language.id}\nSection: #{@language.section}"
      )
      dialog.run
      dialog.destroy
    else
      puts "Aucun langage chargé"
    end
  end
end

# Vérification de la disponibilité de gtksourceview3
unless defined?(GtkSource)
  puts "GtkSourceView3 n'est pas disponible"
  puts "Sur Ubuntu/Debian, installez avec:"
  puts "  sudo apt-get install gir1.2-gtksource-3.0 libgtksourceview-3.0-dev"
  puts "Puis installez la gem: gem install gtksourceview3"
  exit(1)
end

# Lancement de l'application
app = CodeEditor.new
app.show_all
Gtk.main
