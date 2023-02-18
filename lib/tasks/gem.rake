require "packcr/version"

file "packcr-#{Packcr::VERSION}.gem" => Dir.glob("lib/**/*.rb") + Dir.glob("lib/**/*.erb") + Dir.glob("exe/*") + ["packcr.gemspec", "rubocop"] do |_t|
  system("gem build")
end
task "gem" => "packcr-#{Packcr::VERSION}.gem"

namespace :gem do
  task "push" => "packcr-#{Packcr::VERSION}.gem" do |t|
    system("git diff --exit-code") || raise("make sure your git status clean")
    system("gem push #{t.source}")
  end
end
