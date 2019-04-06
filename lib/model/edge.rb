class E  < ActiveOrient::Model
  ## class methods
  class << self
=begin
Establish constrains on Edges

After applying this method Edges are uniq!

Creates individual indices for child-classes if applied to the class itself.
=end
  def  uniq_index
    create_property  :in,  type: :link, linked_class: :V
    create_property  :out, type: :link, linked_class: :V
    create_index "#{ref_name}_idx", on: [ :in, :out ]
  end

=begin
 Instantiate a new Edge between two Vertices 

  The parameters »from« _or_ »to« can take a list of model-records. Then subsequent edges are created.

  :call-seq:
  create( from:, to:,  attributes:{} )
=end
  def create( **keyword_arguments )
    new_edge = db.create_edge self, **keyword_arguments
    new_edge =  new_edge.pop if new_edge.is_a?( Array) && new_edge.size == 1

    new_edge # returns the created edge (or an array of created edges)

	rescue ArgumentError => e
		logger.error{ "wrong parameters  #{keyword_arguments} \n\t\t required: from: , to: , attributes:\n\t\t Edge is NOT created"}
  end

=begin
Fires a "delete edge" command to the database.

The where statement can be empty ( "" or {}"), then all edges are removed 

The rid-cache is resetted

  :call-seq:
  delete where: 
=end
  def delete where:  

    db.execute { "delete edge #{ref_name} #{db.compose_where(where)}" }
    reset_rid_store

  end
  
	end   # class methods

	###  instance methods  ###

=begin
Removes the actual ActiveOrient::Model-Edge-Object

This method overloads the unspecified ActiveOrient::Model#remove-Method
=end
  def remove
  # remove works on record-level
    db.delete_edge self
  end
end
