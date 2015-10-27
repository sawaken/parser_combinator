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
