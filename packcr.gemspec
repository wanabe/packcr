Gem::Specification.new "packcr", "0.0.1" do |s|
  version_module = Module.new do
    version_rb = File.join(__dir__, "lib/packcr/version.rb")
    module_eval(File.read(version_rb), version_rb)
  end

  s.name       = "packcr"
  s.version    = version_module::Packcr::VERSION
  s.summary    = "PackCC wrapper"
  s.authors    = ["wanabe"]
  s.licenses   = ["MIT"]

  s.files      = Dir.glob("{lib/**/*.rb,ext/**/*.{c,h}}")
  s.extensions = %w[ext/packcr/extconf.rb]

  s.add_development_dependency "rake-compiler"
end
