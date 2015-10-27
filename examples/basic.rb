require 'parser_combinator/string_parser'

class MyParser < ParserCombinator::StringParser
  parser :noun do
    str("I") | str("you") | str("it")
  end

  parser :verb do
    str("love") | str("hate") | str("live") | str("die")
  end

  parser :token do |p|
    many(str("\s")) > p < many(str("\s"))
  end

  parser :sentence_way1 do
    token(noun) >> proc{|n1|
      token(verb) >> proc{|v|
        token(noun) >> proc{|n2|
          ok("You said, '#{n1} #{v} #{n2}'")
        }}}
  end

  parser :sentence_way2 do
    seq(token(noun), token(verb), token(noun)).map do |x|
      "You said, '#{x[0]} #{x[1]} #{x[2]}'"
    end
  end

  parser :sentence_way3 do
    seq(token(noun).name(:a), token(verb).name(:b), token(noun).name(:c)).map do |x|
      "You said, '#{x[:a]} #{x[:b]} #{x[:c]}'"
    end
  end
end

result = MyParser.sentence_way1.parse_from_string("I love you")
puts result.parsed # => You said, 'I love you.'

result = MyParser.sentence_way2.parse_from_string("I love you")
puts result.parsed # => You said, 'I love you.'

result = MyParser.sentence_way3.parse_from_string("I love you")
puts result.parsed # => You said, 'I love you.'
