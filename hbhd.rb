#!/usr/bin/env ruby

module RegexTimes
  private
  # Markdown-esque headings: #, ##, ... -> <h1>...</h1>, <h2>...</h2>, ...
  def convert_heading(line)
    if line =~ /(#+)\s*(.*)/
      heading = "h#{$1.length}"
      return "<#{heading}>#{$2}</#{heading}>"
    end
    return line
  end

  # Inline `code text` gets turned to </pre>code text</pre>
  def convert_inline_pre(line)
    return line.gsub(/`([^`]*)`/, '<pre>\1</pre>')
  end

  # Grab variable of the form '@name: value'
  def parse_var_line(line)
    if line =~ /^@([a-z]*)\:\s*(.*)$/
      return [$1, $2]
    end
    return nil
  end

  # Trim away comments (and leading whitespace) from line
  def remove_comments(line)
    return line.gsub(/\s*;;(.*)/, '')
  end

  # Merge @vars (with content and sans template) with template HTML string
  def merge_with_template(template, args)
    return (args.keys).inject(template) do |r, i|
       r.gsub(/\{\{#{i.to_s}\}\}/, args[i])
    end
  end

  # Grab path to filepath (e.g. path/to/file -> path/to/)
  def get_file_dir(filepath)
    if filepath =~ /^((.*\/)[^\/]+|[^\/]+)$/
      # Return directory (sans file name)
      return $2
    end
    raise "Invalid path: #{filepath}"
  end
end

class HBHD
  include RegexTimes
  attr_reader :vars, :args
  SPECIAL_LINES = ['#', '@']

  private
  def read_file(path)
    str = ''
    f = File.open(path, 'r')
    f.each_line do |line|
      str += line
    end
    f.close
    return str
  end

  def parse_args
    # ARGV params:
    # - src is required
    # - output is optional
    if ![1, 2].include?(ARGV.length)
      puts "Usage: #{__FILE__} src [output]"
      exit
    end
    path = ARGV[0]
    output = ARGV[1] || ARGV[0].sub(/\..*/, '.html') # TODO: currently not used!
    # Get src lines
    src = read_file(path)
    # Return info about args
    return {
      path: path,
      src: src.split("\n"),
      output: output
    }
  end

  # Add paragraph (<p>, </p>) tags at appropriate points
  def add_paragraph_tags(arr)
    def ignore_line?(line)
      SPECIAL_LINES.include?(line[0]) || line == ''
    end
    final = []
    arr.each_with_index do |line, idx|
      # Ignore "special" and empty lines
      if ignore_line?(line)
        final.push(line)
        next
      end
      # Handle paragraph lines
      if idx == 0 || ignore_line?(arr[idx - 1])
        final.push("<p>")
      end
      final.push(line)
      if idx == (arr.length - 1) || ignore_line?(arr[idx + 1])
        final.push("</p>")
      end
    end
    return final
  end

  # Parse and substitute text with regex
  def regex_handling(line)
    varline = parse_var_line(line)
    if !varline.nil?
      @vars[varline[0].to_sym] = varline[1]
      return ''
    end
    # Note the order here
    conversions = [
      lambda { |x| remove_comments(x) },
      lambda { |x| convert_heading(x) },
      lambda { |x| convert_inline_pre(x) }
    ]
    final = line
    conversions.each do |conv|
      final = conv.call(final)
    end
    return final
  end

  # Handle the merging of parsed data with template string (read from file)
  def do_templating
    tmpl = @vars[:template]
    if tmpl.nil?
      raise "No template file provided!"
    end
    # Find what directory the source file is located in
    filepath = @args[:path] ? get_file_dir(@args[:path]) : ''
    @template = read_file(filepath + tmpl)
    passable_args = @vars.dup
    passable_args.delete(:template)
    passable_args[:content] = @content.join("\n")
    return merge_with_template(@template, passable_args)
  end

  public
  # Handle the entire conversion process
  def convert
    lines = @args[:src]
    final = add_paragraph_tags(lines)
    @content = final.collect { |line| regex_handling(line) }
                    .select { |line| line != '' }
    return do_templating
  end

  def initialize(src=[])
    @vars = {}
    if src.length == 0
      @args = parse_args
      return
    end
    @args = {
      path: nil,
      src: src,
      output: nil
    }
  end
end

if __FILE__ == $0
  puts HBHD.new.convert
end
