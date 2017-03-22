#ARGV << 'test'
#@do_not_preallocate =  true
require './config/boot_spec'
#bundler/setup'
require 'rspec'
require 'rspec/its'
require 'rspec/collection_matchers'
require 'yaml'
require 'active_support'
project_root = File.expand_path('../..', __FILE__)
#require 'my_spec_helper'

unless defined?(SPEC_HELPER_LOADED)
SPEC_HELPER_LOADED =  true
RSpec.configure do |config|
	config.mock_with :rspec
	config.color = true
	# ermöglicht die Einschränkung der zu testenden Specs
	# durch  >>it "irgendwas", :focus => true do <<
	config.filter_run :focus => true
	config.run_all_when_everything_filtered = true
	config.order = 'defined'  # "random"
end

RSpec.shared_context 'private', private: true do

    before :all do
          described_class.class_eval do
	          @original_private_instance_methods = private_instance_methods
		        public *@original_private_instance_methods
			    end
	    end

      after :all do
	    described_class.class_eval do
	            private *@original_private_instance_methods
		        end
	      end

end
else
  puts "***  ---- *** \n"*3
  puts "Reusing rspec configuration "
  puts "***  ---- *** \n"*3
end
#require 'model_helper'
