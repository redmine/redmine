# Copyright (c) 2005-2007 David Barri

$LOAD_PATH.push File.join(File.dirname(__FILE__),'..','lib')
require 'gloc'
require 'gloc-ruby'
GLoc.set_language_mode :cascading
GLoc.set_kcode
require File.join(File.dirname(__FILE__),'lib','rails-time_ext') unless 3.respond_to?(:days)
require File.join(File.dirname(__FILE__),'lib','rails-string_ext') unless ''.respond_to?(:starts_with?)

class Module
  def alias_method_chain(target, feature)
    # Strip out punctuation on predicates or bang methods since
    # e.g. target?_without_feature is not a valid method name.
    aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
    yield(aliased_target, punctuation) if block_given?
    alias_method "#{aliased_target}_without_#{feature}#{punctuation}", target
    alias_method target, "#{aliased_target}_with_#{feature}#{punctuation}"
  end
end
module ActionView; module Helpers; module DateHelper
  def date_select(object_name, method, options={}) end
  def datetime_select(object_name, method, options={}) end
end end end
require 'gloc-rails-text'
#require 'gloc-dev'

class LClass; include GLoc; end
class LClass2 < LClass; end
class LClass_en < LClass2; set_language :en; end
class LClass_ja < LClass2; set_language :ja; end
# class LClass_forced_au < LClass; set_language :en; force_language :en_AU; set_language :ja; end

