require 'spec_helper'

describe OrientSupport::OrientQuery do
  before( :all ) do
    ######################################## ADJUST user+password ###################
    ActiveOrient::OrientDB.default_server= { user: 'hctw', password: 'hc' }
    @r = ActiveOrient::OrientDB.new database: 'ArrayTest'
    TestQuery = @r.open_class "model_query" 
    @record = TestQuery.create
  end # before

  context "Initialize the QueryClass" do
    it "simple Initialisation" do
      q =  OrientSupport::OrientQuery.new from: TestQuery
      expect(q).to be_a OrientSupport::OrientQuery
    end

    it "Initialisation with a Parameter" do
      q =  OrientSupport::OrientQuery.new from: TestQuery, where:{ a: 2 , c: 'ufz' }
      expect(q.where).to eq "where a = 2 and c = 'ufz'"
      q =  OrientSupport::OrientQuery.new from: TestQuery, where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]
      expect(q.where).to eq "where a = 2 and b > 3 and c = 'ufz'"
      q =  OrientSupport::OrientQuery.new from: TestQuery, distinct: 'name'
      expect(q.distinct).to eq "distinct( name )"
      q =  OrientSupport::OrientQuery.new from: TestQuery, order: {name: :asc}, skip: 30
      expect( q.compose ).to eq "select  from ModelQuery order by name asc skip 30"
      expect(q.order).to eq "order by name asc"
      q =  OrientSupport::OrientQuery.new from: TestQuery, projection: { "eval( 'amount * 120 / 100 - discount' )"=> 'finalPrice' }
      expect(q.projection).to eq "eval( 'amount * 120 / 100 - discount' ) as finalPrice"
      expect( q.compose ).to eq  "select eval( 'amount * 120 / 100 - discount' ) as finalPrice from ModelQuery"


    end

    it "subsequent Initialisation" do
      q =  OrientSupport::OrientQuery.new 
      q.from = 'ModelQuery'
      q.where = [{ a: 2} , 'b > 3',{ c: 'ufz' }]
      expect(q.where).to eq "where a = 2 and b > 3 and c = 'ufz'"
      q.distinct = 'name'
      expect(q.distinct).to eq "distinct( name )"
      q.order = {name: :asc}
      expect(q.order).to eq "order by name asc"
      q.projection = { "eval( 'amount * 120 / 100 - discount' )"=> 'finalPrice' }
      expect(q.projection).to eq "distinct( name ), eval( 'amount * 120 / 100 - discount' ) as finalPrice"
      expect(q.compose). to eq "select distinct( name ), eval( 'amount * 120 / 100 - discount' ) as finalPrice from ModelQuery where a = 2 and b > 3 and c = 'ufz' order by name asc"
    end 


    context "use the let block " do
      it "prefetch a link-query " do
	q =  OrientSupport::OrientQuery.new from: 'ModelQuery'
	q.let "$city = adress.city"
	q.where "$city.country.name = 'Italy' OR $city.country.name = 'France'"

	expect( q.compose ).to eq "select  from ModelQuery let $city = adress.city where $city.country.name = 'Italy' OR $city.country.name = 'France'"

      end
      it "subquery and subsequent unionall" do

	q =  OrientSupport::OrientQuery.new 
	q.let  a:  OrientSupport::OrientQuery.new( from: '#5:0' )
	q.let  b:  OrientSupport::OrientQuery.new( from: '#5:1' )
	q.let  '$c= UNIONALL($a,$b) '
	q.projection 'expand( $c )'
	puts q.compose
      end
    end
  end
end  # describe
