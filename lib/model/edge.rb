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

 Properties can be placed using the :set-directive or simply by adding key: value- parameter-pairs

 if the creation of an edged is not possible, due to constrains (uniq_index), the already
 connecting edge is returned 

 the method is thread safe, if transaction and update_cache are set to false
=end
  def create from:, to: , set: {}, transaction:  false, update_cache: false, **attributes
		return nil if from.blank? || to.blank?
		set.merge!(attributes) 
		content =  set.empty? ? "" : "content #{set.to_orient.to_json}" 
		statement = "CREATE EDGE #{ref_name} from #{from.to_or} to #{to.to_or} #{content}"
		transaction = true if [:fire, :complete, :run].include?(transaction)
		ir= db.execute( transaction: transaction, process_error: false ){ statement  }
		if update_cache
			from.reload! # get last version 
			to.is_a?(Array)? to.each( &:reload! )  : to.reload!
		end
		to.is_a?(Array)  ? ir : ir.first   # return the plain edge, if only one is created
	rescue RestClient::InternalServerError => e
		sentence=  JSON.parse( e.response)['errors'].last['content']
		if sentence =~ /found duplicated key/
			ref_rid =  sentence.split.last.expand  # return expanded rid
		else
			raise
		end
	rescue ArgumentError => e
		logger.error{ "wrong parameters  #{keyword_arguments} \n\t\t required: from: , to: , attributes:\n\t\t Edge is NOT created"}
  end

=begin
Fires a "delete edge" command to the database.


The where statement can be empty ( "" or {}"), then all edges are removed 

The rid-cache is resetted


to_do: Implement :all=> true directive
       support from: , to: syntax

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
Deletes the actual ActiveOrient::Model-Edge-Object

=end

	def delete
		db.execute{ "delete edge #{ref_name} #{rrid}" }
	end
	def to_human
		displayed_attributes =  content_attributes.reject{|k,_| [:in, :out].include?(k) }
		"<#{self.class.to_s.demodulize}[#{rrid}] -i-> ##{ attributes[:in].rid} #{displayed_attributes.to_human} -o-> #{out.rrid}>"
	end

end
