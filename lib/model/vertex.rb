class V   < ActiveOrient::Model
  ## link to the library-class
 
=begin
Vertex#delete fires a "delete vertex" command to the database.
The where statement can be empty ( "" or {}"), then all vertices are removed 

The rid-cache is reseted, too
=end
  def self.delete where: ""
    db.execute { "delete vertex #{ref_name} #{db.compose_where(where)}" }
    reset_rid_store
  end

  def detect_inherent_edge kind,  edge_name  # :nodoc:
    ## returns a list of inherented classes
    get_superclass = ->(e) do
      n = ORD.get_db_superclass(e)
      n =='E' ? e : e + ',' + get_superclass[n]
    end
    if edge_name.present?
    e_name =  edge_name.is_a?( Class) ? edge_name.ref_name : edge_name.to_s
    the_edge = @metadata[:edges][kind].detect{|y| get_superclass[y].split(',').detect{|x| x == edge_name } }
    
    candidate= attributes["#{kind.to_s}_#{the_edge}"]
    candidate.present?  ? candidate.map( &:from_orient ) : []
    else
      edges(kind).map &:from_orient
    end
  end
=begin
»in« and »out« provide the main access to edges.

If called without a parameter, all edges connected are displayed.

If called with a string, symbol or class, the edge-class is resolved and even inherented 
edges are retrieved.

=end

  def in edge_name= nil
    detect_inherent_edge :in, edge_name
  end
	
  def out edge_name =  nil
    detect_inherent_edge :out, edge_name
  end
=begin
Retrieves  connected edges

The basic usage is to fetch all/ incomming/ outgoing edges

  Model-Instance.edges :in # :out | :all

One can filter specific edges by providing parts of the edge-name

  Model-Instance.edges 'in_sector'
  Model-Instance.edges /sector/

The method returns an array of rid's.

Example:

  Industry.first.attributes.keys
   => ["in_sector_classification", "k", "name", "created_at", "updated_at"]  # edge--> in ...

  Industry.first.edges :out
    => []

  Industry.first.edges :in
  => ["#61:0", "#61:9", "#61:21", "#61:33", "#61:39", "#61:93", "#61:120", "#61:150", "#61:240", "#61:252", "#61:264", "#61:279", "#61:303", "#61:339" ...]
  


To fetch the associated records use the ActiveOrient::Model.autoload_object method
  
  ActiveOrient::Model.autoload_object Industry.first.edges( :in).first	
  # or
  Industry.autoload_object Industry.first.edges( /sector/ ).first
   => #<SectorClassification:0x00000002daad20 @metadata={"type"=>"d", "class"=>"sector_classification", "version"=>1, "fieldTypes"=>"out=x,in=x", "cluster"=>61, "record"=>0},(...)

=end
  
  def edges kind=:all  # :all, :in, :out 
    expression = case kind
		 when :all
		   /^in|^out/ 
		 when :in
		   /^in/ 
		 when :out
		   /^out/ 
		 when String
		   /#{kind}/
		 when Regexp
		   kind
		 else
		   return  []
		 end

    edges = attributes.keys.find_all{ |x| x =~  expression }
    edges.map{|x| attributes[x]}.flatten
  end

=begin
»in_edges« and »out_edges« are shortcuts to »edges :in« and »edges :out«

Its easy to expand the result:
  tg.out( :ohlc).out.out_edges
   => [["#102:11032", "#121:0"]] 
   tg.out( :ohlc).out.out_edges.from_orient
   => [[#<TG::GRID_OF:0x00000002620e38

this displays the out-edges correctly

whereas
tg.out( :ohlc).out.edges( :out)
 => [["#101:11032", "#102:11032", "#94:10653", "#121:0"]] 

returns all edges. The parameter (:out) is not recognized, because out is already a nested array.

this
  tg.out( :ohlc).first.out.edges( :out)
is a walkaround, but using in_- and out_edges is more  elegant.
=end
  def in_edges
    edges :in
  end
  def out_edges
    edges :out
  end

  def remove
    db.delete_vertex self
  end

end
