# frozen_string_literal: true

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

module Redmine
  module WikiFormatting
    module Macros
      module Definitions
        # Returns true if +name+ is the name of an existing macro
        def macro_exists?(name)
          Redmine::WikiFormatting::Macros.available_macros.key?(name.to_sym)
        end

        def exec_macro(name, obj, args, text, options={})
          macro_options = Redmine::WikiFormatting::Macros.available_macros[name.to_sym]
          return unless macro_options

          if options[:inline_attachments] == false
            Redmine::WikiFormatting::Macros.inline_attachments = false
          else
            Redmine::WikiFormatting::Macros.inline_attachments = true
          end

          method_name = "macro_#{name}"
          unless macro_options[:parse_args] == false
            args = args.split(',').map(&:strip)
          end

          begin
            if self.class.instance_method(method_name).arity == 3
              send(method_name, obj, args, text)
            elsif text
              raise t(:error_macro_does_not_accept_block)
            else
              send(method_name, obj, args)
            end
          rescue => e
            %|<div class="flash error">#{t(:error_can_not_execute_macro_html, :name => name, :error => e.to_s)}</div>|.html_safe
          end
        end

        def extract_macro_options(args, *keys)
          options = {}
          while args.last.to_s.strip =~ %r{^(.+?)\=(.+)$} && keys.include?($1.downcase.to_sym)
            options[$1.downcase.to_sym] = $2
            args.pop
          end
          return [args, options]
        end
      end

      @@available_macros = {}
      @@inline_attachments = true
      mattr_accessor :available_macros
      mattr_accessor :inline_attachments

      class << self
        # Plugins can use this method to define new macros:
        #
        #   Redmine::WikiFormatting::Macros.register do
        #     desc "This is my macro"
        #     macro :my_macro do |obj, args|
        #       "My macro output"
        #     end
        #
        #     desc "This is my macro that accepts a block of text"
        #     macro :my_macro do |obj, args, text|
        #       "My macro output"
        #     end
        #   end
        def register(&block)
          class_eval(&block) if block_given?
        end

        # Defines a new macro with the given name, options and block.
        #
        # Options:
        # * :desc - A description of the macro
        # * :parse_args => false - Disables arguments parsing (the whole arguments
        #   string is passed to the macro)
        #
        # Macro blocks accept 2 or 3 arguments:
        # * obj: the object that is rendered (eg. an Issue, a WikiContent...)
        # * args: macro arguments
        # * text: the block of text given to the macro (should be present only if the
        #   macro accepts a block of text). text is a String or nil if the macro is
        #   invoked without a block of text.
        #
        # Examples:
        # By default, when the macro is invoked, the comma separated list of arguments
        # is split and passed to the macro block as an array. If no argument is given
        # the macro will be invoked with an empty array:
        #
        #   macro :my_macro do |obj, args|
        #     # args is an array
        #     # and this macro do not accept a block of text
        #   end
        #
        # You can disable arguments spliting with the :parse_args => false option. In
        # this case, the full string of arguments is passed to the macro:
        #
        #   macro :my_macro, :parse_args => false do |obj, args|
        #     # args is a string
        #   end
        #
        # Macro can optionally accept a block of text:
        #
        #   macro :my_macro do |obj, args, text|
        #     # this macro accepts a block of text
        #   end
        #
        # Macros are invoked in formatted text using double curly brackets. Arguments
        # must be enclosed in parenthesis if any. A new line after the macro name or the
        # arguments starts the block of text that will be passe to the macro (invoking
        # a macro that do not accept a block of text with some text will fail).
        # Examples:
        #
        #   No arguments:
        #   {{my_macro}}
        #
        #   With arguments:
        #   {{my_macro(arg1, arg2)}}
        #
        #   With a block of text:
        #   {{my_macro
        #   multiple lines
        #   of text
        #   }}
        #
        #   With arguments and a block of text
        #   {{my_macro(arg1, arg2)
        #   multiple lines
        #   of text
        #   }}
        #
        # If a block of text is given, the closing tag }} must be at the start of a new line.
        def macro(name, options={}, &block)
          options.assert_valid_keys(:desc, :parse_args)
          unless /\A\w+\z/.match?(name.to_s)
            raise "Invalid macro name: #{name} (only 0-9, A-Z, a-z and _ characters are accepted)"
          end
          unless block_given?
            raise "Can not create a macro without a block!"
          end

          name = name.to_s.downcase.to_sym
          available_macros[name] = {:desc => @@desc || ''}.merge(options)
          @@desc = nil
          Definitions.send :define_method, "macro_#{name}", &block
        end

        # Sets description for the next macro to be defined
        def desc(txt)
          @@desc = txt
        end
      end

      # Builtin macros
      desc "Sample macro."
      macro :hello_world do |obj, args, text|
        h(
          "Hello world! Object: #{obj.class.name}, " +
          (args.empty? ? "Called with no argument" : "Arguments: #{args.join(', ')}") +
          " and " + (text.present? ? "a #{text.size} bytes long block of text." : "no block of text.")
        )
      end

      desc "Displays a list of all available macros, including description if available."
      macro :macro_list do |obj, args|
        out = ''.html_safe
        @@available_macros.each do |macro, options|
          out << content_tag('dt', content_tag('code', macro.to_s))
          out << content_tag('dd', content_tag('pre', options[:desc]))
        end
        content_tag('dl', out)
      end

      desc "Displays a list of child pages. With no argument, it displays the child pages of the current wiki page. Examples:\n\n" +
             "{{child_pages}} -- can be used from a wiki page only\n" +
             "{{child_pages(depth=2)}} -- display 2 levels nesting only\n" +
             "{{child_pages(Foo)}} -- lists all children of page Foo\n" +
             "{{child_pages(Foo, parent=1)}} -- same as above with a link to page Foo"
      macro :child_pages do |obj, args|
        args, options = extract_macro_options(args, :parent, :depth)
        options[:depth] = options[:depth].to_i if options[:depth].present?

        page = nil
        if args.size > 0
          page = Wiki.find_page(args.first.to_s, :project => @project)
        elsif obj.is_a?(WikiContent) || obj.is_a?(WikiContentVersion)
          page = obj.page
        else
          raise t(:error_childpages_macro_no_argument)
        end
        raise t(:error_page_not_found) if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)

        pages = page.self_and_descendants(options[:depth]).group_by(&:parent_id)
        render_page_hierarchy(pages, options[:parent] ? page.parent_id : page.id)
      end

      desc "Includes a wiki page. Examples:\n\n" +
             "{{include(Foo)}}\n" +
             "{{include(projectname:Foo)}} -- to include a page of a specific project wiki"
      macro :include do |obj, args|
        page = Wiki.find_page(args.first.to_s, :project => @project)
        raise t(:error_page_not_found) if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)

        @included_wiki_pages ||= []
        raise t(:error_circular_inclusion) if @included_wiki_pages.include?(page.id)

        @included_wiki_pages << page.id
        out =
          textilizable(
            page.content,
            :text,
            :attachments => page.attachments,
            :headings => false,
            :inline_attachments => @@inline_attachments
          )
        @included_wiki_pages.pop
        out
      end

      desc "Inserts of collapsed block of text. Examples:\n\n" +
             "{{collapse\nThis is a block of text that is collapsed by default.\nIt can be expanded by clicking a link.\n}}\n\n" +
             "{{collapse(View details...)\nWith custom link text.\n}}"
      macro :collapse do |obj, args, text|
        html_id = "collapse-#{Redmine::Utils.random_hex(4)}"
        show_label = args[0] || l(:button_show)
        hide_label = args[1] || args[0] || l(:button_hide)
        js = "$('##{html_id}-show, ##{html_id}-hide').toggle(); $('##{html_id}').fadeToggle(150);"
        out = ''.html_safe
        out << link_to_function(show_label, js, :id => "#{html_id}-show", :class => 'icon icon-collapsed collapsible')
        out <<
          link_to_function(
            hide_label, js,
            :id => "#{html_id}-hide",
            :class => 'icon icon-expanded collapsible',
            :style => 'display:none;'
          )
        out <<
          content_tag(
            'div',
            textilizable(text, :object => obj, :headings => false,
                         :inline_attachments => @@inline_attachments),
            :id => html_id, :class => 'collapsed-text',
            :style => 'display:none;'
          )
        out
      end

      desc "Displays a clickable thumbnail of an attached image.\n" +
             "Default size is 200 pixels. Examples:\n\n" +
             "{{thumbnail(image.png)}}\n" +
             "{{thumbnail(image.png, size=300, title=Thumbnail)}} -- with custom title and size"
      macro :thumbnail do |obj, args|
        args, options = extract_macro_options(args, :size, :title)
        filename = args.first
        raise t(:error_filename_required) unless filename.present?

        size = options[:size]
        raise t(:error_invalid_size_parameter) unless size.nil? || /^\d+$/.match?(size)

        size = size.to_i
        size = 200 unless size > 0

        container = obj.is_a?(Journal) ? obj.journalized : obj
        attachments = container.attachments if container.respond_to?(:attachments)
        if (controller_path == 'previews' || action_name == 'preview') && @attachments.present?
          attachments = (attachments.to_a + @attachments).compact
        end
        if attachments.present? && (attachment = Attachment.latest_attach(attachments, filename))
          title = options[:title] || attachment.title
          thumbnail_url =
            url_for(:controller => 'attachments', :action => 'thumbnail',
                    :id => attachment, :size => size, :only_path => @only_path)
          image_url =
            url_for(:controller => 'attachments', :action => 'show',
                    :id => attachment, :only_path => @only_path)
          img = image_tag(thumbnail_url, :alt => attachment.filename)
          link_to(img, image_url, :class => 'thumbnail', :title => title)
        else
          raise t(:error_attachment_not_found, :name => filename)
        end
      end

      desc "Displays an issue link including additional information. Examples:\n\n" +
             "{{issue(123)}}                              -- Issue #123: Enhance macro capabilities\n" +
             "{{issue(123, project=true)}}                -- Andromeda - Issue #123: Enhance macro capabilities\n" +
             "{{issue(123, tracker=false)}}               -- #123: Enhance macro capabilities\n" +
             "{{issue(123, subject=false, project=true)}} -- Andromeda - Issue #123\n"
      macro :issue do |obj, args|
        args, options = extract_macro_options(args, :project, :subject, :tracker)
        id = args.first
        issue = Issue.visible.find_by(id: id)

        if issue
          # remove invalid options
          options.delete_if {|k, v| v != 'true' && v != 'false'}

          # turn string values into boolean
          options.each do |k, v|
            options[k] = v == 'true'
          end

          link_to_issue(issue, options)
        else
          # Fall back to regular issue link format to indicate, that there
          # should have been something.
          "##{id}"
        end
      end
    end
  end
end
