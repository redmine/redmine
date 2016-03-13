# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::UnifiedDiffTest < ActiveSupport::TestCase
  def test_subversion_diff
    diff = Redmine::UnifiedDiff.new(read_diff_fixture('subversion.diff'))
    # number of files
    assert_equal 4, diff.size
    assert diff.detect {|file| file.file_name =~ %r{^config/settings.yml}}
  end

  def test_truncate_diff
    diff = Redmine::UnifiedDiff.new(read_diff_fixture('subversion.diff'), :max_lines => 20)
    assert_equal 2, diff.size
  end

  def test_inline_partials
    diff = Redmine::UnifiedDiff.new(read_diff_fixture('partials.diff'))
    assert_equal 1, diff.size
    diff = diff.first
    assert_equal 43, diff.size

    assert_equal [51, -1], diff[0].offsets
    assert_equal [51, -1], diff[1].offsets
    assert_equal 'Lorem ipsum dolor sit amet, consectetur adipiscing <span>elit</span>', diff[0].html_line
    assert_equal 'Lorem ipsum dolor sit amet, consectetur adipiscing <span>xx</span>', diff[1].html_line

    assert_nil diff[2].offsets
    assert_equal 'Praesent et sagittis dui. Vivamus ac diam diam', diff[2].html_line

    assert_equal [0, -14], diff[3].offsets
    assert_equal [0, -14], diff[4].offsets
    assert_equal '<span>Ut sed</span> auctor justo', diff[3].html_line
    assert_equal '<span>xxx</span> auctor justo', diff[4].html_line

    assert_equal [13, -19], diff[6].offsets
    assert_equal [13, -19], diff[7].offsets

    assert_equal [24, -8], diff[9].offsets
    assert_equal [24, -8], diff[10].offsets

    assert_equal [37, -1], diff[12].offsets
    assert_equal [37, -1], diff[13].offsets

    assert_equal [0, -38], diff[15].offsets
    assert_equal [0, -38], diff[16].offsets
  end

  def test_side_by_side_partials
    diff = Redmine::UnifiedDiff.new(read_diff_fixture('partials.diff'), :type => 'sbs')
    assert_equal 1, diff.size
    diff = diff.first
    assert_equal 32, diff.size

    assert_equal [51, -1], diff[0].offsets
    assert_equal 'Lorem ipsum dolor sit amet, consectetur adipiscing <span>elit</span>', diff[0].html_line_left
    assert_equal 'Lorem ipsum dolor sit amet, consectetur adipiscing <span>xx</span>', diff[0].html_line_right

    assert_nil diff[1].offsets
    assert_equal 'Praesent et sagittis dui. Vivamus ac diam diam', diff[1].html_line_left
    assert_equal 'Praesent et sagittis dui. Vivamus ac diam diam', diff[1].html_line_right

    assert_equal [0, -14], diff[2].offsets
    assert_equal '<span>Ut sed</span> auctor justo', diff[2].html_line_left
    assert_equal '<span>xxx</span> auctor justo', diff[2].html_line_right

    assert_equal [13, -19], diff[4].offsets
    assert_equal [24, -8], diff[6].offsets
    assert_equal [37, -1], diff[8].offsets
    assert_equal [0, -38], diff[10].offsets

  end

  def test_partials_with_html_entities
    raw = <<-DIFF
--- test.orig.txt Wed Feb 15 16:10:39 2012
+++ test.new.txt  Wed Feb 15 16:11:25 2012
@@ -1,5 +1,5 @@
 Semicolons were mysteriously appearing in code diffs in the repository
 
-void DoSomething(std::auto_ptr<MyClass> myObj)
+void DoSomething(const MyClass& myObj)
 
