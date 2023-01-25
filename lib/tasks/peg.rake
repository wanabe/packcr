rule ".rb" => ".rb.peg" do |t|
  require "packcr"
  Packcr.new(t.source).run
end

file "lib/packcr/parser.rb" => Dir.glob("{lib/packcr/generated/**/*.rb,lib/packcr/parser.rb.peg,lib/packcr/version.rb}")
