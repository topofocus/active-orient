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
      q =  OrientSupport::OrientQuery.new from: 'ModelQuery'
      q.where [{ a: 2} , 'b > 3',{ c: 'ufz' }]
      expect(q.where).to eq "where a = 2 and b > 3 and c = 'ufz'"
      q.distinct 'name'
      expect(q.distinct).to eq "distinct( name )"
      q.order name: :asc
      expect(q.order).to eq "order by name asc"
      q.projection   "eval( 'amount * 120 / 100 - discount' )"=> 'finalPrice'
      expect(q.projection).to eq "distinct( name ), eval( 'amount * 120 / 100 - discount' ) as finalPrice"
      expect(q.compose). to eq "select distinct( name ), eval( 'amount * 120 / 100 - discount' ) as finalPrice from ModelQuery where a = 2 and b > 3 and c = 'ufz' order by name asc"
    end 

  end
  context "Books Words example" , focus: true do
    before(:all) do
      @r.delete_class :book
      Book = @r.create_vertex_class :book
      Book.create_property( :title, type: :string, index: :unique )
      @r.delete_class :word
      Word= @r.create_vertex_class :word
      Word.create_property( :item , type: :string, index: :unique )
      @r.delete_class :has_content
      HC= @r.create_edge_class :has_content

    end
    it "check structure" do
      expect( @r.class_hierachie( base_class: 'V').sort ).to eq [Book.new.classname, Word.new.classname]
      expect( @r.class_hierachie( base_class: 'E') ).to eq [HC.new.classname]
    end

    it "put test-content" do
     fill_database = ->(sentence, this_book ) do 
       sentence.split(' ').each do |x| 
	 this_word = Word.update_or_create where: { item: x }
	 this_edge = HC.create_edge from: this_book, to: this_word  if this_word.present?
       end 
      end
      words = 'Die Geschäfte in der Industrie im wichtigen US-Bundesstaat New York sind im August so schlecht gelaufen wie seit mehr als sechs Jahren nicht mehr Der entsprechende Empire-State-Index fiel überraschend von plus  Punkten im Juli auf minus 14,92 Zähler Dies teilte die New Yorker Notenbank Fed heut mit Bei Werten im positiven Bereich signalisiert das Barometer ein Wachstum Ökonomen hatten eigentlich mit einem Anstieg auf 5,0 Punkte gerechnet'
      this_book =  Book.create title: 'first'
      fill_database[ words, this_book ]
      expect( Word.count ).to be > 10 

     words2 = 'Das Bruttoinlandsprodukt BIP in Japan ist im zweiten Quartal mit einer aufs Jahr hochgerechneten Rate von Prozent geschrumpft Zu Jahresbeginn war die nach den USA und China drittgrößte Volkswirtschaft der Welt noch um  Prozent gewachsen Der Schwächeanfall wird auch als Rückschlag für Ministerpräsident Shinzo Abe gewertet der das Land mit einem Mix aus billigem Geld und Konjunkturprogramm aus der Flaute bringen will Allerdings wirkte sich die heutige Veröffentlichung auf die Märkten nur wenig aus da Ökonomen mit einem schwächeren zweiten Quartal gerechnet hatten'
     this_book =  Book.create title: 'second'
     fill_database[ words2, this_book ]
     expect( Word.count ).to be  > 100 
    end
    it "Subquery Initialisation" do
      query = OrientSupport::OrientQuery.new where:  "out('HasContent').item IN ['Quartal','Land']"
      result= Book.query_database query
      expect( result).to be_a Array
      expect( result).to have_at_least(1).item
      queried_book =  result.first
      expect( queried_book ).to be_a ActiveOrient::Model::Book
      expect( queried_book.title ).to eq 'second'

    end
  end
end  # describe
