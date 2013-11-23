require "../app/lambda.rb"
require "../app/parser-nolib.rb"

def fol(str)
  FOL.to_object(FOL::Parser.new(str).parse)
end

# note: no clue what I'm doing this was just to try and learn rspec
describe FOL::BinaryOperation do
  subject do 
    fol('x^y^z')
  end
  
  describe "#get_ops" do
    it "should split into its operations" do
      
      subject.get_ops.should == [fol('x'), fol('y'), fol('z')]
    end
  end
  
  describe "#subterms" do
    it "should associate when necessary" do
      subject.subterms.should include(fol('x^y'), fol('y^z'))
    end
    
    it "should not associate when unnecessary" do
      fol('x@y@z').subterms.should_not include(fol('y@z'))
    end
  end
end