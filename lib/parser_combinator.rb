require "parser_combinator/version"

class ParserCombinator
  ParserCombinatorError = Class.new(RuntimeError)

  class Ok
    attr_reader :parsed, :rest
    def initialize(parsed, rest)
      @parsed, @rest = parsed, rest
    end
  end

  class Fail
    attr_reader :status
    def initialize(status=nil)
      @status = status
    end
  end

  class StandardFailStatus
    attr_reader :message, :rest
    def initialize(message, rest)
      @message, @rest = message, rest
    end
  end

  class Item
    attr_reader :item, :tag

    def initialize(item, tag)
      @item, @tag = item, tag
    end

    def to_s
      item.to_s
    end

    def inspect
      "Item {item = #{item}, tag = #{tag}}"
    end
  end

  class Items < Array
    def drop(v)
      Items.new(super(v))
    end

    def drop_while(&p)
      Items.new(super(p))
    end

    def flatten
      Items.new(super())
    end

    def slice(nth)
      if nth.instance_of? Range then
        Items.new(super(nth))
      else
        super(nth)
      end
    end

    def slice(pos, len)
      Items.new(super(pos, len))
    end

    def take(n)
       Items.new(super(n))
    end

    def take_while(&p)
       Items.new(super(p))
    end

    def uniq
       Items.new(super())
    end

    def head
      self.first
    end

    def rest
      self.drop(1)
    end

    def to_s
      self.map(&:to_s).join
    end

    def inspect
      "Items [#{self.map(&:inspect).join(",\n")}]"
    end
  end

  class ParsedSeq
    def initialize(seq)
      @seq = seq
    end

    def to_a
      @seq.map{|e| e[:entity]}
    end

    def to_h
      Hash[@seq.select{|e| e[:name]}.map{|e| [e[:name], e[:entity]]}]
    end

    def self.empty
      new([])
    end

    def cons(entity, name)
      self.class.new([{:entity => entity, :name => name}] + @seq)
    end

    def [](key)
      case key
      when Integer
        if 0 <= key && key < @seq.length
          @seq[key][:entity]
        else
          raise "out of bounds for ParsedSeq"
        end
      else
        if e = @seq.find{|e| e[:name] == key}
          e[:entity]
        else
          raise "key #{key} is not found in ParsedSeq"
        end
      end
    end
  end

  attr_reader :status_handler, :parser_name, :parser_proc
  def initialize(status_handler=proc{nil}, name=nil, &proc)
    @status_handler = status_handler
    @parser_name = name
    @parser_proc = proc
  end

  def parse(items)
    result = @parser_proc.call(items)
    case result
    when Fail
      if  @status_handler.call(items, result.status) != nil
        result.class.new(@status_handler.call(items, result.status))
      else
        result
      end
    when Ok
      result
    else
      raise "parsed object is #{result.inspect}/#{result.class}"
    end
  end

  def onfail(message=nil, ifnotyet=false, &status_handler)
    raise "Only eihter message or fail_handler can be specified" if message && status_handler
    if message
      onfail{|items, status| status == nil ? StandardFailStatus.new(message, items) : status}
    elsif status_handler
      self.class.new(status_handler, @parser_name, &parser_proc)
    else
      self
    end
  end

  def onparse(&proc)
    self.class.new(@status_handler, @parser_name) do |*args|
      proc.call(*args)
      @parser_proc.call(*args)
    end
  end

  def name(new_name)
    self.class.new(@status_handler, new_name, &parser_proc)
  end

  def map(&mapping)
    self >> proc{|x| self.class.ok(mapping.call(x))}
  end

  def >>(proc)
    self.class.so_then(self, &proc)
  end

  def |(other)
    self.class.either(self, other)
  end

  def ^(other)
    self.class.either_fail(self, other)
  end

  def >(other)
    self.class.discardl(self, other)
  end

  def <(other)
    self.class.discardr(self, other)
  end

  # CoreCombinator
  # --------------------

  def self.ok(object)
    new{|i| Ok.new(object, i)}
  end

  def self.fail(status=nil)
    new{|i| Fail.new(status)}
  end

  def self.so_then(parser, &continuation_proc)
    new{|i|
      case result = parser.parse(i)
      when Fail
        result
      when Ok
        continuation_proc.call(result.parsed).parse(result.rest)
      else
        raise "error"
      end
    }
  end

  def self.either(parser1, parser2)
    new{|i|
      case result1 = parser1.parse(i)
      when Fail
        parser2.parse(i)
      when Ok
        result1
      else
        raise "error"
      end
    }
  end

  def self.either_fail(parser1, parser2)
    new{|i|
      case result1 = parser1.parse(i)
      when Fail
        if result1.status == nil
          parser2.parse(i)
        else
          result1
        end
      when Ok
        result1
      else
        raise "error"
      end
    }
  end

  def self.item
    new{|i| i.size == 0 ? Fail.new : Ok.new(i.head, i.rest)}
  end

  def self.end_of_input
    new{|i| i.size == 0 ? Ok.new(nil, i) : Fail.new}
  end

  def self.sat(&item_cond_proc)
    item >> proc{|i|
      item_cond_proc.call(i.item) ? ok(i) : fail
    }
  end

  # UtilCombinator
  # --------------------

  def self.seq(*parsers)
    if parsers.size == 0
      ok(ParsedSeq.empty)
    else
      parsers.first >> proc{|x|
        seq(*parsers.drop(1)) >> proc{|xs|
          ok(xs.cons(x, parsers.first.parser_name))
        }}
    end
  end

  def self.opt(parser)
    parser.map{|x| [x]} | ok([])
  end

  def self.many(parser, separator_parser=ok(nil))
    many1(parser, separator_parser) | ok([])
  end

  def self.many1(parser, separator_parser=ok(nil))
    parser >> proc{|x|
       many(separator_parser > parser) >> proc{|xs|
        ok([x] + xs)
      }}
  end

  def self.opt_fail(parser)
    parser.map{|x| [x]} ^ ok([])
  end

  def self.many_fail(parser, separator_parser=ok(nil))
    many1_fail(parser, separator_parser) ^ ok([])
  end

  def self.many1_fail(parser, separator_parser=ok(nil))
    parser >> proc{|x|
      many_fail(separator_parser > parser) >> proc{|xs|
        ok([x] + xs)
      }}
  end

  def self.discardl(parser1, parser2)
    parser1 >> proc{parser2}
  end

  def self.discardr(parser1, parser2)
    parser1 >> proc{|x|
      parser2 >> proc{
        ok(x)
      }}
  end

  def self.binopl(parser, op_proc_parser)
    rest = proc{|a|
      op_proc_parser >> proc{|f|
        parser >> proc{|b|
          rest.call(f.call(a, b))
        }} | ok(a)
    }
    parser >> proc{|a|
      rest.call(a)
    }
  end

  def self.binopl_fail(parser, op_proc_parser)
    rest = proc{|a|
      op_proc_parser >> proc{|f|
        parser >> proc{|b|
          rest.call(f.call(a, b))
        }} ^ ok(a)
    }
    parser >> proc{|a|
      rest.call(a)
    }
  end

  # Memorization DSL suport (for recursive grammer)
  # --------------------

  def self.parser(name, &proc)
    @cache ||= {}
    spcls = class << self; self end
    spcls.send(:define_method, name) do |*args|
      key = [name, args]
      if @cache[key]
        return @cache[key]
      else
        status_handler = proc{ raise "this is never-called proc (status_handler)" }
        parser_proc = proc{ raise "this is never-called proc (parser_proc)" }
        @cache[key] = self.new(proc{|*args| status_handler.call(*args)}){|*args| parser_proc.call(*args)}
        generated_parser = proc.call(*args)
        parser_proc = generated_parser.parser_proc
        status_handler = generated_parser.status_handler
        return @cache[key]
      end
    end
  end
end
