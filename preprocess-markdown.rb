#!/usr/bin/env ruby

require 'optparse'

# Preprocessor directives have the form {% expr %}
PREPROCESSOR_PATTERN = /(?<!\\)\{%\s*(.+?)\s*%\}/
ESCAPED_DIRECTIVE_OPENING = /\\{%/
ESCAPED_DIRECTIVE_CLOSING = /\\%}/

# Only supported flag is -o (output file)
options = {
  o: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options] INPUT"
  opts.on("-o", "--output PATH", "Output path") do |o|
    options[:o] = o
  end
end.parse!

# The state of the preprocessor (variable defs
# and calls)
class PreprocessorState
  def initialize()
    @symbols = {}
  end

  def has_variable_declaration?(variable_name)
    @symbols.has_key? variable_name
  end

  def define_variable(variable_name, variable_value)
    @symbols[variable_name] = variable_value
  end

  def get_variable_value(variable_name)
    @symbols[variable_name]
  end
end

# A preprocessor grammar production
class Production
  def initialize(pattern, &handler)
    @pattern = pattern
    @handler = handler
  end

  def matches?(str)
    @pattern =~ str
  end

  def parse_and_evaluate(preprocessor_state, str)
    match = str.match @pattern

    @handler.call(preprocessor_state, match)
  end
end

# Preprocessor state holds stuff like the symbol tables, which
# will mutate as new defintions come through
preprocessor_state = PreprocessorState.new

# File is provided as an unnamed argument to the script
# if an unnamed argument is not provided, then use the
# standard input
base_path, input_text =
           if ARGV.empty?
             [Dir.pwd, STDIN.read]
           else
             path = ARGV.first
             [File.dirname(path), IO.read(path)]
           end

productions = [
  # File includes - non-recursive (the included text
  # is not, itself, preprocessed)
  # e.g. {% include file.md %}
  Production.new(/include\s+(.+)/) do |preprocessor_state, match|
    filename = match[1]

    # Paths are relative to the input file, not
    # the current working directory (unless the
    # input text was provided through the
    # standard input)
    file_path = File.join(base_path, filename)

    if(File.exist? file_path)
      IO.read(file_path)
    else
      STDERR.puts("include: File #{filename} could not be found (full path: #{file_path})")
      exit 1
    end
  end,
  # Variable definition
  Production.new(/define\s+([A-Za-z]+[A-Za-z_\-0-9]*)\s+(.+)/) do |preprocessor_state, match|
    preprocessor_state.define_variable(match[1], match[2])
    ""
  end,
  # Variable dereferencing
  Production.new(/([A-Za-z]+[A-Za-z_\-0-9]*)/) do |preprocessor_state, match|
    variable_name = match[1]

    if preprocessor_state.has_variable_declaration?(variable_name)
      preprocessor_state.get_variable_value(variable_name)
    else
      STDERR.puts("No definition found for variable #{variable_name}")
      exit 1
    end
  end
]

# All preprocessor directives are enclosed in {% %}
evaluated_text = input_text.gsub PREPROCESSOR_PATTERN do |match|

  # Productions contains the supported macros, scan through
  # the productions one-by-one looking for a match. If a
  # match isn't found then it's a syntax error
  matches =
    productions.
    select { |production| production.matches? $1 }

  if matches.empty?
    STDERR.puts("Syntax error for #{$1}")
    exit 1
  else
    matches.first.parse_and_evaluate(preprocessor_state, $1)
  end
end.
gsub(ESCAPED_DIRECTIVE_OPENING, '{%'). # Sub the escaped text back to its intended form
gsub(ESCAPED_DIRECTIVE_CLOSING, '%}')

# If the -o option wasn't provided then write the output
# to the standard output; otherwise, put it to the output
# path
output_string = evaluated_text.to_s
if options[:o].nil?
  puts output_string
else
  output_file = File.new(options[:o], "w+")
  output_file.write(output_string)
end

exit 0
