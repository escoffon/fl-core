require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe 'Fl::Core::Comment', type: :model do
  let(:a10) { create(:test_actor, name: 'a10') }
  let(:a11) { create(:test_actor, name: 'a11') }
  let(:a12) { create(:test_actor, name: 'a12') }
  let(:a13) { create(:test_actor, name: 'a13') }

  let(:d10_title) { 'd10 - title' }
  let(:d11_title) { 'd11 - title' }
  let(:d10_content) { 'd10 - content' }
  let(:d11_content) { 'd11 - content' }
  let(:d10) { create(:test_datum_comment, owner: a10, title: d10_title, content: d10_content) }
  let(:d11) { create(:test_datum_comment, owner: a11, title: d11_title, content: d11_content) }

  let(:d20_content) { 'd20 - content' }
  let(:d21_content) { 'd21 - content' }
  let(:d20) { create(:test_datum_comment_two, owner: a10, content: d20_content) }
  let(:d21) { create(:test_datum_comment_two, owner: a11, content: d21_content) }

  describe "nested comments" do
    it "should be supported" do
      expect(d10.comments.count).to eql(0)

      c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
      expect(d10.comments.count).to eql(1)
      expect(c1.comments.count).to eql(0)

      sc1 = c1.add_comment(a11, 'subcontents1', { ops: [ { insert: 'subcontents1' } ] }, 'subtitle1')
      expect(c1.comments.count).to eql(1)
    end
  end
end
