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

    def self.to_utf8(str, encoding)
      return str if str.nil?
      str.force_encoding("ASCII-8BIT") if str.respond_to?(:force_encoding)
      if str.empty?
        str.force_encoding("UTF-8") if str.respond_to?(:force_encoding)
        return str
      end
      enc = encoding.blank? ? "UTF-8" : encoding
      if str.respond_to?(:force_encoding)
        if enc.upcase != "UTF-8"
          str.force_encoding(enc)
          str = str.encode("UTF-8", :invalid => :replace,
                :undef => :replace, :replace => '?')
        else
          str.force_encoding("UTF-8")
          if ! str.valid_encoding?
            str = str.encode("US-ASCII", :invalid => :replace,
                  :undef => :replace, :replace => '?').encode("UTF-8")
          end
        end
      elsif RUBY_PLATFORM == 'java'
        begin
          ic = Iconv.new('UTF-8', enc)
          str = ic.iconv(str)
        rescue
          str = str.gsub(%r{[^\r\n\t\x20-\x7e]}, '?')
        end
      else
        ic = Iconv.new('UTF-8', enc)
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

    def self.to_utf8_by_setting(str)
      return str if str.nil?
      str = self.to_utf8_by_setting_internal(str)
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
      end
      str
    end

    def self.to_utf8_by_setting_internal(str)
      return str if str.nil?
      if str.respond_to?(:force_encoding)
        str.force_encoding('ASCII-8BIT')
      end
      return str if str.empty?
      return str if /\A[\r\n\t\x20-\x7e]*\Z/n.match(str) # for us-ascii
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
      end
      encodings = Setting.repositories_encodings.split(',').collect(&:strip)
      encodings.each do |encoding|
        begin
          return Iconv.conv('UTF-8', encoding, str)
        rescue Iconv::Failure
          # do nothing here and try the next encoding
        end
      end
      str = self.replace_invalid_utf8(str)
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
      end
      str
    end

    def self.from_utf8(str, encoding)
      str ||= ''
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
        if encoding.upcase != 'UTF-8'
          str = str.encode(encoding, :invalid => :replace,
                           :undef => :replace, :replace => '?')
        else
          str = self.replace_invalid_utf8(str)
        end
      elsif RUBY_PLATFORM == 'java'
        begin
          ic = Iconv.new(encoding, 'UTF-8')
          str = ic.iconv(str)
        rescue
          str = str.gsub(%r{[^\r\n\t\x20-\x7e]}, '?')
        end
      else
        ic = Iconv.new(encoding, 'UTF-8')
        txtar = ""
        begin
          txtar += ic.iconv(str)
        rescue Iconv::IllegalSequence
          txtar += $!.success
          str = '?' + $!.failed[1, $!.failed.length]
          retry
        rescue
          txtar += $!.success
        end
        str = txtar
      end
    end
  end
end
