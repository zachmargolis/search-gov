require 'spec_helper'

describe NavigationsHelper do
  shared_examples_for 'doing search on everything' do
    it 'should render default search label' do
      html = helper.render_navigations(affiliate, search, search_params)
      html.should have_selector('.navigations', :content => 'Everything')
    end

    it 'should not render a link to default search label' do
      html = helper.render_navigations(affiliate, search, search_params)
      html.should_not have_selector('.navigations a', :content => 'Everything')
    end
  end

  shared_examples_for 'doing non web search' do
    it 'should render a link to default search label' do
      html = helper.render_navigations(affiliate, search, search_params)
      html.should have_selector('.navigations a', :content => 'Everything')
    end
  end

  shared_examples_for 'doing non image search' do
    it 'should render a link to image search label' do
      html = helper.render_navigations(affiliate, search, search_params)
      html.should have_selector('.navigations a', :content => 'Images')
    end
  end

  shared_examples_for 'doing non odie search' do
    it 'should render a link to document collection' do
      html = helper.render_navigations(affiliate, search, search_params)
      html.should have_selector('.navigations a', :content => 'Blog')
    end
  end

  shared_examples_for 'doing non news channel specific search' do
    it 'should render a link to rss feed' do
      html = helper.render_navigations(affiliate, search, search_params)
      html.should have_selector('.navigations a', :content => 'News')
    end
  end

  describe '#filter_navigations' do
    let(:image_search_label) { mock_model(ImageSearchLabel, name: 'Images') }

    let(:image_nav) do
      mock_model(Navigation,
                 :navigable => image_search_label,
                 :navigable_type => image_search_label.class.name)
    end

    let(:media_nav) do
      mock_model(Navigation,
                 navigable: mock_model(RssFeed,
                                       is_managed: false,
                                       name: 'Photos',
                                       show_only_media_content?: true))
    end

    let(:press_nav) do
      mock_model(Navigation,
                 navigable: mock_model(RssFeed,
                                       is_managed: false,
                                       name: 'Press',
                                       show_only_media_content?: false))
    end

    let(:affiliate) { mock_model(Affiliate,
                                 default_search_label: 'Everything',
                                 name: 'myaff') }

    context 'when is_bing_image_search_enabled=true' do
      before do
        affiliate.should_receive(:has_social_image_feeds?).and_return(true)
        affiliate.should_receive(:navigations).and_return([image_nav, media_nav, press_nav])
      end

      it 'returns only the image nav' do
        helper.filter_navigations(affiliate, affiliate.navigations).should eq([image_nav, press_nav])
      end
    end

    context 'when is_bing_image_search_enabled=false' do
      before do
        affiliate.should_receive(:has_social_image_feeds?).and_return(false)
        affiliate.should_receive(:is_bing_image_search_enabled?).and_return(false)
        affiliate.should_receive(:navigations).and_return([image_nav, media_nav, press_nav])
      end

      it 'returns only the press nav' do
        helper.filter_navigations(affiliate, affiliate.navigations).should eq([press_nav])
      end
    end
  end

  describe '#render_navigations' do
    let(:affiliate) { mock_model(Affiliate, :name => 'myaff', :default_search_label => 'Everything') }

    let(:search_params) { { :query => 'gov', :affiliate => 'myaff' } }

    let(:image_search_label) { mock_model(ImageSearchLabel, :name => 'Images') }
    let(:image_nav) do
      mock_model(Navigation,
                 :navigable => image_search_label,
                 :navigable_type => image_search_label.class.name)
    end

    let(:rss_feed) { mock_model(RssFeed, :name => 'News') }
    let(:rss_feed_nav) do
      mock_model(Navigation,
                 :navigable => rss_feed,
                 :navigable_type => rss_feed.class.name)
    end

    let(:another_rss_feed) { mock_model(RssFeed, :name => 'Press Releases') }
    let(:another_rss_feed_nav) do
      mock_model(Navigation,
                 :navigable => another_rss_feed,
                 :navigable_type => another_rss_feed.class.name)
    end

    let(:document_collection) { mock_model(DocumentCollection, :name => 'Blog') }

    let(:document_collection_nav) do
      mock_model(Navigation,
                 :navigable => document_collection,
                 :navigable_type => document_collection.class.name)
    end

    let(:non_navigable_document_collection) { mock_model(DocumentCollection, name: 'News') }

    let(:search_params) { { :query => 'gov', :affiliate => affiliate.name } }

    context 'when there is no active navigation' do
      before { affiliate.stub_chain(:navigations, :active).and_return([]) }

      specify { helper.render_navigations(affiliate, double(WebSearch), search_params).should be_blank }
    end

    context 'when there are active navigations' do
      before do
        affiliate.stub_chain(:navigations, :active).
            and_return([image_nav, rss_feed_nav, document_collection_nav])
      end

      context 'when doing web search' do
        let(:search) { double(WebSearch) }

        before do
          search.should_receive(:instance_of?).at_least(:once) { |arg| arg == WebSearch }
        end

        it_behaves_like 'doing search on everything'
        it_behaves_like 'doing non image search'
        it_behaves_like 'doing non odie search'
        it_behaves_like 'doing non news channel specific search'
      end

      context 'when doing image search' do
        let(:search) { double(LegacyImageSearch) }

        before do
          search.should_receive(:instance_of?).at_least(:once) { |arg| arg == LegacyImageSearch }
        end

        it 'should render image search label' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should have_selector('.navigations', :content => 'Images')
        end

        it 'should not render a link to image search label' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should_not have_selector('.navigations a', :content => 'Images')
        end

        it_behaves_like 'doing non web search'
        it_behaves_like 'doing non odie search'
        it_behaves_like 'doing non news channel specific search'
      end

      context 'when doing search on a specific document collection' do
        let(:search) { double(SiteSearch) }

        before do
          search.should_receive(:instance_of?).at_least(:once) { |arg| arg == SiteSearch }
          search.should_receive(:is_a?).at_least(:once) { |arg| arg == SiteSearch }
          search.should_receive(:document_collection).at_least(:once).and_return(document_collection)
          document_collection.stub_chain(:navigation, :is_active?).and_return(true)
        end

        it 'should render document collection name' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should have_selector('.navigations', :content => 'Blog')
        end

        it 'should not render a link to document collection' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should_not have_selector('.navigations a', :content => 'Blog')
        end

        it_behaves_like 'doing non web search'
        it_behaves_like 'doing non image search'
        it_behaves_like 'doing non news channel specific search'
      end

      context 'when searching on non navigable document collection' do
        let(:search) { double(SiteSearch) }

        before do
          search.should_receive(:is_a?).at_least(:once) { |arg| arg == SiteSearch }
          search.should_receive(:document_collection).at_least(:once).and_return(non_navigable_document_collection)
          non_navigable_document_collection.stub_chain(:navigation, :is_active?).and_return(false)
        end

        it 'should render document collection name' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should have_selector('.navigations', content: 'News')
        end

        it 'should not render a link to document collection' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should_not have_selector('.navigations a', content: 'News')
        end
      end

      context 'when doing search on a specific news channel' do
        let(:search) { double(NewsSearch, since:nil, until: nil) }

        before do
          search.should_receive(:instance_of?).at_least(:once) { |arg| arg == NewsSearch }
          search.should_receive(:is_a?).at_least(:once) { |arg| arg == NewsSearch }
          search.should_receive(:rss_feed).and_return(rss_feed)
        end

        it 'should render rss feed name' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should have_selector('.navigations', :content => 'News')
        end

        it 'should not render a link to rss feed' do
          html = helper.render_navigations(affiliate, search, search_params)
          html.should_not have_selector('.navigations a', :content => 'News')
        end

        it_behaves_like 'doing non web search'
        it_behaves_like 'doing non image search'
        it_behaves_like 'doing non odie search'
      end
    end

    context 'when there are more than 1 active rss feed navigations' do
      let(:search) { double(NewsSearch, since:nil, until: nil) }

      before do
        affiliate.stub_chain(:navigations, :active).and_return(
            [image_nav, rss_feed_nav, document_collection_nav, another_rss_feed_nav])
        search.should_receive(:instance_of?).at_least(:once) { |arg| arg == NewsSearch }
        search.should_receive(:is_a?).at_least(:once) { |arg| arg == NewsSearch }
      end

      context 'when not doing search on a specific news channel' do
        before { search.should_receive(:rss_feed).and_return(nil) }

        it_behaves_like 'doing search on everything'
        it_behaves_like 'doing non image search'
        it_behaves_like 'doing non odie search'
        it_behaves_like 'doing non news channel specific search'
      end
    end
  end
end
