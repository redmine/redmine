# Patches active_support/core_ext/load_error.rb to support 1.9.3 LoadError message
if RUBY_VERSION >= '1.9.3'
  MissingSourceFile::REGEXPS << [/^cannot load such file -- (.+)$/i, 1] 
end

require 'active_record'

module ActiveRecord
  class Base
    include Redmine::I18n
    def self.named_scope(*args)
      scope(*args)
    end

    # Translate attribute names for validation errors display
    def self.human_attribute_name(attr, *args)
      l("field_#{attr.to_s.gsub(/_id$/, '')}", :default => attr)
    end
  end
end

module ActionView
  module Helpers
    module DateHelper
      # distance_of_time_in_words breaks when difference is greater than 30 years
      def distance_of_date_in_words(from_date, to_date = 0, options = {})
        from_date = from_date.to_date if from_date.respond_to?(:to_date)
        to_date = to_date.to_date if to_date.respond_to?(:to_date)
        distance_in_days = (to_date - from_date).abs

        I18n.with_options :locale => options[:locale], :scope => :'datetime.distance_in_words' do |locale|
          case distance_in_days
            when 0..60     then locale.t :x_days,             :count => distance_in_days.round
            when 61..720   then locale.t :about_x_months,     :count => (distance_in_days / 30).round
            else                locale.t :over_x_years,       :count => (distance_in_days / 365).floor
          end
        end
      end
    end
  end

  class Resolver
    def find_all(name, prefix=nil, partial=false, details={}, key=nil, locals=[])
      cached(key, [name, prefix, partial], details, locals) do
        if details[:formats] & [:xml, :json]
          details = details.dup
          details[:formats] = details[:formats].dup + [:api]
        end
        find_templates(name, prefix, partial, details)
      end
    end
  end
end

ActionView::Base.field_error_proc = Proc.new{ |html_tag, instance| "#{html_tag}" }

module AsynchronousMailer
  # Adds :async_smtp and :async_sendmail delivery methods
  # to perform email deliveries asynchronously
  %w(smtp sendmail).each do |type|
    define_method("perform_delivery_async_#{type}") do |mail|
      Thread.start do
        send "perform_delivery_#{type}", mail
      end
    end
  end

  # Adds a delivery method that writes emails in tmp/emails for testing purpose
  def perform_delivery_tmp_file(mail)
    dest_dir = File.join(Rails.root, 'tmp', 'emails')
    Dir.mkdir(dest_dir) unless File.directory?(dest_dir)
    File.open(File.join(dest_dir, mail.message_id.gsub(/[<>]/, '') + '.eml'), 'wb') {|f| f.write(mail.encoded) }
  end
end

ActionMailer::Base.send :include, AsynchronousMailer

module ActionController
  module MimeResponds
    class Collector
      def api(&block)
        any(:xml, :json, &block)
      end
    end
  end
end
