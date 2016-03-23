module RestRead

  ############# DATABASE #############

  def get_databases
    JSON.parse(@res["/listDatabases"].get.body)['databases']
  end

  def get_database_classes include_system_classes: false, requery: false
    requery = true if @classes.empty?
    if requery
  	  get_class_hierarchy requery: true
  	  system_classes = ["OFunction", "OIdentity", "ORIDs", "ORestricted", "ORole", "OSchedule", "OTriggered", "OUser", "_studio"]
  	  all_classes = get_classes('name').map(&:values).flatten
  	  @classes = include_system_classes ? all_classes : all_classes - system_classes
    end
    @classes
  end
  alias inspect_classes get_database_classes
  alias database_classes get_database_classes

  def get_classes *attributes
    begin
      logger.progname = 'RestRead#GetClasses'
    	response =  @res[database_uri].get
    	if response.code == 200
    	  classes = JSON.parse(response.body)['classes']
    	  unless attributes.empty?
    	    classes.map{|y| y.select{|v,_| attributes.include?(v)}}
    	  else
    	    classes
    	  end
      else
        []
      end
    rescue Exception => e
      logger.error{e.message}
    end
  end

  def get_class_hierarchy base_class: '', requery: false
    @all_classes = get_classes('name', 'superClass') if requery || @all_classes.blank?
    def fv s   # :nodoc:
  	  @all_classes.find_all{|x| x['superClass']== s}.map{|v| v['name']}
    end

    def fx v # :nodoc:
  	  fv(v).map{|x| ar = fx(x); ar.empty? ? x : [x, ar]}
    end
    fx base_class
  end
  alias class_hierarchy get_class_hierarchy

  ############### CLASS ################

  def classname name_or_class
    name= if name_or_class.is_a? Class
      name_or_class.to_s.split('::').last
    elsif name_or_class.is_a? ActiveOrient::Model
      name_or_class.classname
    else
      name_or_class.to_s
    end
    if database_classes.include?(name)
      name
    else
      logger.progname = 'OrientDB#ClassName'
      logger.info{"Classname #{name} not present in active Database"}
      nil
    end
  end

  def get_class_properties o_class   #  :nodoc:
    JSON.parse(@res[class_uri{classname(o_class)}].get)
  end

  def print_class_properties o_class
    puts "Detected Properties for class #{classname(o_class)}"
    rp = get_class_properties o_class
    n = rp['name']
    if rp['properties'].nil?
      puts "No property available"
    else
      puts rp['properties'].map{|x| [n+'.'+x['name'], x['type'],x['linkedClass']].compact.join(' -> ')}.join("\n")
    end
  end

  ############## OBJECT #################

  def get_record rid
    begin
      logger.progname = 'RestRead#GetRecord'
      rid = rid[1..rid.length] if rid[0]=='#'
      response = @res[document_uri{rid}].get
      raw_data = JSON.parse(response.body) #.merge( "#no_links" => "#no_links" )
      ActiveOrient::Model.orientdb_class(name: raw_data['@class']).new raw_data
    rescue RestClient::InternalServerError => e
      if e.http_body.split(':').last =~ /was not found|does not exist in database/
        nil
      else
        logger.error "Something went wrong"
        logger.error e.http_body.inspect
        raise
      end
    rescue RestClient::ResourceNotFound => e
      logger.error "Not data found"
      logger.error e.message
    end
  end
  alias get_document get_record

  def get_records raw: false, query: nil, **args
    query = OrientSupport::OrientQuery.new(args) if query.nil?
    begin
      logger.progname = 'RestRead#GetRecords'
  	  url = query_sql_uri + query.compose(destination: :rest) + "/#{query.get_limit}"

  	  response = @res[URI.encode(url)].get
  	  r = JSON.parse(response.body)['result'].map do |record|
  # parameter: raw is set --> don't initilize a model object
      	if raw
      	  record
    # query returns an anonymus class: Use the provided Block or the Dummy-Model MyQuery
      	elsif record['@class'].blank?
      	  block_given? ? yield.new(record) : ActiveOrient::Model::MyQuery.new(record)
      	else
      	  ActiveOrient::Model.orientdb_class(name: record['@class']).new record
      	end
      end
      return r

    rescue RestClient::InternalServerError => e
  	  response = JSON.parse(e.response)['errors'].pop
  	  logger.error{response['content'].split(':').last}
    rescue URI::InvalidURIError => e
  	  logger.error{"Invalid URI detected"}
  	  logger.error query.to_s
  	  logger.info{"Trying batch processing"}
  	  sql_cmd = -> (command){{type: "cmd", language: "sql", command: command}}
  	  response = execute{[sql_cmd[query.to_s]]}
  	  logger.info{"Success: to avoid this delay use ActiveOrient::Model#query_database instead"}
      response
    end
  end
  alias get_documents get_records

end
