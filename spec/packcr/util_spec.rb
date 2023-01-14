require "rspec"
require "rspec-parameterized"

require "packcr/util"

RSpec.describe Packcr::Util do
  describe "#unescape_string" do
    subject { Packcr.unescape_string(str, charclass) }

    where(:charclass, :str, :expected) do
      [
        [false, "abcd", "abcd"],
        [false, "\\xe3\\x81\\x82", "あ"],
        [false, "\\u3044", "い"],
        [false, "\\'", "'"],
        [false, "\\0", "\0"],
        [false, "\\\\", "\\"],
        [true,  "abcd", "abcd"],
        [true,  "\\xe3\\x81\\x82", "あ"],
        [true,  "\\u3044", "い"],
        [true,  "\\\\", "\\\\"],
      ]
    end

    with_them do
      it do
        expect(subject).to eq(expected)
      end
    end
  end

  describe "#escape_character" do
    subject { Packcr.escape_character(str) }

    where(:str, :expected) do
      [
        [ "\x00", "\\0"],
        [ "\x01", "\\x01"],
        [ "\x02", "\\x02"],
        [ "\x03", "\\x03"],
        [ "\x04", "\\x04"],
        [ "\x05", "\\x05"],
        [ "\x06", "\\x06"],
        [ "\x07", "\\a"],
        [ "\x08", "\\b"],
        [ "\x09", "\\t"],
        [ "\x0a", "\\n"],
        [ "\x0b", "\\v"],
        [ "\x0c", "\\f"],
        [ "\x0d", "\\r"],
        [ "\x1a", "\\x1a"],
        [ "\x1b", "\\x1b"],
        [ "\x1c", "\\x1c"],
        [ "\x20", " "],
        [ "\"", "\\\""],
        [ "'", "\\\'"],
        [ "A", "A"],
        [ "\\", "\\\\"],
        ["~", "~"],
        ["\x7f", "\\x7f"],
        ["\xff", "\\xff"],
        ["only first character", "o"],
      ]
    end

    with_them do
      it do
        expect(subject).to eq(expected)
      end
    end
  end

  describe "#escape_string" do
    subject { Packcr.escape_string(str) }

    where(:str, :expected) do
      [
        [
          "mixed\0\0\x07\x1dsome\e \'char\' can 変換!",
          "mixed\\0\\0\\a\\x1dsome\\x1b \\'char\\' can \\xe5\\xa4\\x89\\xe6\\x8f\\x9b!"
        ],
      ]
    end

    with_them do
      it do
        expect(subject).to eq(expected)
      end
    end
  end

  describe "#find_trailing_blanks" do
    subject { Packcr.find_trailing_blanks(str) }

    where(:str, :expected) do
      [
        ["abcde",   5],
        ["  cde",   5],
        ["a\n\nde", 5],
        ["abc\n\n", 3],
        ["a c  ",   3],
        ["   ",     0]
      ]
    end

    with_them do
      it do
        expect(subject).to eq(expected)
      end
    end
  end

  describe "#unify_indent_spaces" do
    subject { Packcr.unify_indent_spaces(str) }

    where(:str, :expected) do
      [
        ["\t \v\f",      " " * 11],
        ["\t\t\t",       " " * 24],
        [" \t  \t   \t", " " * 24],
        ["",             ""],
      ]
    end

    with_them do
      it do
        expect(subject).to eq(expected)
      end
    end
  end
end
