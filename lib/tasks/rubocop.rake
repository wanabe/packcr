task :rubocop do
  files = Dir.glob("{#{ARGV.join(",")}}")
  system(*(%w[bundle exec rubocop -a] + files))
  system(*(%w[bundle exec rubocop -A] + files)) || raise("rubocop failed")
end
