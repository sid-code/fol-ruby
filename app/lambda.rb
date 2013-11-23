require 'opal'

module FOL
  class Term # Should NOT be instantiated. Some of the defined methods are skeletons
    include Comparable # dubious
    def reduce
      self
    end
    
    def subterms
      [self]
    end
    
    def contains term
      subterms.flatten.index(term)
    end
    
    def replace what, to
      self == what ? to : self
    end
    
    def == other
      instance_of? other.class
    end
    
    def <=> other
      to_s.length <=> other.to_s.length
    end
    
    # cosmetic methods
    
    def is_var?
      kind_of? VariableAtom
    end
    
    def is_atom?
      kind_of? Atom
    end
    
    def is_lambda?
      kind_of? LambdaAbstraction
    end
    
    def is_op?
      kind_of? Operation
    end
    
    def is_uop?
      kind_of? UnaryOperation
    end
    
    def is_bop?
      kind_of? BinaryOperation
    end
    
    def is_app?
      kind_of? BinaryOperation and @operator.type == "@"
    end
      
  end
  
  

  class Atom < Term
    attr_accessor :name
    
    def initialize name
      @name = name
    end
    
    def == other
      super && @name == other.name
    end
    
      
    
    def to_s
      @name
    end
    
  end
  


  class VariableAtom < Atom
  end



  class ConstantAtom < Atom
  end
  
  
  
  
  

  class Operation < Term
    attr_accessor :operator, :term1
    
    def initialize term1, operator
      term1.kind_of? Term or raise ArgumentError, "expected FOL::Term, got #{term1.class.name}"
      
      operator.kind_of? Operator or raise ArgumentError, "expected FOL::Operator, got #{operator.class.name}"
      
      @term1 = term1
      @operator = operator
    end
    
    def reduce
      self.class.new(@term1.reduce, @operator)
    end
    
    
    def to_s
      parens = false
      if @term1.kind_of? Operator
        if Operator.higher_precedence(@operator, @term1.operator) 
          # If we have higher precedence, we need parens
          parens = true
        end
        
      end
      
      "#{@operator.type}#{parens ? "(" : ''}#@term1#{parens ? ")" : ""}"
    end
    
    
    def == other
      super && @term1 == other.term1 && @operator == other.operator
    end
  end
  

  class UnaryOperation < Operation
    
    def subterms
      [self, *@term1.subterms]
    end
    
    def replace what, to
      s = super(what, to)
      return s if s == to
      
      self.class.new(@term1.replace(what, to), @operator)
    end
    
  end

  class BinaryOperation < Operation
    attr_accessor :term2
    
    def initialize term1, term2, operator
      super(term1, operator)
      
      term2.kind_of? Term or raise ArgumentError, "expected FOL::Term, got #{term2.class.name}"
      
      @term2 = term2
    end
    
    def reduce
      if is_app? && @term1.is_lambda?
        @term1.plugin(@term2).reduce
      else
        t = @term1.reduce
        r = self.class.new(t, @term2.reduce, @operator)
        
        t.is_lambda? ? r.reduce : r
      end
    end
    
    
    def subterms
      # This is slightly difficult because if we have nested BinaryOperations
      # e.g. ((A ^ B) ^ C), B ^ C won't be listed as a subterm using the old method:
      # [self, @term1.subterms, @term2.subterms]
      
      # The new method recursively checks for nested BinaryOperations inside this one
      # and finds the subterms of those.
      
      if @operator.associative?
        
        all_ops = get_ops
        all_ops_subsets = (0..all_ops.size - 2).map { |n1| 
          (0..all_ops.size - n1 - 1).map { |n2| all_ops[n2..n2 + n1] } 
        }.flatten(1).map { |c| 
          c.inject { |cur,nxt| FOL::BinaryOperation.new(cur,nxt,@operator) }
        }.compact.reject { |t| t == self } # removes that nil that #combination_n gives us 
        # Also removes any term that is equal to self to prevent infinite recursion
        
        [self, *all_ops_subsets.map(&:subterms).flatten.uniq]
      else
        [self, *@term1.subterms, *@term2.subterms]
      end
      
      
    end
    
    def replace what, to
      s = super(what, to)
      
      return s if s == to
      t1, t2, op = @term1, @term2, @operator
      
      if what.is_bop? && what.operator == @operator && @operator.associative?
        what_ops = what.get_ops
        self_ops = get_ops
        new_self_ops = self_ops.dup
        
        self_ops.each_with_index do |sop, si|
          if what_ops.first == sop
            match = true
            
            what_ops.each_with_index do |wop, wi|
              match = wop == self_ops[si + wi]
            end 
            # I'd probably use a different method in this case with #with_index but
            # Opal doesn't support it
            
            if match
              new_self_ops[si..si + what_ops.size - 1] = to
            end
          end
        end
        
        if new_self_ops != []
          new_self = new_self_ops.inject { |cur,nxt| FOL::BinaryOperation.new(cur,nxt,@operator) }
          
          t1 = new_self.term1
          t2 = new_self.term2
          op = new_self.operator
        end
      end
      
      self.class.new(t1.replace(what, to), t2.replace(what, to), op)
    end
    
    def get_ops
      
      result = []
      result.push *if @term1.is_bop? && @term1.operator == @operator
        @term1.get_ops
      else
        [@term1]
      end
      
      result.push *if @term2.is_bop? && @term2.operator == @operator
        @term2.get_ops
      else
        [@term2]
      end
      
      result
    end
    
    def to_s
      parens_term1 = (@term1.kind_of? Operation and Operator.higher_precedence(@operator, term1.operator)) || 
        @term1.is_lambda? && @operator.type == "@"
        
    
      parens_term2 = (@term2.kind_of? Operation and Operator.higher_precedence(@operator, term2.operator))
      
      term1_string = "#{parens_term1 ? "(" : ''}#{@term1}#{parens_term1 ? ")" : ''}"
      term2_string = "#{parens_term2 ? "(" : ''}#{@term2}#{parens_term2 ? ")" : ''}"
      
      
      "#{term1_string} #{@operator.type} #{term2_string}"
    end
    
    def == other
      other.kind_of? BinaryOperation or return false
      
      same_operator = @operator == other.operator
      
      same_terms = if @operator.associative?
        get_ops == other.get_ops
      else
        (@term1 == other.term1 && @term2 == other.term2) ||
        (@term1 == other.term2 && @term2 == other.term1)
      end
      
      same_operator && same_terms
    end
  end
  
  

  class Operator
    attr_accessor :type
    
    def initialize type
      @type = type
    end
    
    APPLICATION = new "@"
    IMPLICATION = new ":-"
    BICONDITION = new "-:-"
    AND = new "^"
    OR = new "|"
    NOT = new "~"
    
    PRECEDENCE = ["~", "^", "|", ":-", "-:-", "@"]
    ASSOCIATIVE_OPERATORS = ["^", "|"]
    
    def self.higher_precedence a, b
      PRECEDENCE.index(a.type) < PRECEDENCE.index(b.type)
    end
    
    def associative?
      !!ASSOCIATIVE_OPERATORS.index(@type)
    end
    
    def == other
      @type == other.type
    end
  end
  
  
  
  
  
  


  class Predicate < Atom
    attr_accessor :name, :args
    
    def initialize name, args
      args.kind_of? Array or raise ArgumentError, "expected Array, got #{args.class.name}"
      
      
      @name = name
      @args = args
    end
    
    def to_s
      "#@name(#{@args.join(', ')})"
    end
    
    
    def subterms
      [self, *@args.map(&:subterms)]
    end
    
    def replace what, to
      s = super(what, to)
      return s if s == to
      
      self.class.new(@name, @args.map { |a| a.replace(what, to) })
    end
    
    def == other
      super && @args == other.args
    end
  end
  
  
  
  

  class BindingTerm < Term
    attr_accessor :bound, :result
    
    def initialize bound, result
      bound.is_var? or raise ArgumentError, "expected FOLVariableAtom, got #{bound.class.name}"
      result.kind_of? Term or raise ArgumentError, "expected FOLTerm, got #{result.class.name}"
      
      @bound = bound
      @result = result
    end
    
    def reduce
      self.class.new(@bound, @result.reduce)
    end
    
    def subterms
      [self, *@result.subterms]
    end
    
    def replace what, to
      s = super(what, to)
      return s if s == to
      
      self.class.new(@bound, @result.replace(what, to))
      
    end
    
    def to_s
      "#{@bound}.#{@result}"
    end
    
    def == other
      super && @bound == other.bound && @result == other.result
    end
  end
  
  class LambdaAbstraction < BindingTerm
  
  
    def plugin term
      result.replace(bound, term)
    end
    
    def to_s
      "\##{super}"
    end
  end

  class Quantifier < BindingTerm
  end

  class ForAllQuantifier < Quantifier
    
    def to_s
      "&#{super}"
    end
  end
  
  class ThereExistsQuantifier < Quantifier
    
    def to_s
      "%#{super}"
    end
  end
end

