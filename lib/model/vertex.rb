class V   < ActiveOrient::Model
  ## link to the library-class
 
=begin
specialized creation of vertices, overloads model#create
=end
	def self.create set: {},  **attributes
	
		new_vert = db.execute( transaction: false, tolerated_error_code: /found duplicated key/) do
			"CREATE VERTEX #{ref_name} CONTENT #{set.merge(attributes).to_orient.to_json}"
		end

		new_vert =  new_vert.pop if new_vert.is_a?( Array) && new_vert.size == 1
		if new_vert.nil?
			logger.error('Vertex'){ "Table #{ref_name} ->>  create failed:  #{set.merge(attributes).inspect}" } 
		elsif block_given?
			yield new_vert
		else
			new_vert # returns the created vertex (or an array of created vertices)
		end
  end
=begin
Vertex#delete fires a "delete vertex" command to the database.
The where statement can be empty ( "" or {}"), then all vertices are removed 

The rid-cache is reset, too
=end
  def self.delete where: {} , **args
		if args[:all] == true 
			where = {}
		else
			where.merge!(args) if where.is_a?(Hash)
			return 0 if where.empty?
		end
		# query returns [{count => n }]
		count= db.execute { "delete vertex #{ref_name} #{db.compose_where(where)}" }.first[:count] rescue 0
    reset_rid_store
		count #  return count of affected records
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
		detect_edges  :both
		else
			kind =   [:in, :out, :both, :all].detect{|x|  args.include? x }
			if kind.present?
				args =  args - [ kind ]
			else
				kind = :both
			end
		detect_edges  kind, args.first

		end
	end

	# Lists all connected Vertices
	#
	# The Edge-classes can be specified via Classname or a regular expression. 
	#
	# If a regular expression is used, the database-names are searched and inheritance is supported.
	#
	def nodes in_or_out = :out, via:  nil, where: nil, expand:  false
			edges =  detect_edges( in_or_out, via, expand: false )
			return [] if edges.empty?
			q = OrientSupport::OrientQuery.new 
			edges = nil if via.nil?
			q.nodes in_or_out, via:  edges , where: where, expand: expand
			detected_nodes=	query( q ){| record | record.is_a?(Hash)?  record.values.first : record  }
	end


	# Returns a collection of all vertices passed during the traversal 
	#
	# Includes the start_vertex (start_at =0 by default)
	# 
	# If the vector should not include the start_vertex, call with `start_at:1` and increase the depth by 1
	#
	# fires a query
	#   
	#    select  from  ( traverse  outE('}#{via}').in  from #{vertex}  while $depth < #{depth}   ) 
	#            where $depth >= #{start_at} 
	#
	# If » excecute: false « is specified, the traverse-statement is returned (as Orient-Query object)
	def traverse in_or_out = :out, via: nil,  depth: 1, execute: true, start_at: 0, where: nil

			edges = detect_edges( in_or_out, via, expand: false)
			the_query = OrientSupport::OrientQuery.new kind: 'traverse' 
			the_query.where where if where.present?
			the_query.while "$depth < #{depth} " unless depth <=0
			the_query.from   self
			edges.each{ |ec| the_query.nodes in_or_out, via: ec, expand: false }
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

returns the assigned vertex, thus enableing to chain vertices through

    Vertex.assign() via: E , vertex: VertexClass.create()).assign( via: E, ... )
or
	  (1..100).each{|n| vertex = vertex.assign(via: E2, vertext: V2.create(item: n))}
=end

  def assign vertex: , via: E , attributes: {}

    via.create from: self, to: vertex, set: attributes
    
		vertex
  end

## optimisation
	#
	#         "LET $a = CREATE VERTEX VTest SET name = 'John';" +
 #                      "CREATE EDGE ETest FROM :ParentRID TO $a;" +
 #                       "RETURN $a;", params)




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

  Model-Instance.edges :in  :out | :both, :all

One can filter specific edges by providing parts of the edge-name

  Model-Instance.edges /sector/, :in
  Model-Instance.edges :out, /sector/
  Model-Instance.edges  /sector/
  Model-Instance.edges  :in



The method returns an array of  expandes edges.

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

protected
#Present Classes (Hierarchy) 
#---
#- - E
#  - - - e1
#      - - e2
#        - e3
#- - V
#  - - - v1
#      - - v2

# v.to_human
# => "<V2[#36:0]: in: {E2=>1}, node : 4>" 
#
# v.detect_edges( :in, 2).to_human
# => ["<E2: in : #<V2:0x0000000002e66228>, out : #<V1:0x0000000002ed0060>>"] 
# v.detect_edges( :in, E1).to_human
# => ["<E2: in : #<V2:0x0000000002e66228>, out : #<V1:0x0000000002ed0060>>"] 
# v.detect_edges( :in, /e/).to_human
# => ["<E2: in : #<V2:0x0000000002e66228>, out : #<V1:0x0000000002ed0060>>"] 
#
	def detect_edges kind = :in,  edge_name = nil, expand: true  #:nodoc:
		## returns a list of inherented classes
		get_superclass = ->(e) do
			if ["", "e", "E", E ].include?(e)
				"E"
			else
				n = orientdb.get_db_superclass(e)
				n =='E' ? e : e + ',' + get_superclass[n]
			end
		end
		expression = case kind
								 when :in
									 /^in_/ 
								 when :out
									 /^out_/
								 else
									 /^in_|^out_/ 
								 end

		  extract_database_class = ->(c){ y =  c.to_s.gsub(expression, ''); y.empty? ? "E": y   }
		# get a set of available edge-names 
		# in_{abc} and out_{abc}
		# with "out_" and "in_" as placeholder for E itself
	  # populate result in case no further action is required
		result = the_edges = attributes.keys.find_all{ |x|  x =~  expression }
		if edge_name.present?
			# if a class is provided, match for the ref_name only
			if edge_name.is_a?(Class) 
				result = [ the_edges.detect{ |x| edge_name.ref_name == extract_database_class[x] } ]
			else
				e_name = if edge_name.is_a?(Regexp)
									 edge_name
								 else
									 Regexp.new  case  edge_name
						#				 when  Class
						#					 edge_name.ref_name 
										 when String
											 edge_name
										 when Symbol
											 edge_name.to_s 
										 when Numeric
											 edge_name.to_i.to_s
									 end
						end	
				result = the_edges.find_all do |x|
					 get_superclass[extract_database_class[x] ].split(',').detect{|x| x =~ e_name } 
				end

				# this is the same as find_all
				#result = the_edges.map do |x|
			#		x if get_superclass[extract_database_class[x] ].split(',').detect{|x| x =~ e_name } 
			#	end.compact
			end
		end
	# if expand = false , return the orientdb-databasename of the edges
	#  this is used by  Vertex#nodes 
	#  it avoids communications with the database prior to submitting the nodes-query
	# if expand = true (default) load the edges instead
		if expand
			OrientSupport::Array.new work_on: self, 
					work_with: 	result.compact.map{|x| attributes[x]}.map(&:expand).orient_flatten
		else
			result.map{|x|	extract_database_class[x] }
		end
	end
end
