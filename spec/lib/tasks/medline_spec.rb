require 'spec/spec_helper'

describe "Medline rake tasks" do

  before do
    @rake = Rake::Application.new
    Rake.application = @rake
    load Rails.root + "lib/tasks/medline.rake"
    Rake::Task.define_task(:environment)
  end

  describe "usasearch:medline:load" do
    let(:task_name) { 'usasearch:medline:load' }

    it "should have 'environment' as a prereq" do
      @rake[task_name].prerequisites.should include("environment")
    end

    context "when given a date" do
      it "should download and process medline xml file" do
        mock_file_path = mock('file path')
        MedTopic.should_receive(:download_medline_xml).
            with(Date.parse('2011-04-26')).
            and_return(mock_file_path)
        MedTopic.should_receive(:process_medline_xml).with(mock_file_path)
        @rake[task_name].invoke('2011-04-26')
      end
    end

    context "when given no date" do
      it "should download and process medline xml file" do
        mock_file_path = mock('file path')
        MedTopic.should_receive(:download_medline_xml).
            with(nil).
            and_return(mock_file_path)
        MedTopic.should_receive(:process_medline_xml).with(mock_file_path)
        @rake[task_name].invoke
      end
    end
  end
end
