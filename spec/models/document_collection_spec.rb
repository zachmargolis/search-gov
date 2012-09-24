require 'spec_helper'

describe DocumentCollection do
  fixtures :affiliates, :document_collections, :url_prefixes, :navigations

  before do
    @valid_attributes = {
      :name => 'My Collection',
      :affiliate => affiliates(:power_affiliate),
      :url_prefixes_attributes => {'0' => { :prefix => 'http://www.agency.gov/' } }
    }
  end

  describe "Creating new instance" do
    it { should belong_to :affiliate }
    it { should have_many(:url_prefixes).dependent(:destroy) }
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of(:name).scoped_to(:affiliate_id) }

    it "should create navigation" do
      dc = DocumentCollection.create!(@valid_attributes)
      dc.navigation.should == Navigation.find(dc.navigation.id)
      dc.navigation.affiliate_id.should == dc.affiliate_id
      dc.navigation.position.should == 100
      dc.navigation.should_not be_is_active
    end

    it 'should not allow document collection without prefix' do
      dc = DocumentCollection.new(@valid_attributes.except(:url_prefixes_attributes))
      dc.should_not be_valid
    end
  end
end