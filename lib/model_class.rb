module ModelClass

  ########### CLASS FUNCTIONS ######### SELF ####


  ######## INITIALIZE A RECORD FROM A CLASS ########

  def orientdb_class name:
    begin
      klass = Class.new(self)
      name = name.to_s
      if self.send :const_defined?, name
        retrieved_class = self.send :const_get, name
      else
        new_class = self.send :const_set, name, klass
        new_class.orientdb = orientdb
        new_class # return_value
      end
    rescue NameError => e
      logger.error "ActiveOrient::Model::Class name cannot be initialized"
      puts "class: #{klass.inspect}"
      puts "name: #{name.inspect}"
      puts e.inspect
    end
  end

  ########## CREATE ############

  def create_property field, **keyword_arguments, &b
    orientdb.create_property self, field, **keyword_arguments, &b
  end

  def create_properties argument_hash, &b
    orientdb.create_properties self, argument_hash, &b
  end

  def create_record attributes: {}
    orientdb.create_record self, attributes: attributes
  end
  alias create_document create_record

  def update_or_create_records set: {}, where: {}, **args, &b
    orientdb.update_or_create_records self, set: set, where: where, **args, &b
  end
  alias update_or_create_documents update_or_create_records
  alias create_or_update_document update_or_create_records

  def create properties = {}
    self.update_or_create_records set: properties
  end

  def create_edge **keyword_arguments
    new_edge = orientdb.create_edge self, **keyword_arguments
    [:from,:to].each{|y|
      keyword_arguments[y].is_a?(Array) ? keyword_arguments[y].each( &:reload! ) : keyword_arguments[y].reload!
    }
    new_edge
  end

  def create_link name, classname
    orientdb.create_property self, name, type: 'link', linked_class: classname
  end

  def create_linkset name, classname
    orientdb.create_property self, name, type: 'linkset', linked_class: classname
  end

  ########## GET ###############

  # def autoload_object rid
  #   if rid.rid?
  #     @@rid_store[rid].presence || orientdb.get_record(rid)
  #   else
  #     logger.progname = "ActiveOrient::Model#AutoloadObject"
  #     logger.info{"#{rid} is not a valid rid."}
  #   end
  # end

  def classname
    orientdb.classname self
  end

  def get rid
    orientdb.get_record rid
  end

  def all
    orientdb.get_records from: self
  end

  def first where: {}
    orientdb.get_records(from: self, where: where, limit: 1).pop
  end

  def last where: {}
    orientdb.get_records(from: self, where: where, order: {"@rid" => 'desc'}, limit: 1).pop
  end

  def get_class_properties
    orientdb.get_class_properties self
  end

  def print_class_properties
    orientdb.print_class_properties self
  end

  def get_records **args
    orientdb.get_records(from: self, **args){self}
  end
  alias get_documents get_records

  def where attributes =  {}
    q = OrientSupport::OrientQuery.new from: self, where: attributes
    query_database q
  end

  def count **args
    orientdb.count_records from: self, **args
  end

  def get_properties
      object =  orientdb.get_class_properties self
      {:properties => object['properties'], :indexes => object['indexes']}
  end

  def superClass
    logger.progname = 'ActiveOrient::Model#Superclass'
    r = orientdb.get_classes( 'name', 'superClass').detect{|x|
      x["name"].downcase ==  new.class.to_s.downcase.split(':')[-1].to_s
    }['superClass']
    if r.empty?
      logger.info{"#{self} does not have any superclass. Probably it is a Document"}
    end
    return r
  end

  def query_database query, set_from: true
    query.from self if set_from && query.is_a?(OrientSupport::OrientQuery) && query.from.nil?
    sql_cmd = -> (command) {{ type: "cmd", language: "sql", command: command }}
    orientdb.execute(self.to_s.split(':')[-1]) do
      [sql_cmd[query.to_s]]
    end
  end

  ########### DELETE ###############

  def delete_property field
    orientdb.delete_property self, field
  end

  def delete_record *rid
    rid.each do |mm|
      orientdb.delete_record rid
    end
  end
  alias delete_document delete_record

  def delete_records where: {}
    orientdb.delete_records self, where: where
  end
  alias delete_documents delete_records

  ########### UPDATE #############

  def update_records set:, where:
    orientdb.update_records self, set: set, where: where
  end
  alias update_documents update_records

end
