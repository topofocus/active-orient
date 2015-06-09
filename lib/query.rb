
module REST
class Query < REST::Model

#   include BasePropertiesa

#   prop :query  # holds the query-sequence, either as string or as array

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
All predefined query are send to the database.
The result is stored in the records.
The Records are of Tyoe REST::Model::Myquery
=end
   def execute_queries reset: true, transaction: true
     reset_records if reset

     orientdb.execute( transaction: transaction ) do 
     result = queries.map do |q|
       # command: words are seperated by one space only, thus squeeze multible spaces
       sql_cmd = -> (command) { { type: "cmd", language: "sql", command: command.squeeze(' ') } }
       case q
       when String
	 sql_cmd[ q ]
       when Hash
	 q
	else
	  nil
       end # case
     end.compact 
     # save the result in records
     result.compact.each{|y| records << y if true }

     end # block
   end # def  execute_queries

end # class

end # module
