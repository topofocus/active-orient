=begin
---> The Streets Example does not work as the structure of external data used changed! 

Streets Example

We load german cities from wikipedia and parse the document for cities and countries(states).
Further we load a collection of popular streetnames from a web-side called »strassen-in-deutschland«

We define three vertices, State, City and Street.
These are filled with the data from the web-sides

Then we connect the cities through streets just by creating edges.
At last we print the connected cities.

=end
module DataImport
  def read_german_street_names
    doc = Nokogiri::HTML(open('http://www.strassen-in-deutschland.de/die-haeufigsten-strassennamen-in-deutschland.html'))
    strassen = doc.css("td[data-header='Straßenname: '] a") # identified via css-inspector in browser
    # search for the css and include only links, then display the text-part
    strassen.children.map( &:to_s )[3..-1]  # omit the first three (strassen in deutschland, straßenverzeichnis, straßen)
  end

  def read_german_cities_from_wikipedia
    # we extract <li> -elements and use the text until "("
    #doc.xpath("//li").at(80)
    # => #<Nokogiri::XML::Element:0x1ba551c name="li" children=[#<Nokogiri::XML::Element:0x1ba533c name="a" attributes=[#<Nokogiri::XML::Attr:0x1ba52d8 name="href" value="/wiki/Angerm%C3%BCnde">, #<Nokogiri::XML::Attr:0x1ba52c4 name="title" value="Angermünde">] children=[#<Nokogiri::XML::Text:0x1ba4c84 "Angermünde">]>, #<Nokogiri::XML::Text:0x1ba4ae0 " (Brandenburg)">]>

    doc = Nokogiri::HTML(open('https://en.wikipedia.org/wiki/List_of_cities_and_towns_in_Germany'))
    print doc
    doc.xpath("//li").map{|x| x.text[0 .. x.text.index('(')-2] if x.text.index('(').present? }.compact
  end

  def read_german_cities_and_states_from_wikipedia
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
      db.delete_class :State
      db.delete_class :City
      db.delete_class :Street
      db.delete_class :CONNECTS
      db.create_vertex_class :state, :city, :street
      db.create_edge_class :CONNECTS
      State.create_property( :name, type: :string, index: :unique )
      City.create_properties(  { name: { type: :string },
                                 state: { type: :link, :linked_class => 'State' } }
                             ) do
                   { citi_idx: :unique }
                               end
      Street.create_property :name , type: :string, index: :notunique
      CONNECTS.create_property :distance, type: :integer, index: :notunique
      logger.progname = "StreetsExample#Initialize"
      logger.info { "Vertex- and Edge-Classes rebuilded" }
    end
  end


  def read_from_web
    read_german_cities_and_states_from_wikipedia.each do |city,state|
      state =  State.update_or_create( where: { name: state }).first
      City.create name: city, state: "##{state.rid}"
    end
    logger.progname = "StreetsExample#ReadFromWeb"
    logger.info { "#{City.count} Cities imported from Wikipedia " }

    cities_rids =  City.all.map &:rid
    read_german_street_names.each_with_index do |street, i|
      street_record =  Street.create name: street
      count = i
      cities =  Array.new
      while  count < cities_rids.size && cities.size < 5 do
        cities << cities_rids[count]
        count =  count + i
      end
      CONNECTS.create_edge :from => street_record,  :to => cities
    end
    logger.progname = "StreetsExample#ReadFromWeb"
    logger.info { "#{CONNECTS.count} Edges between Streets and Cities created " }
  end

  def display_streets_per_state
    State.all.each do |state|
      streets= Street.all.map do |street |
        if street.connects.in.detect{|x| x.state == state }
          street.name + " connects " + street.connects.in.map( &:name ).join('; ')
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

if $0 == __FILE__

  require '../config/boot'
  require 'open-uri'
  require 'nokogiri'

  ActiveOrient::OrientDB.default_server= { user: 'root', password: 'tretretre' }
  r = ActiveOrient::OrientDB.new database: 'StreetTest'
  ActiveOrient::OrientDB.logger.level = Logger::INFO
  s= StreetExample.new r, rebuild:  true

  def to_orient
    #puts "here hash"
    substitute_hash = Hash.new
    keys.each{|k| substitute_hash[k] = self[k].to_orient}
    substitute_hash
  end


  s.read_from_web if City.count.zero?
  s.display_streets_per_state

end
