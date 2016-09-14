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

  # Handle inline conversions
  def inline_conversions(line)
    # Note the order
    conversions = {
      /\s*;;(.*)/ => '',                    # Comments
      /`([^`]*)`/ => '<pre>\1</pre>',       # Inline code blocks
      /\*([^\*]*)\*/ => '<em>\1</em>'       # Emphasized text
    }
    final = line
    conversions.each do |regex_match, html_sub|
      final = final.gsub(regex_match, html_sub)
    end
    return final
  end

  # Grab variable of the form '@name: value'
  def parse_var_line(line)
    if line =~ /^@([a-z]*)\:\s*(.*)$/
      return [$1, $2]
    end
    return nil
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
  NON_PARAGRAPH_LINES = ['#', '@', '>', ';;', '']

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
    # Checks if line should be ignored wrt. paragraph tags
    def ignore_line?(line)
      NON_PARAGRAPH_LINES.each do |linetype|
        end_idx = linetype.length - 1    # Used to compare linetypes
        line_no_ws = line.strip          # Remove leading whitespace
        # For empty lines, end_idx is -1, hence the first comparison
        if line_no_ws == linetype || line_no_ws[0..end_idx] == linetype
          return true
        end
      end
      return false
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
    conversions = [
      lambda { |x| inline_conversions(x) },
      lambda { |x| convert_heading(x) }
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
