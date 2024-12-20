module SettingPatch
  def self.included(base)
    base.class_eval do
      def self.set_from_params(name, params)
        params = params.dup
        params.delete_if {|v| v.blank?} if params.is_a?(Array)
        params.symbolize_keys! if params.is_a?(Hash)
        params = parse_time_params(params) if name.to_s.eql? 'allow_logging_time_till'
    
    
        m = "#{name}_from_params"
        if respond_to? m
          self[name.to_sym] = send m, params
        else
          self[name.to_sym] = params
        end
      end

      def self.parse_time_params(params)
        time = Time.new(*(1..params.size).map do |i|
          params[:"allow_logging_time_till(#{i}i)"]
        end)
        time
      end
    end
  end
end