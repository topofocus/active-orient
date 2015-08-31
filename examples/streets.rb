module DataImport
  def read_german_street_names
    doc = Nokogiri::HTML(open('http://www.strassen-in-deutschland.de/die-haeufigsten-strassennamen-in-deutschland.html'))
    strassen = doc.css('#strassen-in-deutschland_main a' ) # identified via css-inspector in browser
    # search for the css and include only links, then display the text-part
    strassen.children.map( &:to_s )[3..-1]  # omit the first three (strassen in deutschland, straßenverzeichnis, straßen)
  end

  def read_german_cities_from_wikipedia 
    # we extract <li> -elements and use the text until "(" 
    #doc.xpath("//li").at(80)
    # => #<Nokogiri::XML::Element:0x1ba551c name="li" children=[#<Nokogiri::XML::Element:0x1ba533c name="a" attributes=[#<Nokogiri::XML::Attr:0x1ba52d8 name="href" value="/wiki/Angerm%C3%BCnde">, #<Nokogiri::XML::Attr:0x1ba52c4 name="title" value="Angermünde">] children=[#<Nokogiri::XML::Text:0x1ba4c84 "Angermünde">]>, #<Nokogiri::XML::Text:0x1ba4ae0 " (Brandenburg)">]> 

    doc = Nokogiri::HTML(open('https://en.wikipedia.org/wiki/List_of_cities_and_towns_in_Germany'))
    doc.xpath("//li").map{|x| x.text[0 .. x.text.index('(')-2] if x.text.index('(').present? }.compact
  end

  def read_german_cities_and_states_fom_wikipedia
    doc =
      Nokogiri::HTML(open('https://en.wikipedia.org/wiki/List_of_cities_and_towns_in_Germany'))
    doc.xpath("//li").map do |x| 
      if x.text.index('(').present? 
	[ x.text[0 .. x.text.index('(')-2] , x.text[ x.text.index('(')+1 .. x.text.index(')')-1] ]
      end
    end.compact
  end 

end # module

 class StreetExample

   include  DataImport
    def initialize db, rebuild: true
      if rebuild
	db.delete_class :state
	db.create_vertex_class :state 
	ActiveOrient::Model::State.create_property( :name, type: :string, index: :unique )
	db.delete_class :city
	db.create_vertex_class :city
	ActiveOrient::Model::City.create_properties(  { name: { type: :string },
			    state: { type: :link, :linked_class => 'State' } } 
			      ) do
				{ citi_idx: :unique } 
			      end
	db.delete_class :street
	db.create_vertex_class :street
	ActiveOrient::Model::Street.create_property( :name , type: :string, index: :notunique )
	db.delete_class :connects
	db .create_edge_class :connects
	ActiveOrient::Model::Connects.create_property( :distance, type: :integer, index: :notunique )
      end
    end


      def read_from_web
	read_german_cities_and_states_fom_wikipedia.each do |city,state| 
	  state =  State.update_or_create( where: { name: state }).first
	  city = City.create name: city, state: state.link
	end

	cities_rids =  City.all.map &:link
	read_german_street_names.each_with_index do |street, i|
	  street_record =  Street.create name: street
	  count = i
	  cities =  Array.new
	  while  count < cities_rids.size && cities.size < 5 do
	    cities << cities_rids[count] 
	    count =  count + i 
	  end
	  C.create_edge :from => street_record,  :to => cities
	end
      end
  
    def display_streets_per_state
      State.all.each do |state|
	streets= Street.all.map do |street |
	  if street.connects.in.detect{|x| x.state == state }
	    street.name + " verbindet " + street.connects.in.map( &:name ).join('; ')
	  end
	end.compact
	unless streets.empty?
	  puts "..................................."
	  puts state.name
	  puts "..................................."
	  puts streets.join("\n")
	end
      end
    end
 end


require '../config/boot'
require 'open-uri'
require 'nokogiri'

    ActiveOrient::OrientDB.default_server= { user: 'hctw', password: 'hc' }
    r = ActiveOrient::OrientDB.new database: 'StreetTest'
    s= StreetExample.new r, rebuild:  true 
      
    City = r.open_class :city
    State = r.open_class :state
    Street = r.open_class :street
    C = r.open_class :connects
    
    s.read_from_web if City.count.zero?
    s.display_streets_per_state

