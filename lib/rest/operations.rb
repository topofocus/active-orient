module RestOperations

# Execute a predefined Function

#  untested
  def call_function *args  
  #     puts "uri:#{function_uri { args.join('/') } }"
    begin
      term = args.join('/')
      @res["/function/#{@database}/#{term}"].post ''
    rescue RestClient::InternalServerError => e
  	  puts  JSON.parse(e.http_body)
    end
  end

# Used to count the Records in relation of the arguments
#
# Overwritten by Model#Count
  def count **args
    logger.progname = 'RestOperations#CountRecords'
    query = OrientSupport::OrientQuery.new args
    query.projection << 'COUNT (*)'
    result = get_records raw: true, query: query
    result.first['COUNT'] rescue  0  # return_value
  end


  def manipulate_relation record,  method, array, items  # :nodoc: #
    execute_array = Array.new
    method =  method.to_s.upcase

    add_2_execute_array = -> (it) do
      command = "UPDATE ##{record.rid} #{method} #{array} = #{it.to_orient } " #updating}"
      command.gsub!(/\"/,"") if it.is_a? Array
      #puts "COMMAND:: #{command}"
      execute_array << {type: "cmd", language: "sql", command: command}
    end

    items.each{|x| add_2_execute_array[x] }
    r= execute{ execute_array }

    if r.present?
      case  method
      when 'ADD'
	items.each{|x| record.attributes[array] << x}
      when 'REMOVE'
	items.map{|x| record.attributes[array].delete x.is_a?(ActiveOrient::Model) ? x.rid : x}
      else
      end
      record.increment_version
    end
  end
=begin
Executes a list of commands and returns the result-array (if present)

(External use)

If soley a string is provided in the block, a minimal database-console is realized.
i.e.

  ORD.execute{ 'select from #25:0' }

(Internal Use)

Structure of the provided block:
  [{type: "cmd", language: "sql",  command: "create class Person extends V"}, (...)]
--
  It was first used by ActiveOrient::Query.execute_queries
  Later I (topofocus) discovered that some Queries are not interpretated correctly by #GetRecords but are submitted without Error via batch-processing.
  For instance, this valid query
   select expand(first_list[5].second_list[9]) from base where label = 9
  can only be submitted via batch
++
Parameters:
 
 transaction:  true|false   Perform the batch as transaction
 tolerate_error_code: /a regular expression/   
 Statements to execute are provided via block
 These statements are translated to json and transmitted to the database. Example:

    	{ type: "cmd",
          language: 'sql',
          command: "CREATE EDGE #{classname(o_class)} FROM #{from.to_orient} TO #{to.to_orient}"}

Multible statements are transmitted at once if the Block provides an Array of statements.


=end

  def execute transaction: true, tolerated_error_code: nil, process_error: true, raw: nil # Set up for classes
    batch = {transaction: transaction, operations: yield}
    logger.progname= "Execute"
    unless batch[:operations].blank?
      batch[:operations] = {:type=>"cmd", :language=>"sql", :command=> batch[:operations]} if batch[:operations].is_a? String
      batch[:operations] = [batch[:operations]] unless batch[:operations].is_a? Array
      batch[:operations].compact!
      # transaction is true only for multible statements
#      batch[:transaction] = transaction & batch[:operations].size >1
      begin
	logger.debug{ batch[:operations].map{|y|y[:command]}.join("; ") } 
        response = @res["/batch/#{ActiveOrient.database}"].post batch.to_json
      rescue RestClient::BadRequest => f
	# extract the misspelled query in logfile and abort
	sentence=  JSON.parse( f.response)['errors'].last['content']
	logger.fatal{ " BadRequest --> #{sentence.split("\n")[1]} " }
	puts "Query not recognized"
	puts sentence
	raise
      rescue RestClient::InternalServerError => e
        logger.progname = 'RestOperations#Execute'
	sentence=  JSON.parse( e.response)['errors'].last['content']
	if tolerated_error_code.present? &&  e.response =~ tolerated_error_code
	  logger.info{ "tolerated_error::#{e.message}"}
	else
	  if process_error
#	    puts batch.to_json
#	  logger.error{e.response}
	  logger.error{sentence}
	  logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
#	  logger.error{e.message.to_s}
	  else 
	    raise
	  end
	end 
      end
      if response.present? && response.code == 200
        if response.body['result'].present?
          result= JSON.parse(response.body)['result']
	  return result if raw.present?
          result.map do |x|
            if x.is_a? Hash
              if x.has_key?('@class')
                ActiveOrient::Model.orientdb_class(name: x['@class'], superclass: :find_ME ).new x
              elsif x.has_key?('value')
                x['value']
              else   # create a dummy class and fill with attributes from result-set
                ActiveOrient::Model.orientdb_class(name: 'query' ).new x
              end
            end
          end.compact # return_value
        else
          response.body
        end
      else
        nil
      end
    end
  end

end
