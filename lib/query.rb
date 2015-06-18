
module REST
class Query < REST::Model

   has_many :records
   has_many :queries

   def reset_records
     self.records= []
   end
   alias reset_results reset_records

   def reset_queries
     self.queries = []
   end
=begin
calls REST::Rest#GetDocuments
stores the query in the query-stack and saves the result in the record-Array

returns the count of assigned records
=end

   def get_documents o_class: , where:  

       count= 0
       orientdb.get_documents( o_class: o_class , where: where ){| q| self.queries << q }.each{|c| records << c; count+=1 }
       count
   end

=begin
All predefined queries are send to the database.
The result is stored in the records.
Unknown Records are of Type REST::Model::Myquery, uses REST::Orientdb.execute which tries to autosuggest the REST::Model::{Class}

example: Multible Records
ach = REST::Query.new
ach.queries << 'create class Contracts ABSTRACT'
ach.queries << 'create property Contracts.details link'
ach.queries << 'create class Stocks extends Contracts'
result = ach.execute_queries transaction: false

example: Batch
q = REST::Query.new
q.queries << [
      "select expand( contracts )  from Openinterest"
       "let con = select expand( contracts )  from Openinterest; ",
       "let sub = select from Subcategories where contracts in $con;",
       "let cat = select from Categories where subcategories in $sub;",
       "let ind = select from Industries where categories in $cat;",
       "SELECT expand(unionall) FROM (SELECT unionall( $con, $cat))"
              ]
 q.execute_queries.each{|x|  puts "X #{x.inspect}" }

=end
   def execute_queries reset: true, transaction: true
     reset_records if reset
     begin 
     orientdb.execute( transaction: transaction ) do 
     result = queries.map do |q|
       # command: words are seperated by one space only, thus squeeze multible spaces
       sql_cmd = -> (command) { { type: "cmd", language: "sql", command: command.squeeze(' ') } }
       batch_cmd = ->( command_array ){ {type: "script", language: "sql", script: command_array } }
       case q
       when String
	 sql_cmd[ q ]
       when Hash
	 q
       when Array
	 batch_cmd[ q ]
	else
	  nil
       end # case
     end.compact 
     # save the result in records
     result.each{|y| records << y  }

     end # block
     rescue RestClient::InternalServerError => e
       puts e.inspect
     end

   end # def  execute_queries

end # class

end # module
