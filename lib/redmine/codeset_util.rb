require 'iconv'

module Redmine
  module CodesetUtil

    def self.replace_invalid_utf8(str)
      return str if str.nil?
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
        if ! str.valid_encoding?
          str = str.encode("US-ASCII", :invalid => :replace,
                :undef => :replace, :replace => '?').encode("UTF-8")
        end
      elsif RUBY_PLATFORM == 'java'
        begin
          ic = Iconv.new('UTF-8', 'UTF-8')
          str = ic.iconv(str)
        rescue
          str = str.gsub(%r{[^\r\n\t\x20-\x7e]}, '?')
        end
      else
        ic = Iconv.new('UTF-8', 'UTF-8')
        txtar = ""
        begin
          txtar += ic.iconv(str)
        rescue Iconv::IllegalSequence
          txtar += $!.success
          str = '?' + $!.failed[1,$!.failed.length]
          retry
        rescue
          txtar += $!.success
        end
        str = txtar
      end
      str
    end
  end
end
