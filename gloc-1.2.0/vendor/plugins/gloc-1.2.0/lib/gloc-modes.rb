# Copyright (c) 2005-2007 David Barri

module GLoc
  class << self
    # Changes the way in which <tt>current_language</tt> and <tt>set_language</tt> work.
    # The available modes are <tt>:simple</tt> and <tt>:cascading</tt>.
    # 
    # In simple mode, the current language setting is global (which is fine for 99% of all apps and situations).
    # 
    # In cascading mode, everything that includes the GLoc module (instances, classes + modules) have their own
    # language setting. The language is determined as such: instance -> class -> global setting. This was the
    # way the GLoc worked up until v1.2.0.
    def set_language_mode(mode)
      case mode
      #------------------------------------------------------------------------
      when :simple
        eval <<EOB
module ::GLoc
  def current_language
    GLoc::Constants::CONFIG[:default_language]
  end
  
  class << self
    def current_language
      CONFIG[:default_language]
    end
  end
  
  module InstanceMethods
    def set_language(language)
      GLoc::Constants::CONFIG[:default_language]= language.nil? ? nil : language.to_sym
    end
  end
  
  module ClassMethods
    def current_language
      GLoc::Constants::CONFIG[:default_language]
    end
  end
end
EOB
      #------------------------------------------------------------------------
      when :cascading
        eval <<EOB
module ::GLoc
  def current_language
    @gloc_language || self.class.current_language
  end
  
  class << self
    def current_language
      CONFIG[:default_language]
    end
  end
  
  module InstanceMethods
    def set_language(language)
      @gloc_language= language.nil? ? nil : language.to_sym
    end
  end
  
  module ClassMethods
    def current_language
      @gloc_language || GLoc.current_language
    end
  end
end
EOB
      #------------------------------------------------------------------------
      else
        raise "Invalid mode."
      end
    end
  end # class << self
end # module GLoc
