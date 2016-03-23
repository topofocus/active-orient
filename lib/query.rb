module ActiveOrient
  class Query < ActiveOrient::Model

    has_many :records
    has_many :queries

    def reset_records
      self.records= []
    end
    alias reset_results reset_records

    def reset_queries
      self.queries = []
    end

    def get_records o_class , **args
      query = OrientSupport::OrientQuery.new classname(o_class), args
	    self.queries << query.compose
      count= 0
      orientdb.get_records(o_class , query: query.compose).each{|c| records << c; count+=1 }
      count
    end

    def execute_queries reset: true, transaction: true
      reset_records if reset
      begin
        orientdb.execute( transaction: transaction ) do
          result = queries.map do |q|
# command: words are seperated by one space only, thus squeeze multible spaces
            sql_cmd = -> (command) {{type: "cmd", language: "sql", command: command.squeeze(' ') }}
            batch_cmd = -> (command_array){{type: "script", language: "sql", script: command_array}}
            case q
            when String
	            sql_cmd[q]
            when Hash
	            q
            when Array
	            batch_cmd[q]
	          else
	            nil
            end # case
          end.compact
     # save the result in records
          result.each{|y| records << y}
        end # block
      rescue RestClient::InternalServerError => e
        puts e.inspect
      end
    end # def  execute_queries
  end # class
end # module
