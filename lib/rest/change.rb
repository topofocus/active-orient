module RestChange

  ############### DATABASE ####################

# Changes the working-database to {name}

  def change_database name
    @classes = []
    @database = name
    ActiveOrient.database = name
  end

  ############# OBJECTS #################

=begin
  Convient update of the dataset by calling sql-patch

  The argument record can be specified as ActiveOrient::Model-instance or as rid-string( #0:0 )
  
  called from ModelRecord#update

  if the update was successful, the updated data are returned as Hash.
=end

  def update record, attributes , version=0   
    r = ActiveOrient::Model.autoload_object record.rid 
    return(false) unless r.is_a?(ActiveOrient::Model)
    version = r.version if version.zero?
    result = patch_record(r.rid) do
      attributes.merge({'@version' => version, '@class' => r.class.ref_name })
    end
    # returns a new instance of ActiveOrient::Model and updates any reference on rid
    # It's assumed, that the version 
    # if the patch is not successfull no string is returned and thus no record is fetched
    # JSON.parse(result) if result.is_a?(String)
    if result.is_a?(String)
       JSON.parse(result) # return value
    else
      logger.error{ "REST::Update was not successfull" }
      logger.error{ "DB-Record #{rrid} is NOT updated "}
       nil   # returnvalue
    end
    #   ActiveOrient::Model.orientdb_class(name: r.class.ref_name).new(JSON.parse(result))  if result.is_a?(String)
  end


=begin
Example:
  ORD.update_documents classname, set: {:symbol => 'TWR'}, where: {con_id: 340}

Replaces the symbol to TWR in each record where the con_id is 340

Both set and where take multiple attributes

Returns the JSON-Response.

# todo: clear the rid-cache 
=end

  def update_records o_class, set:{}, where: {}, remove: nil
    logger.progname = 'RestChange#UpdateRecords'
    url = if set.present?
      "UPDATE #{classname(o_class)} SET #{generate_sql_list(set)} #{compose_where(where)}"
    elsif remove.present?
      "UPDATE #{classname(o_class)} remove #{remove} #{compose_where(where)}"
    end
    r = @res[URI.encode("/command/#{ActiveOrient.database}/sql/" << url)].post ''
    count_of_updated_records = (JSON.parse( r))['result'].first['value']
     ## remove all records of the class from cache
    ActiveOrient::Base.display_rid.delete_if{|x,y| y.is_a? o_class } if count_of_updated_records > 0 && o_class.is_a?(Class)
    count_of_updated_records # return_value
    rescue Exception => e
         logger.error{e.message}
     nil

    
  end

# Lazy Updating of the given Record.

  def patch_record rid	    # :nodoc:   (used by #update )
    logger.progname = 'RestChange#PatchRecord'
    content = yield
    if content.is_a? Hash
      begin
        @res["/document/#{ActiveOrient.database}/#{rid}"].patch content.to_orient.to_json
      rescue Exception => e
        logger.error{e.message}
      end
    else
  	  logger.error{"FAILED: The Block must provide an Hash with properties to be updated"}
    end
  end
  alias patch_document patch_record


  #### EXPERIMENTAL ##########

=begin
  Used to add restriction or other properties to the Property of a Class.
  See http://orientdb.com/docs/2.1/SQL-Alter-Property.html
=end

  def alter_property o_class, property:, attribute: "DEFAULT", alteration:  # :nodoc: because untested
    logger.progname = 'RestChange#AlterProperty'
    begin
      attribute.to_s! unless attribute.is_a? String
      attribute.capitalize_first_letter
      case attribute
      when "LINKEDCLASS", "LINKEDTYPE", "NAME", "REGEX", "TYPE", "REGEX", "COLLATE", "CUSTOM"
        unless alteration.is_a? String
          logger.error{"#{alteration} should be a String."}
          return 0
        end
      when "MIN", "MAX"
        unless alteration.is_a? Integer
          logger.error{"#{alteration} should be an Integer."}
          return 0
        end
      when "MANDATORY", "NOTNULL", "READONLY"
        unless alteration.is_a? TrueClass or alteration.is_a? FalseClass
          logger.error{"#{alteration} should be an Integer."}
          return 0
        end
      when "DEFAULT"
      else
        logger.error{"Wrong attribute."}
        return 0
      end

      name_class = classname(o_class)
      execute name_class, transaction: false do # To execute commands
        [{ type: "cmd",
          language: 'sql',
          command: "ALTER PROPERTY #{name_class}.#{property} #{attribute} #{alteration}"}]
      end
    rescue Exception => e
      logger.error{e.message}
    end
  end


end
