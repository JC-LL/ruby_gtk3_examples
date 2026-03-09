#!/usr/bin/env ruby
# frozen_string_literal: false
# =============================================================================
# syntax_to_lang.rb  —  Convertit syntax.json en fichier .lang GtkSourceView
#
# Usage :
#   ruby syntax_to_lang.rb [syntax.json] [--id=mondsl] [--name="Mon DSL"] [--install]
#
# Options :
#   syntax.json   Chemin vers le fichier de règles (défaut : ./syntax.json)
#   --id=ID       Identifiant GtkSourceView du langage  (défaut : bde_custom)
#   --name=NOM    Nom affiché dans les menus            (défaut : BDE Custom)
#   --section=S   Section GtkSourceView                 (défaut : Source)
#   --install     Installe dans ~/.local/share/gtksourceview-4/language-specs/
#   --output=F    Écrit dans le fichier F (défaut : <id>.lang dans le dossier courant)
#
# Exemples :
#   ruby syntax_to_lang.rb
#   ruby syntax_to_lang.rb syntax.json --id=mondsl --name="Mon DSL" --install
#   ruby syntax_to_lang.rb --id=ruby_dsl --output=/tmp/ruby_dsl.lang
# =============================================================================

require 'json'
require 'fileutils'

# ---- Parsing des arguments ----

args    = ARGV.dup
json_path = nil
lang_id   = 'bde_custom'
lang_name = 'BDE Custom'
section   = 'Source'
do_install = false
output_path = nil

args.each do |a|
  case a
  when /\A--id=(.+)\z/       then lang_id   = $1
  when /\A--name=(.+)\z/     then lang_name = $1
  when /\A--section=(.+)\z/  then section   = $1
  when '--install'            then do_install = true
  when /\A--output=(.+)\z/   then output_path = $1
  when /\A[^-]/               then json_path = a
  end
end

# Cherche syntax.json si non précisé
json_path ||= [
  './syntax.json',
  File.join(File.dirname(__FILE__), 'syntax.json'),
  File.expand_path('~/.config/bde/syntax.json')
].find { |f| File.exist?(f) }

abort "Erreur : aucun fichier syntax.json trouvé. Précisez le chemin en argument." unless json_path
abort "Erreur : fichier introuvable : #{json_path}" unless File.exist?(json_path)

data  = JSON.parse(File.read(json_path))
rules = data['rules']
abort "Erreur : le fichier JSON ne contient pas de clé 'rules'." unless rules.is_a?(Array)
abort "Erreur : 'rules' est vide." if rules.empty?

puts "Source     : #{json_path}"
puts "Langage ID : #{lang_id}"
puts "Nom        : #{lang_name}"
puts "#{rules.size} règle(s) trouvée(s)"
puts

# ---- Helpers XML ----

def xml_escape(str)
  str.to_s
     .gsub('&',  '&amp;')
     .gsub('<',  '&lt;')
     .gsub('>',  '&gt;')
     .gsub('"',  '&quot;')
end

# Convertit une regex Ruby/PCRE en regex GtkSourceView (POSIX ERE subset).
# GtkSourceView utilise GRegex (PCRE) — la plupart des regex Ruby sont compatibles.
def to_gsv_regex(pattern)
  xml_escape(pattern)
end

# ---- Construction des styles ----

styles_xml = rules.map do |rule|
  name    = rule['name'] or abort "Règle sans 'name' : #{rule.inspect}"
  color   = rule['color'] || '#cccccc'
  attrs   = ["foreground=\"#{xml_escape(color)}\""]
  attrs << 'bold="true"'   if rule['bold']
  attrs << 'italic="true"' if rule['italic']
  "    <style id=\"#{lang_id}:#{name}\" #{attrs.join(' ')}/>"
end.join("\n")

# ---- Construction des contextes ----

contexts_xml = rules.map do |rule|
  name     = rule['name']
  style_ref = "#{lang_id}:#{name}"

  if rule['patterns']
    # Mots-clés : utilise <keyword> pour chacun (GtkSourceView les entoure de \b)
    kw_items = rule['patterns'].map { |w| "          <keyword>#{xml_escape(w)}</keyword>" }.join("\n")
    <<~CTX
          <context id="#{name}" style-ref="#{style_ref}">
            <keyword-char-class>[a-zA-Z0-9_]</keyword-char-class>
      #{kw_items}
          </context>
    CTX
  elsif rule['regex']
    re = to_gsv_regex(rule['regex'])
    <<~CTX
          <context id="#{name}" style-ref="#{style_ref}">
            <match>#{re}</match>
          </context>
    CTX
  else
    warn "  Avertissement : règle '#{name}' sans 'patterns' ni 'regex', ignorée."
    nil
  end
end.compact.join("\n")

# Références dans le contexte racine
ctx_refs = rules
  .select { |r| r['patterns'] || r['regex'] }
  .map    { |r| "        <context ref=\"#{r['name']}\"/>" }
  .join("\n")

# ---- Assemblage final ----

lang_xml = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <!--
    Généré automatiquement par syntax_to_lang.rb
    Source : #{json_path}
    Ne pas éditer manuellement — modifiez syntax.json puis relancez le script.
  -->
  <language id="#{lang_id}" name="#{xml_escape(lang_name)}"
            version="2.0" _section="#{xml_escape(section)}">

    <metadata>
      <property name="mimetypes">text/x-#{lang_id}</property>
      <property name="globs">*.#{lang_id}</property>
    </metadata>

    <styles>
  #{styles_xml}
    </styles>

    <definitions>

  #{contexts_xml}
      <!-- Contexte racine : inclut toutes les règles ci-dessus -->
      <context id="#{lang_id}">
        <include>
  #{ctx_refs}
        </include>
      </context>

    </definitions>

  </language>
XML

# ---- Écriture ----

output_path ||= "#{lang_id}.lang"

File.write(output_path, lang_xml)
puts "Fichier généré : #{output_path}"

# ---- Installation optionnelle ----

if do_install
  install_dir = File.expand_path('~/.local/share/gtksourceview-4/language-specs')
  FileUtils.mkdir_p(install_dir)
  dest = File.join(install_dir, File.basename(output_path))
  FileUtils.cp(output_path, dest)
  puts "Installé dans  : #{dest}"
  puts
  puts "Le langage '#{lang_id}' sera disponible au prochain lancement de l'éditeur."
  puts "Sélectionnez-le dans le combo 'Langage' de l'éditeur de code."
else
  puts
  puts "Pour installer dans GtkSourceView :"
  puts "  ruby syntax_to_lang.rb #{json_path} --id=#{lang_id} --install"
  puts
  puts "Ou manuellement :"
  puts "  mkdir -p ~/.local/share/gtksourceview-4/language-specs"
  puts "  cp #{output_path} ~/.local/share/gtksourceview-4/language-specs/"
end
