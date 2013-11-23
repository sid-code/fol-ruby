# This file exists solely because Opal hasn't implemented Array#permutation
# Most of the code is coped from http://rosettacode.org/wiki/Permutations#Ruby
###########################################################################

class Array
  # Yields distinct permutations of _self_ to the block.
  # This method requires that all array elements be Comparable.
  def permutation_p  # :yields: _ary_
    # If no block, return an enumerator. Works with Ruby 1.8.7.
    block_given? or return enum_for(:permutation_p)
 
    copy = self.sort
    yield copy.dup
    return if size < 2
 
    while true
      # from: "The Art of Computer Programming" by Donald Knuth
      j = size - 2;
      j -= 1 while j > 0 && copy[j] >= copy[j+1]
      if copy[j] < copy[j+1]
        l = size - 1
        l -= 1 while copy[j] >= copy[l] 
        copy[j] , copy[l] = copy[l] , copy[j]
        copy[j+1..-1] = copy[j+1..-1].reverse
        yield copy.dup
      else
        break
      end
    end
  end
  
  # messy hack
  def combination_n howmany=-1
    (0..2**size-1).map { |n|
      i = -1 # Can't use #with_index because of Opal
      sprintf("%0#{size}s", n.to_s(2)).split("").map { |x|
        i += 1
        x == "1" ? self[i] : nil
      }.compact
    }.keep_if { |c| howmany == -1 || c.size == howmany }
  end
  
  def permutation_n howmany=size
    block_given? or return enum_for(:permutation_p)
    
    combination_n(howmany).each do |c|
      c.permutation_p do |p|
        yield p
      end
    end
  end
  
end