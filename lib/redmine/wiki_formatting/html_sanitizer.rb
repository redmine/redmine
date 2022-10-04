module Redmine
  module WikiFormatting

    # Combination of SanitizationFilter and ExternalLinksFilter
    class HtmlSanitizer

      Pipeline = HTML::Pipeline.new([
        Redmine::WikiFormatting::CommonMark::SanitizationFilter,
        Redmine::WikiFormatting::CommonMark::ExternalLinksFilter,
      ], {})

      def self.call(html)
        result = Pipeline.call html
        result[:output].to_s
      end
    end

  end
end

