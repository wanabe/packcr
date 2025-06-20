def generate_code(t, namespace, base, selector, args_map)
  scr = +""
  namespace.each do |klass|
    scr << "class #{klass}\n"
  end
  results = {}
  t.sources.sort.each do |template_path|
    template_path =~ /#{base}(\w*)\.(\w*)\.erb$/
    suffix = Regexp.last_match(1)
    lang = Regexp.last_match(2)
    args = args_map[suffix]
    if suffix != "" && suffix !~ /^_/
      suffix = "_#{suffix}"
    end
    method_name = "get#{suffix}_code"

    src = ERB.new(File.read(template_path), trim_mode: "%-", eoutvar: "erbout").src
    src.sub!(/\A#coding:UTF-8\n/, "")
    body = +""
    Ripper.lex(src).each do |(_, on, s, _)|
      case on
      when :on_semicolon
        body << ("\n" * s.size)
      when :on_kw
        if s == "end"
          body.gsub!(/\n+(\n *)\z/) { Regexp.last_match(1) }
        end
        body << s
      else
        body << s
      end
    end
    results[method_name] ||= [args, {}]
    results[method_name].last[lang] = body
  end
  results.each do |method_name, (args, lang_results)|
    scr << <<~EOS
      def #{method_name}#{args}
        case #{selector}
    EOS
    lang_results.each do |lang, body|
      scr << <<~EOS
        when :#{lang}
          #{body}
      EOS
    end
    scr << <<~EOS
        else
          raise "unknown lang \#{#{selector}}"
        end
      end
    EOS
  end
  namespace.size.times do
    scr << "end\n"
  end
  File.write(t.name, scr)
end

file "lib/packcr/generated/context.rb" => Dir.glob("lib/packcr/templates/context/*.erb") do |t|
  generate_code(t, %w[Packcr Context], "", "lang",
    "source" => "(lang, stream)",
    "source_body" => "(lang, stream)",
    "header" => "(lang, stream)",
  )
end

file "lib/packcr/generated/node/action_node.rb" => Dir.glob("lib/packcr/templates/node/action*.erb") do |t|
  generate_code(t, %w[Packcr Node ActionNode], "action", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/alternate_node.rb" => Dir.glob("lib/packcr/templates/node/alternate*.erb") do |t|
  generate_code(t, %w[Packcr Node AlternateNode], "alternate", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/capture_node.rb" => Dir.glob("lib/packcr/templates/node/capture*.erb") do |t|
  generate_code(t, %w[Packcr Node CaptureNode], "capture", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/charclass_node.rb" => Dir.glob("lib/packcr/templates/node/charclass*.erb") do |t|
  generate_code(t, %w[Packcr Node CharclassNode], "charclass", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, charclass, n, a)",
    "_one" => "(gen, onfail, indent, unwrap, charclass, n, a)",
    "_any" => "(gen, onfail, indent, unwrap, charclass)",
    "_fail" => "(gen, onfail, indent, unwrap)",
    "_utf8" => "(gen, onfail, indent, unwrap, charclass, n)",
    "_utf8_reverse" => "(gen, onsuccess, indent, unwrap, charclass, n)",
  )
end

file "lib/packcr/generated/node/eof_node.rb" => Dir.glob("lib/packcr/templates/node/eof*.erb") do |t|
  generate_code(t, %w[Packcr Node EofNode], "eof", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/error_node.rb" => Dir.glob("lib/packcr/templates/node/error*.erb") do |t|
  generate_code(t, %w[Packcr Node ErrorNode], "error", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/expand_node.rb" => Dir.glob("lib/packcr/templates/node/expand*.erb") do |t|
  generate_code(t, %w[Packcr Node ExpandNode], "expand", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/predicate_node.rb" => Dir.glob("lib/packcr/templates/node/predicate*.erb") do |t|
  generate_code(t, %w[Packcr Node PredicateNode], "predicate", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
    "_neg" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/quantity_node.rb" => Dir.glob("lib/packcr/templates/node/quantity*.erb") do |t|
  generate_code(t, %w[Packcr Node QuantityNode], "quantity", "gen.lang",
    "_many" => "(gen, onfail, indent, unwrap, oncut)",
    "_one" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/reference_node.rb" => Dir.glob("lib/packcr/templates/node/reference*.erb") do |t|
  generate_code(t, %w[Packcr Node ReferenceNode], "reference", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
    "_reverse" => "(gen, onsuccess, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/rule_node.rb" => Dir.glob("lib/packcr/templates/node/rule*.erb") do |t|
  generate_code(t, %w[Packcr Node RuleNode], "rule", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/sequence_node.rb" => Dir.glob("lib/packcr/templates/node/sequence*.erb") do |t|
  generate_code(t, %w[Packcr Node SequenceNode], "sequence", "gen.lang",
    "" => "(gen, onfail, indent, unwrap, oncut)",
  )
end

file "lib/packcr/generated/node/string_node.rb" => Dir.glob("lib/packcr/templates/node/string*.erb") do |t|
  generate_code(t, %w[Packcr Node StringNode], "string", "gen.lang",
    "_many" => "(gen, onfail, indent, unwrap, oncut, n)",
    "_one" => "(gen, onfail, indent, unwrap, oncut, n)",
    "_many_reverse" => "(gen, onsuccess, indent, unwrap, oncut, n)",
    "_one_reverse" => "(gen, onsuccess, indent, unwrap, oncut, n)",
  )
end
