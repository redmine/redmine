module ApplicationHelperPatch
  def self.included(base)
    base.class_eval do

      # Resolve whether the text given is 'textile' or 'markdown'. Fall back to 'markdown' if the text is not recognized.
      def detect_format(text)
        # Regular expressions to match patterns specific to CommonMark (Markdown) and Textile
      
        # Markdown patterns
        markdown_patterns = [
          /^\#{1,6}\s/,  # Headings like #, ##, ###, etc.
          /\*\*.*?\*\*/, # Bold text like **bold**
          /\*.*?\*/,     # Italic text like *italic*
          /\[.*?\]\(.*?\)/, # Links like [text](url)
          /\!\[.*?\]\(.*?\)/ # Images like ![alt text](url)
        ]
      
        # Textile patterns
        textile_patterns = [
          /^h[1-6]\.\s/,   # Headings like h1., h2., etc.
          /\*\*.*?\*\*/,   # Bold text like **bold**
          /_.*?_/,         # Italic text like _italic_
          /\".*?\":.*?/,   # Links like "text":url
          /!\{.*?\}/       # Images like !{image-url}
        ]
      
        # Check for Markdown patterns
        markdown_detected = markdown_patterns.any? { |pattern| text.match?(pattern) }
      
        # Check for Textile patterns
        textile_detected = textile_patterns.any? { |pattern| text.match?(pattern) }
      
        if markdown_detected && !textile_detected
          'common_mark'
        elsif textile_detected && !markdown_detected
          'textile'
        else
          'common_mark'
        end
      end

      # Formats text according to system settings.
      # 2 ways to call this method:
      # * with a String: textilizable(text, options)
      # * with an object and one of its attribute: textilizable(issue, :description, options)
      def textilizable(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        case args.size
        when 1
          obj = options[:object]
          text = args.shift
        when 2
          obj = args.shift
          attr = args.shift
          text = obj.send(attr).to_s
        else
          raise ArgumentError, 'invalid arguments to textilizable'
        end
        return '' if text.blank?

        project = options[:project] || @project || (obj && obj.respond_to?(:project) ? obj.project : nil)
        @only_path = only_path = options.delete(:only_path) == false ? false : true

        text = text.dup
        macros = catch_macros(text)

        if options[:formatting] == false
          text = h(text)
        else
          # Old non dynamic text_formatting
          # formatting = Setting.text_formatting

          # New dynamic text_formatting which resolves the text formatting from the given text
          formatting = detect_format(text)
          text = Redmine::WikiFormatting.to_html(formatting, text, :object => obj, :attribute => attr)
        end

        @parsed_headings = []
        @heading_anchors = {}
        @current_section = 0 if options[:edit_section_links]

        parse_sections(text, project, obj, attr, only_path, options)
        text = parse_non_pre_blocks(text, obj, macros, options) do |txt|
          [:parse_inline_attachments, :parse_hires_images, :parse_wiki_links, :parse_redmine_links].each do |method_name|
            send method_name, txt, project, obj, attr, only_path, options
          end
        end
        parse_headings(text, project, obj, attr, only_path, options)

        if @parsed_headings.any?
          replace_toc(text, @parsed_headings)
        end

        text.html_safe
      end
    end
  end
end