# ParserCombinator

Yet another class-base parser combinator (monadic parser) library.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'parser_combinator'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install parser_combinator

## Basics

### Item class
Abstraction of Char (in Ruby, it is String of 1-length).
Parsing charactors through this abstraction, you can handle meta-info of source-string such as file-name, line-number, column-number.

### Items class
Abstraction of String. This is Array of Item.

## Usage

### Basic Example
```ruby
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

```

### Error Handling
`^` is error handling version of `|`.
```ruby
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
```

### Recursive parsing and Left recursion
```ruby
require 'parser_combinator/string_parser'

class MyParser < ParserCombinator::StringParser
  parser :expression do
    add_sub
  end

  parser :add_sub do
    add_op = str("+").map{ proc{|l, r| l + r}}
    sub_op = str("-").map{ proc{|l, r| l - r}}
    binopl(mul_div, add_op | sub_op)
  end

  parser :mul_div do
    mul_op = str("*").map{ proc{|l, r| l * r}}
    div_op = str("/").map{ proc{|l, r| l / r}}
    binopl(integer | parenth, mul_op | div_op)
  end

  parser :integer do
    many1(digit).map{|x| x.map{|i| i.item}.join.to_i}
  end

  parser :parenth do
    str("(") > expression < str(")")
  end
end

result = MyParser.expression.parse_from_string("(1+2)*3+10/2")
puts result.parsed # => 14

result = MyParser.expression.parse_from_string("3-2-1")
puts result.parsed # => 0
```

## Contributing

1. Fork it ( https://github.com/sawaken/parser_combinator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
