class ChangeTextFormattingFromMarkdownToCommonMark < ActiveRecord::Migration[7.2]
  def up
    Setting.find_by(name: 'text_formatting', value: 'markdown')&.update(value: 'common_mark')
  end

  def down
    # no-op
  end
end
