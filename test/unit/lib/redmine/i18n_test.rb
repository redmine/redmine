# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::I18nTest < ActiveSupport::TestCase
  include Redmine::I18n
  include ActionView::Helpers::NumberHelper

  def setup
    User.current = nil
  end

  def teardown
    set_language_if_valid 'en'
  end

  def test_date_format_default
    set_language_if_valid 'en'
    today = Date.today
    with_settings :date_format => '' do
      assert_equal I18n.l(today), format_date(today)
    end
  end

  def test_date_format
    set_language_if_valid 'en'
    today = Date.today
    with_settings :date_format => '%d %m %Y' do
      assert_equal today.strftime('%d %m %Y'), format_date(today)
    end
  end

  def test_date_format_with_month_name_should_translate_with_current_locale
    set_language_if_valid 'es'
    date = Date.parse('2011-02-20 14:00:00')
    with_settings :date_format => '%d %B %Y' do
      assert_equal '20 Febrero 2011', format_date(date)
    end
  end

  def test_date_and_time_for_each_language
    with_settings :date_format => '' do
      valid_languages.each do |lang|
        set_language_if_valid lang
        assert_nothing_raised "#{lang} failure" do
          format_date(Date.today)
          format_time(Time.now)
          format_time(Time.now, false)
          assert_not_equal 'default', ::I18n.l(Date.today, :format => :default),
                           "date.formats.default missing in #{lang}"
          assert_not_equal 'time',    ::I18n.l(Time.now, :format => :time),
                           "time.formats.time missing in #{lang}"
        end
        assert l('date.day_names').is_a?(Array)
        assert_equal 7, l('date.day_names').size
  
        assert l('date.month_names').is_a?(Array)
        assert_equal 13, l('date.month_names').size
      end
    end
  end

  def test_time_for_each_zone
    ActiveSupport::TimeZone.all.each do |zone|
      User.current.stubs(:time_zone).returns(zone.name)
      assert_nothing_raised "#{zone} failure" do
        format_time(Time.now)
      end
    end
  end

  def test_time_format
    set_language_if_valid 'en'
    now = Time.parse('2011-02-20 15:45:22')
    with_settings :time_format => '%H:%M' do
      with_settings :date_format => '' do
        assert_equal '02/20/2011 15:45', format_time(now)
        assert_equal '15:45', format_time(now, false)
      end
      with_settings :date_format => '%Y-%m-%d' do
        assert_equal '2011-02-20 15:45', format_time(now)
        assert_equal '15:45', format_time(now, false)
      end
    end
  end

  def test_time_format_default
    set_language_if_valid 'en'
    now = Time.parse('2011-02-20 15:45:22')
    with_settings :time_format => '' do
      with_settings :date_format => '' do
        assert_equal '02/20/2011 03:45 PM', format_time(now)
        assert_equal '03:45 PM', format_time(now, false)
      end
      with_settings :date_format => '%Y-%m-%d' do
        assert_equal '2011-02-20 03:45 PM', format_time(now)
        assert_equal '03:45 PM', format_time(now, false)
      end
    end
  end

  def test_utc_time_format
    set_language_if_valid 'en'
    now = Time.now
    with_settings :date_format => '%d %m %Y', :time_format => '%H %M' do
      assert_equal now.localtime.strftime('%d %m %Y %H %M'), format_time(now.utc), "User time zone was #{User.current.time_zone}"
      assert_equal now.localtime.strftime('%H %M'), format_time(now.utc, false)
    end
  end

  def test_number_to_human_size_for_each_language
    valid_languages.each do |lang|
      set_language_if_valid lang
      assert_nothing_raised "#{lang} failure" do
        size = number_to_human_size(257024)
        assert_match /251/, size, "#{lang} failure"
      end
    end
  end

  def test_day_name
    set_language_if_valid 'fr'
    assert_equal 'dimanche', day_name(0)
    assert_equal 'jeudi', day_name(4)
  end

  def test_day_letter
    set_language_if_valid 'fr'
    assert_equal 'd', day_letter(0)
    assert_equal 'j', day_letter(4)
  end

  def test_number_to_currency_for_each_language
    valid_languages.each do |lang|
      set_language_if_valid lang
      assert_nothing_raised "#{lang} failure" do
        number_to_currency(-1000.2)
      end
    end
  end

  def test_l_hours_short
    set_language_if_valid 'en'
    assert_equal '2.00 h', l_hours_short(2.0)
  end

  def test_number_to_currency_default
    set_language_if_valid 'bs'
    assert_equal "KM -1000,20", number_to_currency(-1000.2)
    set_language_if_valid 'de'
    euro_sign = "\xe2\x82\xac".force_encoding('UTF-8')
    assert_equal "-1000,20 #{euro_sign}", number_to_currency(-1000.2)
  end

  def test_lu_should_not_error_when_user_language_is_an_empty_string
    user = User.new
    user.language = ''

    assert_nothing_raised do
      lu(user, :label_issue)
    end
  end

  def test_valid_languages
    assert valid_languages.is_a?(Array)
    assert valid_languages.first.is_a?(Symbol)
  end

  def test_languages_options
    options = languages_options
    assert options.is_a?(Array)
    assert_equal valid_languages.size, options.size
    assert_nil options.detect {|option| !option.is_a?(Array)}
    assert_nil options.detect {|option| option.size != 2}
    assert_nil options.detect {|option| !option.first.is_a?(String) || !option.last.is_a?(String)}
    assert_include ["English", "en"], options
    ja = "Japanese (\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e)".force_encoding('UTF-8')
    assert_include [ja, "ja"], options
  end

  def test_languages_options_should_return_strings_with_utf8_encoding
    strings = languages_options.flatten
    assert_equal ["UTF-8"], strings.map(&:encoding).uniq.map(&:name).sort
  end

  def test_languages_options_should_ignore_locales_without_general_lang_name_key
    stubs(:valid_languages).returns([:en, :foo])
    assert_equal [["English", "en"]], languages_options(:cache => false)
  end

  def test_locales_validness
    lang_files_count = Dir["#{Rails.root}/config/locales/*.yml"].size
    assert_equal lang_files_count, valid_languages.size
    valid_languages.each do |lang|
      assert set_language_if_valid(lang)
    end
    set_language_if_valid('en')
  end

  def test_valid_language
    to_test = {'fr' => :fr,
               'Fr' => :fr,
               'zh' => :zh,
               'zh-tw' => :"zh-TW",
               'zh-TW' => :"zh-TW",
               'zh-ZZ' => nil }
    to_test.each {|lang, expected| assert_equal expected, find_language(lang)}
  end

  def test_fallback
    ::I18n.backend.store_translations(:en, {:untranslated => "Untranslated string"})
    ::I18n.locale = 'en'
    assert_equal "Untranslated string", l(:untranslated)
    ::I18n.locale = 'fr'
    assert_equal "Untranslated string", l(:untranslated)

    ::I18n.backend.store_translations(:fr, {:untranslated => "Pas de traduction"})
    ::I18n.locale = 'en'
    assert_equal "Untranslated string", l(:untranslated)
    ::I18n.locale = 'fr'
    assert_equal "Pas de traduction", l(:untranslated)
  end

  def test_utf8
    set_language_if_valid 'ja'
    str_ja_yes  = "\xe3\x81\xaf\xe3\x81\x84".force_encoding('UTF-8')
    i18n_ja_yes = l(:general_text_Yes)
    assert_equal str_ja_yes, i18n_ja_yes
    assert_equal "UTF-8", i18n_ja_yes.encoding.to_s
  end

  def test_traditional_chinese_locale
    set_language_if_valid 'zh-TW'
    str_tw = "Traditional Chinese (\xe7\xb9\x81\xe9\xab\x94\xe4\xb8\xad\xe6\x96\x87)".force_encoding('UTF-8')
    assert_equal str_tw, l(:general_lang_name)
  end

  def test_french_locale
    set_language_if_valid 'fr'
    str_fr = "French (Fran\xc3\xa7ais)".force_encoding('UTF-8')
    assert_equal str_fr, l(:general_lang_name)
  end
end
