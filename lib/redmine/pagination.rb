# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module Pagination
    class Paginator
      attr_reader :item_count, :per_page, :page, :page_param

      def initialize(*args)
        if args.first.is_a?(ActionController::Base)
          args.shift
          ActiveSupport::Deprecation.warn "Paginator no longer takes a controller instance as the first argument. Remove it from #new arguments."
        end
        item_count, per_page, page, page_param = *args

        @item_count = item_count
        @per_page = per_page
        page = (page || 1).to_i
        if page < 1
          page = 1
        end
        @page = page
        @page_param = page_param || :page
      end

      def offset
        (page - 1) * per_page
      end

      def first_page
        if item_count > 0
          1
        end
      end

      def previous_page
        if page > 1
          page - 1
        end
      end

      def next_page
        if last_item < item_count
          page + 1
        end
      end

      def last_page
        if item_count > 0
          (item_count - 1) / per_page + 1
        end
      end

      def multiple_pages?
        per_page < item_count
      end

      def first_item
        item_count == 0 ? 0 : (offset + 1)
      end

      def last_item
        l = first_item + per_page - 1
        l > item_count ? item_count : l
      end

      def linked_pages
        pages = []
        if item_count > 0
          pages += [first_page, page, last_page]
          pages += ((page-2)..(page+2)).to_a.select {|p| p > first_page && p < last_page}
        end
        pages = pages.compact.uniq.sort
        if pages.size > 1
          pages
        else
          []
        end
      end

      def items_per_page
        ActiveSupport::Deprecation.warn "Paginator#items_per_page will be removed. Use #per_page instead."
        per_page
      end

      def current
        ActiveSupport::Deprecation.warn "Paginator#current will be removed. Use .offset instead of .current.offset."
        self
      end
    end

    # Paginates the given scope or model. Returns a Paginator instance and
    # the collection of objects for the current page.
    #
    # Options:
    #   :parameter     name of the page parameter
    #
    # Examples:
    #   @user_pages, @users = paginate User.where(:status => 1)
    #
    def paginate(scope, options={})
      options = options.dup

      paginator = paginator(scope.count, options)
      collection = scope.limit(paginator.per_page).offset(paginator.offset).to_a

      return paginator, collection
    end

    def paginator(item_count, options={})
      options.assert_valid_keys :parameter, :per_page

      page_param = options[:parameter] || :page
      page = (params[page_param] || 1).to_i
      per_page = options[:per_page] || per_page_option
      Paginator.new(item_count, per_page, page, page_param)
    end

    module Helper
      include Redmine::I18n

      # Renders the pagination links for the given paginator.
      #
      # Options:
      #   :per_page_links    if set to false, the "Per page" links are not rendered
      #
      def pagination_links_full(*args)
        pagination_links_each(*args) do |text, parameters, options|
          if block_given?
            yield text, parameters, options
          else
            link_to text, {:params => request.query_parameters.merge(parameters)}, options
          end
        end
      end

      # Yields the given block with the text and parameters
      # for each pagination link and returns a string that represents the links
      def pagination_links_each(paginator, count=nil, options={}, &block)
        options.assert_valid_keys :per_page_links

        per_page_links = options.delete(:per_page_links)
        per_page_links = false if count.nil?
        page_param = paginator.page_param

        html = '<ul class="pages">'

        if paginator.multiple_pages?
          # \xc2\xab(utf-8) = &#171;
          text = "\xc2\xab " + l(:label_previous)
          if paginator.previous_page
            html << content_tag('li',
                                yield(text, {page_param => paginator.previous_page},
                                      :accesskey => accesskey(:previous)),
                                :class => 'previous page')
          else
            html << content_tag('li', content_tag('span', text), :class => 'previous')
          end
        end

        previous = nil
        paginator.linked_pages.each do |page|
          if previous && previous != page - 1
            html << content_tag('li', content_tag('span', '&hellip;'.html_safe), :class => 'spacer')
          end
          if page == paginator.page
            html << content_tag('li', content_tag('span', page.to_s), :class => 'current')
          else
            html << content_tag('li',
                                yield(page.to_s, {page_param => page}),
                                :class => 'page')
          end
          previous = page
        end

        if paginator.multiple_pages?
          # \xc2\xbb(utf-8) = &#187;
          text = l(:label_next) + " \xc2\xbb"
          if paginator.next_page
            html << content_tag('li',
                                yield(text, {page_param => paginator.next_page},
                                      :accesskey => accesskey(:next)),
                                :class => 'next page')
          else
            html << content_tag('li', content_tag('span', text), :class => 'next')
          end
        end
        html << '</ul>'

        info = ''.html_safe
        info << content_tag('span', "(#{paginator.first_item}-#{paginator.last_item}/#{paginator.item_count})", :class => 'items') + ' '
        if per_page_links != false && links = per_page_links(paginator, &block)
          info << content_tag('span', links.to_s, :class => 'per-page')
        end
        html << content_tag('span', info)

        html.html_safe
      end

      # Renders the "Per page" links.
      def per_page_links(paginator, &block)
        values = per_page_options(paginator.per_page, paginator.item_count)
        if values.any?
          links = values.collect do |n|
            if n == paginator.per_page
              content_tag('span', n.to_s, :class => 'selected')
            else
              yield(n, :per_page => n, paginator.page_param => nil)
            end
          end
          l(:label_display_per_page, links.join(', ')).html_safe
        end
      end

      def per_page_options(selected=nil, item_count=nil)
        options = Setting.per_page_options_array
        if item_count && options.any?
          if item_count > options.first
            max = options.detect {|value| value >= item_count} || item_count
          else
            max = item_count
          end
          options = options.select {|value| value <= max || value == selected}
        end
        if options.empty? || (options.size == 1 && options.first == selected)
          []
        else
          options
        end
      end
    end
  end
end
