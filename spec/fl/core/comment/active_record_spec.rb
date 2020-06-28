require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe 'Fl::Core::Comment::ActiveRecord', type: :model do
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
  let(:d20) { create(:test_datum_comment_two, owner: a10, content: d20_content) }

  def _clist(cl)
    cl.map do |c|
      if c.respond_to?(:title)
        c.title
      elsif c.is_a?(Hash)
        if c.has_key?(:title)
          c[:title]
        elsif c.has_key?('title')
          c['title']
        else
          nil
        end
      else
        nil
      end
    end
  end

  describe ".commentable?" do
    it "should return true for the comment class" do
      expect(Fl::Core::Comment::ActiveRecord::Comment.commentable?).to eql(true)
    end
  end

  describe "#commentable?" do
    it "should return true for comment objects" do
      c1 = Fl::Core::Comment::ActiveRecord::Comment.create(
        author: a10,
        commentable: d10,
        contents: 'contents1',
        contents_delta: { }
      )
      expect(c1.commentable?).to eql(true)
    end
  end
  
  describe "initialization" do
    it "should populate the :title attribute" do
      expect(d10.comments.count).to eql(0)

      c1 = Fl::Core::Comment::ActiveRecord::Comment.new(
        author: a10,
        commentable: d10,
        contents: 'contents1',
        contents_delta: { }
      )
      expect(c1.valid?).to eql(true)
      expect(c1.save).to eql(true)
      expect(c1.title).to eql('contents1')
    end

    it "should populate the _fingerprint attributes" do
      expect(d10.comments.count).to eql(0)

      c1 = Fl::Core::Comment::ActiveRecord::Comment.new(
        author: a10,
        commentable: d10,
        contents: 'contents1',
        contents_delta: { }
      )
      expect(c1.valid?).to eql(true)
      expect(c1.save).to eql(true)
      expect(c1.author_fingerprint).to eql(a10.fingerprint)
      expect(c1.commentable_fingerprint).to eql(d10.fingerprint)
    end
  end
  
  describe "comment factory" do
    it "should create an instance of an active record comment" do
      h = {
        author: a10,
        commentable: d10,
        contents: 'contents1',
        contents_delta: { },
        title: 'title1'
      }

      expect(d10.comments.count).to eql(0)

      c1 = Fl::Core::TestDatumComment.build_comment(h)
      expect(c1).to be_a(Fl::Core::Comment::ActiveRecord::Comment)
      expect(c1.valid?).to eql(true)
      expect(c1.save).to eql(true)
      expect(d10.comments.count).to eql(1)
    end
  end

  describe "comment count" do
    it "should register callbacks if enabled" do
      expect(Fl::Core::TestDatumComment.instance_methods).to include(:_bump_comment_count, :_drop_comment_count)
      expect(Fl::Core::TestDatumCommentTwo.instance_methods).not_to include(:_bump_comment_count, :_drop_comment_count)
    end

    context "when comment is created" do
      it "should execute the callback if enabled" do
        expect(d10.comments.count).to eql(0)
        expect(d10.num_comments).to eql(0)

        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.valid?).to eql(true)
        expect(c1.persisted?).to eql(true)
        expect(d10.comments.count).to eql(1)
        d10.reload
        expect(d10.num_comments).to eql(1)
      end

      it "should not execute the callback if not enabled" do
        # there's no clear way to know that it does not get executed, but at least we can check that it runs
      
        expect(d20.comments.count).to eql(0)

        c1 = d20.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.valid?).to eql(true)
        expect(c1.persisted?).to eql(true)
        d20.reload
        expect(d20.comments.count).to eql(1)
      end

      it "should execute the callback for subcomments" do
        expect(d10.comments.count).to eql(0)
        expect(d10.num_comments).to eql(0)

        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.comments.count).to eql(0)
        expect(c1.num_comments).to eql(0)

        sc1 = c1.add_comment(a10, 'subcontents1', { ops: [ { insert: 'subcontents1' } ] }, 'subtitle1')
        expect(sc1.valid?).to eql(true)
        expect(sc1.persisted?).to eql(true)
        expect(c1.comments.count).to eql(1)
        c1.reload
        expect(c1.num_comments).to eql(1)

        # Subcomments are tracked even when the top level commentable does not

        c1 = d20.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.comments.count).to eql(0)
        expect(c1.num_comments).to eql(0)

        sc1 = c1.add_comment(a10, 'subcontents1', { ops: [ { insert: 'subcontents1' } ] }, 'subtitle1')
        expect(sc1.valid?).to eql(true)
        expect(sc1.persisted?).to eql(true)
        expect(c1.comments.count).to eql(1)
        c1.reload
        expect(c1.num_comments).to eql(1)
      end
    end

    context "when comment is destroyed" do
      it "should execute the callback if enabled" do
        expect(d10.comments.count).to eql(0)
        expect(d10.num_comments).to eql(0)

        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.valid?).to eql(true)
        expect(c1.persisted?).to eql(true)
        expect(d10.comments.count).to eql(1)
        d10.reload
        expect(d10.num_comments).to eql(1)

        c1.destroy
        expect(d10.comments.count).to eql(0)
        d10.reload
        expect(d10.num_comments).to eql(0)
      end

      it "should not execute the callback if not enabled" do
        # there's no clear way to know that it does not get executed, but at least we can check that it runs
      
        expect(d20.comments.count).to eql(0)

        c1 = d20.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.valid?).to eql(true)
        expect(c1.persisted?).to eql(true)
        d20.reload
        expect(d20.comments.count).to eql(1)

        c1.destroy
        expect(d20.comments.count).to eql(0)
      end

      it "should execute the callback for subcomments" do
        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.comments.count).to eql(0)
        expect(c1.num_comments).to eql(0)

        sc1 = c1.add_comment(a10, 'subcontents1', { ops: [ { insert: 'subcontents1' } ] }, 'subtitle1')
        expect(c1.comments.count).to eql(1)
        c1.reload
        expect(c1.num_comments).to eql(1)

        sc1.destroy
        expect(c1.comments.count).to eql(0)
        c1.reload
        expect(c1.num_comments).to eql(0)

        c1 = d20.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        expect(c1.comments.count).to eql(0)
        expect(c1.num_comments).to eql(0)

        sc1 = c1.add_comment(a10, 'subcontents1', { ops: [ { insert: 'subcontents1' } ] }, 'subtitle1')
        expect(c1.comments.count).to eql(1)
        c1.reload
        expect(c1.num_comments).to eql(1)

        sc1.destroy
        expect(c1.comments.count).to eql(0)
        c1.reload
        expect(c1.num_comments).to eql(0)
      end
    end
  end
  
  describe "commentable" do
    context "#add_comment" do
      it "should create an instance of an active record comment" do
        expect(d10.comments.count).to eql(0)

        c1 = d10.add_comment(a10, 'contents1', { }, 'title1')
        expect(c1).to be_a(Fl::Core::Comment::ActiveRecord::Comment)
        expect(c1.valid?).to eql(true)
        expect(c1.persisted?).to eql(true)
        expect(d10.comments.count).to eql(1)
      end
    end

    context "#comments_query" do
      let(:d100) do
        d = create(:test_datum_comment, owner: a10, title: 'd100.title', content: 'd100.content')
        d.add_comment(a10, 'a10 - c1', { }, 'a10 - t1')
        d.add_comment(a11, 'a11 - c1', { }, 'a11 - t1')
        d.add_comment(a10, 'a10 - c2', { }, 'a10 - t2')
        d.add_comment(a12, 'a12 - c1', { }, 'a12 - t1')
        d.add_comment(a12, 'a12 - c2', { }, 'a12 - t2')
        d.add_comment(a13, 'a13 - c1', { }, 'a13 - t1')
        
        d
      end

      it "should return all comments with default (empty) options" do
        q = d100.comments_query

        xl = [ 'a10 - t1', 'a11 - t1', 'a10 - t2', 'a12 - t1', 'a12 - t2', 'a13 - t1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support :only_authors" do
        q = d100.comments_query(only_authors: a10)
        xl = [ 'a10 - t1', 'a10 - t2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = d100.comments_query(only_authors: [ a10.fingerprint, a13.to_global_id.to_s ])
        xl = [ 'a10 - t1', 'a10 - t2', 'a13 - t1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support :except_authors" do
        q = d100.comments_query(except_authors: a10)
        xl = [ 'a11 - t1', 'a12 - t1', 'a12 - t2', 'a13 - t1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = d100.comments_query(except_authors: [ a10.fingerprint, a13.to_global_id.to_s ])
        xl = [ 'a11 - t1', 'a12 - t1', 'a12 - t2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support both :only_authors and :except_authors" do
        q = d100.comments_query(only_authors: [ a10, a12.fingerprint ], except_authors: a10)
        xl = [ 'a12 - t1', 'a12 - t2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end
    end

    context "on destroy" do
      it "should delete comments" do
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: d10.fingerprint)
        expect(q.count).to eql(0)
        
        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: d10.fingerprint)
        expect(q.count).to eql(1)
        
        d10_fp = d10.fingerprint
        d10.destroy
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: d10_fp)
        expect(q.count).to eql(0)
      end

      it "should delete nested comments" do
        d10_fp = d10.fingerprint
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: d10_fp)
        expect(q.count).to eql(0)
        
        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: 'contents1' } ] }, 'title1')
        c1_fp = c1.fingerprint
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: d10_fp)
        expect(q.count).to eql(1)

        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: c1_fp)
        expect(q.count).to eql(0)
        sc1 = c1.add_comment(a11, 'subcontents1', { ops: [ { insert: 'subcontents1' } ] }, 'subtitle1')
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: c1_fp)
        expect(q.count).to eql(1)

        d10.destroy
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: d10_fp)
        expect(q.count).to eql(0)
        q = Fl::Core::Comment::ActiveRecord::Comment.where('(commentable_fingerprint = :cfp)', cfp: c1_fp)
        expect(q.count).to eql(0)
      end
    end
  end

  describe "comment" do
    context "#add_comment" do
      it "should create an instance of an active record subcomment" do
        c1 = d10.add_comment(a10, 'contents1', { }, 'title1')
        expect(c1.comments.count).to eql(0)
        sc1 = c1.add_comment(a11, 'subcontents1', { }, 'subtitle1')

        expect(sc1).to be_a(Fl::Core::Comment::ActiveRecord::Comment)
        expect(sc1.valid?).to eql(true)
        expect(sc1.persisted?).to eql(true)
        expect(c1.comments.count).to eql(1)
      end
    end

    context "#comments_query" do
      let(:d100) { create(:test_datum_comment, owner: a10, title: 'd100.title', content: 'd100.content') }
      let(:c100) do
        c = d100.add_comment(a10, 'a10 - c1', { }, 'a10 - t1')
        c.add_comment(a10, 'a10 - sc1', { }, 'a10 - st1')
        c.add_comment(a11, 'a11 - sc1', { }, 'a11 - st1')
        c.add_comment(a10, 'a10 - sc2', { }, 'a10 - st2')
        c.add_comment(a12, 'a12 - sc1', { }, 'a12 - st1')
        c.add_comment(a12, 'a12 - sc2', { }, 'a12 - st2')
        c.add_comment(a13, 'a13 - sc1', { }, 'a13 - st1')
        
        c
      end

      it "should return all comments with default (empty) options" do
        q = c100.comments_query

        xl = [ 'a10 - st1', 'a11 - st1', 'a10 - st2', 'a12 - st1', 'a12 - st2', 'a13 - st1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support :only_authors" do
        q = c100.comments_query(only_authors: a10)
        xl = [ 'a10 - st1', 'a10 - st2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = c100.comments_query(only_authors: [ a10.fingerprint, a13.to_global_id.to_s ])
        xl = [ 'a10 - st1', 'a10 - st2', 'a13 - st1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support :except_authors" do
        q = c100.comments_query(except_authors: a10)
        xl = [ 'a11 - st1', 'a12 - st1', 'a12 - st2', 'a13 - st1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = c100.comments_query(except_authors: [ a10.fingerprint, a13.to_global_id.to_s ])
        xl = [ 'a11 - st1', 'a12 - st1', 'a12 - st2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support both :only_authors and :except_authors" do
        q = c100.comments_query(only_authors: [ a10, a12.fingerprint ], except_authors: a10)
        xl = [ 'a12 - st1', 'a12 - st2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end
    end
  end
end
