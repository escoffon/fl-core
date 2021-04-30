require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe 'Fl::Core::Commentable', type: :model do
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

  describe ".commentable?" do
    it "should return false if class is not commentable" do
      expect(Fl::Core::TestActor.commentable?).to eql(false)
    end
    
    it "should return true if class is commentable" do
      expect(Fl::Core::TestDatumComment.commentable?).to eql(true)
    end
  end

  describe "#commentable?" do
    it "should return false if object is not commentable" do
      expect(a10.commentable?).to eql(false)
    end
    
    it "should return true if object is commentable" do
      expect(d10.commentable?).to eql(true)
    end
  end

  describe ".has_comment" do
    it "should define the :comments association" do
      expect(d10.respond_to?(:comments)).to eql(true)
      
      expect(d10.comments.count).to eql(0)
    end

    it "should define a summary method" do
      expect(d10.respond_to?(:comment_summary)).to eql(true)
      expect(d10.comment_summary).to eql(d10.title)
    end

    it "should support configurable summary" do
      expect(d20.comment_summary).to eql(d20.content)
    end
  end
  
  describe "#add_comment" do
    it "should create a comment" do
      expect(d10.comments.count).to eql(0)

      c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
      expect(c1.valid?).to eql(true)
      expect(c1.persisted?).to eql(true)
      expect(d10.comments.count).to eql(1)
      expect(c1.author.fingerprint).to eql(a10.fingerprint)
      expect(c1.title).to eql('title1')
      expect(c1.contents_html).to eql('contents1')
      expect(c1.contents_json).to eql({ "ops" => [ { "insert" => "contents1" } ] })
    end
  end
end
