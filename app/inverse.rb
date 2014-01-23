
class Inverse
  attr_accessor :parent
  
  def initialize nodes
    @parent = nodes[:parent]
    @boundvars = [] # Array of strings to keep track of all bound variables used
  end

  alias_method :h, :parent
  
  
  def make_bvar
    bvar = FOL::VariableAtom.new("x#{@boundvars.length}")
    @boundvars << FOL::VariableAtom.new(bvar.name)
    
    bvar
  end
  
  def clear_bvars
    @boundvars = []
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
  
  def run
    
    if g.is_lambda? && g.result.is_var? && g.result.name == g.bound.name
      return case1
    end
    
    
    h.contains(g) and return case2
    
    g.is_lambda? and c3 = case3 and return c3
    
    g.is_lambda? and c4 = case4 and return c4
    
    nil
    
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
    n_abstractors = InverseUtils.get_abstractors(g).size - InverseUtils.get_abstractors(h).size
    
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
    
    if h.is_lambda?
      abstractors = InverseUtils.get_abstractors(h)
    end
    
    conductor = nil
    
    # Looks for terms like a@b@c@d and extract it into [b,c,d]
    
    candidates = g.subterms.flatten.map { |st| InverseUtils.get_app_terms(st, g.bound) }.compact
    
    return nil if candidates.empty?
    
    possible_subterm, chosen_candidate = nil
    possible_results = []
    
    candidates.each do |cand|
      # Look through H to see if there are any subterms that contain all
      #   of the candidate's terms
      InverseUtils.term_after_abstractors(h).subterms.flatten.select { |subterm| 
        cand.all? { |term| subterm.contains(term) }
      }.each do |possible_subterm|
      
        if !possible_subterm.nil?
          chosen_candidate = cand
          next if chosen_candidate.nil?
          bv = nil
      
          inner_term = chosen_candidate.inject(possible_subterm) { |cur, nxt| FOL::LambdaAbstraction.new(bv = make_bvar, cur.replace(nxt, bv)) }
          
          at_inner_term = FOL::BinaryOperation.new(bvar, inner_term, FOL::Operator::APPLICATION) # w @ INNER_TERM
          
          add_h_abstractors = if h.is_lambda?
            abstractors.inject(at_inner_term) { |cur, nxt| FOL::LambdaAbstraction.new(nxt, at_inner_term) }
          else
            at_inner_term
          end
          
          possible_results << FOL::LambdaAbstraction.new(bvar, add_h_abstractors)
        end
      end
      
    end
    
    possible_results.each do |result|
      if result.plugin(g).reduce == h
        return result
      end
    end
  end
end

class InverseR < Inverse
  attr_accessor :leftchild

  def initialize nodes
    super(nodes)

    @leftchild = nodes[:leftchild]
  end

  alias_method :f, :leftchild

  def run
    
    # case 1
    if f.is_lambda? && f.result.is_bop? && 
      f.result.operator.type == '@' &&
      f.result.term1 == f.bound
      
      return InverseL.new(parent: h, rightchild: f.result.term2).run
    end
    
    # case 2
    
    possible_js = h.subterms.keep_if { |subterm| 
      f.result == h.replace(subterm, f.bound)
    }
    
    possible_js[0] and return possible_js[0]
    
    # case 3
    
    f.is_lambda? and c3 = case3 and return c3
    
    nil

  end
  
  def case3
    f_bvar = f.bound
    candidates = []
    result = nil
    
    catch :found do
      f.subterms.each do |fsub|
        at = InverseUtils.get_app_terms(fsub, f_bvar)
        
        if at
          candidates = h.subterms.keep_if { |hsub| 
            at.all? { |t| hsub.contains(t) } 
          }
          
          # candidates.min isn't strictly required, they could be looped over
          # if this becomes a problem, change
          result = at.inject(candidates.min) { |cur, nxt| FOL::LambdaAbstraction.new(bv = make_bvar, cur.replace(nxt, bv)) }
          
          
          throw :found if f.plugin(result).reduce == h
          
        end
        
      end
    end
    
    return result
  end
  
  def case4
    
  end
end


module InverseUtils
  # Takes a term like innermost @ A @ B and gives you [A, B]
  def self.get_app_terms term, innermost
    
    result = []
      
    if term.is_app? && get_innermost(term) == innermost
      
      conductor = term
      
      while conductor.is_app?
        result << conductor.term2
        conductor = conductor.term1
      end
      
      
    end
    
    result == [] ? nil : result
  end
  
  def self.get_innermost term # expects a binary operation
    term.term1.is_app? ? get_innermost(term.term1) : term.term1 
  end
  
  def self.get_abstractors term
    conductor = term
    abstractors = []
    while conductor.is_lambda?
      abstractors << conductor.bound
      conductor = conductor.result
    end
    
    abstractors
  end
  
  def self.term_after_abstractors term
    conductor = term
    while conductor.is_lambda?
      conductor = conductor.result
    end
    
    conductor
  end
end

if __FILE__ == $0
  p InverseR.new(parent: fol('loves(Mia, Vincent) ^ loves(Mia, Robert)'), leftchild: fol('#w.w@Mia@Vincent ^ w@Mia@Robert')).run
end