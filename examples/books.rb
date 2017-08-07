=begin
Books Example

There are several Books. And there is a Table with Keywords. These are our Vertex-Classes

The Keywords are associated to the books, this is realized via an Edge »has_content«

This Example demonstrates how create a simple graph:

Book --> HasContent --> KeyWord

and to query it dynamically using OrientSupport::OrientQuery

REQUIREMENT: Configurate config/connectyml (admin/user+pass) 

There are 3 default search items provided. They are used if no parameter is given.
However, any parameter given is transmitted as serach-criteria, ie.
  ruby books.rb Juli August
defines two search criteria.

=end

 class BooksExample

    def initialize  rebuild: true
      if rebuild
        print "\n === REBUILD === \n"
	## check wether the database tables exist. Then delete Database-Class and preallocated ruby-Object
	database_classes = [ :book, :keyword, :has_content ]
	puts "allocated-database-classes: #{ORD.database_classes.join(" , ")} "
	if database_classes.map{|c|  ORD.database_classes.include?( c.to_s ) ? c : nil }.compact.size == 3
	print " deleting database tables \n"
	database_classes.each{ | c | d_class=  c.to_s.classify.constantize  # works if namespace=Object
				     d_class.delete_class if d_class.present? }
	else
	  puts " omitting deletion of database-classes "
	end
	print " creating Book and  Keyword as Vertex; HasContent as Edge \n"
	ORD.create_vertex_class :book, :keyword
	ORD.create_edge_class :has_content
        print "\n === PROPERTY === \n"
        Keyword.create_property  :item,  type: :string, index: :unique
        Book.create_property     :title, type: :string, index: :unique
	print "\n === Unique Edges === \n"
	HasContent.uniq_index
      end
    end


      def read_samples
        print "\n === READ SAMPLES === \n"
	## Lambda fill databasea
	# Anaylse a sentence
	# Split into words and upsert them to Word-Class.
	# The Block is only performed, if a new Word is inserted. 
	fill_database = ->(sentence, this_book ) do

	  sentence.split(' ').map do | word |
	    Keyword.upsert where: { item: word } do | new_keyword |
	          HasContent.create from: this_book, to: new_keyword 
	    end
	  end

	end
	## Lambda end
	words = 'Die Geschäfte in der Industrie im wichtigen US-Bundesstaat New York sind im August so schlecht gelaufen wie seit mehr als sechs Jahren nicht mehr Der entsprechende Empire-State-Index fiel überraschend von plus  Punkten im Juli auf minus 14,92 Zähler Dies teilte die New Yorker Notenbank Fed heute mit. Bei Werten im positiven Bereich signalisiert das Barometer ein Wachstum Ökonomen hatten eigentlich mit einem Anstieg auf 5,0 Punkte gerechnet'
	this_book =  Book.create title: 'first'
	fill_database[ words, this_book ]

	words2 = 'Das Bruttoinlandsprodukt BIP in Japan ist im zweiten Quartal mit einer aufs Jahr hochgerechneten Rate von Prozent geschrumpft Zu Jahresbeginn war die nach den USA und China drittgrößte Volkswirtschaft der Welt noch um  Prozent gewachsen Der Schwächeanfall wird auch als Rückschlag für Ministerpräsident Shinzo Abe gewertet der das Land mit einem Mix aus billigem Geld und Konjunkturprogramm aus der Flaute bringen will Allerdings wirkte sich die heutige Veröffentlichung auf die Märkten nur wenig aus da Ökonomen mit einem schwächeren zweiten Quartal gerechnet hatten'
	this_book =  Book.create title: 'second'
	fill_database[ words2, this_book ]
	puts "#{Keyword.count} keywords inserted into Database" 
      end

    def display_books_with *desired_words

      ## Each serach criteria becomes a subquery
      ## This is integrated into the main_query using 'let'.
      ## Subquery:  let ${a-y} = select expand(in('has_content')) from keyword where item = {search_word} 
      ## combine with intercect: $z =  Intercect( $a ... $y )
      ##  Main Query is just
      ##  select expand( $z )  followed by all let-statements and finalized by "intercect"
      #
      print("\n === display_books_with » #{ desired_words.join "," } « === \n")
      main_query =  OrientSupport::OrientQuery.new projection: 'expand( $z )'

      intersects = Array.new
      desired_words.each_with_index do | word, i |
	       symbol = ( i+97 ).chr   #  convert 1 -> 'a', 2 -> 'b' ...
	       subquery = OrientSupport::OrientQuery.new from: Keyword, projection: "expand(in('has_content'))"
	       subquery.where = { item: word  }
               main_query.let << { symbol =>  subquery }
	       intersects << "$#{symbol}"
      end
      main_query.let <<  "$z = Intersect(#{intersects.join(', ')}) "
      puts "generated Query:"
      puts main_query.compose
      result = Keyword.query_database  main_query, set_from: false
      puts '-' * 23 
      puts "found books: "
      puts result.map( &:title ).join("; ")
      if result.empty?
	puts " -- None -- "
	puts " try » ruby books.rb japan flaute «  for a positive search in one of the two sentences"
      else 
	puts '-_' * 23 
	puts "that's it folks"
      end 
    end
 end

if $0 == __FILE__

    search_items =  ARGV.empty? ? ['China', 'aus', 'Flaute'] : ARGV
    ARGV = [ 'd' ]  # development-mode
    @configDatabase =  'BookTest'

    require '../config/boot'

   # search_items =  ARGV.empty? ? ['China', 'aus', 'Flaute'] : ARGV
    b = BooksExample.new  rebuild:  true

#    ORD.create_vertex_class "Book", "Keyword" 
#    ORD.create_edge_class 'has_content'

    b.read_samples if Keyword.count.zero?
    b.display_books_with *search_items

end
