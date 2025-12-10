#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'

class SVGAnimator
  def initialize(output_dir = "svg_animation_frames")
    @output_dir = output_dir
    @width = 800
    @height = 600
    @total_frames = 100

    # Créer le répertoire de sortie
    FileUtils.mkdir_p(@output_dir)
  end

  def generate_animation_sequence
    puts "Génération de #{@total_frames} images SVG dans le dossier '#{@output_dir}'..."

    (0...@total_frames).each do |frame_number|
      generate_frame(frame_number)

      # Afficher la progression
      if (frame_number + 1) % 10 == 0
        puts "  #{frame_number + 1}/#{@total_frames} images générées..."
      end
    end

    puts "✓ Animation complète générée avec succès !"
    puts "Dossier: #{File.expand_path(@output_dir)}"
  end

  def generate_frame(frame_number)
    # Paramètres d'animation
    progress = frame_number.to_f / (@total_frames - 1)

    # Position du cercle (animation circulaire)
    center_x = @width / 2
    center_y = @height / 2
    radius = 150

    angle = progress * 2 * Math::PI
    circle_x = center_x + radius * Math.cos(angle)
    circle_y = center_y + radius * Math.sin(angle)

    # Couleur du cercle (change progressivement)
    r = (Math.sin(progress * Math::PI) * 255).round
    g = (Math.sin(progress * Math::PI + 2 * Math::PI / 3) * 255).round
    b = (Math.sin(progress * Math::PI + 4 * Math::PI / 3) * 255).round

    # Taille du cercle (pulse)
    circle_radius = 30 + 20 * Math.sin(progress * 4 * Math::PI)

    # Créer le contenu SVG
    svg_content = <<~SVG
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
      <svg width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}"
           xmlns="http://www.w3.org/2000/svg" version="1.1">

        <!-- Fond avec dégradé -->
        <defs>
          <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#1a1a2e;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#16213e;stop-opacity:1" />
          </linearGradient>
          <linearGradient id="circleGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:rgb(#{r},#{g},#{b});stop-opacity:0.8" />
            <stop offset="100%" style="stop-color:rgb(#{r/2},#{g/2},#{b/2});stop-opacity:0.8" />
          </linearGradient>
          <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur in="SourceAlpha" stdDeviation="5" result="blur"/>
            <feFlood flood-color="rgb(#{r},#{g},#{b})" flood-opacity="0.5" result="color"/>
            <feComposite in="color" in2="blur" operator="in" result="glow"/>
            <feMerge>
              <feMergeNode in="glow"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>

        <!-- Fond -->
        <rect width="100%" height="100%" fill="url(#bgGradient)"/>

        <!-- Grille de référence -->
        <g stroke="#2d4059" stroke-width="1" stroke-opacity="0.3" fill="none">
          #{(0..@width).step(50).map { |x| "<line x1='#{x}' y1='0' x2='#{x}' y2='#{@height}'/>" }.join("\n          ")}
          #{(0..@height).step(50).map { |y| "<line x1='0' y1='#{y}' x2='#{@width}' y2='#{y}'/>" }.join("\n          ")}
        </g>

        <!-- Axes centraux -->
        <line x1="#{center_x}" y1="0" x2="#{center_x}" y2="#{@height}" stroke="#4a6572" stroke-width="2" stroke-opacity="0.5"/>
        <line x1="0" y1="#{center_y}" x2="#{@width}" y2="#{center_y}" stroke="#4a6572" stroke-width="2" stroke-opacity="0.5"/>

        <!-- Trajectoire du cercle (chemin) -->
        <circle cx="#{center_x}" cy="#{center_y}" r="#{radius}" fill="none" stroke="#e4e4e4" stroke-width="2" stroke-opacity="0.3"/>

        <!-- Ligne qui suit le cercle -->
        <line x1="#{center_x}" y1="#{center_y}" x2="#{circle_x}" y2="#{circle_y}"
              stroke="rgb(#{r},#{g},#{b})" stroke-width="2" stroke-opacity="0.5"/>

        <!-- Cercle animé -->
        <circle cx="#{circle_x}" cy="#{circle_y}" r="#{circle_radius}"
                fill="url(#circleGradient)" stroke="white" stroke-width="2"
                filter="url(#glow)"/>

        <!-- Texte d'information -->
        <g font-family="Arial, sans-serif" font-size="14" fill="white">
          <rect x="10" y="10" width="250" height="90" fill="#000000" fill-opacity="0.5" rx="5" ry="5"/>
          <text x="20" y="30">
            <tspan fill="#4fc3f7">Frame: #{frame_number + 1}/#{@total_frames}</tspan>
          </text>
          <text x="20" y="50">
            <tspan fill="#4fc3f7">Position: </tspan>
            <tspan>#{circle_x.round(1)}, #{circle_y.round(1)}</tspan>
          </text>
          <text x="20" y="70">
            <tspan fill="#4fc3f7">Couleur: </tspan>
            <tspan>rgb(#{r}, #{g}, #{b})</tspan>
          </text>
          <text x="20" y="90">
            <tspan fill="#4fc3f7">Progression: </tspan>
            <tspan>#{(progress * 100).round(1)}%</tspan>
          </text>
        </g>

        <!-- Indicateur de position sur le cercle -->
        <circle cx="#{circle_x}" cy="#{circle_y}" r="5" fill="white" stroke="red" stroke-width="1"/>

        <!-- Titre de l'animation -->
        <text x="#{@width/2}" y="30" text-anchor="middle" font-family="Arial, sans-serif"
              font-size="24" fill="white" font-weight="bold">
          Animation SVG Test - Frame #{frame_number + 1}
        </text>

      </svg>
    SVG

    # Sauvegarder le fichier avec un nom suffixé par le numéro
    filename = File.join(@output_dir, "animation_#{sprintf('%03d', frame_number)}.svg")
    File.write(filename, svg_content)
  end
end

# Version alternative avec plusieurs objets animés
class MultiObjectSVGAnimator < SVGAnimator
  def generate_frame(frame_number)
    progress = frame_number.to_f / (@total_frames - 1)

    svg_content = <<~SVG
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
      <svg width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}"
           xmlns="http://www.w3.org/2000/svg" version="1.1">

        <!-- Fond avec dégradé dynamique -->
        <defs>
          <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#0f3460;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#533483;stop-opacity:1" />
          </linearGradient>

          <radialGradient id="sunGradient">
            <stop offset="0%" style="stop-color:#ff9800;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#ff5722;stop-opacity:0.7" />
          </radialGradient>
        </defs>

        <!-- Fond -->
        <rect width="100%" height="100%" fill="url(#bgGradient)"/>

        <!-- Soleil (tourne) -->
        <g transform="rotate(#{progress * 360}, #{@width/2}, #{@height/2})">
          <circle cx="#{@width/2}" cy="#{@height/2}" r="60" fill="url(#sunGradient)"/>
          #{(0..11).map do |i|
            angle = i * 30
            radians = angle * Math::PI / 180
            x1 = @width/2 + 60 * Math.cos(radians)
            y1 = @height/2 + 60 * Math.sin(radians)
            x2 = @width/2 + 90 * Math.cos(radians)
            y2 = @height/2 + 90 * Math.sin(radians)
            "<line x1='#{x1}' y1='#{y1}' x2='#{x2}' y2='#{y2}' stroke='#ff9800' stroke-width='4'/>"
          end.join("\n          ")}
        </g>

        <!-- Planète 1 (orbite elliptique) -->
        <g>
          <ellipse cx="#{@width/2}" cy="#{@height/2}" rx="200" ry="120" fill="none" stroke="#4a6572" stroke-width="1" stroke-opacity="0.3"/>
          #{
            planet1_x = @width/2 + 200 * Math.cos(progress * 2 * Math::PI)
            planet1_y = @height/2 + 120 * Math.sin(progress * 2 * Math::PI)
            "<circle cx='#{planet1_x}' cy='#{planet1_y}' r='25' fill='#2196f3' opacity='0.8'>
              <animate attributeName='r' values='25;30;25' dur='2s' repeatCount='indefinite'/>
            </circle>"
          }
        </g>

        <!-- Planète 2 (orbite différente) -->
        <g>
          #{
            planet2_x = @width/2 + 150 * Math.cos(progress * 4 * Math::PI + Math::PI/2)
            planet2_y = @height/2 + 80 * Math.sin(progress * 4 * Math::PI)
            planet2_color = "rgb(#{100 + 155 * Math.sin(progress * Math::PI)}, #{100 + 155 * Math.sin(progress * Math::PI + 2*Math::PI/3)}, 200)"
            "<circle cx='#{planet2_x}' cy='#{planet2_y}' r='15' fill='#{planet2_color}' opacity='0.9'>
              <animate attributeName='opacity' values='0.7;1;0.7' dur='1.5s' repeatCount='indefinite'/>
            </circle>"
          }
        </g>

        <!-- Étoiles filantes -->
        #{
          stars = []
          5.times do |i|
            star_progress = (progress + i * 0.2) % 1.0
            star_x = @width * star_progress
            star_y = @height * 0.2 + (@height * 0.6) * Math.sin(star_progress * Math::PI)
            star_size = 3 + 2 * Math.sin(star_progress * 10 * Math::PI)
            stars << "<circle cx='#{star_x}' cy='#{star_y}' r='#{star_size}' fill='white' opacity='#{0.3 + 0.7 * Math.sin(star_progress * Math::PI)}'/>"
          end
          stars.join("\n        ")
        }

        <!-- Comète -->
        #{
          comet_progress = progress * 1.5 % 1.0
          comet_x = @width * comet_progress
          comet_y = @height * 0.7 + 100 * Math.sin(comet_progress * 4 * Math::PI)
          comet_tail_length = 30
          "<g>
            <circle cx='#{comet_x}' cy='#{comet_y}' r='8' fill='#00bcd4'/>
            <polygon points='#{comet_x - comet_tail_length},#{comet_y - 5} #{comet_x},#{comet_y} #{comet_x - comet_tail_length},#{comet_y + 5}'
                     fill='#4dd0e1' opacity='0.6'/>
          </g>"
        }

        <!-- Texte d'information -->
        <g font-family="Arial, sans-serif" font-size="14" fill="white">
          <rect x="10" y="10" width="300" height="80" fill="#000000" fill-opacity="0.5" rx="5" ry="5"/>
          <text x="20" y="30">
            <tspan fill="#4fc3f7">Animation Spatiale</tspan>
          </text>
          <text x="20" y="50">
            <tspan fill="#4fc3f7">Frame: #{frame_number + 1}/#{@total_frames}</tspan>
          </text>
          <text x="20" y="70">
            <tspan fill="#4fc3f7">Progression: </tspan>
            <tspan>#{(progress * 100).round(1)}%</tspan>
          </text>
          <text x="20" y="90">
            <tspan fill="#4fc3f7">Objets: Soleil, 2 planètes, étoiles, comète</tspan>
          </text>
        </g>

        <!-- Titre -->
        <text x="#{@width/2}" y="#{@height - 30}" text-anchor="middle" font-family="Arial, sans-serif"
              font-size="20" fill="#bbdefb" font-weight="bold">
          Système Solaire Animé - Test SVG
        </text>

      </svg>
    SVG

    filename = File.join(@output_dir, "space_#{sprintf('%03d', frame_number)}.svg")
    File.write(filename, svg_content)
  end
