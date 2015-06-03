
require 'spec_helper'
require 'active_support'

describe REST::Model do
  before( :all ) do

    # working-database: hc_database
    REST::Base.logger = Logger.new('/dev/stdout')

    @r= REST::OrientDB.new database: 'hc_database' , :connect => false
    REST::Model.orientdb  =  @r
  end

  context "REST::Model classes got a logger and a database-reference" do
    
    subject { REST::Model.orientdb_class name: 'Test' }
    it{ is_expected.to be_a Class }
    its( :logger) { is_expected.to be_a Logger }
    its( :orientdb) { is_expected.to be_a REST::OrientDB }

    it "a Model-Instance inherents logger and db-reference" do
      object =  subject.new
      expect( object.logger ).to be_a Logger
      expect( object.orientdb ).to be_a REST::OrientDB
    end

    it "repeatedly instantiated Mode-Objects are allocated once" do
      second =  REST::Model.orientdb_class name: 'Test' 
      expect( second).to eq subject
    end
  end


end

