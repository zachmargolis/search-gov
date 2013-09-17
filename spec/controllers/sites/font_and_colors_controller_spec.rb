require 'spec_helper'

describe Sites::FontAndColorsController do
  fixtures :users, :affiliates
  before { activate_authlogic }

  describe '#update' do
    it_should_behave_like 'restricted to approved user', :put, :update

    context 'when logged in as affiliate' do
      include_context 'approved user logged in to a site'

      context 'when site params are not valid' do
        before do
          site.should_receive(:update_attributes).and_return(false)

          put :update,
               site_id: site.id,
               id: 100,
               site: { css_property_hash: { font_family: 'Arial, san-serif' } }
        end

        it { should render_template(:edit) }
      end
    end
  end
end