# Copyright (c) 2005-2007 David Barri

require 'yaml'

module GLoc
  module Constants
    UTF_8= 'utf-8'
    SHIFT_JIS= 'sjis'
    EUC_JP= 'euc-jp'

    CONFIG= {
      :default_language => :en,
      :default_param_name => 'lang',
      :default_cookie_name => 'lang',
      :raise_string_not_found_errors => true,
      :verbose => false,
    }

    LOCALIZED_STRINGS= {}
    LOWERCASE_LANGUAGES= {}
    RULES= {}
    YAML_PRIVATETYPE2= YAML::Syck::PrivateType rescue YAML::PrivateType unless const_defined?(:YAML_PRIVATETYPE2)
  end
end
