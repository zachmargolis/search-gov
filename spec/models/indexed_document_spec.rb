require 'spec/spec_helper'

describe IndexedDocument do
  fixtures :affiliates, :superfresh_urls
  before do
    @min_valid_attributes = {
      :url => "http://min.usa.gov/link.html",
      :affiliate_id => affiliates(:basic_affiliate).id
    }
    @valid_attributes = {
      :title => 'PDF Title',
      :description => 'This is a PDF document.',
      :url => 'http://something.gov/pdf.pdf',
      :last_crawl_status => IndexedDocument::OK_STATUS,
      :body => "this is the doc body",
      :affiliate_id => affiliates(:basic_affiliate).id,
      :content_hash => "a6e450cc50ac3b3b7788b50b3b73e8b0b7c197c8"
    }
  end

  it { should validate_presence_of :url }
  it { should validate_presence_of :affiliate_id }
  it { should allow_value("http://some.site.gov/url").for(:url) }
  it { should allow_value("http://some.site.mil/url").for(:url) }
  it { should allow_value("http://some.govsite.com/url").for(:url) }
  it { should allow_value("http://some.govsite.us/url").for(:url) }
  it { should allow_value("http://some.govsite.info/url").for(:url) }
  it { should_not allow_value("https://some.govsite.info/url").for(:url) }
  it { should_not allow_value("http://something.gov/there_is_a_space_in_this url.pdf").for(:url) }
  it { should_not allow_value("http://www.ssa.gov./trailing-period-in-domain.pdf").for(:url) }
  it { should belong_to :affiliate }

  context "when associated affiliate has a site domain list" do
    before do
      SiteDomain.create!(:affiliate=>affiliates(:basic_affiliate), :domain => "whitelist.gov")
    end

    context "when URL of indexed document doen't match anything in affiliate's site domain list" do
      it "should find the record invalid" do
        IndexedDocument.new(@valid_attributes.merge(:url=>"http://www.blacklisted.gov/foo?cache_url=http://www.whitelist.gov/someurl")).valid?.should be_false
      end
    end

    context "when URL of indexed document matches something in affiliate's site domain list" do
      it "should find the record valid given all other attributes are valid" do
        IndexedDocument.new(@valid_attributes.merge(:url=>"http://www.WHITELIST.gov/someurl")).valid?.should be_true
      end
    end
  end

  it "should create a new instance given valid attributes" do
    IndexedDocument.create!(@valid_attributes)
  end

  it "should assign/create an associated indexed_domain" do
    IndexedDocument.create!(@valid_attributes)
    IndexedDomain.find_by_affiliate_id_and_domain(affiliates(:basic_affiliate).id, "something.gov").should_not be_nil
  end

  describe "handling file extensions for URLs" do
    it "should not allow unsupported extensions" do
      base_url = "http://www.nps.gov/honey-badger."
      %w{json xml rss csv css js png gif jpg jpeg txt ico wsdl htc swf}.each do |ext|
        IndexedDocument.new(@valid_attributes.merge(:url => base_url + ext)).should_not be_valid
      end
    end
  end

  describe "handling document types for content" do
    it "should not allow unsupported types" do
      IndexedDocument.new(@valid_attributes.merge(:doctype => "pdf")).should be_valid
      IndexedDocument.new(@valid_attributes.merge(:doctype => "html")).should be_valid
      IndexedDocument.new(@valid_attributes.merge(:doctype => "vrml")).should_not be_valid
    end
  end

  describe "normalizing URLs when saving" do
    context "when URL doesn't have a protocol" do
      let(:url) { "www.foo.gov/sdfsdf" }
      it "should prepend it with http://" do
        IndexedDocument.create!(@valid_attributes.merge(:url=>url)).url.should == "http://www.foo.gov/sdfsdf"
      end
    end

    context "when an URL contains an anchor tag" do
      let(:url) { "http://www.foo.gov/sdfsdf#anchorme" }
      it "should remove it" do
        IndexedDocument.create!(@valid_attributes.merge(:url=>url)).url.should == "http://www.foo.gov/sdfsdf"
      end
    end
  end

  it "should enqueue the creation of a IndexedDocument entry via Resque" do
    ResqueSpec.reset!
    indexed_document = IndexedDocument.create!(@min_valid_attributes)
    IndexedDocumentFetcher.should have_queued(indexed_document.id)
  end

  it "should create a SuperfreshUrl entry for the affiliate" do
    SuperfreshUrl.find_by_url_and_affiliate_id(@min_valid_attributes[:url], @min_valid_attributes[:affiliate_id]).should be_nil
    IndexedDocument.create!(@min_valid_attributes)
    SuperfreshUrl.find_by_url_and_affiliate_id(@min_valid_attributes[:url], @min_valid_attributes[:affiliate_id]).should_not be_nil
  end

  it "should validate unique url" do
    IndexedDocument.create!(@valid_attributes)
    duplicate = IndexedDocument.new(@valid_attributes)
    duplicate.should_not be_valid
    duplicate.errors[:url].first.should =~ /already been added/
  end

  it "should allow a duplicate url for a different affiliate" do
    IndexedDocument.create!(@valid_attributes)
    duplicate = IndexedDocument.new(@valid_attributes.merge(:affiliate_id => affiliates(:power_affiliate).id))
    duplicate.should be_valid
  end

  it "should validate unique content hash across URLs for a given affiliate" do
    attrs = @valid_attributes.merge(:content_hash => '92ebcfafee3260a041f9624525a45328')
    IndexedDocument.create!(attrs)
    duplicate = IndexedDocument.new(attrs.merge(:url=>"http://www.otherone.gov/"))
    duplicate.should_not be_valid
    duplicate.errors[:content_hash].first.should =~ /Identical content/
    duplicate = IndexedDocument.new(attrs.merge(:affiliate_id => affiliates(:power_affiliate).id))
    duplicate.should be_valid
  end

  it "should not allow setting last_crawl_status to OK if the title is blank" do
    odie = IndexedDocument.create!(@min_valid_attributes)
    odie.update_attributes(:title => nil, :description => 'bogus description', :last_crawl_status => IndexedDocument::OK_STATUS).should be_false
    odie.errors[:title].first.should =~ /can't be blank/
  end

  it "should not allow setting last_crawl_status to OK if the description is blank" do
    odie = IndexedDocument.create!(@min_valid_attributes)
    odie.update_attributes(:title => 'bogus title', :description => ' ', :last_crawl_status => IndexedDocument::OK_STATUS).should be_false
    odie.errors[:description].first.should =~ /can't be blank/
  end

  describe "deleting an indexed_document" do
    context "when it's the last IndexedDocument associated with an IndexedDomain" do
      before do
        IndexedDocument.destroy_all
        @indexed_document = IndexedDocument.create!(@valid_attributes)
        @indexed_document.update_attributes!(:title => 'bogus title', :description => 'description', :last_crawl_status => IndexedDocument::OK_STATUS,:content_hash => '92ebcfafee3260a041f9624525a45328')
        IndexedDocument.create!(@valid_attributes.merge(:url=>"http://something.gov/second.html"))
      end

      it "should delete the associated orphaned IndexedDomain, too" do
        IndexedDocument.last.destroy
        IndexedDomain.find_by_domain("something.gov").should_not be_nil
        IndexedDocument.last.destroy
        IndexedDomain.find_by_domain("something.gov").should be_nil
      end
    end
  end

  describe "#search_for" do
    before do
      @affiliate = affiliates(:basic_affiliate)
    end

    context "when the affiliate is not specified" do
      it "should return nil" do
        IndexedDocument.search_for('foo', nil).should be_nil
      end
    end

    context "when the query is blank" do
      it "should return nil" do
        IndexedDocument.search_for('', @affiliate).should be_nil
      end
    end

    context "when the affiliate is specified" do
      it "should instrument the call to Solr with the proper action.service namespace, affiliate, and query param hash" do
        ActiveSupport::Notifications.should_receive(:instrument).
          with("solr_search.usasearch", hash_including(:query => hash_including(:affiliate => @affiliate.name, :model=>"IndexedDocument", :term => "foo")))
        IndexedDocument.search_for('foo', @affiliate)
      end
    end

    context "when some documents have non-OK statuses" do
      before do
        IndexedDocument.delete_all
        IndexedDocument.create!(:last_crawl_status => IndexedDocument::OK_STATUS, :title => 'HTML Title', :description => 'This is a HTML document.', :url => 'http://something.gov/html.html', :affiliate_id => affiliates(:basic_affiliate).id)
        IndexedDocument.create!(:last_crawl_status => "Broken", :title => 'PDF Title', :description => 'This is a PDF document.', :url => 'http://something.gov/pdf.pdf', :affiliate_id => affiliates(:basic_affiliate).id)
        IndexedDocument.reindex
        Sunspot.commit
      end

      it "should only return the OK ones" do
        search = IndexedDocument.search_for('document', affiliates(:basic_affiliate))
        search.total.should == 1
        search.results.first.last_crawl_status.should == IndexedDocument::OK_STATUS
      end
    end

    context "when the parent affiliate's locale is English" do
      before do
        @affiliate = affiliates(:basic_affiliate)
        IndexedDocument.create!(:last_crawl_status => IndexedDocument::OK_STATUS, :title => 'pollution is bad', :description => 'speaking', :url => 'http://something.gov/html.html', :body => "something about swimming", :affiliate_id => @affiliate.id)
        IndexedDocument.create!(:last_crawl_status => IndexedDocument::OK_STATUS, :title => 'pollution is bad', :description => 'speaking', :url => 'http://something.gov/html.html', :body => "something about swimming", :affiliate_id => affiliates(:power_affiliate).id)
        Sunspot.commit
        IndexedDocument.reindex
      end

      it "should find by title, description, and body for that affiliate, and highlight only the terms in the title and description" do
        title_search = IndexedDocument.search_for('swim pollutant', @affiliate)
        title_search.total.should == 1
        title_search.hits.first.highlight(:title).should_not be_nil
        description_search = IndexedDocument.search_for('speak', @affiliate)
        description_search.total.should == 1
        description_search.hits.first.highlight(:description).should_not be_nil
        body_search = IndexedDocument.search_for('swim', @affiliate)
        body_search.total.should == 1
        body_search.hits.first.highlight(:body).should be_nil
      end
    end

    context "when the parent affiliate's locale is Spanish" do
      before do
        @affiliate = affiliates(:basic_affiliate)
        @affiliate.update_attribute(:locale, 'es')
        affiliates(:power_affiliate).update_attribute(:locale, 'es')
        IndexedDocument.create!(:last_crawl_status => IndexedDocument::OK_STATUS, :title => 'jugar', :description => 'hablar', :url => 'http://something.gov/html.html', :body => "Declaraciones", :affiliate_id => @affiliate.id)
        IndexedDocument.create!(:last_crawl_status => IndexedDocument::OK_STATUS, :title => 'jugar', :description => 'hablar', :url => 'http://something.gov/html.html', :body => "Declaraciones", :affiliate_id => affiliates(:power_affiliate).id)
        Sunspot.commit
        IndexedDocument.reindex
      end

      it "should find by title, description, and body for that affiliate, and highlight only the terms in the title and description" do
        title_search = IndexedDocument.search_for('jugando', @affiliate)
        title_search.total.should == 1
        title_search.hits.first.highlight(:title_text).should_not be_nil
        description_search = IndexedDocument.search_for('hablando', @affiliate)
        description_search.total.should == 1
        description_search.hits.first.highlight(:description_text).should_not be_nil
        body_search = IndexedDocument.search_for('Declaraciones', @affiliate)
        body_search.total.should == 1
        body_search.hits.first.highlight(:body_text).should be_nil
      end
    end

  end

  describe "#fetch" do
    before do
      File.stub!(:delete)
    end

    let(:indexed_document) { IndexedDocument.create!(@valid_attributes) }

    context "when the URL isn't a match for existing site domain entries for the affiliate" do
      before do
        indexed_document.affiliate.site_domains.destroy_all
        indexed_document.affiliate.site_domains.create!(:domain=>"somethingelse.gov")
      end

      it "should delete the entry and stop processing" do
        indexed_document.should_receive(:remove_from_index)
        indexed_document.fetch
        IndexedDocument.exists?(indexed_document.id).should be_false
      end
    end

    it "should set the content hash for the entry" do
      mockfile = mock("File")
      indexed_document.stub!(:open).and_return mockfile
      mockfile.stub!(:content_type).and_return "foo"
      indexed_document.stub!(:index_document)
      indexed_document.stub!(:build_content_hash).and_return 'somehash'
      indexed_document.should_receive(:update_content_hash)
      indexed_document.fetch
    end

    context "when there is a problem fetching and indexing the URL content" do
      before do
        indexed_document.stub!(:open).and_raise Exception.new("404 Document Not Found")
      end

      it "should update the url with last crawled date and error message and set the hash to nil" do
        indexed_document.fetch
        indexed_document.last_crawled_at.should_not be_nil
        indexed_document.last_crawl_status.should == "404 Document Not Found"
        indexed_document.content_hash.should be_nil
      end

      it "should not attempt to clean up the nil file descriptor" do
        File.should_not_receive(:delete)
        indexed_document.fetch
      end
    end

    context "when the URL points at a PDF" do
      before do
        indexed_document.url = 'http://something.gov/something.pdf'
        @pdf_io = StringIO.new(File.read(Rails.root.to_s + "/spec/fixtures/pdf/test.pdf"))
        @pdf_io.stub!(:content_type).and_return 'application/pdf'
        indexed_document.stub!(:open).and_return @pdf_io
        @tempfile = Tempfile.new(Time.now.to_i)
        Tempfile.stub!(:new).and_return @tempfile
      end

      it "should call index_document" do
        indexed_document.stub!(:update_attribute)
        indexed_document.should_receive(:index_document).with(anything(), 'application/pdf')
        indexed_document.fetch
      end

      it "should delete the downloaded temporary PDF file" do
        File.should_receive(:delete)
        indexed_document.fetch
      end
    end

    context "when the URL doesn't point at a PDF" do
      before do
        indexed_document.url = 'http://something.gov/something.html'
        @html_io = open(Rails.root.to_s + '/spec/fixtures/html/fresnel-lens-building-opens-july-23.htm')
        indexed_document.stub!(:open).and_return @html_io
      end

      it "should not try to create a tempfile" do
        Tempfile.should_not_receive(:new)
      end

      it "should call index_document" do
        indexed_document.stub!(:update_attribute)
        indexed_document.should_receive(:index_document).with(@html_io, 'text/html')
        indexed_document.fetch
      end

      it "should delete the downloaded temporary HTML file" do
        File.should_receive(:delete).with(@html_io)
        indexed_document.fetch
      end
    end
  end

  describe "#update_content_hash" do
    let(:indexed_document) { IndexedDocument.create!(@valid_attributes) }
    context "when the content hash is a duplicate" do
      before do
        @dupe = indexed_document.clone
        @dupe.update_attributes!(:title=>"new title", :content_hash => "temp", :url => "http://www.gov.gov/newurl")
        @dupe.stub!(:build_content_hash).and_return(indexed_document.content_hash)
      end

      it "should raise an IndexedDocumentError with the validation error as the message" do
        lambda { @dupe.update_content_hash }.should raise_error(IndexedDocument::IndexedDocumentError, "Content hash is not unique: Identical content (title and body) already indexed")
      end
    end
  end

  describe "#index_document(file)" do
    before do
      @indexed_document = IndexedDocument.create!(@min_valid_attributes)
      @file = open(Rails.root.to_s + '/spec/fixtures/html/fresnel-lens-building-opens-july-23.htm')
    end

    context "when the content type of the fetched document contains 'pdf'" do
      before do
        @file.stub!(:content_type).and_return 'application/pdf'
      end

      it "should call index_pdf if the content type contains 'pdf'" do
        @indexed_document.should_receive(:index_pdf).with(@file.path).and_return true
        @indexed_document.index_document(@file, @file.content_type)
      end
    end

    context "when the content type of the fetched document contains 'html'" do
      before do
        @file.stub!(:content_type).and_return 'text/html'
        @indexed_document.stub!(:update_attribute)
      end

      it "should call index_html if the content type contains 'pdf'" do
        @indexed_document.should_receive(:index_html).with(@file).and_return true
        @indexed_document.index_document(@file, @file.content_type)
      end
    end

    context "when the content type of the fetched document contains neither 'pdf' or 'html'" do
      before do
        @file.stub!(:content_type).and_return 'application/msword'
      end

      it "should raise an IndexedDocumentError error indicating that the document type is not yet supported" do
        lambda { @indexed_document.index_document(@file, @file.content_type) }.should raise_error(IndexedDocument::IndexedDocumentError, "Unsupported document type: application/msword")
      end
    end
  end

  describe "#index_html(file)" do
    context "when the page has a HTML title" do
      let(:indexed_document) { IndexedDocument.create!(@min_valid_attributes) }
      let(:file) { open(Rails.root.to_s + '/spec/fixtures/html/fresnel-lens-building-opens-july-23.htm') }

      context "when the title is long" do
        it "should use the title, truncated to 60 characters on a word boundary" do
          indexed_document.index_html(file)
          indexed_document.title.should == "Fire Island National Seashore - Fire Island Light Station..."
        end
      end

      context "when the page has a description meta tag" do
        it "should use it when creating the boosted content" do
          indexed_document.index_html(file)
          indexed_document.description.should == "New display building for the original Fire Island Lighthouse Fresnel lens opens"
        end
      end

      context "when the page has a differently capitalized DeScriPtioN meta tag" do
        it "should still find it and use it" do
          indexed_document.index_html(file)
          indexed_document.description.should == "New display building for the original Fire Island Lighthouse Fresnel lens opens"
        end
      end

      context "when the page does not have a description meta tag" do
        before do
          indexed_document.index_html open(Rails.root.to_s + '/spec/fixtures/html/data-layers.html')
        end

        it "should use the initial subset of non-HTML words of the web page as the description" do
          indexed_document.title.should == "Carribean Sea Regional Atlas - Map Service and Layer..."
          indexed_document.description.should == "Carribean Sea Regional Atlas. -. Map Service and Layer Descriptions. Ocean Exploration and Research (OER) Digital Atlases. Caribbean Sea. Description. This map aids the public in locating surveys carried out by NOAA's Office of Exploration and..."
        end
      end

      context "when the page body (inner text) is empty" do
        before do
          indexed_document.stub!(:scrub_inner_text)
        end

        it "should raise an IndexedDocumentError" do
          lambda { indexed_document.index_html(file) }.should raise_error(IndexedDocument::IndexedDocumentError)
        end
      end

      it "should try to find and index nested PDFs" do
        indexed_document.should_receive(:discover_nested_pdfs).with(an_instance_of(Nokogiri::HTML::Document))
        indexed_document.index_html(file)
      end
    end
  end

  describe "#discover_nested_pdfs(doc, max)" do
    before do
      @aff = affiliates(:basic_affiliate)
      @aff.site_domains.destroy_all
      @aff.site_domains.create(:domain=>"agency.gov")
      @indexed_document = IndexedDocument.new(:affiliate => @aff, :url => "http://www.agency.gov/index.html")
    end

    context "when the HTML document contains PDF links" do
      before do
        @doc = Nokogiri::HTML(open(Rails.root.to_s + '/spec/fixtures/html/page_with_pdf_links.html'))
      end

      it "should create new IndexedDocuments with absolute URLs for PDFs from valid URLs with matching site domains" do
        @indexed_document.discover_nested_pdfs(@doc)
        @aff.indexed_documents.count.should == 2
        @aff.indexed_documents.find_by_url("http://www.agency.gov/relative.pdf").should_not be_nil
        @aff.indexed_documents.find_by_url("http://www.agency.gov/absolute.pdf").doctype.should == 'pdf'
      end

      context "when the HTML document contains more than the threshold number of PDFs" do
        it "should only discover up to the specified maximum number of them" do
          @indexed_document.discover_nested_pdfs(@doc, 1)
          @aff.indexed_documents.count.should == 1
        end
      end
    end

    context "when the HTML document contains no PDF links" do
      before do
        @doc = Nokogiri::HTML(open(Rails.root.to_s + '/spec/fixtures/html/data-layers.html'))
      end

      it "shouldn't create any new IndexedDocuments" do
        @indexed_document.discover_nested_pdfs(@doc)
        @aff.indexed_documents.count.should == 0
      end
    end

  end

  describe "#index_pdf(file)" do
    let(:indexed_document) { IndexedDocument.create!(@min_valid_attributes) }

    context "for a normal PDF file" do
      before do
        indexed_document.index_pdf(Rails.root.to_s + "/spec/fixtures/pdf/test.pdf")
      end

      it "should create an indexed document that has a title and description from the pdf" do
        indexed_document.id.should_not be_nil
        indexed_document.title.should == "This is a test PDF file, we are use it to test our PDF parsing technology"
        indexed_document.description.should =~ /This is a test PDF file/
        indexed_document.description.should =~ /in the right.../
        indexed_document.url.should == @min_valid_attributes[:url]
      end

      it "should set the the time and status from the crawl" do
        indexed_document.last_crawled_at.should_not be_nil
        indexed_document.last_crawl_status.should == IndexedDocument::OK_STATUS
      end
    end

    context "for a PDF that, when parsed, has garbage characters in the description" do
      before do
        indexed_document.index_pdf(Rails.root.to_s + "/spec/fixtures/pdf/garbage_chars.pdf")
      end

      it "should remove the garbage characters from the description" do
        indexed_document.description.should_not =~ /[“’‘”]/
        indexed_document.description[0..-4].should_not =~ /[^\w_ ]/
        indexed_document.description.should_not =~ / /
      end
    end

    context "when the page content is empty" do
      before do
        PDF::Toolkit.stub!(:pdftotext).and_return ""
      end

      it "should raise an IndexedDocumentError" do
        lambda { indexed_document.index_pdf(Rails.root.to_s + "/spec/fixtures/pdf/test.pdf") }.should raise_error(IndexedDocument::IndexedDocumentError)
      end
    end
  end

  describe "#uncrawled_urls" do
    before do
      IndexedDocument.destroy_all
      @affiliate = affiliates(:basic_affiliate)
      @first_uncrawled_url = IndexedDocument.create!(:url => 'http://some.mil/', :affiliate => @affiliate)
      @last_uncrawled_url = IndexedDocument.create!(:url => 'http://another.mil', :affiliate => @affiliate)
      @other_affiliate_uncrawled_url = IndexedDocument.create!(:url => 'http://other.mil', :affiliate => affiliates(:power_affiliate))
      @already_crawled_url = IndexedDocument.create!(:url => 'http://already.crawled.mil', :affiliate => @affiliate, :last_crawled_at => Time.now)
    end

    it "should return the first page of all crawled urls" do
      uncrawled_urls = IndexedDocument.uncrawled_urls(@affiliate)
      uncrawled_urls.size.should == 2
      uncrawled_urls.include?(@first_uncrawled_url).should be_true
      uncrawled_urls.include?(@last_uncrawled_url).should be_true
    end

    it "should paginate the results if the page is passed in" do
      uncrawled_urls = IndexedDocument.uncrawled_urls(@affiliate, 2)
      uncrawled_urls.size.should == 0
    end
  end

  describe "#crawled_urls" do
    before do
      @affiliate = affiliates(:basic_affiliate)
      @first_crawled_url = IndexedDocument.create!(:url => 'http://crawled.mil', :last_crawled_at => Time.now, :affiliate => @affiliate)
      @last_crawled_url = IndexedDocument.create!(:url => 'http://another.crawled.mil', :last_crawled_at => Time.now, :affiliate => @affiliate)
      IndexedDocument.create!(:url => 'http://anotheraffiliate.mil', :last_crawled_at => Time.now, :affiliate => affiliates(:power_affiliate))
    end

    it "should return the first page of all crawled urls" do
      crawled_urls = IndexedDocument.crawled_urls(@affiliate)
      crawled_urls.size.should == 2
      crawled_urls.include?(@first_crawled_url).should be_true
      crawled_urls.include?(@last_crawled_url).should be_true
    end

    it "should paginate the results if the page is passed in" do
      crawled_urls = IndexedDocument.crawled_urls(@affiliate, 2)
      crawled_urls.size.should == 0
    end
  end

  describe "#process_file" do
    before do
      @affiliate = affiliates(:basic_affiliate)
    end

    context "when file format is not text/plain or txt" do
      before do
        @urls = ['http://search.usa.gov', 'http://usa.gov', 'http://data.gov']
        tempfile = Tempfile.new('urls.xml')
        @urls.each do |url|
          tempfile.write(url + "\n")
        end
        tempfile.close
        tempfile.open
        @file = ActionDispatch::Http::UploadedFile.new(:tempfile => tempfile, :type => 'text/xml')
      end

      it "should return with error_message" do
        IndexedDocument.process_file(@file, @affiliate).should == {:success => false, :error_message => 'Invalid file format; please upload a plain text file (.txt).'}
      end
    end

    context "when a file is passed in without any URLs" do
      before do
        @urls = ['http://search.usa.gov', 'http://usa.gov', 'http://data.gov']
        tempfile = Tempfile.new('urls.txt')
        @file = ActionDispatch::Http::UploadedFile.new(:tempfile => tempfile, :type => 'text/plain')
      end

      it "should return with success = false, and error message" do
        result = IndexedDocument.process_file(@file, @affiliate)
        result[:success].should be_false
        result[:error_message].should == 'No URLs uploaded; please check your file and try again.'
      end
    end

    context "when a file is passed in with 100 or fewer URLs" do
      before do
        @urls = ['http://search.usa.gov', 'http://usa.gov', 'http://data.gov']
        tempfile = Tempfile.new('urls.txt')
        @urls.each do |url|
          tempfile.write(url + "\n")
        end
        tempfile.close
        tempfile.open
        @file = ActionDispatch::Http::UploadedFile.new(:tempfile => tempfile, :type => 'text/plain')
        @result = IndexedDocument.process_file(@file, @affiliate)
      end

      it "should create a new IndexedDocument for each of the lines in the file" do
        @urls.each { |url| IndexedDocument.find_by_url_and_affiliate_id(url, @affiliate.id).should_not be_nil }
      end

      it "should return with success = true, and count" do
        @result[:success].should be_true
        @result[:count].should == 3
      end
    end

    context "when a file is passed in with more than 100 URLs" do
      before do
        tempfile = Tempfile.new('too_many_urls.txt')
        101.times { |x| tempfile.write("http://search.usa.gov/#{x}\n") }
        tempfile.close
        tempfile.open
        @file = ActionDispatch::Http::UploadedFile.new(:tempfile => tempfile, :type => 'text/plain')
      end

      it "should return with success = false and error message if max URLs is set below the number of URLs in the file" do
        result = IndexedDocument.process_file(@file, @affiliate)
        result[:success].should be_false
        result[:error_message].should == 'Too many URLs in your file.  Please limit your file to 100 URLs.'
      end

      it "should return with success = true if max URLs is set above the number of URLs in the file" do
        result = IndexedDocument.process_file(@file, @affiliate, 1000)
        result[:success].should be_true
        result[:count].should == 101
      end
    end
  end

  describe "#refresh_all" do
    before do
      ResqueSpec.reset!
      IndexedDocument.delete_all
      @first = IndexedDocument.create!(:url => 'http://some.mil/', :affiliate => affiliates(:power_affiliate))
      @last = IndexedDocument.create!(:url => 'http://another.mil', :affiliate => affiliates(:power_affiliate))
    end

    it "should enqueue a fetch call for all available indexed docs" do
      IndexedDocument.refresh_all
      IndexedDocumentFetcher.should have_queued(@first.id)
      IndexedDocumentFetcher.should have_queued(@last.id)
    end
  end

  describe "#bulk_load_urls" do
    before do
      IndexedDocument.delete_all
      @file = Tempfile.new('aid_urls.txt')
      @aff = affiliates(:power_affiliate)
      2.times { @file.puts([@aff.id, 'http://www.usa.gov'].join("\t")) }
      @file.puts([@aff.id, 'http://www.usa.z/invalid'].join("\t"))
      @file.close
    end

    it "should create new, valid IndexedDocument entries" do
      IndexedDocument.bulk_load_urls(@file.path)
      IndexedDocument.count.should == 1
      IndexedDocument.find_by_url("http://www.usa.gov", @aff.id).should_not be_nil
    end

  end

  describe "#build_content_hash" do
    it "should build it from the title and body" do
      IndexedDocument.new(@valid_attributes).build_content_hash.should == '92ebcfafee3260a041f9624525a45327'
    end

    context "when title is empty" do
      it "should just use the body" do
        IndexedDocument.new(@valid_attributes.merge(:title => nil)).build_content_hash.should == '0a56786098d4b95f93ebff6070b0a24f'
      end
    end
  end
end