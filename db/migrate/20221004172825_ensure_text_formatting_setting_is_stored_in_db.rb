class EnsureTextFormattingSettingIsStoredInDb < ActiveRecord::Migration[6.1]
  def change
    unless Setting.where(name: "text_formatting").exists?
      setting = Setting.new(:name => "text_formatting", :value => 'textile')
      setting.save!
    end
  end
end
