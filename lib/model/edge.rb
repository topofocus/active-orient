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

=end
  def create from:, to: , attributes: {}, transaction:  false
		return nil if from.blank? || to.blank?
		statement = "CREATE EDGE #{ref_name} from #{from.to_or} to #{to.to_or}"
		transaction = true if [:fire, :complete, :run].include?(transaction)
		ir= db.execute( transaction: transaction ){ statement  }
		from.reload! # get last version 
		to.is_a?(Array)? to.each( &:reload! )  : to.reload!
		ir
		
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

	def to_human
		displayed_attributes =  content_attributes.reject{|k,_| [:in, :out].include?(k) }
		"<#{self.class.to_s.demodulize}[#{rrid}] -i-> ##{ attributes[:in].rid} #{displayed_attributes.to_human} -o-> #{out.rrid}>"
	end

end
