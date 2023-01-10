Gem::Specification.new do |s|
  version_module = Module.new do
    version_rb = File.join(__dir__, "lib/packcr/version.rb")
    module_eval(File.read(version_rb), version_rb)
  end

  s.name       = "packcr"
  s.version    = version_module::Packcr::VERSION
  s.homepage   = "https://github.com/wanabe/packcr"
  s.summary    = "Parser generator for C or Ruby"
  s.authors    = ["wanabe"]
  s.licenses   = ["MIT"]

  s.bindir      = "exe"
  s.files       = Dir.glob("lib/**/*.rb") + Dir.glob("exe/*")
  s.executables = ["packcr"]

  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "test-unit", "~> 3.5"
end
