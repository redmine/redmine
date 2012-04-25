$:.unshift "#{File.dirname(__FILE__)}/tmail-1.2.7"

require 'tmail'

module TMail
  # TMail::Unquoter.convert_to_with_fallback_on_iso_8859_1 introduced in TMail 1.2.7
  # triggers a test failure in test_add_issue_with_japanese_keywords(MailHandlerTest)
  class Unquoter
    class << self
      alias_method :convert_to, :convert_to_without_fallback_on_iso_8859_1
    end
  end

  # Patch for TMail 1.2.7. See http://www.redmine.org/issues/8751
  class Encoder
    def puts_meta(str)
      add_text str
    end
  end
end
