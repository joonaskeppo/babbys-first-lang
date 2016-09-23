require_relative "../hbhd.rb"
require "test/unit"

def report(hbhd)
  str = hbhd.args[:src]
  src_as_str = str.join("\n")
  converted = hbhd.convert
  print "\n\n=== INPUT ===\n\n"
  puts src_as_str
  print "\n\n=== OUTPUT ===\n\n"
  puts converted
end

class TestExampleInputs < Test::Unit::TestCase
  def test_example
    test_src = [
      '@author: /u/keppo',
      '@template: ../examples/base.html',
      'This is some text.',
      '#Test heading',
      '##     This is a subheading',
      'This is some text.',
      '#### Heading',
      'More text...',
      'And more.',
      'And here is some `code for testing` purposes.',
      ''
    ]
    hbhd = HBHD.new(test_src)
    report(hbhd)
    assert('/u/keppo', hbhd.vars[:author])
  end

  def test_comments
    test_src = [
      '@template: ../examples/base.html',
      ';;comment',
      'Test `code` with ;; comments here',
      '## This is seen ;; and this is not'
    ]
    hbhd = HBHD.new(test_src)
    report(hbhd)
  end

  def test_multi_paragraphs
    test_src = [
      '@template: ../examples/base.html',
      '',
      'This is the first paragraph.',
      'Part of first paragraph.',
      '',
      'Second paragraph here.',
      'More of second paragraph'
    ]
    hbhd = HBHD.new(test_src)
    report(hbhd)
  end
end
