require 'spec_helper'
require_relative '../support/verifiers_helper'

describe Sprinkle::Verifiers::Directory do
  
  include VerifiersHelper
  
  context '#lacks_directory' do
    
    it "should raise VerificationFailed if the given directory exists" do
      expect {
        run_verifier { lacks_directory(File.dirname(__FILE__)) }
      }.to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should not raise VerificationFailed if the given directory does not exist" do
      expect {
        run_verifier { lacks_directory('missing') }
      }.not_to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should not raise VerificationFailed if the given path is a file" do
      expect {
        run_verifier { lacks_directory(__FILE__) }
      }.not_to raise_error(Sprinkle::VerificationFailed)
    end
    
  end
  
  context '#has_directory' do
    
    it "should not raise VerificationFailed if the given directory exists" do
      expect {
        run_verifier { has_directory(File.dirname(__FILE__)) }
      }.not_to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should raise VerificationFailed if the given directory does not exist" do
      expect {
        run_verifier { has_directory('missing') }
      }.to raise_error(Sprinkle::VerificationFailed)
    end
    
    it "should raise VerificationFailed if the given path is a file" do
      expect {
        run_verifier { has_directory(__FILE__) }
      }.to raise_error(Sprinkle::VerificationFailed)
    end
    
  end
  
end