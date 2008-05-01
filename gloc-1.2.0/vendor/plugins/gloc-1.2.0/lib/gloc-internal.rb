# Copyright (c) 2005-2007 David Barri

require 'iconv'
require 'yaml'
require 'gloc-constants'
require 'gloc-custom_types'

module GLoc
  class GLocError < StandardError #:nodoc:
  end
  class InvalidArgumentsError < GLocError #:nodoc:
  end
  class InvalidKeyError < GLocError #:nodoc:
  end
  class RuleNotFoundError < GLocError #:nodoc:
  end
  class StringNotFoundError < GLocError #:nodoc:
  end
  class UnsupportedValueTypeError < GLocError #:nodoc:
  end
  
  class << self
    include ::GLoc::Constants
    private
    
    def _add_localized_data(lang, symbol_hash, override, target) #:nodoc:
      lang= lang.to_sym
      if override
        target[lang] ||= {}
        target[lang].merge!(symbol_hash)
      else
        symbol_hash.merge!(target[lang]) if target[lang]
        target[lang]= symbol_hash
      end
    end
    
    def _add_localized_strings(lang, symbol_hash, override=true, strings_charset=nil) #:nodoc:
      _charset_required
      
      # Convert all incoming strings to the gloc charset
      if strings_charset
        Iconv.open(get_charset(lang), strings_charset) do |i|
          symbol_hash.each_pair {|k,v| symbol_hash[k]= i.iconv(v)}
        end
      end

      # Convert rules
      rules= {}
      old_kcode= $KCODE
      begin
        $KCODE= 'u'
        Iconv.open(UTF_8, get_charset(lang)) do |i|
          symbol_hash.each {|k,v|
            if /^_gloc_rule_(.+)$/ =~ k.to_s
              v= i.iconv(v) if v
              v= '""' if v.nil?
              rules[$1.to_sym]= eval "Proc.new do #{v} end"
            end
          }
        end
      ensure
        $KCODE= old_kcode
      end
      rules.keys.each {|k| symbol_hash.delete "_gloc_rule_#{k}".to_sym}
      
      # Add new localized data
      LOWERCASE_LANGUAGES[lang.to_s.downcase]= lang
      _add_localized_data(lang, symbol_hash, override, LOCALIZED_STRINGS)
      _add_localized_data(lang, rules, override, RULES)
    end
    
    def _charset_required #:nodoc:
      set_charset UTF_8 unless CONFIG[:internal_charset]
    end
    
    def _get_internal_state_vars #:nodoc:
      [ CONFIG, LOCALIZED_STRINGS, RULES, LOWERCASE_LANGUAGES ]
    end
    
    def _get_lang_file_list(dir) #:nodoc:
      dir= File.join(RAILS_ROOT,'{.,vendor/plugins/*}','lang') if dir.nil?
      Dir[File.join(dir,'*.{yaml,yml}')]
    end
    
    def _internalize_value(value, lang, charset) #:nodoc:
      case value
      when YAML::PrivateType, YAML_PRIVATETYPE2
        CustomType.new(lang, value.type_id, value.value, charset)
      when Array
        CustomType.new(lang, :array, value, charset)
      when Hash
        CustomType.new(lang, :hash, value, charset)
      when nil
        ''
      when String, Symbol, Fixnum, true, false
        value
      else
        raise UnsupportedValueTypeError.new("Unsupported value type: #{value.class}")
      end
    end
    
    def _l(key, language, *arguments) #:nodoc:
      translation= _l_without_args(key, language)
      case translation
      when String
        begin
          translation % arguments
        rescue => e
          raise InvalidArgumentsError.new("Translation value #{translation.inspect} with arguments #{arguments.inspect} caused error '#{e.message}'")
        end
      when CustomType
        translation.value_with_args(*arguments)
      else
        translation
      end
    end
    
    def _l_without_args(key, language) #:nodoc:
      key= key.to_sym if key.is_a?(String)
      raise InvalidKeyError.new("Symbol or String expected as key.") unless key.kind_of?(Symbol)
      
      translation= LOCALIZED_STRINGS[language][key] rescue nil
      if translation.nil? && !_l_has_string?(key,language)
        raise StringNotFoundError.new("There is no key called '#{key}' in the #{language} strings.") if CONFIG[:raise_string_not_found_errors]
        translation= key.to_s
      end
      
      translation
    end
  
    def _l_has_string?(symbol,lang) #:nodoc:
      symbol= symbol.to_sym if symbol.is_a?(String)
      LOCALIZED_STRINGS[lang].has_key?(symbol.to_sym) rescue false
    end

    def _l_rule(symbol,lang) #:nodoc:
      symbol= symbol.to_sym if symbol.is_a?(String)
      raise InvalidKeyError.new("Symbol or String expected as key.") unless symbol.kind_of?(Symbol)

      r= RULES[lang][symbol] rescue nil
      raise RuleNotFoundError.new("There is no rule called '#{symbol}' in the #{lang} rules.") if r.nil?
      r
    end
    
    def _set_value_charset(v, iconv, charset) #:nodoc:
      case v
      when String     then iconv.iconv(v)
      when CustomType then v.set_charset(charset); v
      else v
      end
    end
    
    def _verbose_msg(type=nil) #:nodoc:
      return unless CONFIG[:verbose]
      x= case type
        when :stats
          x= valid_languages.map{|l| ":#{l}(#{LOCALIZED_STRINGS[l].size}/#{RULES[l].size})"}.sort.join(', ')
          "Current stats -- #{x}"
        else
          yield
        end
      puts "[GLoc] #{x}"
    end

    public :_l, :_l_has_string?, :_l_rule, :_l_without_args, :_internalize_value, :_set_value_charset
  end
end
