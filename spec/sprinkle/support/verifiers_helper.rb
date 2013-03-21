module VerifiersHelper
  
  def run_verifier(&block)
    verify = Sprinkle::Verify.new(mock(Sprinkle::Package, :name => 'spec')) do
      self.instance_eval(&block)
    end
    verify.delivery = Sprinkle::Actors::Local.new
    verify.process('role')
  end
  
end
