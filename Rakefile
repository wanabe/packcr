require "bundler/setup"
require "bundler"
require "packcr"

task default: :test

namespace :update do
  task :parser do
    Packcr.new("lib/packcr/parser.rb.peg").run
  end
end

task :test do
  Dir.glob("test/**/*.rb") do |path|
    load path
  end
end
