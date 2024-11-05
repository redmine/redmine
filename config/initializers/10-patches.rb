# frozen_string_literal: true

module ActiveRecord
  # Undefines private Kernel#open method to allow using `open` scopes in models.
  # See Defect #11545 (http://www.redmine.org/issues/11545) for details.
  class Base
    class << self
      undef open
    end
  end

  class Relation ; undef open ; end
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
end

ActionView::Base.field_error_proc = Proc.new{ |html_tag, instance| html_tag || ''.html_safe }

module ActionView
  module Helpers
    module FormHelper
      alias :date_field_without_max :date_field
      def date_field(object_name, method, options = {})
        date_field_without_max(object_name, method, options.reverse_merge(max: '9999-12-31'))
      end
    end

    module FormTagHelper
      alias :date_field_tag_without_max :date_field_tag
      def date_field_tag(name, value = nil, options = {})
        date_field_tag_without_max(name, value, options.reverse_merge(max: '9999-12-31'))
      end
    end
  end
end

require 'mail'

module DeliveryMethods
  class TmpFile
    def initialize(*args); end

    def deliver!(mail)
      dest_dir = File.join(Rails.root, 'tmp', 'emails')
      Dir.mkdir(dest_dir) unless File.directory?(dest_dir)
      filename = "#{Time.now.to_i}_#{mail.message_id.gsub(/[<>]/, '')}.eml"
      File.binwrite(File.join(dest_dir, filename), mail.encoded)
    end
  end
end

ActionMailer::Base.add_delivery_method :tmp_file, DeliveryMethods::TmpFile

module ActionController
  module MimeResponds
    class Collector
      def api(&)
        any(:xml, :json, &)
      end
    end
  end
end

module ActionController
  class Base
    # Displays an explicit message instead of a NoMethodError exception
    # when trying to start Redmine with an old session_store.rb
    # TODO: remove it in a later version
    def self.session=(*args)
      $stderr.puts "Please remove config/initializers/session_store.rb and run `rake generate_secret_token`.\n" +
        "Setting the session secret with ActionController.session= is no longer supported."
      exit 1
    end
  end
end

module ActionView
  LookupContext.prepend(Module.new do
    def formats=(values)
      if Array(values).intersect?([:xml, :json])
        values << :api
      end
      super
    end
  end)
end

module ActionController
  Base.prepend(Module.new do
    def rendered_format
      if lookup_context.formats.first == :api
        return request.format
      end

      super
    end
  end)
end

Mime::SET << 'api'

module Propshaft
  Assembly.prepend(Module.new do
    def initialize(config)
      super
      if Rails.application.config.assets.redmine_detect_update && (!config.manifest_path.exist? || manifest_outdated?)
        processor.process
      end
    end

    def manifest_outdated?
      !!load_path.asset_files.detect{|f| f.mtime > config.manifest_path.mtime}
    end

    def load_path
      @load_path ||= Redmine::AssetLoadPath.new(config, compilers)
    end
  end)

  Helper.prepend(Module.new do
    def compute_asset_path(path, options = {})
      super
    rescue MissingAssetError => e
      File.join Rails.application.assets.resolver.prefix, path
    end
  end)
end
