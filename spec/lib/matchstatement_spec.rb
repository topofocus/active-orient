require 'spec_helper'
require 'rest_helper'
require 'connect_helper'
require 'rspec/given'

describe OrientSupport::MatchStatement do
  before( :all ) do
    @db = connect database: 'temp'
    @db.create_class :test_query
  end # before

	after(:all){ @db.delete_database database: 'temp' }
  context "Initialize the QueryClass" do
    Given( :simple ){ OrientSupport::MatchStatement.new @db.classname(TestQuery), where: { a:2 } }
      Then { expect( simple ).to be_a OrientSupport::MatchStatement }
      Then { simple.to_s  == '{class: test_query, as: test_queries, where:( a = 2)}'}
      Then { simple.compose  ==  simple.compose_simple }
      Then { simple.as  == 'test_queries' }
    end
  end



RSpec.describe OrientSupport::MatchConnection do
  before( :all ) do
    @db = connect database: 'temp'
    V.create_class :test_query
		E.create_class :my_edge
  end # before

#	after(:all){ @db.delete_database database: 'temp' }

  context 'initialize ' do
    Given( :c ){ OrientSupport::MatchConnection.new }
    Then{ expect( c.compose).to eq ' -- ' }
    end

    context  "in-edges (2 fold) "  do
     Given( :i2e ) {  OrientSupport::MatchConnection.new  direction: :in, count: 3 }
		 Then {   i2e.compose  == " <-- {} <-- {} <-- " }
		end

    context  "out-edges (2 fold) "  do
      Given( :o2e ) { OrientSupport::MatchConnection.new  direction: :out, count: 3 }
      Then { o2e.compose  == " --> {} --> {} --> " }
    end


     context "includes edges" do
     Given( :ie ) { OrientSupport::MatchConnection.new  edge: MyEdge, direction: :out }
     Then { ie.compose  == " -my_edge-> " }

    end

    context "includes a ministatement " do
     Given( :icm  ) { OrientSupport::MatchConnection.new  edge: MyEdge, direction: :out, as: "friend" }
     Then { icm.compose  == " -my_edge-> { as: friend } " }

    end

		context "traverses throught the graph" do
     Given( :ttg  ) { OrientSupport::MatchConnection.new  edge: MyEdge, direction: :out, while: '$depth < 6' }
     Then { ttg.compose  == " -my_edge-> { as: friend } " }

		end
end
