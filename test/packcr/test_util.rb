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
end
