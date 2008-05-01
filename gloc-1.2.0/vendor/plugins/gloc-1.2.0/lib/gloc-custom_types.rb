# Copyright (c) 2005-2007 David Barri

module GLoc
  class CustomType
    include ::GLoc::Constants

    def self.is_valid_type?(type)
      [:array, :datetime_fmt, :hash, :lambda, :proc, :sameas].include? type
    end
    
    def initialize(lang,type,value,charset)
      @lang= lang
      @type= type.to_sym
      raise UnsupportedValueTypeError.new("Unsupported value type: '#{@type}'") unless self.class.is_valid_type?(@type)
      [:set_value].each {|m|
        instance_eval "alias :#{m} :#{@type}_#{m}"
      }
      [:set_charset, :value_with_args].each {|m|
        m2= :"#{@type}_#{m}"
        instance_eval "alias :#{m} :#{m2}" if respond_to?(m2)
      }
      @original_value= value
      @original_charset= charset
      set_value value
    end

    def set_charset(new_charset)
      set_value Iconv.iconv(new_charset, @original_charset, @original_value)[0]
    end
    
    def value
      @value
    end

    def value_with_args(*args)
      raise InvalidArgumentsError.new("The custom type '#{@type}' does not accept arguments.") unless args.empty?
      @value
    end
    
    #===========================================================================
    # Array
    
    def array_set_charset(charset)
      Iconv.open(charset, @original_charset) {|iconv|
        array_set_value2 @original_value, iconv, charset
      }
    end
    
    def array_set_value(a)
      array_set_value2 a, nil, nil
    end
    
    def array_set_value2(a, iconv, charset)
      @value= []
      a.each_index {|i|
        @value[i]= GLoc._internalize_value(a[i], @lang, @original_charset)
        @value[i]= GLoc._set_value_charset(@value[i], iconv, charset) if iconv
        @value[i]= @value[i].value_with_args() if @value[i].is_a?(CustomType)
      }
    end
    private :array_set_value2
    
    #===========================================================================
    # datetime_fmt
    
    def datetime_fmt_set_value(v)
      v2= v.gsub('%%',"\0")
      subs= {
          :a => v2.include?('%a'),
          :A => v2.include?('%A'),
          :b => v2.include?('%b'),
          :B => v2.include?('%B'),
        }
      x= nil
      if subs.values.include?(true)
        x= "v= #{v2.inspect};"
        x<< "v.gsub! '%a', GLoc.ll(@lang,:general_text_day_names_abbr  )[d.wday];"    if subs[:a]
        x<< "v.gsub! '%A', GLoc.ll(@lang,:general_text_day_names       )[d.wday];"    if subs[:A]
        x<< "v.gsub! '%b', GLoc.ll(@lang,:general_text_month_names_abbr)[d.month-1];" if subs[:b]
        x<< "v.gsub! '%B', GLoc.ll(@lang,:general_text_month_names     )[d.month-1];" if subs[:B]
        x<< %[v.gsub! "\0", '%%';]
        x<< 'd.strftime v'
      else
        x= "d.strftime #{v.inspect}"
      end
      @value= eval "lambda do |d| #{x} end"
    end
    
    def datetime_fmt_value_with_args(*args)
      @value.call(*args)
    end
    
    #===========================================================================
    # Hash
    
    def hash_set_charset(charset)
      Iconv.open(charset, @original_charset) {|iconv|
        hash_set_value2 @original_value, iconv, charset
      }
    end
    
    def hash_set_value(h)
      hash_set_value2 h, nil, nil
    end
    
    def hash_set_value2(h, iconv, charset)
      @value= {}
      h.each {|k,v|
        hash_set_value3 k, v, iconv, charset
        sk= k.is_a?(String) ? (k.to_sym rescue nil) : nil
        hash_set_value3 sk, v, iconv, charset if sk && !@value.has_key?(sk)
      }
    end
    def hash_set_value3(k, v, iconv, charset)
      @value[k]= GLoc._internalize_value(v, @lang, @original_charset)
      @value[k]= GLoc._set_value_charset(@value[k], iconv, charset) if iconv
      @value[k]= @value[k].value_with_args() if @value[k].is_a?(CustomType)
    end
    private :hash_set_value2, :hash_set_value3
    
    #===========================================================================
    # Lambda
    
    def lambda_set_charset(new_charset)
      @iconv_for_output.close if @iconv_for_output
      @iconv_for_output= (new_charset == UTF_8 ? nil : Iconv.new(new_charset,UTF_8))
    end
    
    def lambda_set_value(v)
      lambda_set_value2 :lambda, 'lambda', v
    end
    
    def lambda_set_value2(type, lambda_creation, v)
      send "#{type}_set_charset", @original_charset
      v= Iconv.iconv(UTF_8,@original_charset,v)[0] unless @original_charset == UTF_8
      @value= eval "#{lambda_creation} do #{v} end"
    end
    private :lambda_set_value2
    
    def lambda_value_with_args(*args)
      if @iconv_for_output
        @iconv_for_output.iconv @value.call(*args)
      else
        @value.call(*args)
      end
    end
    
    #===========================================================================
    # Proc
    
    def proc_set_value(v)
      lambda_set_value2 :proc, 'Proc.new', v
    end
    
    alias :proc_set_charset :lambda_set_charset
    alias :proc_value_with_args :lambda_value_with_args
    
    #===========================================================================
    # sameas
    
    def sameas_set_charset(charset)
    end
    
    def sameas_set_value(v)
      @key= v.to_s
    end
    
    def sameas_value_with_args(*args)
      GLoc.ll(@lang,@key,*args)
    end
    
  end
end