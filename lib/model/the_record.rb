module ModelRecord
  ############### RECORD FUNCTIONS ###############

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
    attributes.keys.include? property.to_s
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

  def to_or #:nodoc:
    rrid
  end
=begin
Query uses the current model-record  as origin of the query.

It sends the OrientSupport::OrientQuery directly to the database and returns an 
ActiveOrient::Model-Object or an Array of Model-Objects as result. 

*Usage:* Query the Database by traversing through edges and vertices starting at a known location

=end

  def query query
    
    sql_cmd = -> (command) {{ type: "cmd", language: "sql", command: command }}
    result = orientdb.execute do
      sql_cmd[query.to_s]
    end
    if result.is_a? Array
      OrientSupport::Array.new work_on: self, work_with: result
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

  def version= version  # :nodoc:
    @metadata[:version] = version
  end

  def increment_version # :nodoc: 
    @metadata[:version] += 1
  end
  ########### UPDATE PROPERTY ############

=begin
  Convient method for populating embedded- or linkset-properties
  In both cases an array/a collection is stored in the database.
  Its called via
    model.add_item_to_property(linkset- or embedded property, Object_to_be_linked_to\)
  or
    mode.add_items_to_property( linkset- or embedded property ) do
      Array_of_Objects_to_be_linked_to
      #(actually, the objects must inherent from ActiveOrient::Model, Numeric, String)
    end
  
  The method is aliased by "<<" i.e
    model.array << new_item
=end

  def update_item_property method, array, item = nil, &ba # :nodoc:
 #   begin
      logger.progname = 'ActiveOrient::Model#UpdateItemToProperty'
      self.attributes[array] = Array.new unless attributes[array].present?

      items = if item.present?
		item.is_a?(Array)? item : [item]  
	      elsif block_given?
		yield
	      end
      db.manipulate_relation self, method, array, items
    end
=begin
Add Items to a linked or embedded class

Parameter:

[array] the name of the property to work on
[item ]  what to add (optional)
[block]  has to provide an array of elements to add to the property

Example: add 10 elements to the property

   add_item_to_property :second_list do
       (0 .. 9).map do | s |
               SecondList.create label: s
       end  
   end


The method returns the model record itself. Thus nested initialisations are possible:
   
       ORD.create_classes([:base, :first_list, :second_list ]){ "V" }
       ORD.create_property :base, :first_list,  type: :linklist, linkedClass: :first_list
       ORD.create_property :base, :label, index: :unique
       ORD.create_property :first_list,  :second_list , type: :linklist, linkedClass: :second_list
       ORD.create_vertex_class :log
       (0 .. 9).each do | b |
          base= Base.create label: b, first_list: []
          base.add_item_to_property :first_list do
             (0 .. 9).map do | f |
                first = FirstList.create label: f, second_list: []
	         base.add_item_to_property :first_list , first
	         first.add_item_to_property :second_list do
	           (0 .. 9).map{| s |  SecondList.create label: s }
	         end    # add item  second_list
	      end      # 0..9 -> f
	   end        # add item  first_list
	end        # 0..9 -> b


Record#AddItemToProperty shines with its feature to specify records to insert in a block.

If only single Items are to  be inserted, use
  model_record.linklist << item 

=end

  def add_item_to_property array, *item
       item =  yield if block_given?
	if attributes.keys.include? array.to_s
	  item.each{|x| self.attributes[array].push x.to_orient }
	  update
	else
	  update array=> item 
	end	
#  rescue NoMethodError
    #undefined method `<<' for nil:NilClass

  end


  def set_item_to_property array, *item  # :nodoc:
      update  array.to_s => item
  end

  def remove_position_from_property array, *pos  # :nodoc:
      if attributes[array].is_a? Array
        pos.each{|x| self.attributes[array].delete_at( x )}
	update
      end
  end
  def remove_item_from_property array, *item 
      if attributes[array].is_a? Array
        item.each{|x| self.attributes[array].delete( x.to_orient )}
	update
      else
	logger.error  "Wrong attribute: #{attributes[array]}"
      end
  end

  ############# DELETE ###########

# Removes the Model-Instance from the database.
#
# It is overloaded in Vertex and Edge.

def remove 
  orientdb.delete_record self
  ActiveOrient::Base.remove_rid self ##if is_edge? # removes the obj from the rid_store
end

alias delete remove

########### UPDATE ############

=begin
Convient update of the dataset by calling sql-patch

Previously changed attributes are saved to the database.

Using the optional :set argument ad-hoc attributes can be defined

    obj = ActiveOrient::Model::Contracts.first
    obj.name =  'new_name'
    obj.update set: { yesterdays_event: 35 }
updates both, the »name« and the »yesterdays_event«-properties

_note:_ The keyword »set« is optional, thus
    obj.update  yesterdays_event: 35 
is identical
=end

  def update set: {}, **args
    logger.progname = 'ActiveOrient::Model#Update'
    self.attributes.merge!(set) if set.present?
    self.attributes.merge!(args) if args.present?
    self.attributes['updated_at'] =  DateTime.now
    if rid.rid?
      updated_data= db.update self, attributes, @metadata[:version]
      # if the updated dataset changed, drop the changes made siently
#      puts "updated dataset 
      if updated_data.is_a? Hash
	self.version =  updated_data["@version"]
	self # return value
      else
	logger.error{ "UPDATE:  #{rrid} "}
	logger.error{ "Version Conflict: reloading database values, local updates are lost!"}
	logger.error{ "The Args: #{attributes.inspect} "}
	logger.error{ "The Object: #{updated_data.inspect} "}
	reload!
      end
    else
      save 
    end

  end

# mocking active record  
  def update_attribute the_attribute, the_value # :nodoc:
    update set: {the_attribute => the_value }
    super the_attribute, the_value
  end

  def update_attributes **args    # :nodoc:
    update set: args
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
  if rid.rid?
    update
  else
    the_record =   db.create_record  self, attributes: attributes, cache: false 
    transfer_content from: the_record
    ActiveOrient::Base.store_rid self
  end
end

=begin
  Overwrite the attributes with Database-Contents 

  If a record is provided as argument, those attributes and metadata are copied to the object
=end

  def reload! updated_dataset = nil
    updated_dataset = db.get_record(rid) if updated_dataset.nil?
    transfer_content from: updated_dataset
  self
  end


  def transfer_content  from:
       @metadata = from.metadata
       @attributes =  from.attributes
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
    puts "MM: #{args.inspect}"
    if args.size == 1
       attributes[args.first.to_s]  # return the attribute-value
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
      logger.error{" Unknown method-call: #{args.first.to_s} "}
      raise NameError
    end
  end
#end


end
