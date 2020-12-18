
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
		Given( :m1){  TestQuery.start  where: {a: 9, b: 's'} }    
		Then { expect( m1.to_s ).to match /test/ }
		Then { expect( m1.to_s).to eq "{class: test_query, as: test_queries, where: ( a = 9 and b = 's')}" }

		Given( :m2 ){ m1.where c:9 }
		Then { m2.to_s == "{class: test_query, as: test_queries, where: ( a = 9 and b = 's' and c = 9)}" }

		Given( :c0  ){ E.connect  }
		Then { c0.to_s == " -- " }
		Given( :c1  ){ MATCH_EDGE.connect }
		Then { c1.to_s ==  " -match_edge- " }
		 
		Given( :c2  ){ MATCH_EDGE.connect count: 2}
		Then { c2.to_s ==  " -match_edge- {} -match_edge- " }
		Given( :c3  ){ MATCH_EDGE.connect count: 2, as: 'test'}
		Then { c3.to_s ==  " -match_edge- {} -match_edge- {as: test}" }
		Given( :c4a  ){ MATCH_EDGE.connect "<-"}
		Then { c4a.to_s ==  " <-match_edge- " }

		Given( :c4b  ){ MATCH_EDGE.connect  direction: :in}
		Then { c4b.to_s ==  " <-match_edge- " }
		Given( :c5a  ){ MATCH_EDGE.connect "->"}
		Then { c5a.to_s ==  " -match_edge-> " }
		Given( :c5b  ){ MATCH_EDGE.connect  direction: :out}
		Then { c5b.to_s ==  " -match_edge-> " }
		Given( :c6  ){ MATCH_EDGE.connect "->", count: 2}
		Then { c6.to_s ==  " -match_edge-> {} -match_edge-> " }

		Given( :c7  ){ MATCH_EDGE.connect direction: :bothE }
		Then { expect(c7.to_s).to eq  ".bothE(match_edge) " }
		Given( :c8  ){ MATCH_EDGE.connect direction: :both_vertex }
		Then { expect(c8.to_s).to eq  ".bothV() " }

		Given( :c9  ){ MATCH_EDGE.connect direction: :bothE, where: {a: 1 }}   
		Then { expect(c9.to_s).to eq  ".bothE(match_edge) {where: ( a = 1)}" }
		Given( :c10  ){ MATCH_EDGE.connect count: 2, as: 'test', where: "$matched.person != $currentMatch" }
		Then { c10.to_s ==  " -match_edge- {} -match_edge- {as: test, where: ( $matched.person != $currentMatch)}" }
	end

	context 'compile statements' do

	Given( :s1 ){ TestQuery.start(  where: {a: 9, b: 's'} ) << E.connect("<-", as: :test) }
	Then { s1.compile == "match {class: test_query, as: test_queries, where: ( a = 9 and b = 's')} <-- {as: test} return  test_queries,  test" }
	Then { s1.compile{|y| y.last} == "match {class: test_query, as: test_queries, where: ( a = 9 and b = 's')} <-- {as: test} return  test" }
	Then { s1.compile{|y| "#{y.last}.name"} == "match {class: test_query, as: test_queries, where: ( a = 9 and b = 's')} <-- {as: test} return  test.name" }
#		context "add and modify where-filter" do
#			Given( :m1 ) { q1.match_statements[0].where c: 9; q1 }
#			Then {  expect( m1.to_s ).to eq   "MATCH {class: test_query, as: test_queries, where :( a = 9 and b = 's' and c = 9)} RETURN test_queries" }
#
#			Given( :m2  ){ q1.match_statements[0].where =  {a: 9, b: 'O'} ; q1 }
#			Then {   m2.to_s ==  "MATCH {class: test_query, as: test_queries, where:( a = 9 and b = 'O')} RETURN test_queries" }
#			end
#		end
#
#	context 'standard Match Query ' do
#		Given( :q2){ OrientSupport::OrientQuery.new  start:{ class: TestQuery, where: {item: 's'} ,maxdepth: 6 },  
#																								connect:{ direction: :out, edge: MATCH_EDGE, as: :node }     }
#		Then { expect( q2.to_s ).to eq "" }
#
	end
end
