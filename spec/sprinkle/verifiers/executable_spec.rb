require 'spec_helper'
require_relative '../support/verifiers_helper'

describe Sprinkle::Verifiers::Directory do
  
  include VerifiersHelper
  
  context '#command_succeeds' do
    
    it "should not raise VerificationFailed if the given command exits with status 0" do
      expect {
        run_verifier { command_succeeds('ls .') }
      }.not_to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should raise VerificationFailed if the given command exits with status > 0" do
      expect {
        run_verifier { command_succeeds('ls xyz') }
      }.to raise_error(Sprinkle::VerificationFailed)
    end
    
  end
  
end
