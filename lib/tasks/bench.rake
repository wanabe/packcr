class Bench
  def initialize(scr, w: 5.0, b: "")
    @scr = scr
    @w = w
    @b = b
  end

  def ips
    i, s = iter_sec
    i / s
  end

  def iter_sec
    n = 2
    while @w > 3 * s = sec(@scr, @b, n)
      n = (n * [@w / s / 3, 2].max).to_i
    end
    [n, s - sec("", "", n)]
  end

  def sec(s, setup_code, n)
    eval <<~EOS, binding, __FILE__, __LINE__ + 1
      # parser = Packcr.new("tmp/ast-tinyc.peg")
      # _t = Time.now
      # _i = 100
      # while _i > 0
      #   _i -= 1
      #   parser.run
      # end
      # Time.now - _t

      #{setup_code}
      _t = Time.now
      _i = #{n}
      while _i > 0
        _i -= 1
        #{s}
      end
      Time.now - _t
    EOS
  end
end

file "tmp/ast-tinyc.peg" => "packcc/examples/ast-tinyc/parser.peg" do |t|
  cp t.source, t.name
end

file "tmp/bench.rb" do |t|
  n = ENV["TIMES"]&.to_i || 5
  open(t.name, "w") do |ofile|
    ofile.print <<~EOS
      require "bundler/setup"
      require "packcr"
    EOS
    ofile.puts File.read(__FILE__)[/^class Bench.*?^end/m]
    ofile.print <<~EOS
      bench = Bench.new("parser.run", w: 5.0, b: "parser = Packcr.new(\\\"tmp/ast-tinyc.peg\\\")")
      #{n}.times do
        print ENV["PREFIX"], " " if ENV["PREFIX"]
        puts bench.ips
        STDOUT.flush
      end
    EOS
  end
end

task bench: "tmp/ast-tinyc.peg" do
  require "packcr"
  n = ENV["TIMES"]&.to_i || 1
  w = ENV["WAIT"]&.to_f || 5.0

  bench = Bench.new("parser.run", w: w, b: "parser = Packcr.new(\"tmp/ast-tinyc.peg\")")
  n.times do
    puts bench.ips
  end
end

task bench_commits: ["tmp/ast-tinyc.peg", "tmp/bench.rb"] do
  current = `git branch --show-current`.chomp
  current = `git rev-parse HEAD`.chomp if current.empty?
  begin
    commits = `git log --reverse --format=%h #{ENV["COMMIT_RANGE"]}`.split("\n")
    r, w = IO.pipe
    open("tmp/bench.log", "w") do |ofile|
      th = Thread.new do
        while !r.eof?
          line = r.gets
          warn line
          ofile.puts line
          ofile.flush
        end
      end
      commits.each do |commit|
        system("git checkout #{commit}", err: File::NULL) || raise
        warn commit
        system("PREFIX=#{commit} ruby tmp/bench.rb", out: w)
      end
      w.close
      th.join
    end
  ensure
    system("git checkout #{current}")
  end
end
