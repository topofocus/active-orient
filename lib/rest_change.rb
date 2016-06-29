module RestChange

  ############### DATABASE ####################

# Changes the working-database to {name}

  def change_database name
    @classes = []
    @database = name
  end

  ############# OBJECTS #################
=begin
  Convient update of the dataset by calling sql-patch

  Previously changed attributes are saved to the database.
  With the optional :set argument ad-hoc attributes can be defined
    obj = ActiveOrient::Model::Contracts.first
    obj.name =  'new_name'
    obj.update set: { yesterdays_event: 35 }
=end

  def update rid, attributes , version
    rid =  rid.rid if rid.is_a? ActiveOrient::Model
    attributes.merge!(set) if set.present?
    result = patch_record(rid) do
      attributes.merge({'@version' => version, '@class' => classname(o_class)})
    end
    # returns a new instance of ActiveOrient::Model and updates any reference on rid
    ActiveOrient::Model.orientdb_class(name: classname(o_class)).new(JSON.parse(result))  
  end


=begin
  update_documents classname, set: {:symbol => 'TWR'}, where: {con_id: 340}
  Replaces the symbol to TWR in each record where the con_id is 340
  Both set and where take multiple attributes
  Returns the JSON-Response.
=end

  def update_records o_class, set:, where: {}
    url = "UPDATE #{classname(o_class)} SET #{generate_sql_list(set)} #{compose_where(where)}"


    response = @res[URI.encode("/command/#{@database}/sql/" << url)].post ''
  end
  alias update_documents update_records

# Lazy Updating of the given Record.

  def patch_record rid
    logger.progname = 'RestChange#PatchRecord'
    content = yield
    if content.is_a? Hash
      begin
        @res["/document/#{@database}/#{rid}"].patch content.to_orient.to_json
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

  def alter_property o_class, property:, attribute: "DEFAULT", alteration:
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
