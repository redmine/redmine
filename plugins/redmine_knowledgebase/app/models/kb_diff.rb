require_dependency 'redmine/helpers/diff'

class KbDiff < Redmine::Helpers::Diff
  attr_reader :content_to, :content_from

  def initialize(content_to, content_from)
    @content_to = content_to
    @content_from = content_from
    super(content_to.content, content_from.content)
  end
end