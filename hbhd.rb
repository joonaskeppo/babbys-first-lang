#!/usr/bin/env ruby

# Handle regex-related tasks
module RegexTimes
  # Use backslashes to escape tokens
  ESCAPE_CHAR = /(?<!\\)/
  # A list of all tokens (these are escapable)
  ALL_TOKENS = %w(\# \@ \> \; \* \`).freeze
  # If a line starts with one of these, it is ignored when looking at
  # paragraph tag insertions (<p> and </p>)
  NON_PARAGRAPH_LINES = %w(# @ > ;;).unshift('').freeze
  # All inline regex substitutions
  SUBSTITUTIONS = {
    /\s*;;(.*)/ => '',                                  # Comments
    /`([^`]*)`/ => '<code>\1</code>',                   # Inline code blocks
    /\*([^\*]*)\*/ => '<em>\1</em>',                    # Emphasized text
    /\[([^\]]+)\]\(([^\)]+)\)/ => '<a href="\2">\1</a>' # Anchor tags
  }.freeze

  private

  # Markdown-esque headings: #, ##, ... -> <h1>...</h1>, <h2>...</h2>, ...
  def convert_heading(line)
    if line =~ /#{ESCAPE_CHAR}(#+)\s*(.*)/
      size = Regexp.last_match[1].length
      text = Regexp.last_match[2]
      heading = "h#{size}"
      return "<#{heading}>#{text}</#{heading}>"
    end
    line
  end

  # Handle all inline conversions with regex
  def inline_conversions(line)
    SUBSTITUTIONS.each do |regex_match, html_sub|
      line.gsub!(/#{ESCAPE_CHAR}#{regex_match}/, html_sub)
    end
    line
  end

  # Remove backslashes used to escape tokens (e.g. \# -> #)
  def trim_escape_chars(line)
    escapable = '(' + ALL_TOKENS.join('|') + ')'
    line.gsub(/\\(?=#{escapable})/, '')
  end

  # Parse for keywords (e.g. TIME)
  def parse_keywords(value)
    # TODO: loop over all keywords
    if value =~ /TIME\((.*)\)/
      time_format = Regexp.last_match[1]
      value = Time.new.strftime(time_format)
    end
    value
  end

  # Grab variable data of the form '@name: value'
  def parse_varline(line)
    var = nil
    if line =~ /^@(\w+)\:\s*(.*)$/
      var = {
        name: Regexp.last_match[1],
        value: Regexp.last_match[2]
      }
      # Check for reserved keywords (currently only 'TIME')
      var[:value] = parse_keywords(var[:value])
    end
    var
  end

  # Merge @vars (with content and sans template) with template HTML string
  def merge_with_template(template, args)
    args.keys.inject(template) do |r, i|
      r.gsub(/\{\{#{i.to_s}\}\}/, args[i])
    end
  end

  # Handle all regex and other operations
  def handle_operations(line)
    [
      -> (x) { inline_conversions(x) },
      -> (x) { convert_heading(x) },
      -> (x) { trim_escape_chars(x) }
    ].each { |conv| line = conv.call(line) }
    line
  end
end

# Various utility functions for the main HBHD class
module Utils
  private

  def read_file(path)
    str = ''
    f = File.open(path, 'r')
    f.each_line do |line|
      str += line
    end
    f.close
    str
  end

  # Parse cli ARGV params (required: src, optional: output)
  def parse_args
    unless [1, 2].include?(ARGV.length)
      puts "Usage: #{__FILE__} src [output]"
      exit
    end
    {
      path: ARGV[0], # Path to src file
      output: ARGV[1] || ARGV[0].sub(/\..*/, '.html'), # Path to output file
      src: read_file(ARGV[0]).split("\n") # src file content
    }
  end

  # Grab path to filepath (e.g. path/to/file -> path/to/)
  def get_file_dir(filepath)
    if filepath =~ %r{^((.*\/)[^\/]+|[^\/]+)$}
      # Return directory (sans file name)
      return Regexp.last_match[2]
    end
    raise "Invalid path: #{filepath}"
  end
end

# Main program logic goes under this class
class HBHD
  include RegexTimes
  include Utils
  attr_reader :vars, :args

  private

  # Should line be ignored when tagging with <p> and </p>?
  def paragraph?(line)
    NON_PARAGRAPH_LINES.each do |linetype|
      end_idx = linetype.length - 1 # Used to compare linetypes
      line_no_ws = line.strip # Remove leading whitespace
      # For empty lines, end_idx is -1, hence the first comparison
      if line_no_ws == linetype || line_no_ws[0..end_idx] == linetype
        return false
      end
    end
    true
  end

  # Add paragraph (<p>, </p>) tags at appropriate points
  def add_paragraph_tags(lines)
    final = []
    lines.each_with_index do |line, idx|
      if paragraph?(line)
        final.push('<p>') if idx.zero? || !paragraph?(lines[idx - 1])
        final.push(line)
        final.push('</p>') if line == lines.last || !paragraph?(lines[idx + 1])
      else
        final.push(line)
      end
    end
    final
  end

  # Parse and substitute text with regex
  def regex_handling(line)
    var = parse_varline(line)
    unless var.nil?
      @vars[var[:name].to_sym] = var[:value]
      return ''
    end
    # Regex and other substitutions
    handle_operations(line)
  end

  # Handle the merging of parsed data with template string (read from file)
  def do_templating
    tmpl = @vars[:template]
    raise 'No template file provided' if tmpl.nil?
    # Find what directory the source file is located in
    filepath = @args[:path] ? get_file_dir(@args[:path]) : ''
    @template = read_file(filepath + tmpl)
    passable_args = @vars.dup
    passable_args.delete(:template)
    passable_args[:content] = @content.join("\n")
    merge_with_template(@template, passable_args)
  end

  public

  # Handle the entire conversion process
  def convert
    lines = @args[:src]
    final = add_paragraph_tags(lines)
    # p final
    @content = final.collect { |line| regex_handling(line) }
                    .select { |line| line != '' }
    do_templating
  end

  def initialize(src = [])
    @vars = {}
    if src.length.zero?
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

puts HBHD.new.convert if __FILE__ == $PROGRAM_NAME
