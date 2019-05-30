module ModelRecord
  ############### RECORD FUNCTIONS ###############
 
	def to_s
		to_human
	end
  ############# GET #############

  def from_orient # :nodoc:
    self
  end

  # Returns just the name of the Class

  def self.classname  # :nodoc:
    self.class.to_s.split(':')[-1]
  end
=begin
flag whether a property exists on the Record-level
=end
  def has_property? property
    attributes.keys.include? property.to_sym
  end

	def properties 
		{ "@type" => "d", "@class" => self.metadata[:class] }.merge attributes
	end

  #
  # Obtain the RID of the Record  (format: *00:00*)
  #

  def rid
    begin
      "#{@metadata[:cluster]}:#{@metadata[:record]}"
    rescue
      "0:0"
    end
  end
=begin
The extended representation of RID (format: *#00:00* )
=end
  def rrid
    "#" + rid
  end
  alias to_orient rrid

  def to_or
    rid.rid? ?  rrid : "{ #{embedded} }"
  end
=begin
Query uses the current model-record  as origin of the query.

It sends the OrientSupport::OrientQuery directly to the database and returns an 
ActiveOrient::Model-Object or an Array of Model-Objects as result. 

*Usage:* Query the Database by traversing through edges and vertices starting at a known location

=end

  def query query, delete_cash: false
    
    query.from  rrid if query.is_a?( OrientSupport::OrientQuery) && query.from.nil?
		ActiveOrient::Base.remove_rid( self ) if delete_cash
    result = orientdb.execute{ query.to_s }
		result = if block_given?
							 result.is_a?(Array)? result.map{|x| yield x } : yield(result)
						 else
							 result
						 end
    if result.is_a? Array  
      OrientSupport::Array.new work_on: self, work_with: result.orient_flatten
    else
      result
    end  # return value
   end

=begin
Fires a »where-Query» to the database starting with the current model-record.

Attributes:
* a string ( obj.find "in().out().some_attribute >3" )
* a hash   ( obj.find 'some_embedded_obj.name' => 'test' )
* an array 

Returns the result-set, ie. a Query-Object which contains links to the addressed records.

=end
  def find attributes =  {}
    q = OrientSupport::OrientQuery.new from: self, where: attributes
    query q
  end
 
  # Get the version of the object
  def version  # :nodoc:
    if document.present?
      document.version
    else
      @metadata[:version]
    end
  end
private
  def version= version  # :nodoc:
    @metadata[:version] = version
  end

  def increment_version # :nodoc: 
    @metadata[:version] += 1
  end

public

  ############# DELETE ###########

# Removes the Model-Instance from the database.
#
# It is overloaded in Vertex and Edge.

def delete 
  orientdb.delete_record  self 
end


########### UPDATE ############

=begin
Convient update of the dataset 

Previously changed attributes are saved to the database.

Using the optional :set argument ad-hoc attributes can be defined
    V.create_class :contracts
    obj = Contracts.first
    obj.name =  'new_name'
    obj.update set: { yesterdays_event: 35 }
updates both, the »name« and the »yesterdays_event«-properties

_note:_ The keyword »set« is optional, thus
    obj.update  yesterdays_event: 35 
is identical to the update statement above
=end

  def update set:{}, add: nil, to: nil, **args
    logger.progname = 'ActiveOrient::Model#Update'

		if block_given?			# calling vs. a block is used internally
			# to remove an Item from lists and sets call update(remove: true){ query }
			set_or_remove =  args[:remove].present? ? "remove" : "set"
			#transfer_content from: 	 
			updated_record = 	query( "update #{rrid} #{set_or_remove} #{ yield }  return after @this", delete_cash: true )&.first
			transfer_content from: updated_record  if updated_record.present?
		else
			set.merge! args
			#	set.merge updated_at: DateTime.now
			if rid.rid?
				db.update( self, set, version )
				reload!
			else  # new record
				@attributes.merge! set
				save
			end
		end
  end

# mocking active record  
  def update_attribute the_attribute, the_value # :nodoc:
    update( delete_cash: true ){ " #{the_attribute} = #{the_value.to_or} " }
  end

  def update_attributes **args    # :nodoc:
    update  args
  end

  ########## SAVE   ############
 
=begin
Saves the record  by calling update  or  creating the record

  ORD.create_class :a
  a =  A.new
  a.test = 'test'
  a.save

  a =  A.first
  a.test = 'test'
  a.save

=end
	def save
		transfer_content from:  if rid.rid?
															db.update self, attributes, version
														else
															db.create_record  self, attributes: attributes, cache: false 
														end
		ActiveOrient::Base.store_rid self
	end

  def reload! 
    transfer_content from: db.get_record(rid) 
		self
  end


  ########## CHECK PROPERTY ########

=begin
  An Edge is defined
  * when inherented from the superclass »E» (formal definition)
  * if it has an in- and an out property

  Actually we just check the second term as we trust the constuctor to work properly
=end

  def is_edge? # :nodoc:
    attributes.keys.include?('in') && attributes.keys.include?('out')
  end

=begin
How to handle other calls

* if  attribute is specified, display it
* if  attribute= is provided, assign to the known property or create a new one

Example:
  ORD.create_class :a
  a = A.new
  a.test= 'test'  # <--- attribute: 'test=', argument: 'test'
  a.test	  # <--- attribute: 'test' --> fetch attributes[:test]

Assignments are performed only in ruby-space.

Automatic database-updates are deactivated for now
=end
  def method_missing *args
    # if the first entry of the parameter-array is a known attribute
    # proceed with the assignment
    if args.size == 1
       attributes[args.first.to_sym]  # return the attribute-value
    elsif args[0][-1] == "=" 
      if args.size == 2
#	if rid.rid? 
#	  update set:{ args[0][0..-2] => args.last }
#	else
	  self.attributes[ args[0][0..-2]  ] = args.last
#	end
      else
	  self.attributes[ args[0][0..-2]  ] = args[1 .. -1]
#	update set: {args[0][0..-2] => args[1 .. -1] } if rid.rid?
      end
    else
      raise NameError, "Unknown method call #{args.first.to_s}", caller
    end
  end
#end

#protected
  def transfer_content  from:
		# »from« can be either 
		# a model record (in case of  create-record, get_record) or
		# a hash containing {"@type"=>"d", "@rid"=>"#xx:yy", "@version"=>n, "@class"=>'a_classname'} 
		# and a list of updated properties (in case of db.update). Then  update the version field and the 
		# attributes.
			if from.is_a? ActiveOrient::Model
       @metadata = from.metadata
       self.attributes =  from.attributes
			else
				self.version =  from['@version']
				# throw from["@..."] away and convert keys to symbols, merge that into attributes
				@attributes.merge! Hash[ from.delete_if{|k,_| k =~ /^@/}.map{|k,v| [k.to_sym, v.from_orient]}]
			end
			self  # return the modified object
  end
end
