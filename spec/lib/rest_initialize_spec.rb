
require 'spec_helper'
require 'connect_helper'
##
# Initialise ActiveOrient::OrientDB
##
#
describe ActiveOrient::OrientDB do

  before( :all ) do
     @db = connect
  end

	context "the initialized database " do 
	
		it "has an appropiate logger" do
			expect(ActiveOrient::OrientDB.logger).to be_a Logger
			expect(@db.logger).to be_a Logger
			expect(ActiveOrient::Base.logger).to be_a Logger
			expect(ActiveOrient::Model.logger).to be_a Logger
		end
	
		it "has initialized Base-classes and methods" do
			expect( ActiveOrient.database_classes ).to eq "E"=>E, "V"=>V

			expect( E.respond_to? :uniq_index ).to be_truthy  # test a class method defined in model/e.rb

		end

		it "logs the events properly" do
			should_log /CREATE CLASS E/
			should_log /CREATE CLASS V/
			should_log /Connected to database/
		end
	end
end


