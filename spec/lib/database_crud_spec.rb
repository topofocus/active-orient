require 'spec_helper'

describe OrientSupport::Connection do
  before( :all ) do
#    @connect = OrientSupport::Messages::Outgoing::RequestConnect.new  username: 'hctw', password: 'hc'
      @oc = OrientSupport::Connection.new   user: 'hctw', password: 'hc' , database: 'First' # 'hc_database'

end

  ## Add a Database
  ## Check it's Presence
  ## List all Databases
  ## Delete Database
  ## Restore Database from Backup  (not jet implemented)
  context  'Database CRLD'  do
    it "create it" do
  
      @oc.send_message :RequestDBCreate, name: 'MyOwnTest'  

      @oc.wait_for( :RequestDBCreate ) do | message_object |
	expect( message_object ).to eq ""
      end
    end    # it
  end	   # context
end	   # describe
