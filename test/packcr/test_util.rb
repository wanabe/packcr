require "test-unit"

require "packcr/util"

class Packcr::TestUtil < Test::Unit::TestCase
  sub_test_case "#is_identifier_string" do
    data(
      "downcase"   => "abc",
      "CamelCase"  => "DefGhi",
      "underscore" => "___",
      "mix"        => "some_words_joined_with_underscore",
    )
    test "all character are alphabets or underscore" do |str|
      assert_equal(true, Packcr.is_identifier_string(str))
    end

    data(
      "tail"       => "abc0",
      "mid"        => "de1fg",
      "underscore" => "_2",
    )
    test "contains numbers" do |str|
      assert_equal(true, Packcr.is_identifier_string(str))
    end

    data(
      "alphabet"   => "0abc",
      "underscore" => "1_",
    )
    test "start with number" do |str|
      assert_equal(false, Packcr.is_identifier_string(str))
    end

    data(
      "alphabet"   => "Ａ",
      "japanese"   => "あいう",
    )
    test "UTF-8" do |str|
      assert_equal(false, Packcr.is_identifier_string(str))
    end
  end

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

  sub_test_case "#find_first_trailing_space" do
    data(
      "no space"    => ["abcde", 0, 5, [5, 5]],
      "first space" => [" bcde", 0, 4, [4, 4]],
      "mid space"   => ["ab de", 0, 5, [5, 5]],
    )
    test "no trailing space" do |(str, s, e, expected)|
      assert_equal(expected, Packcr.find_first_trailing_space(str, s, e))
    end

    data(
      "no space with LF"         => ["abcd\n",  0, 5, [4, 5]],
      "no space with CR"         => ["abcd\r",  0, 5, [4, 5]],
      "no space with CRLF"       => ["abc\r\n", 0, 5, [3, 5]],
      "trailing space with LF"   => ["abc \n",  0, 5, [3, 5]],
      "trailing space with CR"   => ["abc \r",  0, 5, [3, 5]],
      "trailing space with CRLF" => ["ab \r\n", 0, 5, [2, 5]],
      "mid space with LF"        => ["a cd\n",  0, 5, [4, 5]],
      "mid space with CR"        => ["a cd\r",  0, 5, [4, 5]],
      "mid space with CRLF"      => ["a c\r\n", 0, 5, [3, 5]],
    )
    test "line break" do |(str, s, e, expected)|
      assert_equal(expected, Packcr.find_first_trailing_space(str, s, e))
    end

    data(
      "start with space"    => [" a b c  \n def  ", 0, 15, [ 6,  9]],
      "start with no-space" => [" a b c  \n def  ", 1, 15, [ 6,  9]],
      "trailing space"      => [" a b c  \n def  ", 7, 15, [ 7,  9]],
      "start with eol"      => [" a b c  \n def  ", 8, 15, [ 8,  9]],
      "no lf"               => [" a b c  \n def  ", 9, 15, [13, 15]],
      "short end pos"       => [" a b c  \n def  ", 9, 14, [13, 14]],
    )
    test "complex pattern" do |(str, s, e, expected)|
      assert_equal(expected, Packcr.find_first_trailing_space(str, s, e))
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

  sub_test_case "#count_indent_spaces" do
    data(
      "first tab"     => ["\tabc",       0, 4, [ 8, 1]],
      "space and tab" => ["  \t  \tabc", 0, 9, [16, 6]],
      "no space"      => ["abcd",        0, 4, [ 0, 0]],
      "offset"        => ["abcd",        2, 4, [ 0, 2]],
    )
    test "found" do |(str, s, e, expected)|
      assert_equal(expected, Packcr.count_indent_spaces(str, s, e))
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