end

# Générateur de formes géométriques aléatoires
class GeometricSVGAnimator < SVGAnimator
  def generate_frame(frame_number)
    progress = frame_number.to_f / (@total_frames - 1)

    shapes = []
    10.times do |i|
      shape_type = i % 4
      x = @width * (0.1 + 0.8 * Math.sin(progress * Math::PI + i * 0.5))
      y = @height * (0.1 + 0.8 * Math.cos(progress * Math::PI + i * 0.3))
      size = 20 + 15 * Math.sin(progress * 4 * Math::PI + i)
      color = "rgb(#{rand(150..255)}, #{rand(150..255)}, #{rand(150..255)})"

      case shape_type
      when 0
        shapes << "<circle cx='#{x}' cy='#{y}' r='#{size}' fill='#{color}' opacity='0.7'/>"
      when 1
        shapes << "<rect x='#{x - size}' y='#{y - size}' width='#{size * 2}' height='#{size * 2}'
                   fill='#{color}' opacity='0.7' transform='rotate(#{progress * 360}, #{x}, #{y})'/>"
      when 2
        points = ""
        6.times do |j|
          angle = j * 60 * Math::PI / 180
          px = x + size * Math.cos(angle)
          py = y + size * Math.sin(angle)
          points += "#{px},#{py} "
        end
        shapes << "<polygon points='#{points.strip}' fill='#{color}' opacity='0.7'
                   transform='rotate(#{progress * -180}, #{x}, #{y})'/>"
      when 3
        shapes << "<ellipse cx='#{x}' cy='#{y}' rx='#{size}' ry='#{size/2}'
                   fill='#{color}' opacity='0.7'
                   transform='rotate(#{progress * 90}, #{x}, #{y})'/>"
      end
    end

    svg_content = <<~SVG
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
      <svg width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}"
           xmlns="http://www.w3.org/2000/svg" version="1.1">

        <!-- Fond avec motif animé -->
        <defs>
          <pattern id="grid" width="50" height="50" patternUnits="userSpaceOnUse">
            <path d="M 50 0 L 0 0 0 50" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>
          </pattern>
        </defs>

        <rect width="100%" height="100%" fill="#0d1117"/>
        <rect width="100%" height="100%" fill="url(#grid)"/>

        <!-- Formes géométriques animées -->
        #{shapes.join("\n        ")}

        <!-- Lignes de connexion -->
        <g stroke="rgba(100, 200, 255, 0.3)" stroke-width="1" fill="none">
          #{5.times.map { |i|
            x1 = @width * (0.2 + 0.6 * Math.sin(progress * Math::PI + i * 0.4))
            y1 = @height * (0.2 + 0.6 * Math.cos(progress * Math::PI + i * 0.4))
            x2 = @width * (0.2 + 0.6 * Math.sin(progress * Math::PI + (i+1) * 0.4))
            y2 = @height * (0.2 + 0.6 * Math.cos(progress * Math::PI + (i+1) * 0.4))
            "<line x1='#{x1}' y1='#{y1}' x2='#{x2}' y2='#{y2}'/>"
          }.join("\n          ")}
        </g>

        <!-- Texte -->
        <g font-family="Arial, sans-serif" font-size="16" fill="white" text-anchor="middle">
          <text x="#{@width/2}" y="40" font-size="28" fill="#58a6ff">
            Animation Géométrique
          </text>
          <text x="#{@width/2}" y="70">
            Frame #{frame_number + 1}/#{@total_frames} - Progression: #{(progress * 100).round(1)}%
          </text>
          <text x="#{@width/2}" y="#{@height - 40}" font-size="14" fill="#8b949e">
            Formes: Cercles, Carrés, Hexagones, Ellipses
          </text>
        </g>

      </svg>
    SVG

    filename = File.join(@output_dir, "geometric_#{sprintf('%03d', frame_number)}.svg")
    File.write(filename, svg_content)
  end
