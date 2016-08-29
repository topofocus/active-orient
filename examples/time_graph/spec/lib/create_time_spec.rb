require 'spec_helper'
require 'rest_helper'

describe CreateTime do
  before( :all ) do
    reset_database 
    ActiveOrient::OrientSetup.init_database 
  end
  context "check environment" do
    it "nessesary classes are allocated" do
      [ Monat, Tag, Stunde ].each do | klass |
	expect( klass.superclass).to eq TimeBase
      end
    end
  end

  context "populate" do
    before( :all ) do
       CreateTime.populate_month
    end
    let( :month){  Date.today.month }

    it "The actual Month is used" do
      expect( Monat.count ).to eq 1
      expect( Monat.first.value ).to eq  Date.today.month
    end

    it "The actual Month has several days" do
      expect( Monat.first.tag.count ).to be >= 28
    end

    it	"Address a specific day", focus: true do

      expect( Monat[month].tag[5].value ).to eq 5
    end

    it "Address a specific hour" do
      expect( Monat[month].tag[5].value ).to eq 5
      expect( Monat[month].tag[7].stunde[5].value ).to eq 5
    end
    it "Switch to the next hour" do

      expect( Monat[month].tag[7].stunde[5].next.value ).to eq 6
    end
  end




end
