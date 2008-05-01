# Copyright (c) 2005-2007 David Barri

module GLoc
  # These helper methods will be included in the InstanceMethods module.
  module Helpers
    def l_age(age)             lwr :general_fmt_age, age end
    def l_date(date)           l_strftime :general_fmt_date, date end
    def l_datetime(date)       l_strftime :general_fmt_datetime, date end
    def l_strftime(fmt,date)   l(fmt,date) end
    def l_time(time)           l_strftime :general_fmt_time, time end
    def l_YesNo(value)         l(value ? :general_text_Yes : :general_text_No) end
    def l_yesno(value)         l(value ? :general_text_yes : :general_text_no) end

    def l_lang_name(lang, display_lang=nil)
      ll display_lang || current_language, "general_lang_#{lang}"
    end

  end
end
