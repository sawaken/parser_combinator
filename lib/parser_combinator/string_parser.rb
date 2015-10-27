require "parser_combinator"

class ParserCombinator
  class StringParser < ParserCombinator
    def self.convert_string_into_items(string, document_name)
      integers = (1..100000).lazy
      items = string.each_line.zip(integers).map{|line, line_number|
        line.chars.zip(integers).map{|char, column_number|
          Item.new(char, :document_name => document_name, :line_number => line_number, :column_number => column_number)
        }
      }.flatten
      return Items.new(items)
    end

    def parse_from_string(input_string, document_name="anonymous")
      parse(self.class.convert_string_into_items(input_string,  document_name))
    end

    def self.char(char)
      sat{|c| c == char}
    end

    def self.notchar(char)
      sat{|c| c != char}
    end

    def self.str(object)
      seq(*object.to_s.chars.map{|c| char(c)}) >> proc{|items|
        ok Items.new(items.to_a)
      }
    end

    def self.lower_alpha
      sat{|c| "a" <= c && c <= "z"}
    end

    def self.upper_alpha
      sat{|c| "A" <= c && c <= "Z"}
    end

    def self.digit
      sat{|c| "0" <= c && c <= "9"}
    end

    def self.pdigit
      sat{|c| "1" <= c && c <= "9"}
    end
  end
end
