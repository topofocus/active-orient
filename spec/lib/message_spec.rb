require 'spec_helper'

describe OrientSupport::Messages do
  before( :all ) do
  end

  context "check AbstractMessage" , focus: true do

    it "is a valid class" do  # check wether require/include/extend work
      m = OrientSupport::Messages::Outgoing::AbstractMessage.new
      expect( m ).to be
      expect( m.to_human ).to eq "<AbstractMessage: >"
      expect( m.message_type ).to eq :AbstractMessage
    end
    it "has class_methods" do
      expect( OrientSupport::Messages::Outgoing::AbstractMessage.version ).to  eq 1
      expect( OrientSupport::Messages::Outgoing::AbstractMessage.message_type ).to eq :AbstractMessage
      expect( OrientSupport::Messages::Outgoing::AbstractMessage.message_id ).to  eq -1
    end
  end

  context "create new class" do
    before( :all ) do
      RequestOpenOrders = OrientSupport::Messages::Outgoing.def_message 5
    #  RequestConnect = OrientSupport::Messages::Outgoing.def_message(2, [:driver, 'ActiveOrient'],
    #    							     [:driver_version, '1.0', :string ],
    #    							     [:protocol,  30 ],
    #    							     [:client_id, "0", :string ],
    #    							     [:serialization, "ORecordSerializerBinary"],
    #    							     [:token,  false],
    #    							     [:username, :string ],
    #    							     [:password, :string ])
    end

    it "allocate simple class", focus:true do
      m = OrientSupport::Messages::Outgoing::RequestConnect.new 
		  
      expect( m.to_human ).to eq "<RequestConnect: >"
      expect( m.message_type ).to eq :RequestConnect
      expect( m.session_id ).to eq -1
 #     expect( m.encode ).to eq [2, -1, "ActiveOrient", "1.0", 30, "0", "ORecordSerializerBinary", false, nil, nil]
 #     expect( m.to_s ).to eq '2--1-ActiveOrient-1.0-30-0-ORecordSerializerBinary-false--'
    end

    it "allocate message class with parameters", focus:true do

      m = OrientSupport::Messages::Outgoing::RequestConnect.new  user: 'hctw', password: 'hc'

#      expect( m.encode ).to eq [2, -1, "ActiveOrient", "1.0", 30, "0", "ORecordSerializerBinary", false, "hctw", "hc"]a
      puts m.encode.inspect
      expect( m.serialize).to eq "cl>Na12Na3nNa1Na23nNa4Na2"
     puts  m.encode.pack(m.serialize).inspect


    end

    it "allocate complex class " do
      m = OrientSupport::Messages::Outgoing::RequestConnect.new 
      expect( m.to_human ).to eq "<RequestConnect: >"
      expect( m.message_type ).to eq :RequestConnect
      expect( m.message_id ).to eq 2
#      expect( m.encode ).to eq [2, -1, ["ActiveOrient", "1.0", 30, "", "ORecordSerializerBinary", false, "hctw", "hc"]]
 ä     expect( m.to_s ).to eq '2-30-ActiveOrient-1.0-30--ORecordSerializerBinary-false-hctw-hc'
  

    end


  end




end

