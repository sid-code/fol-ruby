
class Inverse
  attr_accessor :parent
  
  def initialize nodes
    @parent = nodes[:parent]
    @boundvars = [] # Array of strings to keep track of all bound variables used
  end
  
end

# H = parent
# F = leftchild
# G = rightchild
#   H
#  / \
# F   G
#        H = F @ G


# F is unknown, H and G are known

class InverseL < Inverse
  attr_accessor :rightchild
  
  def initialize nodes
    super(nodes)
    
    @rightchild = nodes[:rightchild]
  end
  
  alias_method :g, :rightchild
  alias_method :h, :parent
  
  
  
  def run
    
    if g.is_lambda? and g.result.is_var? and g.result.name = g.bound.name
      return case1
    end
    
    
    h.contains(g) and return case2
    
    g.is_lambda? and c3 = case3 and return c3
    
    h.is_lambda? && g.is_lambda? and c4 = case4 and return c4
    
    nil
    
  end
  
  private
  
  def get_abstractors term
    conductor = term
    abstractors = []
    while conductor.is_lambda?
      abstractors << conductor.bound
      conductor = conductor.result
    end
    
    abstractors
  end
  
  def term_after_abstractors term
    conductor = term
    while conductor.is_lambda?
      conductor = conductor.result
    end
    
    conductor
  end
  
  def make_bvar
    bvar = FOL::VariableAtom.new("x#{@boundvars.length}")
    @boundvars << FOL::VariableAtom.new(bvar.name)
    
    bvar
  end
  
  def case1
    bvar = make_bvar
    
    FOL::LambdaAbstraction.new(bvar, FOL::BinaryOperation.new(bvar, h, FOL::Operator::APPLICATION))
  end
  
  def case2
    bvar = make_bvar
    
    FOL::LambdaAbstraction.new(bvar, FOL::BinaryOperation.new(bvar, h.replace(g, bvar), FOL::Operator::APPLICATION))
  end
  
  def case3
    bvar = make_bvar
    
    # Find how many abstractors G needs to remove
    n_abstractors = get_abstractors(g).size - get_abstractors(h).size
    
    # Since G is a list of abstractors then an expression, we plug in every possible combination
    #   of subterm from H into it to see if there is one that makes it H
    
    result = nil
    h.subterms.flatten.permutation_n(n_abstractors) do |perm|
      # plug the permutation into G in order
      if perm.inject(g) { |cur, nxt| cur.plugin(nxt) } == h
        result = perm
        break
      end
    end
    
    result or return nil
    
    FOL::LambdaAbstraction.new(bvar, result.inject(bvar) { |cur, nxt| 
      FOL::BinaryOperation.new(cur, nxt, FOL::Operator::APPLICATION) 
    })
  end
  
  def case4
    bvar = make_bvar
    
    abstractors = get_abstractors(h)
    
    candidates = []
    conductor = nil
    
    # Looks for terms like a@b@c@d and extract it into [b,c,d]
    g.subterms.flatten.each do |subterm|
      getinnermost = ->(term) { term.term1.is_app? ? getinnermost.call(term.term1) : term.term1 }
      
      if subterm.is_app? && getinnermost.call(subterm) == g.bound
        
        candidates << curr = []
        conductor = subterm
        
        while conductor.is_app?
          curr << conductor.term2
          conductor = conductor.term1
        end
        
        
      end
    end
    return nil if candidates.empty?
    
    possible_subterm, chosen_candidate = nil
  
    
    candidates.each do |cand|
      
      # Look through H to see if there are any subterms that contain all
      #   of the candidate's terms
      possible_subterm = term_after_abstractors(h).subterms.flatten.select { |subterm| 
        cand.all? { |term| subterm.contains(term) }
      }.max { |a, b| a.to_s.size <=> b.to_s.size } # Very crude way to find the innermost subterm
                                                   #   Might not even be required
      
      if !possible_subterm.nil?
        chosen_candidate = cand
        break
      end
    end
    
    return nil if chosen_candidate.nil?
    
    bv = nil
    inner_term = chosen_candidate.inject(possible_subterm) { |cur, nxt| FOL::LambdaAbstraction.new(bv = make_bvar, cur.replace(nxt, bv)) }
    at_inner_term = FOL::BinaryOperation.new(bvar, inner_term, FOL::Operator::APPLICATION)
    
    add_h_abstractors = abstractors.inject(at_inner_term) { |cur, nxt| FOL::LambdaAbstraction.new(nxt, at_inner_term) }
    
    FOL::LambdaAbstraction.new(bvar, add_h_abstractors)
  end
end
