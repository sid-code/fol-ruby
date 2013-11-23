
module FOL
  
  class Token
    def initialize str, match
      @str = str
      @match = match
    end
    
    def to_s
      @str
    end
    
    def =~ str
      str =~ @match
    end
    
    FOL_TOKENS = [
      IDENT = new('IDENT', /^[\w\d]+$/),
      COMMA = new('COMMA', /^\,$/),
      OPAREN = new('OPAREN', /^\($/),
      CPAREN = new('CPAREN', /^\)$/),
      AND = new('AND', /^\^$/),
      OR = new('OR', /^\|$/),
      NOT = new('NOT', /^~$/),
      IMP = new('IMP', /^\:\-$/),
      BIC = new('BIC', /^\-\:\-$/),
      APP = new('APP', /^@$/),
      
      DOT = new('DOT', /^\.$/),
      LAMBDA = new('LAMBDA', /^\#$/),
      FORALL = new('FORALL', /^&$/),
      THEREX = new('THEREX', /^%$/),
      
      END_T = new('END', /$/),
      
      UNKNOWN = new('UNKNOWN', /^(.*?)$/)
    ]
    
    BINARY_OPERATORS = [AND, OR, IMP, BIC, APP]
    
    def self.get_fol_token str
      FOL_TOKENS.find {|t| t =~ str}
    end
    
    
  end
  
  
  def self.tokenize str
    # Some of the calls here are unnecessary, but it won't work with opal if I don't use them
    str.gsub(/(\:\-|\-\:\-|[|,^~()#.@&%])/, ' \\1 ').split(" ").map do |str|
      [str, Token.get_fol_token(str)] if str != ""
    end.compact
  end
  
  class Parser
    attr_accessor :str
    
    def initialize str
      @str = str
      @tokens = FOL.tokenize(str).push(["END_T", Token::END_T])
      @index = 0
    end
    
    def consume token
      token = [token] if !token.kind_of? Array
      
      t = @tokens[@index]
      tt = t[1]
      @index += 1
      
      raise SyntaxError, "Expected #{token} got #{tt}" if !token.index tt
      #puts "#{tt} consumed (#{t[0]})"
      
      return t
    end
    
    def peek n=0
      @tokens[@index + n][1]
        
    end
    
    def parse
      tparse = term
      consume(Token::END_T)
      tparse
    end
    
    def term
      op(:bic)
    end
    
    PRECEDENCE_LIST = [:bic, :imp, :or, :and, :app, :not, :atom]
    BOP_TOKENS = {bic: Token::BIC, imp: Token::IMP, :or => Token::OR, :and => Token::AND, app: Token::APP}
    
    def op type
      
      # atom is a special case because it's not an operator
      type == :atom and return atom
      
      
      # not is a special case because it's an unary operator
      if type == :not
        tparse = {type: 'uop'}
        if peek != Token::NOT
          tparse = atom
        else
          tparse[:op] = consume(Token::NOT)
          tparse[:term] = atom
        end
        
        return tparse
      end
      
      tparse = {type: 'op', terms: []}
      
      # this gets the next operation in the precedence order
      next_in_order = PRECEDENCE_LIST[PRECEDENCE_LIST.index(type) + 1]
      
      # first gobble up the first seen operation of the next kind (higher precedence)
      tparse[:terms] << op(next_in_order)
      
      # if our kind of operator is not here, return what we have so far
      if peek != BOP_TOKENS[type]
        tparse = tparse[:terms].first
      end
      
      
      # if it is, gobble them all up
      while peek == BOP_TOKENS[type]
        tparse[:op] = consume(BOP_TOKENS[type])
        tparse[:terms] << op(next_in_order)
      end
      
      tparse
    end
    
    def paren_term
      consume(Token::OPAREN)
      tparse = term
      consume(Token::CPAREN)
      
      tparse
    end
    
    
    def unary
      tparse = {}
      tparse[:op] = consume(Token::NOT)
      tparse[:term] = term
      
      tparse
    end
    
    def lambda
      tparse = {type: 'lambda'}
      consume(Token::LAMBDA)
      tparse[:bound] = identifier
      consume(Token::DOT)
      tparse[:result] = term
      
      tparse
    end
    
    def forall
      tparse = {type: 'forall'}
      consume(Token::FORALL)
      tparse[:bound] = identifier
      consume(Token::DOT)
      tparse[:result] = term
      
      tparse
    end
    
    def therex
      tparse = {type: 'therex'}
      consume(Token::THEREX)
      tparse[:bound] = identifier
      consume(Token::DOT)
      tparse[:result] = term
      
      tparse
    end
    
    def predicate
      tparse = {}
      tparse[:pname] = consume(Token::IDENT)
      consume(Token::OPAREN)
      tparse[:arglist] = arglist
      consume(Token::CPAREN)
      tparse
    end
    
    def arglist
      tparse = []
      tparse << atom
      until peek != Token::COMMA
        consume(Token::COMMA)
        tparse << atom
      end
      tparse
    end
    
    def atom
      tparse = {}
      if peek == Token::OPAREN
        tparse = paren_term
      elsif peek == Token::LAMBDA
        tparse = lambda
      elsif peek == Token::FORALL
        tparse = forall
      elsif peek == Token::THEREX
        tparse = therex
      elsif peek(1) == Token::OPAREN
        tparse = predicate
        tparse[:type] = "predicate"
      else
        tparse.merge! identifier
        tparse[:type] = "identifier"
      end
      tparse
    end
    
    def identifier
      tparse = {}
      tparse[:identifier] = consume(Token::IDENT)
      tparse
    end
    
  end
  
  def self.to_object parse
    @boundvars ||= [] # keep track of all the bound variables so we can use FOL::VariableAtom instead of FOL::ConstantAtom
    # the root is always an term of some sort
    if parse[:type] == "identifier"
      if @boundvars.index(parse[:identifier][0])
        FOL::VariableAtom.new(parse[:identifier][0])
      else
        FOL::ConstantAtom.new(parse[:identifier][0])
      end
    elsif parse[:type] == "uop"
      FOL::UnaryOperation.new(to_object(parse[:term]), FOL::Operator.new(parse[:op][0]))
    elsif parse[:type] == "op" # Technically it's a binary operation, but there can be more than 2 terms. Left associative.
      op = FOL::Operator.new(parse[:op][0])
      parse[:terms].map { |term| to_object(term) }.inject { |cur, nxt|
        FOL::BinaryOperation.new(cur, nxt, op)
      }
    elsif parse[:type] == "lambda"
      @boundvars << (boundvar = FOL::VariableAtom.new(parse[:bound][:identifier][0])).name
      FOL::LambdaAbstraction.new(boundvar, to_object(parse[:result]))
    elsif parse[:type] == "forall"
      @boundvars << (boundvar = FOL::VariableAtom.new(parse[:bound][:identifier][0])).name
      FOL::ForAllQuantifier.new(boundvar, to_object(parse[:result]))
    elsif parse[:type] == "therex"
      @boundvars << (boundvar = FOL::VariableAtom.new(parse[:bound][:identifier][0])).name
      FOL::ThereExistsQuantifier.new(boundvar, to_object(parse[:result]))
    elsif parse[:type] == "predicate"
      FOL::Predicate.new(
        parse[:pname][0],
        parse[:arglist].map { |a| to_object(a) })
    end
  end
  
end

def fol str
  FOL.to_object(FOL::Parser.new(str).parse)
end
