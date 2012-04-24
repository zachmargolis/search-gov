require 'spec/spec_helper'

describe AffiliateObserver do
  let(:rss_feed_content) { File.open(Rails.root.to_s + '/spec/fixtures/rss/youtube.xml').read }
  before { Kernel.stub(:open).and_return(rss_feed_content) }

  describe "#after_create" do
    context "when youtube handle is specified" do
      it "should create a managed 'Videos' RSS feed" do
        affiliate = Affiliate.new(:display_name => 'site with videos', :youtube_handles => %w(USGovernment whitehouse))
        affiliate.save!
        rss_feeds = Affiliate.find(affiliate.id).rss_feeds
        rss_feeds.count.should == 1
        rss_feed = rss_feeds.first
        rss_feed.name.should == 'Videos'
        rss_feed.should be_is_managed
        rss_feed.should be_is_video
        rss_feed_urls = rss_feed.rss_feed_urls
        rss_feed_urls.collect(&:url).should == ['http://gdata.youtube.com/feeds/base/videos?alt=rss&author=usgovernment&orderby=published',
                                                'http://gdata.youtube.com/feeds/base/videos?alt=rss&author=whitehouse&orderby=published']
      end
    end
  end

  describe "#after_update" do
    context "when there is an existing managed video RSS feed" do
      let!(:affiliate) { Affiliate.create!(:display_name => 'site with videos', :youtube_handles => %w(USAgov whitehouse)) }
      let(:managed_video_feeds) { affiliate.rss_feeds.managed.videos }
      let(:video_feed_urls) { managed_video_feeds.first.rss_feed_urls.collect(&:url) }

      context "when current youtube handles are different from the old handles" do
        it "should delete RssFeedUrl that is not in the new list" do
          existing_rss_feed_urls = Affiliate.find(affiliate.id).rss_feeds.first.rss_feed_urls
          existing_rss_feed_urls.count.should == 2
          affiliate.update_attributes!(:youtube_handles => %w(USGovernment))
          existing_rss_feed_urls.all? { |url| RssFeedUrl.find_by_id(url.id).nil? }
        end

        it "should create a new RssFeedUrl" do
          affiliate.update_attributes!(:youtube_handles => %w(USGovernment))
          managed_video_feeds.count.should == 1
          video_feed_urls.should == %w(http://gdata.youtube.com/feeds/base/videos?alt=rss&author=usgovernment&orderby=published)
        end

        it "should keep RssFeedUrl that does not change" do
          wh_rss_feed_url = RssFeedUrl.find_by_url('http://gdata.youtube.com/feeds/base/videos?alt=rss&author=whitehouse&orderby=published')
          affiliate.update_attributes!(:youtube_handles => %w(whitehouse USGovernment))
          affiliate.rss_feeds.first.rss_feed_urls.should include(wh_rss_feed_url)
          video_feed_urls.should == ['http://gdata.youtube.com/feeds/base/videos?alt=rss&author=usgovernment&orderby=published',
                                     'http://gdata.youtube.com/feeds/base/videos?alt=rss&author=whitehouse&orderby=published']
        end
      end

      context "when the youtube handles does not change" do
        it "should not update managed video rss_feed" do
          existing_rss_feed_urls = Affiliate.find(affiliate.id).rss_feeds.first.rss_feed_urls
          affiliate.update_attributes!(:display_name => 'another test site')
          managed_video_feeds.first.rss_feed_urls.should == existing_rss_feed_urls
        end
      end

      context "when youtube handles is blank" do
        it "should not have managed video rss feed" do
          affiliate.update_attributes!(:youtube_handles => [])
          managed_video_feeds.count.should == 0
        end
      end
    end

    context "when there is no existing managed video RSS feed" do
      let(:affiliate) { Affiliate.create!(:display_name => 'site with videos') }
      let(:managed_video_feeds) { affiliate.rss_feeds.managed.videos }
      let(:video_feed_urls) { managed_video_feeds.first.rss_feed_urls.collect(&:url) }

      context "when youtube handles is not blank" do
        it "should have a Videos RSS feed with youtube URL" do
          affiliate.update_attributes!(:youtube_handles => %w(whitehouse USGovernment))
          managed_video_feeds.count.should == 1
          managed_video_feeds.first.name.should == 'Videos'
          video_feed_urls.should == ['http://gdata.youtube.com/feeds/base/videos?alt=rss&author=usgovernment&orderby=published',
                                     'http://gdata.youtube.com/feeds/base/videos?alt=rss&author=whitehouse&orderby=published']
        end
      end
    end
  end
end