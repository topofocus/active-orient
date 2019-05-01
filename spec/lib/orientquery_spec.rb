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

#	after(:all){ @db.delete_database database: 'temp' }
  context "Initialize the QueryClass" do
    Given( :query ){  OrientSupport::OrientQuery.new from: TestQuery }
    Then { expect( query ).to be_a OrientSupport::OrientQuery }

		Given( :traverse_query ) do
					OrientSupport::OrientQuery.new from: TestQuery, 
																				 where:{ a: 2 , c: 'ufz' }, 
																				 kind: 'traverse'  
		end
    Then  {  expect(traverse_query.to_s).to eq "traverse from test_query where a = 2 and c = 'ufz' "  }

		Given( :update_query ) do
					OrientSupport::OrientQuery.new from: TestQuery, 
																				 where: { a: 2},	
																				 set: { c: 'ufz' }, 
																				 kind: 'update'  
		end
    Then  {  expect(update_query.to_s).to eq "update test_query set c = 'ufz' where a = 2 return after $this"  }
  #  it "where with dates" do 
  #    date = Date.today
  #    q = OrientSupport::OrientQuery.new from: :Openinterest, 
#		where:{"fieldtype.date(\"yyyy-mm-dd\")"=> date.to_s}
 #     q.where << {:a =>  2}
 #     puts q.to_s
 #   end

		context " parameter where" do
			Given( :where_with_hash ) { query.where   a: 2 , c: 'ufz';  }
			Then { expect( where_with_hash.to_s ).to match /where a = 2 and c = 'ufz'/ }
			Given( :where_with_mixed_array ){ query.where  [{ a: 2} , 'b > 3',{ c: 'ufz' }]  }
			Then {  expect( where_with_mixed_array.to_s ).to match /where a = 2 and b > 3 and c = 'ufz'/ }
		end
	
		context " distinct results" do
     Given( :with_distinct ) { OrientSupport::OrientQuery.new from: TestQuery, distinct: 'name'  }
     Then { expect( with_distinct.to_s ).to eq "select distinct name from test_query " }

		 it " distinct as method returns the compiled string " do
			 q = OrientSupport::OrientQuery.new from: TestQuery
			 expected_result =  "select distinct a from test_query "
			 expect( q.distinct 'a' ).to  be_a OrientSupport::OrientQuery
			 expect( q.to_s ).to eq expected_result
		 end
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
      Then { expect(  eval_projection.to_s ).to eq  "select eval( 'amount * 120 / 100 - discount' ) as finalPrice from test_query " }
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

		context "applying nodes" do
			# todo: applying node based envrionment

		end

		context " old stuff,  but still working" do 
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
      it "prefetch a link-query " do
        q =  OrientSupport::OrientQuery.new from: TestQuery
        q.let  "$city = adress.city"
        q.where  "$city.country.name = 'Italy' OR $city.country.name = 'France'"

        expect( q.compose ).to eq "select from test_query let $city = adress.city where $city.country.name = 'Italy' OR $city.country.name = 'France' "

      end
      it "subquery and expand" do
        oi_query =  OrientSupport::OrientQuery.new from: 'Openinterest', limit: 10, projection: 'expand( contracts )'
	#puts oi_query.to_s
        contracts_query = OrientSupport::OrientQuery.new from: oi_query, projection: 'expand( distinct(ORDid) )'
        expect( contracts_query.to_s ).to eq 'select expand( distinct(ORDid) ) from  ( select expand( contracts ) from Openinterest  limit  10 )  '

      end
      it "subquery and subsequent unionall" do
# pending( "Try's to fetch data from #5:0, if there aren'd any, it fails")
        q =  OrientSupport::OrientQuery.new
        q.let   a:  OrientSupport::OrientQuery.new( from: '#5:0' ) 
        q.let   b:  OrientSupport::OrientQuery.new( from: '#5:1' ) 
        q.let  '$c= UNIONALL($a,$b) '
        q.projection  'expand( $c )'
        expect( q.to_s ).to eq 'select expand( $c ) let $a = (select from #5:0 ), $b = (select from #5:1 ), $c= UNIONALL($a,$b)  '
      end
      it "Use a subquery" do
        q =  OrientSupport::OrientQuery.new from: TestQuery, where: { a: 2 , c: 'ufz' }
        r =  OrientSupport::OrientQuery.new from: q , kind: 'traverse', projection: :day
        expect( r.to_s ).to eq "traverse day from  ( select from test_query where a = 2 and c = 'ufz'  )  "
        s = OrientSupport::OrientQuery.new from: r, projection: 'unionall( logs ) AS logs '
        t = OrientSupport::OrientQuery.new from: s, projection: 'expand( logs ) '
        expect( t.to_s ).to eq "select expand( logs )  from  ( select unionall( logs ) AS logs  from  ( traverse day from  ( select from test_query where a = 2 and c = 'ufz'  )   )   )  "

      end
    end

  end
end  # describe