DIFF

    diff = Redmine::UnifiedDiff.new(raw, :type => 'sbs')
    assert_equal 1, diff.size
    assert_equal 'void DoSomething(<span>std::auto_ptr&lt;MyClass&gt;</span> myObj)', diff.first[2].html_line_left
    assert_equal 'void DoSomething(<span>const MyClass&amp;</span> myObj)', diff.first[2].html_line_right

    diff = Redmine::UnifiedDiff.new(raw, :type => 'inline')
    assert_equal 1, diff.size
    assert_equal 'void DoSomething(<span>std::auto_ptr&lt;MyClass&gt;</span> myObj)', diff.first[2].html_line
    assert_equal 'void DoSomething(<span>const MyClass&amp;</span> myObj)', diff.first[3].html_line
  end

  def test_line_starting_with_dashes
    diff = Redmine::UnifiedDiff.new(<<-DIFF
--- old.txt Wed Nov 11 14:24:58 2009
+++ new.txt Wed Nov 11 14:25:02 2009
@@ -1,8 +1,4 @@
-Lines that starts with dashes:
-
-------------------------
--- file.c
-------------------------
+A line that starts with dashes:
 
 and removed.
 
@@ -23,4 +19,4 @@
 
 
 
-Another chunk of change
+Another chunk of changes

DIFF
    )
    assert_equal 1, diff.size
  end

  def test_one_line_new_files
    diff = Redmine::UnifiedDiff.new(<<-DIFF
diff -r 000000000000 -r ea98b14f75f0 README1
--- /dev/null
+++ b/README1
@@ -0,0 +1,1 @@
+test1
diff -r 000000000000 -r ea98b14f75f0 README2
--- /dev/null
+++ b/README2
@@ -0,0 +1,1 @@
+test2
diff -r 000000000000 -r ea98b14f75f0 README3
--- /dev/null
+++ b/README3
@@ -0,0 +1,3 @@
+test4
+test5
+test6
diff -r 000000000000 -r ea98b14f75f0 README4
--- /dev/null
+++ b/README4
@@ -0,0 +1,3 @@
+test4
+test5
+test6
DIFF
    )
    assert_equal 4, diff.size
    assert_equal "README1", diff[0].file_name
  end

  def test_both_git_diff
    diff = Redmine::UnifiedDiff.new(<<-DIFF
# HG changeset patch
# User test
# Date 1348014182 -32400
# Node ID d1c871b8ef113df7f1c56d41e6e3bfbaff976e1f
# Parent  180b6605936cdc7909c5f08b59746ec1a7c99b3e
modify test1.txt

diff -r 180b6605936c -r d1c871b8ef11 test1.txt
--- a/test1.txt
+++ b/test1.txt
@@ -1,1 +1,1 @@
-test1
+modify test1
DIFF
    )
    assert_equal 1, diff.size
    assert_equal "test1.txt", diff[0].file_name
  end

  def test_include_a_b_slash
    diff = Redmine::UnifiedDiff.new(<<-DIFF
--- test1.txt
+++ b/test02.txt
@@ -1 +0,0 @@
-modify test1
DIFF
    )
    assert_equal 1, diff.size
    assert_equal "b/test02.txt", diff[0].file_name

    diff = Redmine::UnifiedDiff.new(<<-DIFF
--- a/test1.txt
+++ a/test02.txt
@@ -1 +0,0 @@
-modify test1
DIFF
    )
    assert_equal 1, diff.size
    assert_equal "a/test02.txt", diff[0].file_name

    diff = Redmine::UnifiedDiff.new(<<-DIFF
--- a/test1.txt
+++ test02.txt
@@ -1 +0,0 @@
-modify test1
DIFF
    )
    assert_equal 1, diff.size
    assert_equal "test02.txt", diff[0].file_name
  end

  def test_utf8_ja
    ja = "  text_tip_issue_end_day: "
    ja += "\xe3\x81\x93\xe3\x81\xae\xe6\x97\xa5\xe3\x81\xab\xe7\xb5\x82\xe4\xba\x86\xe3\x81\x99\xe3\x82\x8b<span>\xe3\x82\xbf\xe3\x82\xb9\xe3\x82\xaf</span>".force_encoding('UTF-8')
    with_settings :repositories_encodings => '' do
      diff = Redmine::UnifiedDiff.new(read_diff_fixture('issue-12641-ja.diff'), :type => 'inline')
      assert_equal 1, diff.size
      assert_equal 12, diff.first.size
      assert_equal ja, diff.first[4].html_line_left
    end
  end

  def test_utf8_ru
    ru = "        other: &quot;\xd0\xbe\xd0\xba\xd0\xbe\xd0\xbb\xd0\xbe %{count} \xd1\x87\xd0\xb0\xd1\x81<span>\xd0\xb0</span>&quot;".force_encoding('UTF-8')
    with_settings :repositories_encodings => '' do
      diff = Redmine::UnifiedDiff.new(read_diff_fixture('issue-12641-ru.diff'), :type => 'inline')
      assert_equal 1, diff.size
      assert_equal 8, diff.first.size
      assert_equal ru, diff.first[3].html_line_left
    end
  end

  def test_offset_range_ascii_1
    raw = <<-DIFF
