#require 'lib/messages/outgoing/abstract'  in boot.rb

module OrientSupport
  module Messages
    module Incoming
       extend Messages # def_message macros

             RequestConnect = OrientSupport::Messages::Incoming.def_message(2) 
	     class RequestConnect
	       def load
		 # does not load anything
	       end
	     end

             RequestDBClose = OrientSupport::Messages::Incoming.def_message(5 )
	     class RequestDBClose
	       def load
		 # does not load anything
	       end
	     end

             RequestDBOpen = OrientSupport::Messages::Incoming.def_message(3) 
	     # Response: (session-id:int)(token:bytes) --> handled by connection
	     # (num-of-clusters:short)
	     # [(cluster-name:string)(cluster-id:short)]
	     # (cluster-config:bytes)
	     # (orientdb-release:string)

	     class RequestDBOpen
	       def  read_data
		 logger.progname='OrientSupport::Message::RequestDBOpen' 
		@data[:clusters] = clusters = Hash.new
		 socket.read_short.times { clusters[  socket.read_string ] =  socket.read_short }
		 logger.debug{ "clusters --> #{clusters.size}"  }
		 logger.debug{ clusters.sort{|a,b| a[1]<=>b[1]}.map{|x,y| "#{y}~>#{x}"}.join(';')} 
		 @data[:cluster_config] =  socket.read_string 
		 @data[:database_version] = socket.read_string
		 @loading_completed =  true
	       end
	     end
             RequestDBExist = OrientSupport::Messages::Incoming.def_message(6)
	     class RequestDBExist
	       def load
		 # does not load anything
	       end
	     end
    end
  end
end
