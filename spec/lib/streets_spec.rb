#### the streets example is brocken, because the webside  "strassen-in-deutschland" changed its design  
#### the fetch from wikipedia works as planed
require 'spec_helper'
require 'open-uri'
require 'nokogiri'
require 'rest_helper'

=begin
You need to include nikogiri and open-uri in the gem-file  to run this example


We load german cities from wikipedia and parse the document for cities and countries(states)
and use a collection of popular streetnames from a web-side called »strassen-in-deutschland«

We define three vertices, State, City and Street.
These are filled with the data from the web-sides

Then we connect the cities through streets just by creating edges.
At last we print the connected cities.

The expected result:
Erlenstraße verbindet Bärnau; Delitzsch; Fröndenberg; Heidenau; Königsee-Rottenbach
Rheinstraße verbindet Barntrup; Demmin; Fürstenberg/Havel; Heiligenhafen; Königs Wusterhausen
Rotdornweg verbindet Barsinghausen; Detmold; Fürth; Heimsheim; Korntal-Münchingen
Robert-Bosch-Straße verbindet Barth; Dieburg; Füssen; Helmbrechts; Krakow am See
Lindenallee verbindet Baruth/Mark; Diepholz; Gaildorf; Hemmingen; Krempe
Luisenstraße verbindet Bassum; Dietenheim; Garching bei München; Hennigsdorf; Kroppenstedt
Max-Planck-Straße verbindet Battenberg; Dietzenbach; Gartz; Herbrechtingen; Künzelsau

=end

describe OrientSupport::OrientQuery do
  pending:  "The webside has changed"
  def read_german_street_names
    doc = Nokogiri::HTML(open('http://www.strassen-in-deutschland.de/die-haeufigsten-strassennamen-in-deutschland.html'))
    strassen = doc.css('#strassen-in-deutschland_main a' ) # identified via css-inspector in browser
    # search for the css and include only links, then display the text-part
    puts "STRASSEN"
    puts strassen.inspect
    strassen.children.map( &:to_s )[3..-1]  # omit the first three (strassen in deutschland, straßenverzeichnis, straßen)
  end

  def read_german_cities_from_wikipedia
    # we extract <li> -elements and use the text until "("
    #doc.xpath("//li").at(80)
    # => #<Nokogiri::XML::Element:0x1ba551c name="li" children=[#<Nokogiri::XML::Element:0x1ba533c name="a" attributes=[#<Nokogiri::XML::Attr:0x1ba52d8 name="href" value="/wiki/Angerm%C3%BCnde">, #<Nokogiri::XML::Attr:0x1ba52c4 name="title" value="Angermünde">] children=[#<Nokogiri::XML::Text:0x1ba4c84 "Angermünde">]>, #<Nokogiri::XML::Text:0x1ba4ae0 " (Brandenburg)">]>

    doc = Nokogiri::HTML(open('https://en.wikipedia.org/wiki/List_of_cities_and_towns_in_Germany'))
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

  before( :all ) do
    reset_database
    ORD.create_vertex_class :state
    State.create_property( :name, type: :string, index: :unique )
    ORD.create_vertex_class :city
    City.create_properties(  { name: { type: :string },
    state: { type: :link, :linked_class => 'State' } }
    ) do
      { citi_idx: :unique }
    end
    ORD.create_vertex_class :street
    Street.create_property( :name , type: :string, index: :notunique )
    C = ORD.create_edge_class :connects
    C.create_property( :distance, type: :integer, index: :notunique )


  end
  it "check structure" do
    expect( ORD.class_hierarchy( base_class: 'V').sort ).to eq ["city","state","street"]
    expect( ORD.class_hierarchy( base_class: 'E') ).to eq ["connects"]
  end



  it "put new_test-content"  do
    read_german_cities_and_states_from_wikipedia.each do |city,state|
      state =  State.upsert where: { name: state }
      city = City.create name: city, state: state.rid
    end

    expect( State.count ).to eq 118
    expect( City.count ).to eq 2067
  end

  it "connect cities through streets" do
    streets =  read_german_street_names
    expect( streets ).to be_a Array
    expect( streets ).to have( 200 ).items
  end

  it "assign streets to cities" do
    cities_rids =  City.all.map &:rid

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

  #       it "printout the connected cities" do
  #	  Street.all.each do | street |
  #	   puts street.name + " verbindet " + street.connects.in.map( &:name ).join('; ')
  #
  #	 end
  #
  #       end

  it "select only cities from a selected state " do
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


end  # describe
