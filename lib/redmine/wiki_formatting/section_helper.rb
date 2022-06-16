module Redmine
  module WikiFormatting
    module SectionHelper

      def get_section(index)
        section = extract_sections(index)[1]
        hash = Digest::MD5.hexdigest(section)
        return section, hash
      end

      def update_section(index, update, hash=nil)
        t = extract_sections(index)
        if hash.present? && hash != Digest::MD5.hexdigest(t[1])
          raise Redmine::WikiFormatting::StaleSectionError
        end

        t[1] = update unless t[1].blank?
        t.reject(&:blank?).join "\n\n"
      end

      def extract_sections(index)
        sections = [+'', +'', +'']
        offset = 0
        i = 0
        l = 1
        inside_pre = false
        @text.split(/(^(?:\S+\r?\n\r?(?:\=+|\-+)|#+.+|(?:~~~|```).*)\s*$)/).each do |part|
          level = nil
          if part =~ /\A(~{3,}|`{3,})(\s*\S+)?\s*$/
            if !inside_pre
              inside_pre = true
            elsif !$2
              inside_pre = false
            end
          elsif inside_pre
            # nop
          elsif part =~ /\A(#+).+/
            level = $1.size
          elsif part =~ /\A.+\r?\n\r?(\=+|\-+)\s*$/
            level = $1.include?('=') ? 1 : 2
          end
          if level
            i += 1
            if offset == 0 && i == index
              # entering the requested section
              offset = 1
              l = level
            elsif offset == 1 && i > index && level <= l
              # leaving the requested section
              offset = 2
            end
          end
          sections[offset] << part
        end
        sections.map(&:strip)
      end
    end
  end
end