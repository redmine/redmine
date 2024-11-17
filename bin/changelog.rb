#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'date'
require 'uri'
require 'net/http'
require 'json'
require 'base64'

VERSION = '1.0.0'

ARGV << '-h' if ARGV.empty?

class OptionsParser
  def self.parse(args)
    options = OpenStruct.new
    options.release_date = ''
    options.api_url = 'https://www.redmine.org'

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

      opts.on('-d', '--release_date RELEASEDATE',
              'Date of the release [string: YYYY-MM-DD]') do |d|
        options.release_date = d
      end

      opts.on('-u', '--api-url URL',
              'Redmine API URL for requests. Default is https://www.redmine.org') do |u|
        options.api_url = u
      end

      opts.on('-a', '--api_key APIKEY',
              'Redmine API-Key to authenticate to the API. Default mode is anonymous') do |a|
        options.api_key = a
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
  $r_date = options[:release_date]
  $api_url = options[:api_url]
  $api_key = options[:api_key]
end

module Redmine
  module ChangelogGenerator
    require 'open-uri'

    @v_id = $v_id
    @r_date = $r_date
    @api_url = $api_url
    @api_key = $api_key

    CONNECTION_ERROR_MSG = "Connection error: couldn't retrieve data from " +
      "https://www.redmine.org.\n" +
      "Please try again later..."

    # Page size (number of issues per request)
    PAGE_SIZE = 100

    class << self
      def generate
        get_changelog_items
        sort_changelog_items

        build_output(@changelog_items, @no_of_issues, @version_name, release_date, 'packaged_file')
        build_output(@changelog_items, @no_of_issues, @version_name, release_date, 'website')
      end

      def api_issues_get(page)
        uri = URI(@api_url + "/issues.json?fixed_version_id=#{@v_id}&status_id=*&limit=#{PAGE_SIZE}&offset=#{page * PAGE_SIZE}")

        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true if @api_url.start_with?("https")

        request = Net::HTTP::Get.new(uri)
        request['Content-Type'] = "application/json"
        request['X-Redmine-API-Key'] = @api_key

        response = https.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          puts CONNECTION_ERROR_MSG
          exit
        end

        JSON.parse(response.body)
      end

      def retrieve_issues
        page = 0
        issues_request = api_issues_get(page)
        @no_of_issues = issues_request['total_count']

        issues = issues_request['issues']
        while issues.length > 0 && @no_of_issues > issues.length
          page += 1
          new_issues = api_issues_get(page)
          issues.concat(new_issues['issues'])
        end

        issues
      end

      def get_changelog_items
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

        issues = retrieve_issues
        store_changelog_items(issues)
      end

      def store_changelog_items(issues)
        issues.each do |issue|
          cat = issue.has_key?('category') ? issue['category']['name'] : "No category"

          unless @changelog_items.keys.include?(cat)
            @changelog_items.store(cat, [])
          end

          parse_version_name(issue['fixed_version']['name'])
          issue_hash = { 'id'       => issue['id'],
                         'tracker'  => issue['tracker']['name'],
                         'subject'  => issue['subject']
          }

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

      def parse_version_name(version)
        begin
          if !@version_name || Gem::Version.new(version) > Gem::Version.new(@version_name)
            @version_name = version
          end
        rescue
          @version_name = version
        end
      end

      def release_date
        @r_date.empty? ? (@release_date || Date.today.strftime("%Y-%m-%d")) : @r_date
      end

      # Build and write the changelog file
      def build_output(items, no_of_issues, v_name, r_date, target)
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
