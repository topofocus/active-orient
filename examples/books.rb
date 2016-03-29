=begin
Books Example

There are several Books. And there is a Table with Keywords. These are our Vertex-Classes

The Keywords are associated to the books, this is realized via an Edge »has_content«

This Example demonstrates how to build a query by using OrientSupport::OrientQuery
=end
 class BooksExample

    def initialize db, rebuild: true
      if rebuild
      db.delete_class :book
      db.delete_class :keyword
      db.delete_class :has_content
      db.create_vertex_class :book
      db.create_vertex_class :keyword
      db.create_edge_class :has_content
      ActiveOrient::Model::Keyword.create_property( :item , type: :string, index: :unique )
      ActiveOrient::Model::Book.create_property( :title, type: :string, index: :unique )
      end
    end


      def read_samples
	fill_database = ->(sentence, this_book ) do
	  sentence.split(' ').each do |x|
	    this_word = Keyword.update_or_create where: { item: x }
	    this_edge = HC.create_edge from: this_book, to: this_word  if this_word.present?
	  end
	end
	words = 'Die Geschäfte in der Industrie im wichtigen US-Bundesstaat New York sind im August so schlecht gelaufen wie seit mehr als sechs Jahren nicht mehr Der entsprechende Empire-State-Index fiel überraschend von plus  Punkten im Juli auf minus 14,92 Zähler Dies teilte die New Yorker Notenbank Fed heut mit Bei Werten im positiven Bereich signalisiert das Barometer ein Wachstum Ökonomen hatten eigentlich mit einem Anstieg auf 5,0 Punkte gerechnet'
	this_book =  Book.create title: 'first'
	fill_database[ words, this_book ]

	words2 = 'Das Bruttoinlandsprodukt BIP in Japan ist im zweiten Quartal mit einer aufs Jahr hochgerechneten Rate von Prozent geschrumpft Zu Jahresbeginn war die nach den USA und China drittgrößte Volkswirtschaft der Welt noch um  Prozent gewachsen Der Schwächeanfall wird auch als Rückschlag für Ministerpräsident Shinzo Abe gewertet der das Land mit einem Mix aus billigem Geld und Konjunkturprogramm aus der Flaute bringen will Allerdings wirkte sich die heutige Veröffentlichung auf die Märkten nur wenig aus da Ökonomen mit einem schwächeren zweiten Quartal gerechnet hatten'
	this_book =  Book.create title: 'second'
	fill_database[ words2, this_book ]
      end

    def display_books_with *desired_words
      query = OrientSupport::OrientQuery.new  from: Keyword, projection: "expand(in('HasContent'))"
      q =  OrientSupport::OrientQuery.new projection: 'expand( $z )'

      intersects = Array.new
      desired_words.each_with_index do | word, i |
	       symbol = ( i+97 ).chr   #  convert 1 -> 'a'
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

    ActiveOrient::OrientDB.default_server = { user: 'root', password: 'tretretre' }
    ActiveOrient::OrientDB.logger.level = Logger::WARN
    r = ActiveOrient::OrientDB.new database: 'BookTest'
    b= BooksExample.new r, rebuild:  true

    Book = r.open_class :book
    Keyword = r.open_class :keyword
    HC = r.open_class :has_content

    b.read_samples if Keyword.count.zero?
    b.display_books_with 'Land', 'Quartal'
end
