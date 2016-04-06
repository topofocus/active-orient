module ModelRecord

  ############### RECORD FUNCTIONS ###############

  ############# GET #############

  def to_orient
    rid
  end

  def from_orient
    self
  end

# Returns just the name of the Class

  def classname
    self.class.to_s.split(':')[-1]
  end

# Obtain the RID of the Record

  def rid
    begin
      "#{@metadata[:cluster]}:#{@metadata[:record]}"
    rescue
      "0:0"
    end
  end

# Create a query

  def query q
    a = ActiveOrient::Query.new
    a.queries << q
    a.execute_queries
  end

# Get the version of the object

  def version
    @metadata[:version]
  end

  ########### CREATE ############

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

  def add_item_to_property array, item = nil
    begin
      logger.progname = 'ActiveOrient::Model#AddItemToProperty'
      execute_array = Array.new
      self.attributes[array] = Array.new unless attributes[array].present?
      add_2_execute_array = -> (it) do
        case it
        when ActiveOrient::Model
          execute_array << {type: "cmd", language: "sql", command: "update ##{rid} add #{array} = ##{it.rid}"}
        when String
          execute_array << {type: "cmd", language: "sql", command: "update ##{rid} add #{array} = '#{it}'"}
        when Numeric
          execute_array << {type: "cmd", language: "sql", command: "update ##{rid} add #{array} = #{it}"}
        else
          logger.error{"Only Basic Formats supported. Cannot Serialize #{it.class} this way"}
          logger.error{"Try to load the array from the DB, modify it and update the hole record"}
        end
      end

      if block_given?
        items =  yield
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
      reload!

    rescue RestClient::InternalServerError => e
      logger.error{"Duplicate found in #{array}"}
      logger.error{e.inspect}
    end
  end
  alias add_items_to_property add_item_to_property
  ## historical aliases
  alias update_linkset  add_item_to_property
  alias update_embedded  add_item_to_property

  ############# DELETE ###########

#  Removes the Model-Instance from the database

  def delete
    orientdb.delete_record rid
    ActiveOrient::Base.remove_rid self if is_edge? # removes the obj from the rid_store
  end

# Remove item from property

  def remove_item_from_property array, item = nil
    begin
      logger.progname = 'ActiveOrient::Model#RemoveItemFromProperty'
      execute_array = Array.new
      return unless attributes.has_key? array
      remove_execute_array = -> (it) do
        case it
        when ActiveOrient::Model
          execute_array << {type: "cmd", language: "sql", command: "UPDATE ##{rid} REMOVE #{array} = ##{it.rid}"}
        when String
          execute_array << {type: "cmd", language: "sql", command: "UPDATE ##{rid} REMOVE #{array} = '#{it}'"}
        when Numeric
          execute_array << {type: "cmd", language: "sql", command: "UPDATE ##{rid} REMOVE #{array} = #{it}"}
        else
          logger.error{"Only Basic Formats supported. Cannot Serialize #{it.class} this way"}
          logger.error{"Try to load the array from the DB, modify it and update the hole record"}
        end
      end

      if block_given?
        items =  yield
        items.each{|x|
          remove_execute_array[x];
          self.attributes[array].delete(x)}
      elsif item.present?
        remove_execute_array[item]
        a = attributes
        a.delete item
        self.attributes[array].delete(item)
      end
      orientdb.execute do
        execute_array
      end
      reload!
    rescue RestClient::InternalServerError => e
      logger.error{"Could not remove item in #{array}"}
      logger.error{e.inspect}
    end
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
    reload! ActiveOrient::Model.orientdb_class(name:  classname).new(JSON.parse(result))
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
