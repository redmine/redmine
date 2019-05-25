#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'date'

VERSION = '1.0.0'

ARGV << '-h' if ARGV.empty?

class OptionsParser
  def self.parse(args)
    options = OpenStruct.new
    options.version_name = ''
    options.release_date = ''
    options.new_branch = 'auto'

    opt_parser = OptionParser.new do |opts|
      opts.banner = 'Usage: changelog_generator.rb [options]'

      opts.separator ''
      opts.separator 'Required specific options:'

      opts.on('-i', '--version_id VERSIONID',
              'Numerical id of the version [int]') do |i|
        options.version_id = i
      end

      opts.separator ''
      opts.separator 'Optional specific options:'

      opts.on('-n', '--version_name VERSIONNAME',
              'Name of the version [string]') do |n|
        options.version_name = n
      end
      opts.on('-d', '--release_date RELEASEDATE',
              'Date of the release [string: YYYY-MM-DD]') do |d|
        options.release_date = d
      end
      opts.on('-b', '--new_branch NEWBRANCH',
              'New release branch indicator [string: true/false/auto (default)]') do |b|
        options.new_branch = b
      end

      opts.separator ''
      opts.separator 'Common options:'

      opts.on_tail('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end

      opts.on_tail('-v', '--version', 'Show version') do
        puts VERSION
        exit
      end
    end

    opt_parser.parse!(args)
    options
  end
end

# Gracely handle missing required options
begin
  options = OptionsParser.parse(ARGV)
  required = [:version_id]
  missing = required.select{ |param| options[param].nil? }
  unless missing.empty?
    raise OptionParser::MissingArgument.new(missing.join(', '))
  end
rescue OptionParser::ParseError => e
  puts e
  exit
end

# Extract options values into global variables
$v_id = options[:version_id]
$v_name = options[:version_name]
$r_date = options[:release_date]
$n_branch = options[:new_branch]

module Redmine
  module ChangelogGenerator
    require 'nokogiri'
    require 'open-uri'

    @v_id = $v_id
    @v_name = $v_name
    @r_date = $r_date
    @n_branch = $n_branch

    ISSUES_URL = 'http://www.redmine.org/projects/redmine/issues' +
                 '?utf8=%E2%9C%93&set_filter=1' +
                 '&f%5B%5D=status_id&op%5Bstatus_id%5D=*' +
                 '&f%5B%5D=fixed_version_id&op%5Bfixed_version_id%5D=%3D' +
                   '&v%5Bfixed_version_id%5D%5B%5D=' + @v_id +
                 '&f%5B%5D=&c%5B%5D=tracker&c%5B%5D=subject' +
                 '&c%5B%5D=category&group_by='
    VERSIONS_URL = 'http://www.redmine.org/versions/' + @v_id

    PAGINATION_ITEMS_SPAN_SELECTOR = 'div#content p.pagination > span.items'
    ISSUE_TR_SELECTOR = 'div#content table.list.issues > tbody > tr'
    VERSION_DETAILS_SELECTOR = 'div#content'
    VERSION_NAME_SELECTOR = 'div#content > h2'
    RELEASE_DATE_SELECTOR = 'div#content > div#roadmap > p'

    PAGINATION_ITEMS_SPAN_REGEX = %r{(?:[(])([\d]+)(?:-)([\d]+)(?:[\/])([\d]+)(?:[)])}
    RELEASE_DATE_REGEX_INCOMPLETE = %r{\((\d{4}-\d{2}-\d{2})\)}
    RELEASE_DATE_REGEX_COMPLETE = %r{^(\d{4}-\d{2}-\d{2})}
    VERSION_REGEX = %r{^(\d+)(?:\.(\d+))?(?:\.(\d+))?}

    CONNECTION_ERROR_MSG = "Connection error: couldn't retrieve data from " +
                           "https://www.redmine.org.\n" +
                           "Please try again later..."

    class << self
      def generate
        parse_pagination_items_span_content
        get_changelog_items(@no_of_pages)
        sort_changelog_items
        build_output(@changelog_items, @no_of_issues, version_name, release_date,
                     new_branch?, 'packaged_file')
        build_output(@changelog_items, @no_of_issues, version_name, release_date,
                     new_branch?, 'website')
      end

      def parse_pagination_items_span_content
        items_span = retrieve_pagination_items_span_content
        items_span = items_span.match(PAGINATION_ITEMS_SPAN_REGEX)

        items_per_page = items_span[2].to_i
        @no_of_issues = items_span[3].to_i

        begin
          raise if items_per_page == 0 || @no_of_issues == 0
        rescue => e
          puts "No changelog items to process.\n" +
               "Make sure to provide a valid version id as the -i parameter."
          exit
        end

        @no_of_pages = @no_of_issues / items_per_page
        @no_of_pages += 1 if @no_of_issues % items_per_page > 0
      end

      def retrieve_pagination_items_span_content
        begin
          Nokogiri::HTML(open(ISSUES_URL)).css(PAGINATION_ITEMS_SPAN_SELECTOR).text
        rescue OpenURI::HTTPError
          puts CONNECTION_ERROR_MSG
          exit
        end
      end

      def get_changelog_items(no_of_pages)
        # Initialize @changelog_items hash
        #
        # We'll store categories as hash keys and issues, as nested
        # hashes, in nested arrays as the hash'es values:
        #
        #   {"categoryX"=>
        #     [{"id"=>1, "tracker"=>"tracker1", "subject"=>"subject1"},
        #      {"id"=>2, "tracker"=>"tracker2", "subject"=>"subject2"}],
        #    "categoryY"=>
        #     [{"id"=>3, "tracker"=>"tracker3", "subject"=>"subject3"},
        #      {"id"=>4, "tracker"=>"tracker4", "subject"=>"subject4"}]}
        #
        @changelog_items = Hash.new

        (1..no_of_pages).each do |page_number|
          page = retrieve_issues_list_page(page_number)
          page_trs = page.css(ISSUE_TR_SELECTOR).to_a
          store_changelog_items(page_trs)
        end
      end

      def retrieve_issues_list_page(page_number)
        begin
          Nokogiri::HTML(open(ISSUES_URL + '&page=' + page_number.to_s))
        rescue OpenURI::HTTPError
          puts CONNECTION_ERROR_MSG
          exit
        end
      end

      def store_changelog_items(page_trs)
        page_trs.each do |tr|
          cat = tr.css('td.category').text
          unless @changelog_items.keys.include?(cat)
            @changelog_items.store(cat, [])
          end

          issue_hash = { 'id'       => tr.css('td.id > a').text.to_i,
                         'tracker'  => tr.css('td.tracker').text,
                         'subject'  => tr.css('td.subject> a').text.strip }
          @changelog_items[cat].push(issue_hash)
        end
      end

      # Sort the changelog items hash
      def sort_changelog_items
        # Sort changelog items hash values; first by tracker, then by id
        @changelog_items.each do |key, value|
          @changelog_items[key] = value.sort_by{ |a| [a['tracker'], a['id']] }
        end
        # Sort changelog items hash keys; by category
        @changelog_items = @changelog_items.sort
      end

      def version_name
        @v_name.empty? ? (@version_name || parse_version_name) : @v_name
      end

      def parse_version_name
        version_details = retrieve_version_details
        @version_name = version_details.css(VERSION_NAME_SELECTOR).text
      end

      def release_date
        @r_date.empty? ? (@release_date || Date.today.strftime("%Y-%m-%d")) : @r_date
      end

      def retrieve_version_details
        begin
          Nokogiri::HTML(open(VERSIONS_URL)).css(VERSION_DETAILS_SELECTOR)
        rescue OpenURI::HTTPError
          puts CONNECTION_ERROR_MSG
          exit
        end
      end

      def new_branch?
        @new_branch.nil? ? parse_new_branch : @new_branch
      end

      def parse_new_branch
        @version_name =~ VERSION_REGEX
        version = Array.new([$1, $2, $3])

        case @n_branch
        when 'auto'
          # New branch version detection logic:
          #
          #   [x.x.0]  => true
          #   [x.x.>0] => false
          #   [x.x]    => true
          #   [x]      => true
          #
          if (version[2] != nil && version[2] == '0') ||
             (version[2] == nil && version[1] != nil) ||
             (version[2] == nil && version[1] == nil && version[0] != nil)
            new_branch = true
          end
        when 'true'
          new_branch = true
        when 'false'
          new_branch = false
        end
        @new_branch = new_branch
      end

      # Build and write the changelog file
      def build_output(items, no_of_issues, v_name, r_date, n_branch, target)
        target = target

        output_filename = v_name + '_changelog_for_' + target + '.txt'
        out_file = File.new(output_filename, 'w')

        # Categories counter
        c_cnt = 0
        # Issues with category counter
        i_cnt = 0
        # Issues without category counter
        nc_i_cnt = 0

        if target == 'packaged_file'
          out_file << "== #{r_date} v#{v_name}\n\n"
        elsif target == 'website'
          out_file << "h1. Changelog #{v_name}\n\n" if n_branch == true
          out_file << "h2. version:#{v_name} (#{r_date})\n\n"
        end

        # Print the categories...
        items.each do |key, values|
          key = key.empty? ? '-none-' : key

          if target == 'packaged_file'
            out_file << "=== [#{key}]\n"
          elsif target == 'website'
            out_file << "h3. [#{key}]\n"
          end
          out_file << "\n"
          (c_cnt += 1) unless key == '-none-'

          # ...and their associated issues
          values.each do |val|
            out_file << "* #{val['tracker']} ##{val['id']}: #{val['subject']}\n"
            key == '-none-' ? (nc_i_cnt += 1) : (i_cnt += 1)
          end
          out_file << "\n"
        end

        summary(v_name, target, i_cnt, nc_i_cnt, no_of_issues, c_cnt)

        out_file.close
      end

      def summary(v_name, target, i_cnt, nc_i_cnt, no_of_issues, c_cnt)
        summary = (('-' * 72) + "\n")
        summary << "Generation of the #{v_name} changelog for '#{target}' has " +
                   "#{result_label(i_cnt, nc_i_cnt, no_of_issues)}:\n"
        summary << "* #{i_cnt} #{issue_label(i_cnt)} within #{c_cnt} issue " +
                   "#{category_label(c_cnt)}\n"
        if nc_i_cnt > 0
          summary << "* #{nc_i_cnt} #{issue_label(nc_i_cnt)} without issue category\n"
        end
        puts summary
        return summary
      end

      def result_label(i_cnt, nc_i_cnt, no_of_issues)
        result = i_cnt + nc_i_cnt == no_of_issues ? 'succeeded' : 'failed'
        result.upcase
      end

      def issue_label(count)
        count > 1 ? 'issues' : 'issue'
      end

      def category_label(count)
        count > 1 ? 'categories' : 'category'
      end
    end
  end
end

Redmine::ChangelogGenerator.generate
