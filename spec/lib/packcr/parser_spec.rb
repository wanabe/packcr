require "rspec"
require "rspec-parameterized"

require "packcr"

RSpec.describe Packcr::Parser do
  class DummyContext
    attr_reader :lang, :root

    def initialize(lang)
      @lang = lang
      @codes = {}
      @root = Packcr::Node::RootNode.new
    end

    def code(name)
      @codes[name] ||= []
    end

    def codes
      @codes.transform_values { |codes| codes.map(&:text) }
    end
  end

  describe "#parse" do
    subject { parser.parse }

    let(:parser) { Packcr::Parser.new(ctx, ifile, debug: true) }
    let(:ifile) { StringIO.new(peg) }
    let(:ctx) { DummyContext.new(lang) }
    let(:lang) { :c }
    let(:debug_messages) { +"" }

    before do
      allow(parser).to receive(:warn) { |msg| debug_messages << msg << "\n" }
    end

    context "no effects" do
      where(:rule, :peg, :str) do
        [
          ["EOF", "", ""],
          ["spaces", " ", " "],
          ["spaces", "\n\n\t\n \n", "\n\n\t\n \n"],
          ["comment", "#", "#"],
          ["comment", "# abc", "# abc"],
          ["comment", "# abc\nthis is next statement\n", "# abc\n"],
        ]
      end

      with_them do
        it do
          subject
          expect(debug_messages).to match(/^ *MATCH *#{rule} 0 #{Regexp.escape(str.inspect)}/)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
        end
      end
    end

    context "directive_include" do
      where(:peg, :codes) do
        [
          ["%earlysource {}", esource: [""]],
          ["%earlycommon { }", esource: [" "], eheader: [" "]],
          ["%source {  test();  }", source: ["  test();  "]],
          ["%source rb -> { other language code is just ignore }", {}],
          ["%lateheader rb->{} c->{\n if () {\n} \n}", lheader: ["\n if () {\n} \n"]],
          ['%latesource { "}}\\"}" }', lsource: [' "}}\\"}" ']],
          ["%header {1}\n rb->{2} {3}", header: ["1", "3"]],
          ["%common { $$ = 1; }", source: [" __ = 1; "], header: [" __ = 1; "]],
          ["%location ${ $$ = 2; }", location: [" $$ = 2; "]],
          ["%initialize {}", init: [""]],
        ]
      end

      with_them do
        it do
          subject
          expect(debug_messages).to match(/^ *MATCH *directive_include 0 #{Regexp.escape(peg.inspect)}/)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
          expect(ctx.codes).to eq(codes)
        end
      end

      context "directive mismatch" do
        let(:peg) { "%value {}" }

        it "rejects" do
          expect(ctx).to receive(:error).with(1, 1, "Invalid directive: value")
          subject
          expect(debug_messages).to match(/^ *MATCH *directive_include 0 /)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
        end
      end
    end

    context "directive_string" do
      where(:peg, :meth, :str) do
        [
          ['%value ""', :value_type=, ""],
          ['%auxil "ab\\"c"', :auxil_type=, 'ab\\"c'],
          ['%prefix rb -> "abc" c -> "def"', :prefix=, 'def'],
          ['%prefix rb -> "ignore"', nil, nil],
        ]
      end

      with_them do
        it do
          expect(ctx).to receive(meth).with(str) if meth
          subject
          expect(debug_messages).to match(/^ *MATCH *directive_string 0 #{Regexp.escape(peg.inspect)}/)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
        end
      end

      context "directive mismatch" do
        let(:peg) { '%header ""' }

        it "rejects" do
          expect(ctx).to receive(:error).with(1, 1, "Invalid directive: header")
          subject
          expect(debug_messages).to match(/^ *MATCH *directive_string 0 /)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
        end
      end
    end

    context "directive_value" do
      where(:peg, :meth, :str) do
        [
          ["%capture on", :capture_in_code=, true],
          ["%capture true", :capture_in_code=, true],
        ]
      end

      with_them do
        it do
          expect(ctx).to receive(meth).with(str)
          subject
          expect(debug_messages).to match(/^ *MATCH *directive_value 0 #{Regexp.escape(peg.inspect)}/)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
        end
      end
    end

    context "footer" do
      where(:peg, :codes) do
        [
          ["%%", lsource: [""]],
          ["%%\n", lsource: [""]],
          ["%%\n\nabc", lsource: ["\nabc"]],
        ]
      end

      with_them do
        it do
          subject
          expect(debug_messages).to match(/^ *MATCH *footer 0 #{Regexp.escape(peg.inspect)}/)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
          expect(ctx.codes).to eq(codes)
        end
      end
    end

    context "rule" do
      where(:peg, :name, :expr) do
        [
          ["a <- b", "a", type: :reference, name: "b"],
          ["foo <- 'bar'", "foo", type: :string, value: "bar"],
        ]
      end

      with_them do
        it do
          subject
          expect(debug_messages).to match(/^ *MATCH *rule 0 #{Regexp.escape(peg.inspect)}/)
          expect(debug_messages).to match(/^MATCH *statement 0 .*\n\z/)
          expect(ctx.root.rules.map(&:to_h)).to match([
            hash_including(expr: hash_including(expr))
          ])
        end
      end
    end

    context "SyntaxError" do
      where(:peg, :line, :col, :error) do
        [
          ["a", 1, 1, "Illegal syntax"],
          ["%% \n", 1, 1, "Illegal syntax"],
        ]
      end

      with_them do
        it do
          expect(ctx).to receive(:error).with(line, col, error)
          expect { subject }.to raise_error(SyntaxError)
          expect(debug_messages).to match(/^NOMATCH *statement 0 .*\n\z/)
        end
      end
    end
  end
end
