class V   < ActiveOrient::Model
  ## link to the library-class

=begin
retrieves  connected edges

The basic ussage is to fetch all/ incomming/ outgoing edges

  Model-Instance.edges :in # :out | :all

One can filter specific edges by providing parts of the edge-name

  Model-Instance.edges 'in_sector'
  Model-Instance.edges /sector/

returns an array of rid's 

example:

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

  def remove
    db.delete_vertex self
  end

end
