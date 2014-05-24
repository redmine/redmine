# AwesomeNestedSet

Awesome Nested Set is an implementation of the nested set pattern for ActiveRecord models.
It is a replacement for acts_as_nested_set and BetterNestedSet, but more awesome.

Version 2 supports Rails 3. Gem versions prior to 2.0 support Rails 2.

## What makes this so awesome?

This is a new implementation of nested set based off of BetterNestedSet that fixes some bugs, removes tons of duplication, adds a few useful methods, and adds STI support.

[![Code Climate](https://codeclimate.com/github/collectiveidea/awesome_nested_set.png)](https://codeclimate.com/github/collectiveidea/awesome_nested_set)

## Installation

Add to your Gemfile:

```ruby
gem 'awesome_nested_set'
```

## Usage

To make use of `awesome_nested_set`, your model needs to have 3 fields:
`lft`, `rgt`, and `parent_id`. The names of these fields are configurable.
You can also have an optional field, `depth`:

```ruby
class CreateCategories < ActiveRecord::Migration
  def self.up
    create_table :categories do |t|
      t.string :name
      t.integer :parent_id
      t.integer :lft
      t.integer :rgt
      t.integer :depth # this is optional.
    end
  end

  def self.down
    drop_table :categories
  end
end
```

Enable the nested set functionality by declaring `acts_as_nested_set` on your model

```ruby
class Category < ActiveRecord::Base
  acts_as_nested_set
end
```

Run `rake rdoc` to generate the API docs and see [CollectiveIdea::Acts::NestedSet](lib/awesome_nested_set/awesome_nested_set.rb) for more information.

## Callbacks

There are three callbacks called when moving a node:
`before_move`, `after_move` and `around_move`.

```ruby
class Category < ActiveRecord::Base
  acts_as_nested_set

  after_move :rebuild_slug
  around_move :da_fancy_things_around

  private

  def rebuild_slug
    # do whatever
  end

  def da_fancy_things_around
    # do something...
    yield # actually moves
    # do something else...
  end
end
```

Beside this there are also hooks to act on the newly added or removed children.

```ruby
class Category < ActiveRecord::Base
  acts_as_nested_set  :before_add     => :do_before_add_stuff,
                      :after_add      => :do_after_add_stuff,
                      :before_remove  => :do_before_remove_stuff,
                      :after_remove   => :do_after_remove_stuff

  private

  def do_before_add_stuff(child_node)
    # do whatever with the child
  end

  def do_after_add_stuff(child_node)
    # do whatever with the child
  end

  def do_before_remove_stuff(child_node)
    # do whatever with the child
  end

  def do_after_remove_stuff(child_node)
    # do whatever with the child
  end
end
```

## Protecting attributes from mass assignment

It's generally best to "whitelist" the attributes that can be used in mass assignment:

```ruby
class Category < ActiveRecord::Base
  acts_as_nested_set
  attr_accessible :name, :parent_id
end
```

If for some reason that is not possible, you will probably want to protect the `lft` and `rgt` attributes:

```ruby
class Category < ActiveRecord::Base
  acts_as_nested_set
  attr_protected :lft, :rgt
end
```

## Conversion from other trees

Coming from acts_as_tree or another system where you only have a parent_id? No problem. Simply add the lft & rgt fields as above, and then run:

```ruby
Category.rebuild!
```

Your tree will be converted to a valid nested set. Awesome!

## View Helper

The view helper is called #nested_set_options.

Example usage:

```erb
<%= f.select :parent_id, nested_set_options(Category, @category) {|i| "#{'-' * i.level} #{i.name}" } %>

<%= select_tag 'parent_id', options_for_select(nested_set_options(Category) {|i| "#{'-' * i.level} #{i.name}" } ) %>
```

See [CollectiveIdea::Acts::NestedSet::Helper](lib/awesome_nested_set/helper.rb) for more information about the helpers.

## References

You can learn more about nested sets at: http://threebit.net/tutorials/nestedset/tutorial1.html

## How to contribute

Please see the ['Contributing' document](CONTRIBUTING.md).

Copyright © 2008 - 2013 Collective Idea, released under the MIT license
