require 'parser_combinator/string_parser'

class MyParser < ParserCombinator::StringParser
  parser :love_sentence do
    str("I") > str("\s") > str("love") > str("you").onfail("Who do you love?")
  end

  parser :hate_sentence do
    str("I") > str("\s") > str("hate") > str("you").onfail("Who do you hate?")
  end

  parser :sentence do
    love_sentence ^ hate_sentence
  end
end

result = MyParser.sentence.parse_from_string("I love")
puts result.status.message # => Who do you love?

result = MyParser.sentence.parse_from_string("I hate")
puts result.status.message # => Who do you hate?

result = MyParser.sentence.parse_from_string("I am laughing")
puts result.status == nil # => true
