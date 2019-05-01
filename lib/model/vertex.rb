class V   < ActiveOrient::Model
  ## link to the library-class
 
=begin
specialized creation of vertices, overloads model#create
=end
	def self.create( **keyword_arguments )
		new_vert = db.create_vertex self, attributes: keyword_arguments
		new_vert =  new_vert.pop if new_vert.is_a?( Array) && new_vert.size == 1
		if new_vert.nil?
			logger.error('Vertex'){ "Table #{ref_name} ->>  create failed:  #{keyword_arguments.inspect}" } 
		elsif block_given?
			yield new_vert
		else
			new_vert # returns the created vertex (or an array of created vertices)
		end
  end
=begin
Vertex#delete fires a "delete vertex" command to the database.
The where statement can be empty ( "" or {}"), then all vertices are removed 

The rid-cache is reseted, too
=end
  def self.delete where: ""
    db.execute { "delete vertex #{ref_name} #{db.compose_where(where)}" }
    reset_rid_store
  end

#Present Classes (Hierarchy) 
#---
#- - E
#  - - - e1
#      - - e2
#        - e3
#- - V
#  - - - v1
#      - - v2

#v.to_human
# => "<V2[#36:0]: in: {E2=>1}, node : 4>" 
#
# v.detect_edges( :in, 2).to_human
# => ["<E2: in : #<V2:0x0000000002e66228>, out : #<V1:0x0000000002ed0060>>"] 
# v.detect_edges( :in, E1).to_human
# => ["<E2: in : #<V2:0x0000000002e66228>, out : #<V1:0x0000000002ed0060>>"] 
# v.detect_edges( :in, /e/).to_human
# => ["<E2: in : #<V2:0x0000000002e66228>, out : #<V1:0x0000000002ed0060>>"] 
#
  def detect_edges kind = :in,  edge_name = nil # :nodoc:
    ## returns a list of inherented classes
    get_superclass = ->(e) do
			if [ "e", "E", E ].include?(e)
				"E"
			else
      n = orientdb.get_db_superclass(e)
      n =='E' ? e : e + ',' + get_superclass[n]
			end
    end

		result = if edge_name.nil?
							 expression = case kind
														when :in
															/^in/ 
														when :out
															/^out/
														else
															/^in|^out/ 
														end

							 the_edges = attributes.keys.find_all{ |x| x =~  expression }
							 the_edges.map{|x| attributes[x]}.flatten.map &:expand
						 else
							 e_name = if edge_name.is_a?(Regexp)
													edge_name
												else
													Regexp.new  case  edge_name
																			when  Class
																				edge_name.ref_name 
																			when String
																				edge_name
																			when Symbol
																				edge_name.to_s 
																			when Numeric
																				edge_name.to_i.to_s
																			end
												 end
								the_edges = @metadata[:edges][kind].find_all do |y| 
									get_superclass[y].split(',').detect{|x| x =~ e_name } 
								end
								puts "the edges: #{the_edges.inspect}"

								the_edges.map do | the_edge|
									candidate= attributes["#{kind.to_s}_#{the_edge}".to_sym]
									candidate.present?  ? candidate.map( &:expand ).first  : nil 
								end
							end
		OrientSupport::Array.new work_on: self, work_with: result
	end

=begin
List edges

1. call without any parameter:  list all edges present
2. call with :in or :out     :  list any incoming or outgoing edges
3. call with /regexp/, Class, symbol or string: restrict to this edges, including inheritence
   If a pattern, symbol string or class is provided, the default is to list outgoing edges

  :call-seq:
  edges in_or_out, pattern 
=end
	def edges *args
		if args.empty?
			kind = :both
		else
			kind =   [:in, :out, :both, :all].detect{|x|  args.include? x }
			if kind.present?
				args =  args -[ kind ]
			else
				kind = :out
			end
		detect_edges  kind, args.first

		end

	end

	# Lists all connected Vertices
	#
	# The Edge-classes can be specified via Classname or a regular expression. 
	#
	# If a regular expression is used, the database-names are searched.
	def nodes in_or_out = :out, via:  nil, where: nil, expand:  false
		if via.present?
			edges = detect_edges( in_or_out, via )
			detected_nodes = edges.map do |e|
				q = OrientSupport::OrientQuery.new 
				q.nodes in_or_out, via: e.class, where: where, expand: expand
				query( q )
			end.first
		end
	end


	# Returns a collection of all vertices passed during the traversal 
	#
	# fires a query
	#   
	#    select  from  ( traverse  outE('#{via}').in  from #{vertex}  while $depth <= #{depth}   ) 
	#            where $depth >= #{start_at} 
	#
	# If » excecute: false « is specified, the traverse-statement is returned (as Orient-Query object)
	def traverse in_or_out = :out, via: nil,  depth: 1, execute: true, start_at: 1

			edges = detect_edges( in_or_out, via )
			the_query = OrientSupport::OrientQuery.new kind: 'traverse' 
			the_query.while( "$depth <= #{depth} ")  unless depth <=0
			the_query.from   self
			edges.each{ |ec| the_query.nodes in_or_out, via: ec.class, expand: false }
			outer_query = OrientSupport::OrientQuery.new from: the_query, where: "$depth >= #{start_at}"
			if execute 
				query( outer_query ) 
				else
		#			the_query.from self  #  complete the query by assigning self 
					the_query            #  returns the OrientQuery  -traverse object
				end
		end



=begin
Assigns another Vertex via an EdgeClass. If specified, puts attributes on the edge.

Wrapper for 
  Edge.create in: self, out: a_vertex, attributes: { some_attributes on the edge }

Reloads the vertex after the assignment and returns it.


Example


=end

  def assign vertex: , via: E , attributes: {}

    via.create from: self, to: vertex, attributes: attributes
    
		reload!
  end





=begin
»in« and »out« provide the main access to edges.
»in» is a reserved keyword. Therfore its only an alias to `in_e`.

If called without a parameter, all connected edges  are retrieved.

If called with a string, symbol or class, the edge-class is resolved and even inherented 
edges are retrieved.

=end

  def in_e edge_name= nil
    detect_edges :in, edge_name
  end
	
	alias_method :in, :in_e

  def out edge_name =  nil
    detect_edges :out, edge_name
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
  


To fetch the associated records use the expand method
  
  ActiveOrient::Model.autoload_object Industry.first.edges( :in).first	
  # or
  Industry.autoload_object Industry.first.edges( /sector/ ).first
   => #<SectorClassification:0x00000002daad20 @metadata={"type"=>"d", "class"=>"sector_classification", "version"=>1, "fieldTypes"=>"out=x,in=x", "cluster"=>61, "record"=>0},(...)

=end
  
#  def edges kind=:all  # :all, :in, :out 
#    expression = case kind
#		 when :all
#		   /^in|^out/ 
#		 when :in
#		   /^in/ 
#		 when :out
#		   /^out/ 
#		 when String
#		   /#{kind}/
#		 when Regexp
#		   kind
#		 when Class
#			 /#{kind.ref_name}/
#		 else
#		   return  []
#		 end
#
#    edges = attributes.keys.find_all{ |x| x =~  expression }
#    edges.map{|x| attributes[x]}.flatten
#  end

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

 # def remove
 #   db.delete_vertex self
#	end
=begin
Human readable represantation of Vertices

Format: < Classname : Edges, Attributes >
=end
	def to_human
		count_and_display_classes = ->(array){array.map(&:class)&.group_by(&:itself)&.transform_values(&:count)} 

		the_ins =    count_and_display_classes[ in_e] 
		the_outs =  count_and_display_classes[ out]

		in_and_out = in_edges.empty? ? "" : "in: #{the_ins}, " 
		in_and_out += out_edges.empty? ? "" : "out: #{the_outs}, " 
 

		#Default presentation of ActiveOrient::Model-Objects

		"<#{self.class.to_s.demodulize}[#{rid}]: " + in_and_out  + content_attributes.map do |attr, value|
			v= case value
				 when ActiveOrient::Model
					 "< #{self.class.to_s.demodulize} : #{value.rid} >"
				 when OrientSupport::Array
					 value.to_s
#					 value.rrid #.to_human #.map(&:to_human).join("::")
				 else
					 value.from_orient
				 end
			"%s : %s" % [ attr, v]  unless v.nil?
		end.compact.sort.join(', ') + ">".gsub('"' , ' ')
	end
end
