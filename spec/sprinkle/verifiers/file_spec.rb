require 'spec_helper'
require_relative '../support/verifiers_helper'

describe Sprinkle::Verifiers::File do
  
  include VerifiersHelper
  
  context '#lacks_file' do
    
    it "should raise VerificationFailed if the given file exists" do
      expect {
        run_verifier { lacks_file(__FILE__) }
      }.to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should not raise VerificationFailed if the given file does not exist" do
      expect {
        run_verifier { lacks_file('missing') }
      }.not_to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should not raise VerificationFailed if the given path is a directory" do
      expect {
        run_verifier { lacks_file(File.dirname(__FILE__)) }
      }.to_not raise_error(Sprinkle::VerificationFailed)
    end
    
  end
  
  context '#has_file' do
    
    it "should not raise VerificationFailed if the given file exists" do
      expect {
        run_verifier { has_file(__FILE__) }
      }.not_to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should raise VerificationFailed if the given file does not exist" do
      expect {
        run_verifier { has_file('missing') }
      }.to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should raise VerificationFailed if the given path is a directory" do
      expect {
        run_verifier { has_file(File.dirname(__FILE__)) }
      }.to raise_error(Sprinkle::VerificationFailed)
    end
    
  end
  
end
