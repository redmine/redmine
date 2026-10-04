# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

require_relative '../../../test_helper'
require 'rubygems/package'

class Redmine::MermaidTest < ActiveSupport::TestCase
  CONTENT = %(var a={version:"#{Redmine::Mermaid::VERSION}"},b=i(()=>a.version,"getVersion");globalThis.mermaid={};\n)

  def setup
    @dir = Dir.mktmpdir
    Redmine::Mermaid.stubs(:path).returns(Pathname.new(@dir).join('mermaid.min.js'))
    Redmine::Mermaid.reset
    Redmine::Mermaid.stubs(:checksum).returns(Digest::SHA256.hexdigest(CONTENT))
  end

  def teardown
    Redmine::Mermaid.reset
    FileUtils.rm_rf(@dir)
  end

  def test_available_should_log_a_warning_when_another_version_is_installed
    File.write(Redmine::Mermaid.path, CONTENT.sub(Redmine::Mermaid::VERSION, '11.17.2'))
    Rails.logger.expects(:warn).with(regexp_matches(/Mermaid\.js 11\.17\.2 is installed/))

    assert Redmine::Mermaid.available?
  end

  def test_install_should_reject_content_with_wrong_checksum
    source = File.join(@dir, 'mermaid.tgz')
    File.binwrite(source, tarball("console.log('another version');"))

    error = assert_raises(Redmine::Mermaid::Error) {Redmine::Mermaid.install(source: source)}
    assert_match /checksum mismatch/, error.message
    assert_not File.exist?(Redmine::Mermaid.path)
  end

  def test_install_should_download_the_tarball
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.stubs(:body).returns(tarball(CONTENT))
    Net::HTTP.expects(:start).returns(response)

    Redmine::Mermaid.install

    assert Redmine::Mermaid.available?
  end

  private

  def tarball(content)
    io = StringIO.new
    gz = Zlib::GzipWriter.new(io)
    Gem::Package::TarWriter.new(gz) do |tar|
      tar.add_file_simple(Redmine::Mermaid::TARBALL_ENTRY, 0o644, content.bytesize) {|f| f.write(content)}
    end
    gz.finish
    io.string
  end
end
