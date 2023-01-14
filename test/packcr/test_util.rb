require "test-unit"

require "packcr/util"

class Packcr::TestUtil < Test::Unit::TestCase
  sub_test_case "#unescape_string" do
    data(
      "ascii"   => ["abcd", "abcd"],
      "\\xnn"   => ["\\xe3\\x81\\x82", "あ"],
      "\\unnnn" => ["\\u3044", "い"],
      "'"       => ["\\'", "'"],
      "\\0"     => ["\\0", "\0"],
      "\\"      => ["\\\\", "\\"],
    )
    test "charclass is false" do |(str, expected)|
      assert_equal(expected, Packcr.unescape_string(str, false))
    end

    data(
      "ascii"   => ["abcd", "abcd"],
      "\\xnn"   => ["\\xe3\\x81\\x82", "あ"],
      "\\unnnn" => ["\\u3044", "い"],
      "\\"      => ["\\\\", "\\\\"],
    )
    test "charclass is true" do |(str, expected)|
      assert_equal(expected, Packcr.unescape_string(str, true))
    end
  end

  sub_test_case "#escape_character" do
    data(
      "\\x00"  => [ "\x00", "\\0"],
      "\\x01"  => [ "\x01", "\\x01"],
      "\\x02"  => [ "\x02", "\\x02"],
      "\\x03"  => [ "\x03", "\\x03"],
      "\\x04"  => [ "\x04", "\\x04"],
      "\\x05"  => [ "\x05", "\\x05"],
      "\\x06"  => [ "\x06", "\\x06"],
      "\\x07"  => [ "\x07", "\\a"],
      "\\x08"  => [ "\x08", "\\b"],
      "\\x09"  => [ "\x09", "\\t"],
      "\\x0a"  => [ "\x0a", "\\n"],
      "\\x0b"  => [ "\x0b", "\\v"],
      "\\x0c"  => [ "\x0c", "\\f"],
      "\\x0d"  => [ "\x0d", "\\r"],
      "\\x1a"  => [ "\x1a", "\\x1a"],
      "\\x1b"  => [ "\x1b", "\\x1b"],
      "\\x1c"  => [ "\x1c", "\\x1c"],
      "\\x20"  => [ "\x20", " "],
      "\""  => [ "\"", "\\\""],
      "'"  => [ "'", "\\\'"],
      "A"  => [ "A", "A"],
      "\\"  => [ "\\", "\\\\"],
      "~" => ["~", "~"],
      "\\x7f" => ["\x7f", "\\x7f"],
      "\\xff" => ["\xff", "\\xff"],
    )
    test "one character" do |(arg, expected)|
      assert_equal(expected, Packcr.escape_character(arg))
    end

    data(
      "A" => ["A", "A"],
      "\\" => ["\\", "\\\\"],
      "string"  => ["only first character", "o"],
    )
    test "string" do |(arg, expected)|
      assert_equal(expected, Packcr.escape_character(arg))
    end
  end

  sub_test_case "#escape_string" do
    data(
      "mixed"  => [ "mixed\0\0\x07\x1dsome\e \'char\' can 変換!", "mixed\\0\\0\\a\\x1dsome\\x1b \\'char\\' can \\xe5\\xa4\\x89\\xe6\\x8f\\x9b!"],
    )
    test "escape" do |(arg, expected)|
      assert_equal(expected, Packcr.escape_string(arg))
    end
  end

  sub_test_case "#find_trailing_blanks" do
    data(
      "no space"     => ["abcde", 5],
      "first space"  => ["  cde", 5],
      "middle space" => ["a\n\nde", 5],
    )
    test "not found" do |(str, expected)|
      assert_equal(expected, Packcr.find_trailing_blanks(str))
    end

    data(
      "trailing LF" => ["abc\n\n", 3],
      "some space"  => ["a c  ", 3],
      "only space"  => ["   ", 0]
    )
    test "found" do |(str, expected)|
      assert_equal(expected, Packcr.find_trailing_blanks(str))
    end
  end

  sub_test_case "#unify_indent_spaces" do
    data(
      "first tab"     => ["\t \v\f",      " " * 11],
      "tabs"          => ["\t\t\t",       " " * 24],
      "space and tab" => [" \t  \t   \t", " " * 24],
      "no space"      => ["",             ""],
    )
    test "found" do |(str, expected)|
      assert_equal(expected, Packcr.unify_indent_spaces(str))
    end
  end
end
