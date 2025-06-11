class EnsureWikiTablesortSettingIsStoredInDb < ActiveRecord::Migration[7.2]
  def change
    unless Setting.where(name: "wiki_tablesort_enabled").exists?
      setting = Setting.new(:name => "wiki_tablesort_enabled", :value => 1)
      setting.save!
    end
  end
end
