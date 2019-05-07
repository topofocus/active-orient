
require 'spec_helper'
require 'rest_helper'
require 'connect_helper'
require 'model_helper'
require 'rspec/given'

RSpec.describe OrientSupport::OrientQuery do
  before( :all ) do
    @db = connect database: 'temp'
    V.create_class "test_query"
    E.create_class "match_edge"
  end # before

#	after(:all){ @db.delete_database database: 'temp' }

	context 'Simple Match Query'  do
		Given( :q1){ OrientSupport::OrientQuery.new( start:{ class: TestQuery , where: {a: 9, b: 's'} }   ) }
		Then { expect( q1.to_s ).to match /test/ }
		Then {  expect(q1.compose).to eq "MATCH {class: test_query, as: test_queries, where:( a = 9 and b = 's')} RETURN test_queries" }

		context "add and modify where-filter" do
			Given( :m1 ) { q1.match_statements[0].where << {c: 9}; q1}
			Then {  m1.compose ==  "MATCH {class: test_query, as: test_queries, where:( a = 9 and b = 's' and c = 9)} RETURN test_queries" }

			Given( :m2  ){ q1.match_statements[0].where =  {a: 9, b: 'O'} ; q1 }
			Then {   m2.compose ==  "MATCH {class: test_query, as: test_queries, where:( a = 9 and b = 'O')} RETURN test_queries" }
			end
		end

	context 'standard Match Query ' do
		Given( :q2){ OrientSupport::OrientQuery.new  start:{ class: TestQuery, where: {item: 's'} ,maxdepth: 6 },  
																								connect:{ direction: :out, edge: MatchEdge, as: :node }     }
		Then { expect( q2.to_s ). to eq "" }

	end
end
