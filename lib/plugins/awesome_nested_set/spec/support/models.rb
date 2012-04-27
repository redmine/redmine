class Note < ActiveRecord::Base
  acts_as_nested_set :scope => [:notable_id, :notable_type]
end

class Default < ActiveRecord::Base
  self.table_name = 'categories'
  acts_as_nested_set
end

class ScopedCategory < ActiveRecord::Base
  self.table_name = 'categories'
  acts_as_nested_set :scope => :organization
end

class RenamedColumns < ActiveRecord::Base
  acts_as_nested_set :parent_column => 'mother_id', :left_column => 'red', :right_column => 'black'
end

class Category < ActiveRecord::Base
  acts_as_nested_set

  validates_presence_of :name

  # Setup a callback that we can switch to true or false per-test
  set_callback :move, :before, :custom_before_move
  cattr_accessor :test_allows_move
  @@test_allows_move = true
  def custom_before_move
    @@test_allows_move
  end

  def to_s
    name
  end

  def recurse &block
    block.call self, lambda{
      self.children.each do |child|
        child.recurse &block
      end
    }
  end
end

class Thing < ActiveRecord::Base
  acts_as_nested_set :counter_cache => 'children_count'
end

class DefaultWithCallbacks < ActiveRecord::Base

  self.table_name = 'categories'

  attr_accessor :before_add, :after_add, :before_remove, :after_remove

  acts_as_nested_set :before_add => :do_before_add_stuff,
    :after_add     => :do_after_add_stuff,
    :before_remove => :do_before_remove_stuff,
    :after_remove  => :do_after_remove_stuff

  private

    [ :before_add, :after_add, :before_remove, :after_remove ].each do |hook_name|
      define_method "do_#{hook_name}_stuff" do |child_node|
        self.send("#{hook_name}=", child_node)
      end
    end

end

class Broken < ActiveRecord::Base
  acts_as_nested_set
end