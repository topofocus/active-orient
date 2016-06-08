=begin
Books Example

There are several Books. And there is a Table with Keywords. These are our Vertex-Classes

The Keywords are associated to the books, this is realized via an Edge »has_content«

This Example demonstrates how to build a query by using OrientSupport::OrientQuery

REQUIREMENT: Configurate config/connectyml (admin/user+pass) 

There are 3 default serach items provided. They are used if no parameter is given.
However, any parameter given is transmitted as serach-criteria, ie.
  ruby books.rb Juli August
defines two serach criteria.

=end
 class BooksExample

    def initialize  rebuild: true
      if rebuild
	database_classes = [ :Book, :Keyword, :HAS_CONTENT ]
        print "\n === REBUILD === \n"
	print " deleting database tables \n"
        database_classes.each{ | c | ORD.delete_class c }
	print " creating Book and  Keyword as Vertex; HAS_CONTENT as Edge \n"
	ORD.create_classes( { V: [:Book, :Keyword], E: :HAS_CONTENT })
        print("\n === PROPERTY === \n")
        ActiveOrient::Model::Keyword.create_property(:item, type: :string, index: :unique)
        ActiveOrient::Model::Book.create_property(:title, type: :string, index: :unique)
      end
    end


      def read_samples
        print("\n === READ SAMPLES === \n")
	## Lambda fill database
	fill_database = ->(sentence, this_book ) do
	  ORD.create_edge HC do
	    sentence.split(' ').map do |x|
	      this_word = Keyword.update_or_create where: { item: x }
	      { :from => this_book, :to => this_word } if this_word.present?
	    end.compact
	  end

	end
	## Lanbda end
	words = 'Die Geschäfte in der Industrie im wichtigen US-Bundesstaat New York sind im August so schlecht gelaufen wie seit mehr als sechs Jahren nicht mehr Der entsprechende Empire-State-Index fiel überraschend von plus  Punkten im Juli auf minus 14,92 Zähler Dies teilte die New Yorker Notenbank Fed heute mit. Bei Werten im positiven Bereich signalisiert das Barometer ein Wachstum Ökonomen hatten eigentlich mit einem Anstieg auf 5,0 Punkte gerechnet'
	this_book =  Book.create title: 'first'
	fill_database[ words, this_book ]

	words2 = 'Das Bruttoinlandsprodukt BIP in Japan ist im zweiten Quartal mit einer aufs Jahr hochgerechneten Rate von Prozent geschrumpft Zu Jahresbeginn war die nach den USA und China drittgrößte Volkswirtschaft der Welt noch um  Prozent gewachsen Der Schwächeanfall wird auch als Rückschlag für Ministerpräsident Shinzo Abe gewertet der das Land mit einem Mix aus billigem Geld und Konjunkturprogramm aus der Flaute bringen will Allerdings wirkte sich die heutige Veröffentlichung auf die Märkten nur wenig aus da Ökonomen mit einem schwächeren zweiten Quartal gerechnet hatten'
	this_book =  Book.create title: 'second'
	fill_database[ words2, this_book ]
      end

    def display_books_with *desired_words
      print("\n === display_books_with #{ desired_words.join "," } === \n")
      q =  OrientSupport::OrientQuery.new projection: 'expand( $z )'

      intersects = Array.new
      desired_words.each_with_index do | word, i |
	puts "word: #{word}"
	       symbol = ( i+97 ).chr   #  convert 1 -> 'a'
	       query = OrientSupport::OrientQuery.new from: Keyword, projection: "expand(in('HAS_CONTENT'))"
	       query.where = { item: word  }
               q.let << { symbol =>  query }
	       intersects << "$#{symbol}"
      end
      q.let <<  "$z = Intersect(#{intersects.join(', ')}) "
      puts "generated Query:"
      puts q.to_s
      result = Keyword.query_database  q, set_from: false
      puts "found books: "
      puts result.map( &:title ).join("; ")
      puts " -- None -- " if result.empty?
    end
 end

if $0 == __FILE__

require '../config/boot'
    search_items =  ARGV.empty? ? ['Land', 'aus', 'Quartal'] : ARGV
    ActiveOrient::OrientDB.logger.level = Logger::WARN
    ORD = ActiveOrient::OrientDB.new database: 'BookTest'
    b = BooksExample.new  rebuild:  true

    Book, Keyword = *ORD.create_classes([ "Book", "Keyword" ]){ "V" }
    HC = ORD.create_edge_class 'HAS_CONTENT'

    b.read_samples if Keyword.count.zero?
    b.display_books_with *search_items

end
