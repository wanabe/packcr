task :rubocop do
  all_files = Dir.glob("{lib,spec,tool}/**/*.{rb,rake}") + Dir.glob("exe/*") + ["packcr.gemspec"]
  files = Dir.glob("{#{ARGV.join(",")}}")
  files &= all_files
  if files.empty?
    files = all_files
  end
  system(*(%w[bundle exec rubocop -a] + files))
  system(*(%w[bundle exec rubocop -A] + files)) || raise("rubocop failed")
end
