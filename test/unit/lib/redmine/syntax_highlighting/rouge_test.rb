# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require File.expand_path('../../../../../test_helper', __FILE__)

class Redmine::SyntaxHighlighting::RougeTest < ActiveSupport::TestCase
  def test_filename_supported
    to_test = {
      'application.js' => true,
      'Gemfile' => true,
      'HELLO.CBL' => false,  # Rouge does not support COBOL
      'HELLO.C' => true
    }
    to_test.each do |filename, expected|
      assert_equal expected, Redmine::SyntaxHighlighting::Rouge.filename_supported?(filename)
    end
  end

  def test_highlight_by_filename_should_distinguish_perl_and_prolog
    raw_perl = <<~'RAW_PERL'
      #!/usr/bin/perl
      print "Hello, world!\n";
    RAW_PERL
    expected_perl = <<~'EXPECTED_PERL'
      <span class="c1">#!/usr/bin/perl</span>
      <span class="k">print</span> <span class="p">"</span><span class="s2">Hello, world!</span><span class="se">\n</span><span class="p">";</span>
    EXPECTED_PERL
    raw_prolog = <<~'RAW_PROLOG'
      #!/usr/bin/swipl
      :- writeln('Hello, world!'),halt.
    RAW_PROLOG
    expected_prolog = <<~'EXPECTED_PROLOG'
      <span class="c1">#!/usr/bin/swipl</span>
      <span class="p">:-</span> <span class="ss">writeln</span><span class="p">(</span><span class="ss">'Hello, world!'</span><span class="p">),</span><span class="ss">halt</span><span class="p">.</span>
    EXPECTED_PROLOG

    filename = 'hello.pl'

    # Rouge cannot distinguish between Perl and Prolog by filename alone
    assert_raises Rouge::Guesser::Ambiguous do
      Rouge::Lexer.guess(:filename => filename)
    end
    assert_equal Rouge::Lexers::Perl, Rouge::Lexer.guess(:filename => filename, :source => raw_perl)
    assert_equal Rouge::Lexers::Prolog, Rouge::Lexer.guess(:filename => filename, :source => raw_prolog)

    assert_equal expected_perl, Redmine::SyntaxHighlighting::Rouge.highlight_by_filename(raw_perl, filename)
    assert_equal expected_prolog, Redmine::SyntaxHighlighting::Rouge.highlight_by_filename(raw_prolog, filename)
  end
end
