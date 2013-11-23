# Introduction

fol-ruby is a lambda calculus and first order logic engine written in Ruby, but can be compiled to JavaScript for web use with [Opal][1] with


    $ gem install opal
    $ rake build
    
(the .js file appears in a directory called built/, and you can test it by opening web/main.html)    
# Usage
Note: I don't think this is big enough to be used as a gem yet. However, if you want to include it in your programs, just copy the app folder into your program it should work.

```ruby
require "./app/lambda.rb"
require "./app/parser-nolib.rb"
require "./app/inverse.rb"

# wrapper
def fol(str)
    FOL.to_object(FOL::Parser.new(str).parse)
end

# reduction
puts fol('(#x.x) @ y').reduce

# inverse
puts InverseL.new(
    parent: fol('#x.Person(x) @ Happy(x)'), 
    rightchild: fol('#v.v')).run
```

  [1]: http://opalrb.org



