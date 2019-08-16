require 'spec_helper'
require 'rest_helper'
require 'connect_helper'
require 'model_helper'
require 'rspec/given'

RSpec.describe OrientSupport::OrientQuery do
  before( :all ) do
    @db = connect database: 'temp'
    @db.create_class "test_query"
#    @db.create_class 'Openinterest'
#    @db.create_class "match_query"
  end # before

	after(:all){ @db.delete_database database: 'temp' }
	

  Given( :query ){  OrientSupport::OrientQuery.new from: TestQuery }
  Then { expect(query).to be_a OrientSupport::OrientQuery }
	Then{ expect( query.to_s).to eq "select from test_query " }

  context "Basic queries" do
		Given( :where_with_hash ) { query.where   a: 2 , c: 'ufz';  }
		Then { expect( where_with_hash.to_s ).to match /where a = 2 and c = 'ufz'/ }
		Given( :where_with_mixed_array ){ query.where  [{ a: 2} , 'b > 3',{ c: 'ufz' }]  }
		Then {  expect( where_with_mixed_array.to_s ).to match /where a = 2 and b > 3 and c = 'ufz'/ }
	end
	context " distinct results" do
		Given( :implicit_distinct ) { OrientSupport::OrientQuery.new from: TestQuery, distinct: 'name'  }
		Then { expect( implicit_distinct.to_s ).to eq "select distinct name from test_query " }

		Given( :explicit_distinct ){ query.distinct 'a' }
		Then { expect( explicit_distinct.to_s ).to eq "select distinct a from test_query " }
	end 	 

	context " order results" do

		Given( :asc_and_skip ) { OrientSupport::OrientQuery.new from: TestQuery, order: {name: :asc}, skip: 30 }
		Then {  expect( asc_and_skip.to_s ).to eq "select from test_query order by name asc skip  30" }

	end

	context "projections " do

		Given( :eval_projection ) do  
			OrientSupport::OrientQuery.new from: TestQuery, 
				projection: { "eval( 'amount * 120 / 100 - discount' )"=> 'finalPrice' } 
		end
		Then { expect(  eval_projection.to_s ).to eq "select eval( 'amount * 120 / 100 - discount' ) as finalPrice from test_query " }
	end

	context "usage of limit"  do
		Given( :limit_query ) {  OrientSupport::OrientQuery.new  from: TestQuery, limit: 23 }
		Then { expect( limit_query.to_s).to eq 'select from test_query  limit  23' }

		#	expect(q.compose( destination: :rest )).to eq 'select  from test_query  '
		#  expect( q.get_limit).to eq 23
		#
		#     q.limit = 15
		#    expect( q.get_limit).to eq 15

	end	


	context "update data" do
		When( :update_with_class ) { query.where(  a: 2 ).set( c: 'ufz' ).kind( 'update!' ) }
    Then  {  expect(update_with_class.to_s).to eq "update test_query set c = 'ufz' where a = 2"  }
		Given( :update_with_rid ) do
					OrientSupport::OrientQuery.new target: "#33:0", 
																				 where: { a: 2},	
																				 set: { c: 'ufz' }, 
																				 kind: 'update'  
		end
    Then  {  expect(update_with_rid.to_s).to eq "update #33:0 set c = 'ufz' return after $current where a = 2"  }

		Given( :update_of_an_array ) do
					OrientSupport::OrientQuery.new target: "#33:0", 
																				 where: { a: 2},	
																				 set: { c: [ :a, 'b', 3 ] }, 
																				 kind: 'update'  
		end
    Then  {  expect(update_of_an_array.to_s).to eq  "update #33:0 set c = [':a:', 'b', 3] return after $current where a = 2"  }
		Then {   expect( update_with_class.kind(:upsert).to_s ).to eq   "update test_query set c = 'ufz' upsert return after $current where a = 2"  }
		Given( :update_of_a_date ) do


		end
  #  it "where with dates" do 
  #    date = Date.today
  #    q = OrientSupport::OrientQuery.new from: :Openinterest, 
