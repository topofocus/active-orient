module ModelRecord
  ############### RECORD FUNCTIONS ###############

  ############# GET #############

  def from_orient
    self
  end

  # Returns just the name of the Class

  def self.classname
    self.class.to_s.split(':')[-1]
  end

  # Obtain the RID of the Record

  def rid
    begin
      "#{@metadata[:cluster]}:#{@metadata[:record]}"
    rescue
      "#0:0"
    end
  end
=begin
The extended representation of rid
=end
  def rrid
    "#" + rid
  end
  alias to_orient rrid
=begin
Query uses a single model-objec as origin for the query
It sends the OrientSuppor::OrientQuery direct to the database and returns a 
ActiveOrient::Model-Object  or an Array of Model-Objects as result. 

=end

  def query query
    sql_cmd = -> (command) {{ type: "cmd", language: "sql", command: command }}
    orientdb.execute do
      sql_cmd[query.to_s]
    end
  end

  # Get the version of the object

  def version
    @metadata[:version]
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
  to_do: use "<<" to add the item to the property
=end

  def method_missing *args
    #puts "MethodMissing TEST, #{args} "
    if args.is_a? Array
      if attributes.keys.include? args.first.to_s
	if args.size == 1
	  attributes[args.first]
	else
	  if args[1] == "<<" or args[1] == "|="
	    update_item_property "ADD", "#{args[0][0..-2]}", args[2]
	  elsif args[0][-1] == "="
	    update_item_property "SET", "#{args[0][0..-2]}", args[1]
	  elsif args[1] == ">>"
	    update_item_property "REMOVE", "#{args[0][0..-2]}", args[2]
	  end
	end
      else
	raise NameError
      end
    end
  rescue NameError => e
    logger.progname = 'ActiveOrient::Model#MethodMissing'
    if args.size == 1
      logger.error{"Unknown Attribute: #{args.first} "}
    else
      logger.error{"Unknown Method: #{args.map{|x| x.to_s}.join(" / ")} "}
    end
    raise
    #      print e.backtrace.join("\n")
  end


  def update_item_property method, array, item = nil, &b
    begin
      logger.progname = 'ActiveOrient::Model#UpdateItemToProperty'
      execute_array = Array.new
      self.attributes[array] = Array.new unless attributes[array].present?

      add_2_execute_array = -> (it) do
        case it
        when ActiveOrient::Model
          updating = "##{it.rid}"
        when String
          updating = "'#{it}'"
        when Numeric
          updating = "#{it}"
        when Array
          updating = it.map{|x| "##{x.rid}"} if it[0].is_a? ActiveOrient::Model
        end
        unless updating.nil?
          command = "UPDATE ##{rid} #{method} #{array} = #{updating}"
          command.gsub!(/\"/,"") if updating.is_a? Array
          execute_array << {type: "cmd", language: "sql", command: command}
        else
          logger.error{"Only Basic Formats supported. Cannot Serialize #{it.class} this way"}
          logger.error{"Try to load the array from the DB, modify it and update the hole record"}
        end
      end

      items = yield if block_given?

      if items.present?
	#puts "items present: #{items}"
        items.each{|x|
          add_2_execute_array[x];
          self.attributes[array] << x}
      elsif item.present?
        add_2_execute_array[item]
        self.attributes[array] << item
      end
      orientdb.execute do
        execute_array
      end
    rescue RestClient::InternalServerError => e
      logger.error{"Duplicate found in #{array}"}
      logger.error{e.inspect}
    end
  end
=begin
Add Items to a linked or embedded class
Parameter
  array : the name of the property to work on
  item :  what to add (optional)
  block:  has to provide an array of elements to add to the property

  example:
   add_item_to_property :second_list do
       (0 .. 9).map do | s |
               ActiveOrient::Model::SecondList.create label: s
       end  
   end
   adds 10 Elements to the property.
=end

  def add_item_to_property array, item = nil, &b
    items = block_given? ? yield : nil
    update_item_property "ADD", array, item, &b
  end
  alias add_items_to_property add_item_to_property
  ## historical aliases
  alias update_linkset  add_item_to_property
  alias update_embedded  add_item_to_property

  def set_item_to_property array, item = nil, &b
    update_item_property "SET", array, item, &b
  end

  def remove_item_from_property array, item = nil, &b
    update_item_property "REMOVE", array, item, &b
    if block_given?
        items =  yield
        items.each{|x| self.attributes[array].delete(x)}
    elsif item.present?
        a = attributes
        a.delete item
        self.attributes[array].delete(item)
      end
  end

  ############# DELETE ###########

#  Removes the Model-Instance from the database

def delete
  orientdb.delete_record self
  ActiveOrient::Base.remove_rid self if is_edge? # removes the obj from the rid_store
end

########### UPDATE ############

=begin
  Convient update of the dataset by calling sql-patch
  The attributes are saved to the database.
  With the optional :set argument ad-hoc attributes can be defined
    obj = ActiveOrient::Model::Contracts.first
    obj.name =  'new_name'
    obj.update set: { yesterdays_event: 35 }
=end

  def update set: {}
    attributes.merge!(set) if set.present?
    result = orientdb.patch_record(rid) do
      attributes.merge({'@version' => @metadata[:version], '@class' => @metadata[:class]})
    end
    # returns a new instance of ActiveOrient::Model
cl = orientdb.classname self.class

    reload! ActiveOrient::Model.orientdb_class(name:  cl).new(JSON.parse(result))
    # instantiate object, update rid_store and reassign to self
  end

=begin
  Overwrite the attributes with Database-Contents (or attributes provided by the updated_dataset.model-instance)
=end

  def reload! updated_dataset = nil
    updated_dataset = orientdb.get_record(rid) if updated_dataset.nil?
    @metadata[:version] = updated_dataset.version
    attributes = updated_dataset.attributes
    self  # return_value  (otherwise only the attributes would be returned)
  end

  ########## CHECK PROPERTY ########

=begin
  An Edge is defined
  * when inherented from the superclass »E» (formal definition)
  * if it has an in- and an out property

  Actually we just check the second term as we trust the constuctor to work properly
=end

  def is_edge?
    attributes.keys.include?('in') && attributes.keys.include?('out')
  end

end
