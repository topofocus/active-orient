module ModelRecord

  ############### RECORD FUNCTIONS ###############

  def each
    self
  end

  ############# GET #############

  def to_orient
    rid
  end

  def from_orient
    self
  end

  def classname
    self.class.to_s.split(':')[-1]
  end

  def rid
    begin
      "#{@metadata[:cluster]}:#{@metadata[:record]}"
    rescue
      "0:0"
    end
  end

  def query q
    a = ActiveOrient::Query.new
    a.queries << q
    a.execute_queries
  end

  def version
    @metadata[:version]
  end

  ########### CREATE ############

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

  ############# DELETE ###########

  def delete
    orientdb.delete_record rid
    ActiveOrient::Base.remove_rid self if is_edge? # removes the obj from the rid_store
  end

  def remove_item_from_property array, item = nil
    begin
      logger.progname = 'ActiveOrient::Model#RemoveItemFromProperty'
      execute_array = Array.new
      return unless attributes.has_key? array
      remove_execute_array = -> (it) do
        case it
        when ActiveOrient::Model
          execute_array << {type: "cmd", language: "sql", command: "update ##{rid} remove #{array} = ##{it.rid}"}
        when String
          execute_array << {type: "cmd", language: "sql", command: "update ##{rid} remove #{array} = '#{it}'"}
        when Numeric
          execute_array << {type: "cmd", language: "sql", command: "update ##{rid} remove #{array} = #{it}"}
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

  def update set: {}
    attributes.merge!(set) if set.present?
    result = orientdb.patch_record(rid) do
      attributes.merge({'@version' => @metadata[:version], '@class' => @metadata[:class]})
    end
    #     returns a new instance of ActiveOrient::Model
    reload! ActiveOrient::Model.orientdb_class(name:  classname).new(JSON.parse(result))
    # instantiate object, update rid_store and reassign to self
  end

  def reload! updated_dataset = nil
    updated_dataset = orientdb.get_record(rid) if updated_dataset.nil?
    @metadata[:version] = updated_dataset.version
    attributes = updated_dataset.attributes
    self  # return_value  (otherwise only the attributes would be returned)
  end

  ########## CHECK PROPERTY ########

  def is_edge?
    attributes.keys.include?('in') && attributes.keys.include?('out')
  end

end
