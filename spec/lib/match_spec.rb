### reference : https://orientdb.org/docs/3.0.x/sql/SQL-Match.html

require 'spec_helper'
require 'rest_helper'
require 'connect_helper'
require 'model_helper'
require 'rspec/given'

RSpec.describe OrientSupport::OrientQuery do
  before( :all ) do
    @db = connect database: 'temp'
    V.create_class :test_query, :second
    E.create_class :match_edge, :alternative
		if TestQuery.count < 3
			a= TestQuery.create  a:9, b: 's' 
			b= TestQuery.create  a:5, b: 's' 
			c= TestQuery.create  a:5, b: 'p' 
			a.assign via: MATCH_EDGE , vertex: Second.create( name:'John')
			b.assign via: MATCH_EDGE , vertex: Second.create( name:'maria')
			c.assign via: MATCH_EDGE , vertex: Second.where( name:'maria').first
		end
  end # before

#	after(:all){ @db.delete_database database: 'temp' }

	context 'Simple Match Query'  do
		Given( :m1){  TestQuery.match  where: {a: 9, b: 's'} }    
		Then { expect( m1.to_s ).to match /test/ }
		Then { expect( m1.to_s).to eq "{class: test_query, as: test_queries, where: ( a = 9 and b = 's')}" }

		Given( :m2 ){ m1.where c:9 }
		Then { m2.to_s == "{class: test_query, as: test_queries, where: ( a = 9 and b = 's' and c = 9)}" }

		context "execute it" do
			Given( :r1 ) {  m1.execute  }
			Then { expect(r1).to be_an(Array) }

		end
	end
	context "Simple Connection" do
		Given( :c0  ){ E.connect  }
		Then { c0.to_s == ".both()" }
		Given( :c1  ){ MATCH_EDGE.connect }
		Then { c1.to_s ==  ".both(match_edge)" }
		 
		Given( :c2  ){ MATCH_EDGE.connect count: 2}
		Then { c2.to_s ==  ".both(match_edge).both(match_edge)" }
		Given( :c3  ){ MATCH_EDGE.connect count: 2, as: 'test'}
		Then { c3.to_s ==  ".both(match_edge).both(match_edge){as: test}" }
		Given( :c4a  ){ MATCH_EDGE.connect "<-"}
		Then { c4a.to_s ==  ".in(match_edge)" }

		Given( :c4b  ){ MATCH_EDGE.connect  direction: :in}
		Then { c4b.to_s ==  ".in(match_edge)" }
		Given( :c5a  ){ MATCH_EDGE.connect "->"}
		Then { c5a.to_s ==  ".out(match_edge)" }
		Given( :c5b  ){ MATCH_EDGE.connect  direction: :out}
		Then { c5b.to_s ==  ".out(match_edge)" }
		Given( :c6  ){ MATCH_EDGE.connect "->", count: 2}
		Then { c6.to_s ==  ".out(match_edge).out(match_edge)" }

		Given( :c7  ){ MATCH_EDGE.connect direction: :bothE }
		Then { expect(c7.to_s).to eq  ".bothE(match_edge)" }
		Given( :c8  ){ MATCH_EDGE.connect direction: :both_vertex }
		Then { expect(c8.to_s).to eq  ".bothV()" }

		Given( :c9  ){ MATCH_EDGE.connect direction: :bothE, where: {a: 1 }}   
		Then { expect(c9.to_s).to eq  ".bothE(match_edge){where: ( a = 1)}" }
		Given( :c9a ){ MATCH_EDGE.connect direction: :bothE, where: {a: 1 }, while: "true"}   
		Then { expect(c9a.to_s).to eq  ".bothE(match_edge){where: ( a = 1), while: ( true)}" }
		Given( :c9b ){ MATCH_EDGE.connect direction: :bothE, where: {a: 1 }, while: "true", max_depth: 8}   
		Then { expect(c9b.to_s).to eq  ".bothE(match_edge){where: ( a = 1), while: ( true), maxDepth: 8}" }
		Given( :c10  ){ MATCH_EDGE.connect count: 2, as: 'test', where: "$matched.person != $currentMatch" }
		Then { c10.to_s ==  ".both(match_edge).both(match_edge){as: test, where: ( $matched.person != $currentMatch)}" }
	end

	context 'a single connection'  do
		Given( :m3 ){ TestQuery.match( where:{ b: 'p' }, as: nil) <<   MATCH_EDGE.connect( "->", as: 'name')  }
    Then { expect( m3.compile).to eq "match {class: test_query, where: ( b = 'p')}.out(match_edge){as: name} return  name" }
		Then { expect( m3.execute(as: :flatten) ).to have(1).record }
		Then { expect( m3.execute(as: :flatten) ).to eq Second.where(  name: 'maria' ) }
	end

	context 'multiple classes', focus: true  do
		Given( :mm1 ) do 
			     TestQuery.match(  where: {a: 9}, as: nil ) << 
					 MATCH_EDGE.connect( :both, as: 'result') << 
					 MATCH_EDGE.connect( :out) << 
				   Second.match( where: { name: 'Rome' }, as: nil)
		end

		Then { expect(mm1.compile).to match /^match/ }
		Then { expect(mm1.compile).to  eq  "match {class: test_query, where: ( a = 9)}.both(match_edge){as: result}.out(match_edge){class: second, where: ( name = 'Rome')} return  result" }
	end

	context 'compile statements' do

		### Standard case: return all "as" values
		Given( :s1 ){ TestQuery.match(  where: {a: 9, b: 's'} ) << E.connect("<-", as: :test) }
		Then { s1.compile == "match {class: test_query, as: test_queries, where: ( a = 9 and b = 's')}.in(){as: test} return  test_queries,  test" }
		### take the last "as"-parameter
		Then { s1.compile{|y| y.last} == "match {class: test_query, as: test_queries, where: ( a = 9 and b = 's')}.in(){as: test} return  test" }
		## fetch name for the last "as" parameter

		context "flexible as statements" do

			Given( :s1 ){ TestQuery.match(  where: {a: 9, b: 's'}, as: nil ) << E.connect("<-", as: :test) }
			Then { s1.compile == "match {class: test_query, where: ( a = 9 and b = 's')}.in(){as: test} return  test" }

			Then { s1.compile{|y| "#{y.last}.name"} == "match {class: test_query, where: ( a = 9 and b = 's')}.in(){as: test} return  test.name" }
		end

		context "Traverse alternatives"  do
			Given( :t1 ){ TestQuery.match(  where: {name: 'John'}, as: nil ) << MATCH_EDGE.connect( as: 'Friends', while: '$dept<3') }

			Then { t1.compile == "match {class: test_query, where: ( name = 'John')}.both(match_edge){as: Friends, while: ( $dept<3)} return  Friends" }
		end
	end
end
