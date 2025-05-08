# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

unless Rails.env.production?
  ICON_RELEASE_VERSION = "v3.19.0"
  ICON_DEFAULT_STYLE = "outline"
  SOURCE = URI.parse("https://raw.githubusercontent.com/tabler/tabler-icons/#{ICON_RELEASE_VERSION}/icons")

  namespace :icons do

    desc 'Downloads default SVG icons'
    task :download do
      icons_mapping = YAML.load_file(Rails.root.join('config/icon_source.yml'))
      destination_path = Rails.root.join("tmp", "icons", "default")

      download_sgv_icons(icons_mapping, destination_path)
    end

    desc "Generates SVG sprite file default SVG icons"
    task :sprite do
      input_path = Rails.root.join("tmp", "icons", "default")
      sprite_path = Rails.root.join('app', 'assets', 'images', 'icons.svg')

      generate_svg_sprite(input_path, sprite_path)
    end

    desc 'Downloads default SVG icons and generates a SVG sprite from the icons'
    task :generate do
      Rake::Task["icons:download"].execute
      Rake::Task["icons:sprite"].execute
    end

    namespace :plugin do
      desc 'Downloads SVG icons for plugin'
      task :download do
        name = ENV['NAME']

        if name.nil?
          abort "The VERSION argument requires a plugin NAME."
        end

        icons_mapping_path = Rails.root.join('plugins', name, 'config', 'icon_source.yml')
        unless File.file?(icons_mapping_path)
          abort "Icon source file for #{name} plugin not found in #{icons_mapping_path}."
        end

        icons_mapping = YAML.load_file(icons_mapping_path)
        destination_path = Rails.root.join("tmp", "icons", name)

        download_sgv_icons(icons_mapping, destination_path)
      end

      desc "Generates SVG sprite for plugin"
      task :sprite do
        name = ENV['NAME']

        if name.nil?
          abort "The VERSION argument requires a plugin NAME."
        end

        input_path = Rails.root.join("tmp", "icons", name)
        sprite_path = Rails.root.join('plugins', name, 'assets', 'images', 'icons.svg')

        generate_svg_sprite(input_path, sprite_path)
      end

      desc 'Downloads SVG icons and generates sprite for plugin'
      task :generate do
        Rake::Task["icons:plugin:download"].execute
        Rake::Task["icons:plugin:sprite"].execute
      end
    end
  end

  def download_sgv_icons(icons_mapping, destination)
    http = Net::HTTP.new(SOURCE.host, SOURCE.port)
    http.use_ssl = true

    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)

    icons_mapping.each do |v|
      name = v['name']
      svg = v['svg']
      style = v['style'] || ICON_DEFAULT_STYLE

      http.start do |h|
        source = "#{SOURCE}/#{style}/#{svg}.svg"

        puts "Downloading #{name} from #{source}..."
        req = Net::HTTP::Get.new(source)
        res = h.request(req)

        case res
        when Net::HTTPSuccess
          target = File.join(destination, "#{name}.svg")
          File.open(target, 'w') do |f|
            f.write res.body
          end
        else
          abort "Error when trying to download the icon for #{name}"
        end
      end
    end
  end

  def generate_svg_sprite(input_path, sprite_path)
    require "svg_sprite"

    SvgSprite.call(
      input: input_path,
      name: 'icon',
      css_path:  File.join(input_path, 'icons.css'),
      sprite_path: sprite_path,
      optimize: true
    )

    doc = Nokogiri::XML(sprite_path)

    doc.traverse do |node|
      node.keys.each do |attribute|
        node.delete attribute if ["fill", "stroke", "stroke-width"].include?(attribute)
      end
    end

    File.write(sprite_path, doc.to_xml)
  end
end
