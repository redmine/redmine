    ja = "  text_tip_issue_end_day: "
    ja += "\xe3\x81\x93\xe3\x81\xae\xe6\x97\xa5\xe3\x81\xab\xe7\xb5\x82\xe4\xba\x86\xe3\x81\x99\xe3\x82\x8b<span>\xe3\x82\xbf\xe3\x82\xb9\xe3\x82\xaf</span>".force_encoding('UTF-8')
      assert_equal ja, diff.first[4].html_line_left
    ru = "        other: &quot;\xd0\xbe\xd0\xba\xd0\xbe\xd0\xbb\xd0\xbe %{count} \xd1\x87\xd0\xb0\xd1\x81<span>\xd0\xb0</span>&quot;".force_encoding('UTF-8')
      assert_equal ru, diff.first[3].html_line_left
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span></span>".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xaa\x9e</span>".force_encoding('UTF-8')
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    ja1 = "<span></span>\xe6\x97\xa5\xe6\x9c\xac".force_encoding('UTF-8')
    ja2 = "<span>\xe3\x81\xab\xe3\x81\xa3\xe3\x81\xbd\xe3\x82\x93</span>\xe6\x97\xa5\xe6\x9c\xac".force_encoding('UTF-8')
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xa8\x98</span>".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe5\xa8\x98</span>".force_encoding('UTF-8')
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xa8\x98</span>".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xaa\x98</span>".force_encoding('UTF-8')
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right
    ja1 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xa8\x98</span>ok".force_encoding('UTF-8')
    ja2 = "\xe6\x97\xa5\xe6\x9c\xac<span>\xe8\xaa\x98</span>ok".force_encoding('UTF-8')
      assert_equal ja1, diff.first[1].html_line_left
      assert_equal ja2, diff.first[1].html_line_right