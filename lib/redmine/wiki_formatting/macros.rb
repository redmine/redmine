# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

module Redmine
  module WikiFormatting
    module Macros
      module Definitions
        def exec_macro(name, obj, args)
          macro_options = Redmine::WikiFormatting::Macros.available_macros[name.to_sym]
          return unless macro_options

          method_name = "macro_#{name}"
          unless macro_options[:parse_args] == false
            args = args.split(',').map(&:strip)
          end
          send(method_name, obj, args) if respond_to?(method_name)
        end

        def extract_macro_options(args, *keys)
          options = {}
          while args.last.to_s.strip =~ %r{^(.+)\=(.+)$} && keys.include?($1.downcase.to_sym)
            options[$1.downcase.to_sym] = $2
            args.pop
          end
          return [args, options]
        end
      end

      @@available_macros = {}
      mattr_accessor :available_macros

      class << self
        # Called with a block to define additional macros.
        # Macro blocks accept 2 arguments:
        # * obj: the object that is rendered
        # * args: macro arguments
        #
        # Plugins can use this method to define new macros:
        #
        #   Redmine::WikiFormatting::Macros.register do
        #     desc "This is my macro"
        #     macro :my_macro do |obj, args|
        #       "My macro output"
        #     end
        #   end
        def register(&block)
          class_eval(&block) if block_given?
        end

        # Defines a new macro with the given name, options and block.
        #
        # Options:
        # * :parse_args => false - Disables arguments parsing (the whole arguments string
        #   is passed to the macro)
        #
        # Examples:
        # By default, when the macro is invoked, the coma separated list of arguments
        # is parsed and passed to the macro block as an array:
        #
        #   macro :my_macro do |obj, args|
        #     # args is an array
        #   end
        #
        # You can disable arguments parsing with the :parse_args => false option:
        #
        #   macro :my_macro, :parse_args => false do |obj, args|
        #     # args is a string
        #   end
        def macro(name, options={}, &block)
          name = name.to_sym if name.is_a?(String)
          @@available_macros[name] = {:desc => @@desc || ''}.merge(options)
          @@desc = nil
          raise "Can not create a macro without a block!" unless block_given?
          Definitions.send :define_method, "macro_#{name}".downcase, &block
        end

        # Sets description for the next macro to be defined
        def desc(txt)
          @@desc = txt
        end
      end

      # Builtin macros
      desc "Sample macro."
      macro :hello_world do |obj, args|
        "Hello world! Object: #{obj.class.name}, " + (args.empty? ? "Called with no argument." : "Arguments: #{args.join(', ')}")
      end

      desc "Displays a list of all available macros, including description if available."
      macro :macro_list do |obj, args|
        out = ''.html_safe
        @@available_macros.each do |macro, options|
          out << content_tag('dt', content_tag('code', macro.to_s))
          out << content_tag('dd', textilizable(options[:desc]))
        end
        content_tag('dl', out)
      end

      desc "Displays a list of child pages. With no argument, it displays the child pages of the current wiki page. Examples:\n\n" +
             "  !{{child_pages}} -- can be used from a wiki page only\n" +
             "  !{{child_pages(Foo)}} -- lists all children of page Foo\n" +
             "  !{{child_pages(Foo, parent=1)}} -- same as above with a link to page Foo"
      macro :child_pages do |obj, args|
        args, options = extract_macro_options(args, :parent)
        page = nil
        if args.size > 0
          page = Wiki.find_page(args.first.to_s, :project => @project)
        elsif obj.is_a?(WikiContent) || obj.is_a?(WikiContent::Version)
          page = obj.page
        else
          raise 'With no argument, this macro can be called from wiki pages only.'
        end
        raise 'Page not found' if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)
        pages = ([page] + page.descendants).group_by(&:parent_id)
        render_page_hierarchy(pages, options[:parent] ? page.parent_id : page.id)
      end

      desc "Include a wiki page. Example:\n\n  !{{include(Foo)}}\n\nor to include a page of a specific project wiki:\n\n  !{{include(projectname:Foo)}}"
      macro :include do |obj, args|
        page = Wiki.find_page(args.first.to_s, :project => @project)
        raise 'Page not found' if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)
        @included_wiki_pages ||= []
        raise 'Circular inclusion detected' if @included_wiki_pages.include?(page.title)
        @included_wiki_pages << page.title
        out = textilizable(page.content, :text, :attachments => page.attachments, :headings => false)
        @included_wiki_pages.pop
        out
      end

      desc "Displays a clickable thumbnail of an attached image. Examples:\n\n<pre>{{thumbnail(image.png)}}\n{{thumbnail(image.png, size=300, title=Thumbnail)}}</pre>"
      macro :thumbnail do |obj, args|
        args, options = extract_macro_options(args, :size, :title)
        filename = args.first
        raise 'Filename required' unless filename.present?
        size = options[:size]
        raise 'Invalid size parameter' unless size.nil? || size.match(/^\d+$/)
        size = size.to_i
        size = nil unless size > 0
        if obj && obj.respond_to?(:attachments) && attachment = Attachment.latest_attach(obj.attachments, filename)
          title = options[:title] || attachment.title
          img = image_tag(url_for(:controller => 'attachments', :action => 'thumbnail', :id => attachment, :size => size), :alt => attachment.filename)
          link_to(img, url_for(:controller => 'attachments', :action => 'show', :id => attachment), :class => 'thumbnail', :title => title)
        else
          raise "Attachment #{filename} not found"
        end
      end
    end
  end
end
