require 'opal-jquery'

def inverse_l_wrap h, g
  InverseL.new(parent: h, rightchild: g).run
end

def fol str
  FOL.to_object(FOL::Parser.new(str).parse)
end

%x{
  window.fol = function(str) {
    return self.$fol(str);
  }
}

if RUBY_PLATFORM == 'opal'
  Document.ready? do 
    puts 'FOL engine written in Ruby and compiled to JS with Opal'
    
    Element.find('.inverse-l-solve').on :click do |ev|
      parent = ev.current_target.parent.parent
      output = ev.current_target.parent.parent.find('.output')
      inverse_l_data = {}
      begin
        Element.find('.formula-input').each do |el|
          if el.value.strip == ""
            raise "don't leave the fields blank"
          end
          inverse_l_data[el['data-var']] = fol(el.value)
        end
        
        result = inverse_l_wrap(inverse_l_data["h"], inverse_l_data["g"]).to_s
        
      rescue SyntaxError => e
        result = "Syntax error - check your lambda expressions"
      rescue Exception => e
        result = e.message
        puts e.message
        puts e.backtrace
      end
      
      output.text(result)
    end
  end
end