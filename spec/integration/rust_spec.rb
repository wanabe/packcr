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
      ]
    end

    with_them do
      it do
        expect(parser.parse(src)).to eq(value)
      end
    end
  end
end
