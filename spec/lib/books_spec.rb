require 'spec_helper'
require 'rest_helper'
require 'pp'
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
    reset_database
  end # before

  context "Books Words example" do
    before(:all) do
      ORD.create_class 'E', 'V'
      ORD.create_vertex_class :book, :word 
      Book.create_property( :title, type: :string, index: :unique )
      Word.create_property( :item , type: :string, index: :unique )
      HC = ORD.create_edge_class :has_content
      puts "HC: #{HC.class} ++ #{HC.superclass} "
      HC.uniq_index
#      ORD.create_properties( :has_content, in: { type: :link}, out: { type: :link } ) do
#	{ name: 'edge_idx', on: [ :in, :out ] }
#      end
#      #ORD.create_index :has_content, name: 'edge_idx', on: [ :in, :out ]

    end
    # there are only the allocated classes present in the database!
    # otherwise we have to use the "include" test
    it "check structure" do
      expect( ORD.class_hierarchy( base_class: 'V').sort ).to eq ["book","word"]
      expect( ORD.class_hierarchy( base_class: 'E') ).to eq ["has_content"]
    end
   
    # we test the lambda "fill database"
    it "apply test-content"  do
			fill_database = ->(sentence, this_book ) do
				nw = Array.new
				## duplicates are not created, a log-entry is created
				word_records =  sentence.split(' ').map{ |x| Word.create item: x  }.compact 
				HC.create :from => this_book, :to => word_records  # return value for the iteration
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
    it "search all books with words \"Quartal\" or \"Flaute\"" do
      query = OrientSupport::OrientQuery.new where:  "out('has_content').item IN ['Quartal','Flaute']"
      result= Book.query_database query
      expect( result).to be_a Array
      expect( result).to have_at_least(1).item
      queried_book =  result.first
      puts "queriede book #{queried_book.inspect}"
      expect( queried_book ).to be_a Book
      expect( queried_book.title ).to eq 'second'

    end
    it "Subquery Initialisation" do
      # search for books wiht contain all given words
      query = OrientSupport::OrientQuery.new  from: Word, projection: "expand(in('has_content'))"

      q =  OrientSupport::OrientQuery.new projection: 'expand( $z )'
      intersects = Array.new
      desired_words = [ 'Land', 'Quartal']
      desired_words.each_with_index do | word, i |
        symbol = ( i+97 ).chr   #  convert 1 -> 'a'
        query.where = { item: word  }
        q.let << { symbol =>  query.compose }
        intersects << "$#{symbol}"
      end
      q.let << "$z = Intersect(#{intersects.join(', ')}) "
      puts "generated Query:"
      puts q.compose
      result = Word.query_database  q, set_from: false
      expect( result.first ).to be_a Book
      expect( result.title ).to eq ["second"]
      puts " ------------------------------"
      puts "congratulations"
      puts "result: #{result.title} (should be second!)"
    end

  end
end  # describe
