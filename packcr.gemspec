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
  s.required_ruby_version = ">= 3.2.0"

  s.bindir      = "exe"
  s.files       = Dir.glob("{#{%w[LICENSE README.md lib/**/*.rb lib/**/*.erb exe/*].join(",")}}")
  s.executables = ["packcr"]

  s.metadata["rubygems_mfa_required"] = "true"
end
