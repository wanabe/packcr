require "rspec"
require "rspec-parameterized"

require "packcr"
require "ffi"

RSpec.describe "rust integration" do
  def make(target, depend, dir, &)
    target = File.expand_path(target, dir)
    if !File.exist?(target) || File.mtime(target) < File.mtime(depend)
      Dir.chdir(dir, &)
    end
    target
  end

  def capture_output
    r, w = IO.pipe
    orig_stdout = $stdout.dup
    begin
      $stdout.reopen(w)
      yield
    ensure
      $stdout.reopen(orig_stdout)
    end
    w.close
    result = r.read
    r.close
    result
  end

  let(:dir) { File.expand_path(__dir__) }
  let(:peg) { File.expand_path("test_parser.peg", dir) }
  let(:rs) { make("test_parser.rs", peg, dir) { Packcr.new(peg, lang: :rs).run } }
  let(:lib) { make("libtest_parser.so", rs, dir) { system("rustc --crate-type=cdylib test_parser.rs") || raise } }

  let(:parser) do
    lib = self.lib
    Module.new do
      extend FFI::Library
      ffi_lib lib
      attach_function :parse, [:string], :int
    end
  end

  context "simple pattern" do
    where(:src, :value) do
      [
        ["action1:", 110],
        ["char1:1", 210],
        ["char2:3", 220],
        ["char3:2", 230],
        ["char4:0", 240],
        ["char5:9", 250],
        ["char6:7", 260],
        ["capt1:1", 311],
        ["capt1:3", 313],
        ["pred1:2", 410],
        ["quan1:1", 510],
        ["quan1:a1", 510],
        ["quan2:a2", 520],
        ["quan2:aaaaa2", 520],
        ["ref1:0", 610],
        ["ref1:123", 610],
        ["unknown", -1],
      ]
    end

    with_them do
      it do
        expect(parser.parse(src)).to eq(value)
      end
    end
  end

  context "calc" do
    where(:src, :value) do
      [
        ["calc:1", 1],
        ["calc:-1+2+4", 5],
        ["calc:1-23*45/3", -344],
        ["calc:(1+2)*3", 9],
        ["calc:x**2", -1],
      ]
    end

    with_them do
      it do
        expect(parser.parse(src)).to eq(value)
      end
    end

    it "handles divzero error" do
      out = capture_output do
        expect(parser.parse("calc:1/0")).to eq(0)
      end
      expect(out.chomp).to eq("Div zero error")
    end
  end
end