--- a.txt	2013-04-05 14:19:39.000000000 +0900
+++ b.txt	2013-04-05 14:19:51.000000000 +0900
@@ -1,3 +1,3 @@
 aaaa
-abc
+abcd
 bbbb
DIFF
    diff = Redmine::UnifiedDiff.new(raw, :type => 'sbs')
    assert_equal 1, diff.size
    assert_equal 3, diff.first.size
    assert_equal "abc<span></span>", diff.first[1].html_line_left
    assert_equal "abc<span>d</span>", diff.first[1].html_line_right
  end

  def test_offset_range_ascii_2
    raw = <<-DIFF
--- a.txt	2013-04-05 14:19:39.000000000 +0900
+++ b.txt	2013-04-05 14:19:51.000000000 +0900
@@ -1,3 +1,3 @@
 aaaa
-abc
+zabc
 bbbb
DIFF
    diff = Redmine::UnifiedDiff.new(raw, :type => 'sbs')
    assert_equal 1, diff.size
    assert_equal 3, diff.first.size
    assert_equal "<span></span>abc", diff.first[1].html_line_left
    assert_equal "<span>z</span>abc", diff.first[1].html_line_right
  end

  def test_offset_range_japanese_1
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span></span>".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xaa\x9e</span>".force_encoding('UTF-8')
    with_settings :repositories_encodings => '' do
      diff = Redmine::UnifiedDiff.new(
               read_diff_fixture('issue-13644-1.diff'), :type => 'sbs')
      assert_equal 1, diff.size
      assert_equal 3, diff.first.size
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    end
  end

  def test_offset_range_japanese_2
    ja1 = "<span></span>\xe6\x97\xa5\xe6\x9c\xac".force_encoding('UTF-8')
    ja2 = "<span>\xe3\x81\xab\xe3\x81\xa3\xe3\x81\xbd\xe3\x82\x93</span>\xe6\x97\xa5\xe6\x9c\xac".force_encoding('UTF-8')
    with_settings :repositories_encodings => '' do
      diff = Redmine::UnifiedDiff.new(
               read_diff_fixture('issue-13644-2.diff'), :type => 'sbs')
      assert_equal 1, diff.size
      assert_equal 3, diff.first.size
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    end
  end

  def test_offset_range_japanese_3
    # UTF-8 The 1st byte differs.
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xa8\x98</span>".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe5\xa8\x98</span>".force_encoding('UTF-8')
    with_settings :repositories_encodings => '' do
      diff = Redmine::UnifiedDiff.new(
               read_diff_fixture('issue-13644-3.diff'), :type => 'sbs')
      assert_equal 1, diff.size
      assert_equal 3, diff.first.size
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    end
  end

  def test_offset_range_japanese_4
    # UTF-8 The 2nd byte differs. 
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xa8\x98</span>".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xaa\x98</span>".force_encoding('UTF-8')
    with_settings :repositories_encodings => '' do
      diff = Redmine::UnifiedDiff.new(
               read_diff_fixture('issue-13644-4.diff'), :type => 'sbs')
      assert_equal 1, diff.size
      assert_equal 3, diff.first.size
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    end
  end

  def test_offset_range_japanese_5
    # UTF-8 The 2nd byte differs. 
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xa8\x98</span>ok".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xaa\x98</span>ok".force_encoding('UTF-8')
    with_settings :repositories_encodings => '' do
      diff = Redmine::UnifiedDiff.new(
               read_diff_fixture('issue-13644-5.diff'), :type => 'sbs')
      assert_equal 1, diff.size
      assert_equal 3, diff.first.size
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    end
  end

  private

  def read_diff_fixture(filename)
    File.new(File.join(File.dirname(__FILE__), '/../../../fixtures/diffs', filename)).read
  end
end
