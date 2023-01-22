rule ".rb" => ".rb.peg" do |t|
  require "packcr"
  Packcr.new(t.source).run
end
