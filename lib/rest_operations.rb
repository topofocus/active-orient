module RestOperations

  def call_function *args
  #     puts "uri:#{function_uri { args.join('/') } }"
    begin
      @res[function_uri{args.join('/')}].post ''
    rescue RestClient::InternalServerError => e
  	  puts  JSON.parse(e.http_body)
    end
  end

  def count_records **args
    logger.progname = 'RestOperations#CountRecords'
    query = OrientSupport::OrientQuery.new args
  	query.projection << 'COUNT (*)'
  	result = get_records raw: true, query: query
    begin
      result.first['COUNT']
    rescue
      return 0
    end
  end
  alias count_documents count_records
  alias count count_records

  def execute classname = 'Myquery', transaction: true # Set up for classes
    batch = {transaction: transaction, operations: yield}
    unless batch[:operations].blank?
      begin
        response = @res[batch_uri].post batch.to_json
      rescue RestClient::InternalServerError => e
        raise
      end
      if response.code == 200
        if response.body['result'].present?
          result= JSON.parse(response.body)['result']
          result.map do |x|
            if x.is_a? Hash
              if x.has_key?('@class')
                ActiveOrient::Model.orientdb_class(name: x['@class']).new x
              elsif x.has_key?('value')
                x['value']
              else
                ActiveOrient::Model.orientdb_class(name: classname).new x
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
