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
    query.projection  'COUNT(*)'
    result = get_records raw: true, query: query
    result.first["COUNT(*)"] rescue  0  # return_value
  end
=begin
--
## historic method 
#  def manipulate_relation record,  method, array, items  # :nodoc: #
#    execute_array = Array.new
#    method =  method.to_s.upcase
#
#    add_2_execute_array = -> (it) do
#      command = "UPDATE ##{record.rid} #{method} #{array} = #{it.to_or } " #updating}"
#      command.gsub!(/\"/,"") if it.is_a? Array
#      puts "COMMAND:: #{command}"
#      execute_array << {type: "cmd", language: "sql", command: command}
#    end
#
#    items.to_a.each{|x| add_2_execute_array[x] }
##    puts "******************"
##    puts record.inspect
##    puts "-----"
##    puts execute_array.join('\n')
#    r= execute{ execute_array }
#    puts record.inspect
#    puts r.inspect
##    puts "******************"
#    if r.present?
#      case  method
#      when 'ADD'
#	items.each{|x| record.attributes[array] << x}
#      when 'REMOVE'
#	items.map{|x| record.attributes[array].delete x}
#      else
#      end
#      record.increment_version
#    end
#  end
++
=end


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

def read_transaction
	@transaction
end
	def execute transaction: false, tolerated_error_code: nil, process_error: true, raw: nil
		@transaction = []  unless @transaction.is_a?(Array)
		if block_given?
			command =  yield
			command.is_a?(Array) ? command.each{|c| @transaction << c} : @transaction << command
		else
			logger.error { "No Block provided to execute" }
			return nil
		end

#			puts "transaction #{@transaction.inspect}"
		unless transaction == :prepare
			commands =  @transaction.map{|y| y if y.is_a? String }.compact
			@transaction.delete_if{|y| y if y.is_a?(String)} 
			#puts "tn #{commands.inspect}"
			return nil if commands.empty?
			if commands.size >1
			@transaction <<	{ type: 'script', language: 'sql', script: commands } 
			elsif  transaction ==  false
				@transaction = 	commands.first
			else
				transaction =  true
				@transaction <<		{ type: 'cmd', language: 'sql', command: commands.first } 
			end	
 			_execute transaction, tolerated_error_code, process_error, raw
		end
	end


		def _execute transaction, tolerated_error_code, process_error, raw

		logger.progname= "Execute"
		begin
			response = if @transaction.is_a?(Array) 
									 @transaction.compact!
									 return nil if @transaction.empty?
									 # transaction is true only for multible statements
									 #      batch[:transaction] = transaction & batch[:operations].size >1
									 logger.info{ @transaction.map{|y|y[:command]}.join(";\n ") } 
									 logger.info{ @transaction.map{|y|y[:script]}.join(";\n ") } 
									batch= { transaction: transaction, operations: @transaction  }
									puts "batch:  #{batch.inspect}"
									 @res["/batch/#{ActiveOrient.database}"].post batch.to_json
								 else
									 logger.info{ @transaction } 
									 @res["/command/#{ActiveOrient.database}/sql"].post @transaction #.to_json
								 end
		rescue RestClient::BadRequest => f
			# extract the misspelled query in logfile and abort
			sentence=  JSON.parse( f.response)['errors'].last['content']
			logger.fatal{ " BadRequest --> #{sentence.split("\n")[1]} " }
			puts "Query not recognized"
			puts sentence
			raise
		rescue RestClient::InternalServerError => e
			@transaction = []
			sentence=  JSON.parse( e.response)['errors'].last['content']
			if tolerated_error_code.present? &&  e.response =~ tolerated_error_code
				logger.debug('RestOperations#Execute'){ "tolerated_error::#{e.message}"}
				logger.debug('RestOperations#Execute'){ e.message }
				nil  # return value
			else
				if process_error
					#	    puts batch.to_json
					#	  logger.error{e.response}
					logger.error{sentence}
					#logger.error{ e.backtrace.map {|l| "  #{l}\n"}.join  }
					#	  logger.error{e.message.to_s}
				else 
					raise
				end
			end 
		rescue Errno::EADDRNOTAVAIL => e
			sleep(2)
			retry
		else  # code to execute if no exception  is raised
			@transaction = []
			if response.code == 200
				if response.body['result'].present?
					result=JSON.parse(response.body)['result']
					if raw.present? 
						 result
					else
						y= result.from_orient
					end
				else
					response.body
				end
			else
				nil
			end
		end
	end

end
