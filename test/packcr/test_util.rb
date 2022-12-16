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
end