class GLocTest < Test::Unit::TestCase
  include GLoc
  include ActionView::Helpers::DateHelper
  
  def setup
    @l1 = LClass.new
    @l2 = LClass.new
    @l3 = LClass.new
    @l1.set_language :ja
    @l2.set_language :en
    @l3.set_language 'en_AU'
    @gloc_state= GLoc.backup_state true
    GLoc::Constants::CONFIG.merge!({
      :default_param_name => 'lang',
      :default_cookie_name => 'lang',
      :default_language => :ja,
      :raise_string_not_found_errors => true,
      :verbose => false,
    })
  end
  
  def teardown
    GLoc.restore_state @gloc_state
  end
  
  #---------------------------------------------------------------------------
  
  def test_basic
    assert_localized_value [nil, @l1, @l2, @l3], nil, :in_both_langs
    
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    
    assert_localized_value [nil, @l1], 'enにもjaにもある', :in_both_langs
    assert_localized_value [nil, @l1], '日本語のみ', :ja_only
    assert_localized_value [nil, @l1], nil, :en_only
    
    assert_localized_value @l2, 'This is in en+ja', :in_both_langs
    assert_localized_value @l2, nil, :ja_only
    assert_localized_value @l2, 'English only', :en_only
    
    assert_localized_value @l3, "Thiz in en 'n' ja", :in_both_langs
    assert_localized_value @l3, nil, :ja_only
    assert_localized_value @l3, 'Aussie English only bro', :en_only

    @l3.set_language :en
    assert_localized_value @l3, 'This is in en+ja', :in_both_langs
    assert_localized_value @l3, nil, :ja_only
    assert_localized_value @l3, 'English only', :en_only

    assert_localized_value nil, 'enにもjaにもある', :in_both_langs
    assert_localized_value nil, '日本語のみ', :ja_only
    assert_localized_value nil, nil, :en_only
  end
  
  def test_load_twice_with_override
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang2')
    
    assert_localized_value [nil, @l1], '更新された', :in_both_langs
    assert_localized_value [nil, @l1], '日本語のみ', :ja_only
    assert_localized_value [nil, @l1], nil, :en_only
    assert_localized_value [nil, @l1], nil, :new_en
    assert_localized_value [nil, @l1], '新たな日本語ストリング', :new_ja
    
    assert_localized_value @l2, 'This is in en+ja', :in_both_langs
    assert_localized_value @l2, nil, :ja_only
    assert_localized_value @l2, 'overriden dude', :en_only
    assert_localized_value @l2, 'This is a new English string', :new_en
    assert_localized_value @l2, nil, :new_ja
    
    assert_localized_value @l3, "Thiz in en 'n' ja", :in_both_langs
    assert_localized_value @l3, nil, :ja_only
    assert_localized_value @l3, 'Aussie English only bro', :en_only
  end
  
  def test_load_twice_without_override
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang2'), false
    
    assert_localized_value [nil, @l1], 'enにもjaにもある', :in_both_langs
    assert_localized_value [nil, @l1], '日本語のみ', :ja_only
    assert_localized_value [nil, @l1], nil, :en_only
    assert_localized_value [nil, @l1], nil, :new_en
    assert_localized_value [nil, @l1], '新たな日本語ストリング', :new_ja
    
    assert_localized_value @l2, 'This is in en+ja', :in_both_langs
    assert_localized_value @l2, nil, :ja_only
    assert_localized_value @l2, 'English only', :en_only
    assert_localized_value @l2, 'This is a new English string', :new_en
    assert_localized_value @l2, nil, :new_ja
    
    assert_localized_value @l3, "Thiz in en 'n' ja", :in_both_langs
    assert_localized_value @l3, nil, :ja_only
    assert_localized_value @l3, 'Aussie English only bro', :en_only
  end
  
  def test_add_localized_strings
    assert_localized_value nil, nil, :add
    assert_localized_value nil, nil, :ja_only
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    assert_localized_value nil, nil, :add
    assert_localized_value nil, '日本語のみ', :ja_only
    GLoc.add_localized_strings 'en', {:ja_only => 'bullshit'}, true
    GLoc.add_localized_strings 'en', {:ja_only => 'bullshit'}, false
    assert_localized_value nil, nil, :add
    assert_localized_value nil, '日本語のみ', :ja_only
    GLoc.add_localized_strings 'ja', {:ja_only => 'bullshit', :add => '123'}, false
    assert_localized_value nil, '123', :add
    assert_localized_value nil, '日本語のみ', :ja_only
    GLoc.add_localized_strings 'ja', {:ja_only => 'bullshit', :add => '234'}
    assert_localized_value nil, '234', :add
    assert_localized_value nil, 'bullshit', :ja_only
  end
  
  def test_class_set_language
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    
    @l1 = LClass_ja.new
    @l2 = LClass_en.new
    @l3 = LClass_en.new
    
    assert_localized_value @l1, 'enにもjaにもある', :in_both_langs
    assert_localized_value @l2, 'This is in en+ja', :in_both_langs
    assert_localized_value @l3, 'This is in en+ja', :in_both_langs

    @l3.set_language 'en_AU'
    
    assert_localized_value @l1, 'enにもjaにもある', :in_both_langs
    assert_localized_value @l2, 'This is in en+ja', :in_both_langs
    assert_localized_value @l3, "Thiz in en 'n' ja", :in_both_langs
  end
  
  def test_ll
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')

    assert_equal 'enにもjaにもある', ll('ja',:in_both_langs)
    assert_equal 'enにもjaにもある', GLoc::ll('ja',:in_both_langs)
    assert_equal 'enにもjaにもある', LClass_en.ll('ja',:in_both_langs)
    assert_equal 'enにもjaにもある', LClass_ja.ll('ja',:in_both_langs)

    assert_equal 'This is in en+ja', ll('en',:in_both_langs)
    assert_equal 'This is in en+ja', GLoc::ll('en',:in_both_langs)
    assert_equal 'This is in en+ja', LClass_en.ll('en',:in_both_langs)
    assert_equal 'This is in en+ja', LClass_ja.ll('en',:in_both_langs)
  end
  
  def test_lsym
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    assert_equal 'enにもjaにもある', LClass_ja.ltry(:in_both_langs)
    assert_equal 'hello', LClass_ja.ltry('hello')
    assert_equal nil, LClass_ja.ltry(nil)
  end
  