#		where:{"fieldtype.date(\"yyyy-mm-dd\")"=> date.to_s}
 #     q.where << {:a =>  2}
 #     puts q.to_s
 #   end
	end

	
		context "applying nodes" do
			# todo: applying node based envrionment

		end

		context " old stuff,  still working" do 
			it "subsequent Initialisation"  do
				q =  OrientSupport::OrientQuery.new
				q.from  'test_query'
				q.where   a: 2
				q.where  'b > 3'
				q.where   c: 'ufz' 
				expect(q.where).to eq "where a = 2 and b > 3 and c = 'ufz'"
				q.distinct  'name'
				q.order  name: :asc 
				q.order  vorname: :asc 
				expect(q.order).to eq "order by name asc, vorname asc"
				q.projection   "eval( 'amount * 120 / 100 - discount' )"=> 'finalPrice' 
				expect(q.projection).to eq "distinct name, eval( 'amount * 120 / 100 - discount' ) as finalPrice"
				expect(q.compose). to eq "select distinct name, eval( 'amount * 120 / 100 - discount' ) as finalPrice from test_query where a = 2 and b > 3 and c = 'ufz' order by name asc, vorname asc"
			end

		end
		context "use the let block "  do
			Given( :prefetch_link ) do
				query.let("$city = adress.city").where  "$city.country.name = 'Italy' OR $city.country.name = 'France'"
			end
			Given( :prefetch_link_alternative ) do
				query.let( city: 'adress.city').where  "$city.country.name = 'Italy' OR $city.country.name = 'France'"
			end

			Then { expect( prefetch_link.to_s ).to eq "select from test_query let $city = adress.city where $city.country.name = 'Italy' OR $city.country.name = 'France' "}

			it "subquery and subsequent unionall" do
				# pending( "Try's to fetch data from #5:0, if there aren'd any, it fails")
				q =  OrientSupport::OrientQuery.new
				q.let   a:  OrientSupport::OrientQuery.new( from: '#5:0' ) 
				q.let   b:  OrientSupport::OrientQuery.new( from: '#5:1' ) 
				q.let  '$c= UNIONALL($a,$b) '
				q.projection  'expand( $c )'
				expect( q.to_s ).to eq 'select expand( $c ) let $a = (select from #5:0 ), $b = (select from #5:1 ), $c= UNIONALL($a,$b)  '
			end
		end
		context "Subqueries" do
			it "with unionall" do
				q =  OrientSupport::OrientQuery.new from: TestQuery, where: { a: 2 , c: 'ufz' }
				r =  OrientSupport::OrientQuery.new from: q , kind: 'traverse', projection: :day
				expect( r.to_s ).to eq "traverse day from  ( select from test_query where a = 2 and c = 'ufz'  )  "
				s = OrientSupport::OrientQuery.new from: r, projection: 'unionall( logs ) AS logs '
				t = OrientSupport::OrientQuery.new from: s, projection: 'expand( logs ) '
				expect( t.to_s ).to eq "select expand( logs )  from  ( select unionall( logs ) AS logs  from  ( traverse day from  ( select from test_query where a = 2 and c = 'ufz'  )   )   )  "

			end
			it " with expand" do
				oi_query =  OrientSupport::OrientQuery.new from: 'Openinterest', limit: 10, projection: 'expand( contracts )'
				#puts oi_query.to_s
				contracts_query = OrientSupport::OrientQuery.new from: oi_query, projection: 'expand( distinct(ORDid) )'
				expect( contracts_query.to_s ).to eq 'select expand( distinct(ORDid) ) from  ( select expand( contracts ) from Openinterest  limit  10 )  '
			end
		end
		context " Traverse " do
			Given( :traverse_query ) do
				OrientSupport::OrientQuery.new from: TestQuery, 
					where:{ a: 2 , c: 'ufz' }, 
					kind: 'traverse'  
			end

			Then  {  expect(traverse_query.to_s).to eq "traverse from test_query where a = 2 and c = 'ufz' "  }
			When( :second_traverse_query ){ query.where( a: 2 , c: 'ufz' ).kind( 'traverse' ) }
			Then  {  expect(second_traverse_query.to_s).to eq  traverse_query.to_s  }
		end


		context "execute" do
			context "class based queries" do 
				before(:all) do
					(1..200).each{|y| TestQuery.create c: y }
				end
				it "count" do
					q = TestQuery.query projection:  'COUNT(*)'
					expect(q.to_s).to eq "select COUNT(*) from test_query "
					expect(q.execute{|x|  x[:"COUNT(*)"]}).to eq [200]
					expect(q.execute(reduce: true){|x|  x[:"COUNT(*)"]}).to eq 200
				end
				it{	expect( TestQuery.count( where: 'c <100' ) ).to eq 99 }

				it "first and last" do
					q =  TestQuery.query( order: "@rid", limit:1)
					expect( q.to_s ).to eq "select from test_query order by @rid limit  1"
					expect(q.execute(reduce: true)).to eq TestQuery.where(c: 1).first
				end
				it { expect( TestQuery.first ). to eq TestQuery.where( c: 1  ).first }
				it { expect( TestQuery.last ). to eq TestQuery.where( c: 200  ).first }

				it "upsert" do
					q =  TestQuery.query(  kind: :upsert, set:{ c: 500}, where:' c = 500'  )
					expect( q.to_s ).to eq "update test_query set c = 500 upsert return after $current where  c = 500"
					p =  q.execute(reduce: true){|y| y[:$current].reload!}
					expect(p).to be_a TestQuery
					expect(p.c).to eq 500
				end
				# new record
				it { expect( TestQuery.upsert where:{ c: 670 } ). to eq TestQuery.where( c: 670  ).first }
				# existing record
				it { expect( TestQuery.upsert where:{ c: 70 } ). to eq TestQuery.where( c: 70  ).first }



				it "update on class level" do

					q =  TestQuery.query(  kind: :update!, set:{ c: 500}, where:'c = 50'  )
					expect( q.to_s ).to eq "update test_query set c = 500 where c = 50"
					p =  q.execute(reduce: true){|y| y[:count]}
					expect(p).to be_a Integer
				end
				it { expect( TestQuery.update u: 65, where:{ c: 70 } ). to eq TestQuery.where( c: 70  )}
				it { expect( TestQuery.update! u: 66, where:{ c: 70 } ). to eq 1 }
				it { expect( TestQuery.update! u: 66, where: ["c < 70", "c > 60"]  ). to eq 9 }
				it { expect( TestQuery.update! u: 66, where:{ c: 700 } ). to eq 0 }
				it { expect( TestQuery.update u: 66, where:{ c: 700 } ). to be_empty }



			end

			context "model record based queries"  do
				before( :all ) do
					TestQuery.delete all: true
				 @the_record =  TestQuery.create c:1 
				end

				it " simple update " do
					r = @the_record.update d:[ 1, 2, 3]
		#			puts "RR:: #{r}"
					expect(r).to be_a TestQuery
					expect(r.c).to eq 1
					expect(r.d).to eq [1,2,3]
					expect( TestQuery.count ).to eq 1
				end
				it " simple remove " do
					r = @the_record.update remove:{ d:1}
					puts r.inspect
					expect(r).to be_a TestQuery
					expect(r.c).to eq 1
					expect(r.d).to  eq [ 2,3 ]
				end

				it "store a value in a hash" do 
					r =  @the_record.update( {h: { a: 'b' }} )
					expect(r.h).to eq  a: 'b' 
					updated_hash = @the_record.h.store :c,10
					expect(@the_record.reload!.h).to eq  a: 'b' , c: 10
					#r = @the_record.update remove:{ d:1}
				end
			end

		end
end
		#end  # describe
