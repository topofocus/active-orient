
require 'spec_helper'
require 'connect_helper'
require 'rspec/given'

describe ActiveOrient do
  before( :all ) do

    db = connect database: 'temp'
	  db.delete_database database: 'temp' 
    @db = connect database: 'temp'
  end

  context "Virgin state" do
		Given( :present_db_classes ){ @db.database_classes }
		Then { present_db_classes == ["E","V"] }
	end

	context "add a class" do
		before(:all){ V.create_class :test_vertex }
		Given( :present_db_classes ){ @db.database_classes }
		Then { present_db_classes == ["E","V", "test_vertex"] }

	end
	context " delete a class" do
		before(:all){ @db.delete_class :test_vertex }
		Given( :present_db_classes ){ @db.database_classes }
		Then { present_db_classes == ["E","V"] }
		Then { @db.database_classes ==  ["E", "V"] }

	end
end
