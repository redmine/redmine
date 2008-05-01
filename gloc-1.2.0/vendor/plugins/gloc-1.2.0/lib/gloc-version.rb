require 'gloc-internal'

module GLoc
  module VERSION #:nodoc:
    MAJOR = 1
    MINOR = 2
    TINY  = nil

    STRING= [MAJOR, MINOR, TINY].delete_if{|x|x.nil?}.join('.')
    def self.to_s; STRING end
  end
  
  _verbose_msg {"NOTICE: You are using a dev version of GLoc."} if GLoc::VERSION::TINY == 'DEV'
end
