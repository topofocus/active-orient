require 'spec_helper'
require 'rest_helper'

describe OrientSupport::MatchStatement do
  before( :all ) do
#    ORD = ActiveOrient::OrientDB.new database: 'ArrayTest'
    reset_database
    ORD.create_class :test_query
  end # before

  context "Initialize the QueryClass" do
    it "simple Initialisation" do
      q =  OrientSupport::MatchStatement.new ORD.classname(TestQuery), where: { a:2 }
      expect(q).to be_a OrientSupport::MatchStatement
      expect( q.compose ).to eq '{class: test_query, as: test_queries, where:( a = 2)}'
      expect( q.compose ).to eq q.compose_simple
      expect(q.as).to eq 'test_queries'
    end
  end
end



describe OrientSupport::MatchConnection do
  before( :all ) do
#    ORD = ActiveOrient::OrientDB.new database: 'ArrayTest'
    reset_database
   ORD.create_class :test_query
  end # before

  context 'initialize and check output' do
    it "the detault case" do  
    c =  OrientSupport::MatchConnection.new 
      expect( c.compose ).to eq " -- "
    end

    it "in-edges (2 fold) "  do
    c =  OrientSupport::MatchConnection.new  direction: :in, count: 3

      expect( c.compose ).to eq " <-- {} <-- {} <-- "
  end
    it "out-edges (2 fold) "  do
    c =  OrientSupport::MatchConnection.new  direction: :out, count: 3
      expect( c.compose ).to eq " --> {} --> {} --> "
    end


    it "includes edges" do
    c =  OrientSupport::MatchConnection.new  edge: 'my_edge', direction: :out
      expect( c.compose ).to eq " -my_edge-> "

    end

    it "includes a ministatement " do
    c =  OrientSupport::MatchConnection.new  edge: 'my_edge', direction: :out, as: "friend"
      expect( c.compose ).to eq " -my_edge-> { as: friend } "

    end

  end
end