end

# Menu principal pour choisir le type d'animation
def main
  puts "=============================================="
  puts "  Générateur d'Animations SVG pour Test"
  puts "=============================================="
  puts
  puts "Choisissez le type d'animation à générer :"
  puts "  1. Animation simple (cercle coloré)"
  puts "  2. Animation spatiale (système solaire)"
  puts "  3. Animation géométrique (formes variées)"
  puts "  4. Toutes les animations (3 séquences)"
  puts
  print "Votre choix (1-4) : "

  choice = gets.chomp.to_i

  animations = []

  case choice
  when 1
    animations << ["simple_circle", SVGAnimator.new("svg_animation_simple")]
  when 2
    animations << ["space", MultiObjectSVGAnimator.new("svg_animation_space")]
  when 3
    animations << ["geometric", GeometricSVGAnimator.new("svg_animation_geometric")]
  when 4
    animations << ["simple_circle", SVGAnimator.new("svg_animation_simple")]
    animations << ["space", MultiObjectSVGAnimator.new("svg_animation_space")]
    animations << ["geometric", GeometricSVGAnimator.new("svg_animation_geometric")]
  else
    puts "Choix invalide. Utilisation par défaut : animation simple."
    animations << ["simple_circle", SVGAnimator.new("svg_animation_simple")]
  end

  puts
  puts "Génération en cours..."
  puts

  animations.each do |name, animator|
    puts "=== Génération de l'animation '#{name}' ==="
    animator.generate_animation_sequence
    puts
  end

  puts "=============================================="
  puts "Génération terminée avec succès !"
  puts
  puts "Pour tester avec votre lecteur SVG :"
  puts "  1. Lancez votre application Ruby/GTK3"
  puts "  2. Cliquez sur 'Charger les images'"
  puts "  3. Sélectionnez l'un des dossiers générés :"
  animations.each do |name, animator|
    puts "     - #{animator.instance_variable_get(:@output_dir)}"
  end
  puts
  puts "Appuyez sur Entrée pour quitter..."
  gets
end

if __FILE__ == $0
  main
end
