require 'spec_helper'
=begin
BOOKs EXAMPLE

There are several Books. And there is a Table with Keywords.

The Keywords are associated to the books, this is realized via an Edge »has_content«

Thus

Book = @r.create_vertex_class :book
Word = @r.create_vertex_class :word
HC = @r.create_edge_class :has_content

Books have a title and many edges to Word.
Words have items, both properties use automatic indexes

Book.create_property( :title, type: :string, index: :unique )
Word.create_property( :item , type: :string, index: :unique )

for each word:
HC.create_edge from: this_book, to: this_word

To query which books have a given set of words:
for each word this query loads a collection of books

query = OrientSupport::OrientQuery.new  from: Word, projection: "expand(in('HasContent'))"#

the query is completed by

query.where(  item: '{given word}'  )

The pieces are tied together in a final query »q«

q =  OrientSupport::OrientQuery.new projection: 'expand( $z )'
desired_words = [ 'Land', 'Quartal' ]
intersects =  Array.new

desired_words.each_with_index do | word, i |
symbol = ( i+97 ).chr   #  convert 1 -> 'a'
q.let symbol => query.where(  item: word  )
intersects << "$#{symbol}"
end
q.let   "$z = Intersect(#{intersects.join(', ')}) "
result = Word.query_database  q, set_from: false

The generated Query »q« for two words that should appear in any book:

select expand( $z ) let $a = ( select expand(in('HasContent')) from Word where item = 'Land' ), $b = ( select expand(in('HasContent')) from Word where item = 'Quartal' ), $z = Intersect($a, $b)

=end

describe OrientSupport::OrientQuery do
  before( :all ) do
    ######################################## ADJUST user+password ###################
    ActiveOrient::OrientDB.default_server= { user: 'root', password: 'tretretre' }
    @r = ActiveOrient::OrientDB.new database: 'ArrayTest'
    TestQuery = @r.open_class "model_query"
    @record = TestQuery.create
  end # before

  context "Books Words example" , focus: true do
    before(:all) do
      @r.delete_class :book
      Book = @r.create_vertex_class :book
      Book.create_property( :title, type: :string, index: :unique )
      @r.delete_class :word
      Word = @r.create_vertex_class :word
      Word.create_property( :item , type: :string, index: :unique )
      @r.delete_class :has_content
      HC= @r.create_edge_class :has_content

    end
    it "check structure" do
      expect( @r.class_hierarchy( base_class: 'V').sort ).to eq [Book.classname, Word.classname]
      expect( @r.class_hierarchy( base_class: 'E') ).to eq [HC.classname]
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
    it "Query Initialisation" do
      # search all books with words "Quartal" or "Landereien"
      query = OrientSupport::OrientQuery.new where:  "out('Has_content').item IN ['Quartal','Landereien']",
      from: Book
      result= Book.query_database query
      expect( result).to be_a Array
      expect( result).to have_at_least(1).item
      queried_book =  result.first
      expect( queried_book ).to be_a ActiveOrient::Model::Book
      expect( queried_book.title ).to eq 'second'

    end
    it "Subquery Initialisation" do
      # search for books wiht contain all given words
      query = OrientSupport::OrientQuery.new  from: Word, projection: "expand(in('Has_content'))"

      q =  OrientSupport::OrientQuery.new projection: 'expand( $z )'
      intersects = Array.new
      desired_words = [ 'Land', 'Quartal']
      desired_words.each_with_index do | word, i |
        symbol = ( i+97 ).chr   #  convert 1 -> 'a'
        query.where = { item: word  }
        q.let << { symbol =>  query }
        intersects << "$#{symbol}"
      end
      q.let << "$z = Intersect(#{intersects.join(', ')}) "
      puts "generated Query:"
      puts q.to_s
      result = Word.query_database  q, set_from: false
      expect( result.pop ).to be_a ActiveOrient::Model::Book
    end

  end
end  # describe