#  def test_forced
#    assert_equal :en_AU, LClass_forced_au.current_language
#    a= LClass_forced_au.new
#    a.set_language :ja
#    assert_equal :en_AU, a.current_language
#    a.force_language :ja
#    assert_equal :ja, a.current_language
#    assert_equal :en_AU, LClass_forced_au.current_language
#  end

  def test_pluralization
    GLoc.add_localized_strings :en, :_gloc_rule_default => %[|n| case n; when 0 then '_none'; when 1 then '_single'; else '_many'; end], :a_single => '%d man', :a_many => '%d men', :a_none => 'No men'
    GLoc.add_localized_strings :en, :_gloc_rule_asd => %[|n| n<10 ? '_few' : '_heaps'], :a_few => 'a few men (%d)', :a_heaps=> 'soo many men'
    set_language :en

    assert_equal 'No men', lwr(:a, 0)
    assert_equal '1 man', lwr(:a, 1)
    assert_equal '3 men', lwr(:a, 3)
    assert_equal '20 men', lwr(:a, 20)

    assert_equal 'a few men (0)', lwr_(:asd, :a, 0)
    assert_equal 'a few men (1)', lwr_(:asd, :a, 1)
    assert_equal 'a few men (3)', lwr_(:asd, :a, 3)
    assert_equal 'soo many men', lwr_(:asd, :a, 12)
    assert_equal 'soo many men', lwr_(:asd, :a, 20)
    
  end
  
  def test_distance_in_words
    load_default_strings
    [
      [20.seconds, 'less than a minute', '1分以内', 'меньше минуты'],
      [80.seconds, '1 minute', '1分', '1 минуту'],
      [3.seconds, 'less than 5 seconds', '5秒以内', 'менее 5 секунд', true],
      [9.seconds, 'less than 10 seconds', '10秒以内', 'менее 10 секунд', true],
      [16.seconds, 'less than 20 seconds', '20秒以内', 'менее 20 секунд', true],
      [35.seconds, 'half a minute', '約30秒', 'полминуты', true],
      [50.seconds, 'less than a minute', '1分以内', 'меньше минуты', true],
      [1.1.minutes, '1 minute', '1分', '1 минуту'],
      [2.1.minutes, '2 minutes', '2分', '2 минуты'],
      [4.1.minutes, '4 minutes', '4分', '4 минуты'],
      [5.1.minutes, '5 minutes', '5分', '5 минут'],
      [1.1.hours, 'about an hour', '約1時間', 'около часа'],
      [3.1.hours, 'about 3 hours', '約3時間', 'около 3 часов'],
      [9.1.hours, 'about 9 hours', '約9時間', 'около 9 часов'],
      [1.1.days, '1 day', '1日間', '1 день'],
      [2.1.days, '2 days', '2日間', '2 дня'],
      [4.days, '4 days', '4日間', '4 дня'],
      [6.days, '6 days', '6日間', '6 дней'],
      [11.days, '11 days', '11日間', '11 дней'],
      [12.days, '12 days', '12日間', '12 дней'],
      [15.days, '15 days', '15日間', '15 дней'],
      [20.days, '20 days', '20日間', '20 дней'],
      [21.days, '21 days', '21日間', '21 день'],
      [22.days, '22 days', '22日間', '22 дня'],
      [25.days, '25 days', '25日間', '25 дней'],
    ].each do |a|
      t, en, ja, ru = a
      inc_sec= (a.size == 5) ? a[-1] : false
      set_language :en
      assert_equal en, distance_of_time_in_words(t,0,inc_sec)
      set_language :ja
      assert_equal ja, distance_of_time_in_words(t,0,inc_sec)
      set_language :ru
      assert_equal ru, distance_of_time_in_words(t,0,inc_sec)
    end
  end
  
  def test_age
    load_default_strings
    [
      [1, '1 yr', '1歳', '1 год'],
      [22, '22 yrs', '22歳', '22 года'],
      [27, '27 yrs', '27歳', '27 лет'],
    ].each do |a, en, ja, ru|
      set_language :en
      assert_equal en, l_age(a)
      set_language :ja
      assert_equal ja, l_age(a)
      set_language :ru
      assert_equal ru, l_age(a)
    end
  end
  
  def test_yesno
    load_default_strings
    set_language :en
    assert_equal 'yes', l_yesno(true)
    assert_equal 'no', l_yesno(false)
    assert_equal 'Yes', l_YesNo(true)
    assert_equal 'No', l_YesNo(false)
  end
  
  def test_all_languages_have_values_for_helpers
    load_default_strings
    t= Time.local(2000, 9, 15, 11, 23, 57)
    GLoc.valid_languages.each {|l|
      set_language l
      0.upto(120) {|n| l_age(n)}
      l_date(t)
      l_datetime(t)
      l_time(t)
      [true,false].each{|v| l_YesNo(v); l_yesno(v) }
    }
  end
  
  def test_similar_languages
    GLoc.add_localized_strings :en, :a => 'a'
    GLoc.add_localized_strings :en_AU, :a => 'a'
    GLoc.add_localized_strings :ja, :a => 'a'
    GLoc.add_localized_strings :zh_tw, :a => 'a'
    
    assert_equal :en, GLoc.similar_language(:en)
    assert_equal :en, GLoc.similar_language('en')
    assert_equal :ja, GLoc.similar_language(:ja)
    assert_equal :ja, GLoc.similar_language('ja')
    # lowercase + dashes to underscores
    assert_equal :en, GLoc.similar_language('EN')
    assert_equal :en, GLoc.similar_language(:EN)
    assert_equal :en_AU, GLoc.similar_language(:EN_Au)
    assert_equal :en_AU, GLoc.similar_language('eN-Au')
    # remove dialect
    assert_equal :ja, GLoc.similar_language(:ja_Au)
    assert_equal :ja, GLoc.similar_language('JA-ASDF')
    assert_equal :ja, GLoc.similar_language('jA_ASD_ZXC')
    # different dialect
    assert_equal :zh_tw, GLoc.similar_language('ZH')
    assert_equal :zh_tw, GLoc.similar_language('ZH_HK')
    assert_equal :zh_tw, GLoc.similar_language('ZH-BUL')
    # non matching
    assert_equal nil, GLoc.similar_language('WW')
    assert_equal nil, GLoc.similar_language('WW_AU')
    assert_equal nil, GLoc.similar_language('WW-AU')
    assert_equal nil, GLoc.similar_language('eZ_en')
    assert_equal nil, GLoc.similar_language('AU-ZH')
  end
  
  def test_clear_strings_and_similar_langs
    GLoc.add_localized_strings :en, :a => 'a'
    GLoc.add_localized_strings :en_AU, :a => 'a'
    GLoc.add_localized_strings :ja, :a => 'a'
    GLoc.add_localized_strings :zh_tw, :a => 'a'
    GLoc.clear_strings :en, :ja
    assert_equal nil, GLoc.similar_language('ja')
    assert_equal :en_AU, GLoc.similar_language('en')
    assert_equal :zh_tw, GLoc.similar_language('ZH_HK')
    GLoc.clear_strings
    assert_equal nil, GLoc.similar_language('ZH_HK')
  end

  def test_lang_name
    GLoc.add_localized_strings :en, :general_lang_en => 'English', :general_lang_ja => 'Japanese'
    GLoc.add_localized_strings :ja, :general_lang_en => '英語', :general_lang_ja => '日本語'
    set_language :en
    assert_equal 'Japanese', l_lang_name(:ja)
    assert_equal 'English', l_lang_name('en')
    set_language :ja
    assert_equal '日本語', l_lang_name('ja')
    assert_equal '英語', l_lang_name(:en)
  end
  
  def test_charset_change_all
    load_default_strings
    GLoc.clear_strings_except :en, :ja
    GLoc.add_localized_strings :ja2, :a => 'a'
    GLoc.valid_languages # Force refresh if in dev mode
    GLoc::Constants.class_eval 'LOCALIZED_STRINGS[:ja2]= LOCALIZED_STRINGS[:ja].clone'

    [:ja, :ja2].each do |l|
      set_language l
      assert_equal 'はい', l_yesno(true)
      assert_equal "E381AFE38184", l_yesno(true).unpack('H*')[0].upcase
    end

    GLoc.set_charset 'sjis'
    assert_equal 'sjis', GLoc.get_charset(:ja)
    assert_equal 'sjis', GLoc.get_charset(:ja2)
    
    [:ja, :ja2].each do |l|
      set_language l
      assert_equal "82CD82A2", l_yesno(true).unpack('H*')[0].upcase
    end
  end
  
  def test_charset_change_single
    load_default_strings
    GLoc.add_localized_strings :ja2, :a => 'a'
    GLoc.add_localized_strings :ja3, :a => 'a'
    GLoc.valid_languages # Force refresh if in dev mode
    GLoc::Constants.class_eval 'LOCALIZED_STRINGS[:ja2]= LOCALIZED_STRINGS[:ja].clone'
    GLoc::Constants.class_eval 'LOCALIZED_STRINGS[:ja3]= LOCALIZED_STRINGS[:ja].clone'

    [:ja, :ja2, :ja3].each do |l|
      set_language l
      assert_equal 'はい', l_yesno(true)
      assert_equal "E381AFE38184", l_yesno(true).unpack('H*')[0].upcase
    end

    GLoc.set_charset 'sjis', :ja
    assert_equal 'sjis', GLoc.get_charset(:ja)
    assert_equal 'utf-8', GLoc.get_charset(:ja2)
    assert_equal 'utf-8', GLoc.get_charset(:ja3)
    
    set_language :ja
    assert_equal "82CD82A2", l_yesno(true).unpack('H*')[0].upcase
    set_language :ja2
    assert_equal "E381AFE38184", l_yesno(true).unpack('H*')[0].upcase
    set_language :ja3
    assert_equal "E381AFE38184", l_yesno(true).unpack('H*')[0].upcase

    GLoc.set_charset 'euc-jp', :ja, :ja3
    assert_equal 'euc-jp', GLoc.get_charset(:ja)
    assert_equal 'utf-8', GLoc.get_charset(:ja2)
    assert_equal 'euc-jp', GLoc.get_charset(:ja3)

    set_language :ja
    assert_equal "A4CFA4A4", l_yesno(true).unpack('H*')[0].upcase
    set_language :ja2
    assert_equal "E381AFE38184", l_yesno(true).unpack('H*')[0].upcase
    set_language :ja3
    assert_equal "A4CFA4A4", l_yesno(true).unpack('H*')[0].upcase
  end
  
  def test_set_language_if_valid
    GLoc.add_localized_strings :en, :a => 'a'
    GLoc.add_localized_strings :zh_tw, :a => 'a'

    assert set_language_if_valid('en')
    assert_equal :en, current_language

    assert set_language_if_valid('zh_tw')
    assert_equal :zh_tw, current_language

    assert !set_language_if_valid(nil)
    assert_equal :zh_tw, current_language

    assert !set_language_if_valid('ja')
    assert_equal :zh_tw, current_language

    assert set_language_if_valid(:en)
    assert_equal :en, current_language
  end
  
  def test_procs_and_lambdas
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    
    assert_equal 'There are 7 birds', ll(:en, :proc_test, 7)
    assert_equal '鳥が7羽いる', ll(:ja, :proc_test, 7)
    assert_equal 'My name is Golly. I am 25 years old.', ll(:en, :lambda_test, 'Golly', 25)
    assert_equal '25才のGollyです。', ll(:ja, :lambda_test, 'Golly', 25)
    # Lambdas REQUIRE exact number of args
    assert_raises(ArgumentError) {ll(:en, :lambda_test, 'Golly')}
    assert_raises(ArgumentError) {ll(:ja, :lambda_test, 'Golly', 25, 4)}
  end
  
  def test_l_without_args
    GLoc.add_localized_strings :en, :asd => 'arg is %d'
    GLoc.add_localized_strings :ja, :asd => '%dです'
    GLoc.valid_languages # Force refresh if in dev mode
    set_language :en
    assert_equal 'arg is %d', l_without_args(:asd)
    assert_equal 'arg is %d', ltry_without_args(:asd)
    assert_equal 'qwe', ltry_without_args('qwe')
    assert_equal 'arg is %d', ll_without_args(:en,:asd)
    assert_equal '%dです', ll_without_args(:ja,:asd)
    set_language :ja
    assert_equal '%dです', l_without_args(:asd)
    assert_equal '%dです', ltry_without_args(:asd)
    assert_equal 'qwe', ltry_without_args('qwe')
  end
  
  def test_date_select_order
    load_default_strings
    GLoc.valid_languages.each {|l|
      set_language l
      v= l(:actionview_datehelper_date_select_order)
      assert_kind_of Array, v
      assert_equal 3, v.size
      assert v.include?(:year)
      assert v.include?(:day)
      assert v.include?(:month)
    }
  end
  
  def test_arrays_and_charset_change
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    GLoc.valid_languages # Force refresh if in dev mode
    set_language :ja
    clear_strings :ja, :proc_test, :lambda_test, :hash_test
    
    v= l(:array_test)
    assert_equal [:yay, 'はい', [1,2,'いいえ',3]], v
    assert_equal "E381AFE38184", v[1].unpack('H*')[0].upcase

    GLoc.set_charset 'sjis'
    v= l(:array_test)
    assert_kind_of Array, v
    assert_equal 3, v.size
    assert_equal :yay, v[0]
    assert_equal "82CD82A2", v[1].unpack('H*')[0].upcase
    v= v[2]
    assert_kind_of Array, v
    assert_equal 4, v.size
    assert_equal 1, v[0]
    assert_equal 2, v[1]
    assert_equal "82A282A282A6", v[2].unpack('H*')[0].upcase
    assert_equal 3, v[3]
  end
  
  def test_hashes_and_charset_change
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    GLoc.valid_languages # Force refresh if in dev mode
    set_language :ja
    clear_strings :ja, :proc_test, :lambda_test, :array_test
    
    v= l(:hash_test)
    assert_equal({'y' => 'はい', 'n' => 'いいえ', :y => 'はい', :n => 'いいえ', 2 => [:ah,'hehe','いいえ']},v)
    assert_equal "E381AFE38184", v[:y].unpack('H*')[0].upcase

    GLoc.set_charset 'sjis'
    v= l(:hash_test)
    assert_kind_of Hash, v
    assert_equal 5, v.size
    assert_equal "82CD82A2", v[:y].unpack('H*')[0].upcase
    assert_equal [:ah,'hehe'], v[2][0..1]
    assert_equal "82A282A282A6", v[2][2].unpack('H*')[0].upcase
  end
  
  def test_lambdas_and_charset_change
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    GLoc.valid_languages # Force refresh if in dev mode
    set_language :ja
    clear_strings :ja, :array_test, :hash_test
    
    # UTF-8
    assert_equal '鳥が15羽いる', ll(:ja, :proc_test, 15)
    assert_equal '20才のBaaです。', ll(:ja, :lambda_test, 'Baa', 20)

    # Shift-JIS
    GLoc.set_charset 'sjis'
    Iconv.open('sjis', 'utf-8') do |iconv|
      assert_equal iconv.iconv('鳥が15羽いる'), ll(:ja, :proc_test, 15)
      assert_equal iconv.iconv('20才のBaaです。'), ll(:ja, :lambda_test, 'Baa', 20)
    end

    # UTF-8
    GLoc.set_charset 'utf-8'
    assert_equal '鳥が15羽いる', ll(:ja, :proc_test, 15)
    assert_equal '20才のBaaです。', ll(:ja, :lambda_test, 'Baa', 20)
  end
  
  def test_nonstring_basic_types
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    GLoc.valid_languages # Force refresh if in dev mode
    set_language :ja
    
    assert_equal true, l(:true_test)
    assert_equal false, l(:false_test)
    assert_equal 52, l(:fixnum_test)
    assert_equal :sweet, l(:symbol_test)
  end
  
  def test_datetime_formats
    load_default_strings
    GLoc.valid_languages.each do |l|
      set_language l
      assert_array l(:general_text_month_names), 12, true, String
      assert_array l(:general_text_month_names_abbr), 12, false, String
      assert_array l(:general_text_day_names), 7, true, String
      assert_array l(:general_text_day_names_abbr), 7, false, String
    end
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    set_language :ru
    t= Time.local(2006,10,13,23,58) # fri
    assert_equal '%b 13/Октябрь/2006 %b', l_date(t)
    assert_equal 'Окт 13 _%b:%Октябрь (2006) 11:58 PM', l_datetime(t)
    set_language :ja
    t= Time.local(2005,1,18,10,05) # tue
    assert_equal '18/1月 火', l_date(t)
    assert_equal '10:05 AM (2005) 18/1月 火曜日', l_datetime(t)
  end
  
  def test_sameas
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    GLoc.valid_languages # Force refresh if in dev mode
    set_language :ja
    GLoc.clear_strings_except :ja
    
    test= lambda do |charset|
      Iconv.open(charset,'utf-8') do |i|
        assert_equal i.iconv('日本語のみ'), l(:sameas_test2)
        assert_equal i.iconv('日本語のみ'), l(:sameas_test1)
        assert_equal i.iconv('鳥が142羽いる'), l(:sameas_test3,142)
        assert_equal i.iconv('鳥が654羽いる'), l(:sameas_test3,654)
      end
    end
    
    test.call 'utf-8'
    test.call 'utf-8'
    GLoc.set_charset 'sjis'
    test.call 'sjis'
    GLoc.set_charset 'utf-8'
    test.call 'utf-8'
  end
  
  def test_constants_not_inherited
    assert !LClass.constants.include?("UTF8")
    assert !LClass.constants.include?("RULES")
    assert !LClass.constants.include?("CONFIG")
    assert !LClass.constants.include?("LOCALIZED_STRINGS")
  end
  
  def test_simple_language_mode
    GLoc.set_language_mode :simple
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'lang')
    targets= [@l1,@l2,LClass,GLoc]
    set_language :en
    assert_localized_value targets, 'This is in en+ja', :in_both_langs
    set_language :ja
    assert_localized_value targets, 'enにもjaにもある', :in_both_langs
    @l1.set_language :en
    assert_localized_value targets, 'This is in en+ja', :in_both_langs
    GLoc.set_language :ja
    assert_localized_value targets, 'enにもjaにもある', :in_both_langs
    LClass.set_language :en
    assert_localized_value targets, 'This is in en+ja', :in_both_langs
  ensure
    GLoc.set_language_mode :cascading
  end
  
  #===========================================================================
  protected
  
  def assert_array(array, size, unique=false, element_classes=nil)
    assert_kind_of Array, array
    assert_equal size, array.size
    assert array.size == array.uniq.size if unique
    array.each {|e| flunk unless e.is_a?(element_classes)} if element_classes
  end
  
  def assert_localized_value(objects,expected,key)
    objects = [objects] unless objects.kind_of?(Array)
    objects.each {|object|
      o = object || GLoc
      assert_equal !expected.nil?, o.l_has_string?(key)
      if expected.nil?
        assert_raise(GLoc::StringNotFoundError) {o.l(key)}
      else
        assert_equal expected, o.l(key)
      end
    }
  end
  
  def clear_strings(langs,*keys)
    x= {}
    keys.each {|k| x[k]= nil}
    [langs].flatten.each {|l| GLoc.add_localized_strings l, x, true}
  end
  
  def load_default_strings
    GLoc.load_localized_strings File.join(File.dirname(__FILE__),'..','lang')
  end
end