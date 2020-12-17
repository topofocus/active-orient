require 'spec_helper'
require 'rest_helper'
require 'connect_helper'
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
	before(:all){  @db = connect database: 'temp' }
	after(:all){ @db.delete_database database: 'temp' }

  context "Books Words example" do
    before(:all) do
      V.create_class :book, :word 
      Book.create_property( :title, type: :string, index: :unique )
      Word.create_property( :item , type: :string, index: :unique )
      HC = E.create_class :has_content
      HC.uniq_index
    end
    # there are only the allocated classes present in the database!
    # otherwise we have to use the "include" test
    it "check structure" do
      expect( V.db.class_hierarchy( base_class: 'V').sort ).to eq ["book","word"]
      expect( V.db.class_hierarchy( base_class: 'E') ).to eq ["has_content"]
    end
   
    # we test the lambda "fill database"
    it "apply test-content"  do
			fill_database = ->(this_book, sentence ) do
				word_records =  sentence.split(' ').uniq.map{ |x| Word.upsert where: {item: x }  } 
				HC.create :from => this_book, :to => word_records   #			 returns edge for the iteration
			end
      fill_database.call  Book.create( title: 'first'), 'Die Geschäfte in der Industrie im wichtigen US-Bundesstaat New York sind im August so schlecht gelaufen wie seit mehr als sechs Jahren nicht mehr Der entsprechende Empire-State-Index fiel überraschend von plus  Punkten im Juli auf minus 14,92 Zähler Dies teilte die New Yorker Notenbank Fed heut mit Bei Werten im positiven Bereich signalisiert das Barometer ein Wachstum Ökonomen hatten eigentlich mit einem Anstieg auf 5,0 Punkte gerechnet'

      expect( Word.count ).to be > 10
      expect( HC.count ).to be > 10

      fill_database.call  Book.create( title: 'second' ), 'Das Bruttoinlandsprodukt BIP in Japan ist im zweiten Quartal mit einer aufs Jahr hochgerechneten Rate von Prozent geschrumpft Zu Jahresbeginn war die nach den USA und China drittgrößte Volkswirtschaft der Welt noch um  Prozent gewachsen Der Schwächeanfall wird auch als Rückschlag für Ministerpräsident Shinzo Abe gewertet der das Land mit einem Mix aus billigem Geld und Konjunkturprogramm aus der Flaute bringen will Allerdings wirkte sich die heutige Veröffentlichung auf die Märkten nur wenig aus da Ökonomen mit einem schwächeren zweiten Quartal gerechnet hatten'

      expect( Word.count ).to be  > 100
      expect( HC.count ).to be > 100
    end

    it "search all books with words \"Quartal\" or \"Flaute\"" do
			query = Book.query 
			query.nodes( :out, via: HAS_CONTENT, where:{ item:  ['Quartal','Flaute'] } )
			result =  query.execute
      expect( result).to be_a Array
      expect( result).to have_at_least(1).item
			result.each do |r|
				 expect(r).to be_a Word 
				 expect( r.in.out.first ).to be_a Book
      end

      queried_book =  result.first.in.out.first
      expect( queried_book ).to be_a Book
      expect( queried_book.title ).to eq 'second'

    end


    it "Subquery Initialisation" do
      # search for books that contain all given words
      word_query = -> (arg) do
				 q= Word.query  where: arg
    		 q.nodes :in, via: HAS_CONTENT		
			end

      q =  OrientSupport::OrientQuery.new
			q.expand('$z' )

      intersects = Array.new
      desired_words = [ 'Land', 'Quartal']
      desired_words.each_with_index do | word, i |
        symbol = ( i+97 ).chr   #  convert 1 -> 'a'
        q.let   symbol =>  word_query[ item: word  ]
        intersects << "$#{symbol}"
      end
      q.let  "$z = Intersect(#{intersects.join(', ')}) "
      puts "generated Query:"
      puts q.to_s
      result = q.execute
      expect( result.first ).to be_a Book
      expect( result.title ).to eq ["second"]
      puts " ------------------------------"
      puts "congratulations"
      puts "result: #{result.title} (should be second!)"
    end

  end
end  # describe
