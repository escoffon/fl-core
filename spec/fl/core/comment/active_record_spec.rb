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
      expect(Fl::Test::Comment.commentable?).to eql(true)
    end
  end

  describe "#commentable?" do
    it "should return true for comment objects" do
      c1 = Fl::Core::Comment::ActiveRecord::Comment.create(
        author: a10,
        commentable: d10,
        contents_html: 'contents1',
        contents_json: { ops: [ { insert: '' } ] }
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
        contents_html: 'contents1',
        contents_json: { ops: [ { insert: '' } ] }
      )
      expect(c1.valid?).to eql(true)
      expect(c1.save).to eql(true)
      expect(c1.title).to eql('contents1')
    end

    it 'should accept the :is_visible attribute' do
      c1 = Fl::Core::Comment::ActiveRecord::Comment.create(
        is_visible: true,
        author: a10,
        commentable: d10,
        contents_html: 'contents1',
        contents_json: { ops: [ { insert: '' } ] }
      )
      expect(c1.valid?).to eql(true)
      expect(c1.is_visible).to eql(true)

      c2 = Fl::Core::Comment::ActiveRecord::Comment.create(
        is_visible: false,
        author: a10,
        commentable: d10,
        contents_html: 'contents2',
        contents_json: { ops: [ { insert: '' } ] }
      )
      expect(c2.valid?).to eql(true)
      expect(c2.is_visible).to eql(false)
    end
    
    it 'should populate the :is_visible attribute if not present' do
      c1 = Fl::Core::Comment::ActiveRecord::Comment.new(
        author: a10,
        commentable: d10,
        contents_html: 'contents1',
        contents_json: { ops: [ { insert: '' } ] }
      )
      expect(c1.valid?).to eql(true)
      expect(c1.is_visible).to be_nil
      expect(c1.save).to eql(true)
      expect(c1.is_visible).to eql(true)

      c2 = Fl::Core::Comment::ActiveRecord::Comment.create(
        author: a10,
        commentable: d10,
        contents_html: 'contents2',
        contents_json: { ops: [ { insert: '' } ] }
      )
      expect(c2.valid?).to eql(true)
      expect(c2.is_visible).to eql(true)
    end
    
    it "should populate the _fingerprint attributes" do
      expect(d10.comments.count).to eql(0)

      c1 = Fl::Core::Comment::ActiveRecord::Comment.new(
        author: a10,
        commentable: d10,
        contents_html: 'contents1',
        contents_json: { ops: [ { insert: '' } ] }
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
        contents_html: 'contents1',
        contents_json: { ops: [ { insert: '' } ] },
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

        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: '' } ] }, 'title1')
        expect(c1).to be_a(Fl::Core::Comment::ActiveRecord::Comment)
        expect(c1.valid?).to eql(true)
        expect(c1.persisted?).to eql(true)
        expect(d10.comments.count).to eql(1)
      end
    end

    context "#comments_query" do
      let(:d100) do
        d = create(:test_datum_comment, owner: a10, title: 'd100.title', content: 'd100.content')
        d.add_comment(a10, 'a10 - c1', { ops: [ { insert: '' } ] }, 'a10 - t1')
        d.add_comment(a11, 'a11 - c1', { ops: [ { insert: '' } ] }, 'a11 - t1')
        d.add_comment(a10, 'a10 - c2', { ops: [ { insert: '' } ] }, 'a10 - t2')
        d.add_comment(a12, 'a12 - c1', { ops: [ { insert: '' } ] }, 'a12 - t1')
        d.add_comment(a12, 'a12 - c2', { ops: [ { insert: '' } ] }, 'a12 - t2')
        d.add_comment(a13, 'a13 - c1', { ops: [ { insert: '' } ] }, 'a13 - t1')
        
        d
      end

      it "should return all comments with default (empty) options" do
        q = d100.comments_query

        xl = [ 'a10 - t1', 'a11 - t1', 'a10 - t2', 'a12 - t1', 'a12 - t2', 'a13 - t1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support the :authors:only filter" do
        q = d100.comments_query(filters: { authors: { only: a10 } })
        xl = [ 'a10 - t1', 'a10 - t2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = d100.comments_query(filters: { authors: { only: [ a10.fingerprint, a13.to_global_id.to_s ] } })
        xl = [ 'a10 - t1', 'a10 - t2', 'a13 - t1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support the :authors:except filter" do
        q = d100.comments_query(filters: { authors: { except: a10 } })
        xl = [ 'a11 - t1', 'a12 - t1', 'a12 - t2', 'a13 - t1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = d100.comments_query(filters: { authors: { except: [ a10.fingerprint, a13.to_global_id.to_s ] } })
        xl = [ 'a11 - t1', 'a12 - t1', 'a12 - t2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support both :authors:only and :authors:except" do
        q = d100.comments_query(filters: { authors: { only: [ a10, a12.fingerprint ], except: a10 } })
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
    context "validation" do
      it "should detect a missing :commentable attribute" do
        c1 = Fl::Core::Comment::ActiveRecord::Comment.new(author: a10, contents_html: 'c1 -c',
                                                          contents_json: { ops: [ { insert: 'c1 - c' } ] })
        expect(c1.valid?).to eql(false)
        expect(c1.errors.messages).to include(:commentable)
      end

      it "should detect a missing :author attribute" do
        c1 = Fl::Core::Comment::ActiveRecord::Comment.new(commentable: d10, contents_html: 'c1 -c',
                                                          contents_json: { ops: [ { insert: 'c1 - c' } ] })
        expect(c1.valid?).to eql(false)
        expect(c1.errors.messages).to include(:author)
      end

      it "should detect a missing :contents_html attribute" do
        c1 = Fl::Core::Comment::ActiveRecord::Comment.new(commentable: d10, author: a10,
                                                          contents_json: { ops: [ { insert: 'c1 - c' } ] })
        expect(c1.valid?).to eql(false)
        expect(c1.errors.messages).to include(:contents_html)
      end

      it "should detect a missing :contents_json attribute" do
        c1 = Fl::Core::Comment::ActiveRecord::Comment.new(commentable: d10, author: a10,
                                                          contents_html: 'c1 -c')
        expect(c1.valid?).to eql(false)
        expect(c1.errors.messages).to include(:contents_json)
      end

      it "should detect an invalid :contents_json attribute" do
        c1 = Fl::Core::Comment::ActiveRecord::Comment.new(commentable: d10, author: a10,
                                                          contents_html: 'c1 -c',
                                                          contents_json: [ 1 ])
        expect(c1.valid?).to eql(false)
        expect(c1.errors.messages).to include(:contents_json)

        c1 = Fl::Core::Comment::ActiveRecord::Comment.new(commentable: d10, author: a10,
                                                          contents_html: 'c1 -c',
                                                          contents_json: { foo: 10 })
        expect(c1.valid?).to eql(true)
      end
    end
    
    context "#add_comment" do
      it "should create an instance of an active record subcomment" do
        c1 = d10.add_comment(a10, 'contents1', { ops: [ { insert: '' } ] }, 'title1')
        expect(c1.comments.count).to eql(0)
        sc1 = c1.add_comment(a11, 'subcontents1', { ops: [ { insert: '' } ] }, 'subtitle1')

        expect(sc1).to be_a(Fl::Core::Comment::ActiveRecord::Comment)
        expect(sc1.valid?).to eql(true)
        expect(sc1.persisted?).to eql(true)
        expect(c1.comments.count).to eql(1)
      end
    end

    context '#to_hash' do
      let(:id_keys) { [ :type, :global_id, :api_root, :fingerprint, :id, :virtual_type ] }
      let(:min_keys) { id_keys | [ :created_at, :updated_at, :permissions,
                                   :commentable, :author, :title, :contents_html, :contents_json ] }
      let(:std_keys) { min_keys | [ ] }
      let(:vrb_keys) { std_keys | [ ] }
      let(:cmp_keys) { vrb_keys | [ ] }

      let(:c1) do
        Fl::Core::Comment::ActiveRecord::Comment.create(
          author: a10,
          commentable: d10,
          contents_html: 'contents1',
          contents_json: { ops: [ { insert: '' } ] }
        )
      end

      it 'should list properties based on verbosity' do
        h = c1.to_hash(a10, { verbosity: :id })
        expect(h.keys.sort).to eql(id_keys.sort)
        expect(h[:id]).to eql(c1.id)
        expect(h[:type]).to eql(c1.class.name)
        expect(h[:global_id]).to eql(c1.to_global_id.to_s)
        expect(h[:fingerprint]).to eql(c1.fingerprint)

        h = c1.to_hash(a10, { verbosity: :minimal })
        expect(h.keys.sort).to eql(min_keys.sort)
        expect(h[:author]).to be_a(Hash)
        expect(h[:author][:fingerprint]).to eql(a10.fingerprint)
        expect(h[:commentable]).to be_a(Hash)
        expect(h[:commentable][:fingerprint]).to eql(d10.fingerprint)
        expect(h[:title]).to eql(c1.title)
        expect(h[:contents_html]).to eql(c1.contents_html)
        expect(h[:contents_json]).to be_a(String)
        expect(JSON.parse(h[:contents_json])).to eql(c1.contents_json)
        
        h = c1.to_hash(a10, { verbosity: :standard })
        expect(h.keys.sort).to eql(std_keys.sort)

        h = c1.to_hash(a10, { verbosity: :verbose })
        expect(h.keys.sort).to eql(vrb_keys.sort)
        
        h = c1.to_hash(a10, { verbosity: :complete })
        expect(h.keys.sort).to eql(cmp_keys.sort)

        h = c1.to_hash(a10, { verbosity: :ignore })
        expect(h.keys.sort).to eq(id_keys.sort)
      end

      it 'should always include :num_comments in :commentable' do
        h = c1.to_hash(a10, { verbosity: :minimal })
        expect(h.keys).to match_array(min_keys)
        expect(h[:commentable]).to include(:num_comments)

        h = c1.to_hash(a10, {
                         verbosity: :minimal,
                         to_hash: {
                           commentable: {
                             verbosity: :id,
                             include: [ :title ]
                           }
                         }
                       })
        expect(h.keys).to match_array(min_keys)
        expect(h[:commentable]).to include(:num_comments, :title)

        h = c1.to_hash(a10, {
                         verbosity: :minimal,
                         to_hash: {
                           commentable: {
                             verbosity: :id,
                             include: [ :num_comments ]
                           }
                         }
                       })
        expect(h.keys).to match_array(min_keys)
        expect(h[:commentable]).to include(:num_comments)

        h = c1.to_hash(a10, {
                         verbosity: :minimal,
                         to_hash: {
                           commentable: {
                             verbosity: :id,
                             include: [ :title, :num_comments ]
                           }
                         }
                       })
        expect(h.keys).to match_array(min_keys)
        expect(h[:commentable]).to include(:num_comments, :title)
      end

      it 'allows customization of key lists' do
        c_keys = id_keys | [ :title ]
        h = c1.to_hash(a10, { verbosity: :id, include: [ :title ] })
        expect(h.keys).to match_array(c_keys)

        c_keys = id_keys | [ :title ]
        h = c1.to_hash(a10, { verbosity: :id, only: [ :title ] })
        expect(h.keys).to match_array(c_keys)

        c_keys = min_keys - [ :title, :author ]
        h = c1.to_hash(a10, { verbosity: :minimal, except: [ :title, :author ] })
        expect(h.keys).to match_array(c_keys)
      end
    end

    context ".build_query" do
      let(:cc) { Fl::Core::Comment::ActiveRecord::Comment }
      
      let(:d100) do
        d = create(:test_datum_comment, owner: a10, title: 'd100.title', content: 'd100.content')
        d.add_comment(a10, 'd100 - a10 - c1', { ops: [ { insert: '' } ] }, 'd100 - a10 - t1')
        d.add_comment(a11, 'd100 - a11 - c1', { ops: [ { insert: '' } ] }, 'd100 - a11 - t1')
        d.add_comment(a10, 'd100 - a10 - c2', { ops: [ { insert: '' } ] }, 'd100 - a10 - t2')
        d.add_comment(a12, 'd100 - a12 - c1', { ops: [ { insert: '' } ] }, 'd100 - a12 - t1')
        d.add_comment(a12, 'd100 - a12 - c2', { ops: [ { insert: '' } ] }, 'd100 - a12 - t2')
        d.add_comment(a13, 'd100 - a13 - c1', { ops: [ { insert: '' } ] }, 'd100 - a13 - t1')
        
        d
      end

      let(:d101) do
        d = create(:test_datum_comment, owner: a10, title: 'd101.title', content: 'd101.content')
        d.add_comment(a10, 'd101 - a10 - c1', { ops: [ { insert: '' } ] }, 'd101 - a10 - t1')
        d.add_comment(a11, 'd101 - a11 - c1', { ops: [ { insert: '' } ] }, 'd101 - a11 - t1')
        d.add_comment(a11, 'd101 - a11 - c2', { ops: [ { insert: '' } ] }, 'd101 - a11 - t2')
        d.add_comment(a12, 'd101 - a12 - c1', { ops: [ { insert: '' } ] }, 'd101 - a12 - t1')
        
        d
      end

      let(:d102) do
        create(:test_datum_comment, owner: a10, title: 'd102.title', content: 'd102.content')
      end

      it "should return all comments with default (empty) options" do
        dl = [ d100, d101, d102 ]
        
        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1',
               'd101 - a10 - t1', 'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support the :visibility filter" do
        d = create(:test_datum_comment, owner: a10, title: 'd100.title', content: 'd100.content')
        d1 = d.add_comment(a10, 'd100 - a10 - c1', { ops: [ { insert: '' } ] }, 'd100 - a10 - t1')
        d2 = d.add_comment(a11, 'd100 - a11 - c1', { ops: [ { insert: '' } ] }, 'd100 - a11 - t1')
        d3 = d.add_comment(a10, 'd100 - a10 - c2', { ops: [ { insert: '' } ] }, 'd100 - a10 - t2')
        d4 = d.add_comment(a12, 'd100 - a12 - c1', { ops: [ { insert: '' } ] }, 'd100 - a12 - t1')
        d5 = d.add_comment(a12, 'd100 - a12 - c2', { ops: [ { insert: '' } ] }, 'd100 - a12 - t2')
        d6 = d.add_comment(a13, 'd100 - a13 - c1', { ops: [ { insert: '' } ] }, 'd100 - a13 - t1')

        
        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2',
               'd100 - a13 - t1' ]
        q = cc.build_query(filters: { visibility: :both })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = cc.build_query(filters: { visibility: :nil })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        expect(d1.update(is_visible: false)).to eql(true)
        expect(d4.update(is_visible: false)).to eql(true)
        
        xl = [ 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t2', 'd100 - a13 - t1' ]
        q = cc.build_query(filters: { visibility: :visible })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd100 - a10 - t1', 'd100 - a12 - t1' ]
        q = cc.build_query(filters: { visibility: :hidden })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support the :commentables:only filter" do
        dl = [ d100, d101, d102 ]
        
        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1' ]
        q = cc.build_query(filters: { commentables: { only: d100 } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd101 - a10 - t1', 'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query(filters: { commentables: { only: d101.fingerprint } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1',
               'd101 - a10 - t1', 'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query(filters: { commentables: { only: [ d100.fingerprint, d101.to_global_id,
                                                              d102.to_global_id.to_s ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ ]
        q = cc.build_query(filters: { commentables: { only: [ d102.to_global_id.to_s ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support the :commentables:except filter" do
        dl = [ d100, d101, d102 ]
        
        xl = [ 'd101 - a10 - t1', 'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query(filters: { commentables: { except: d100 } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1' ]
        q = cc.build_query(filters: { commentables: { except: d101.fingerprint } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ ]
        q = cc.build_query(filters: { commentables: { except: [ d100.fingerprint, d101.to_global_id,
                                                                d102.to_global_id.to_s ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1',
               'd101 - a10 - t1', 'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query(filters: { commentables: { except: [ d102.to_global_id.to_s ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end
      
      it "should support the :authors:only filter" do
        dl = [ d100, d101, d102 ]

        xl = [ 'd100 - a10 - t1', 'd100 - a10 - t2', 'd101 - a10 - t1' ]
        q = cc.build_query(filters: { authors: { only: [ a10.to_global_id.to_s ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd100 - a10 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2',
               'd101 - a10 - t1', 'd101 - a12 - t1' ]
        q = cc.build_query(filters: { authors: { only: [ a10.to_global_id.to_s, a12.fingerprint ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support the :authors:except filter" do
        dl = [ d100, d101, d102 ]

        xl = [ 'd100 - a11 - t1', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1',
               'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query(filters: { authors: { except: [ a10.to_global_id.to_s ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd100 - a11 - t1', 'd100 - a13 - t1',
               'd101 - a11 - t1', 'd101 - a11 - t2' ]
        q = cc.build_query(filters: { authors: { except: [ a10.to_global_id.to_s, a12.fingerprint ] } })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support combinations of :commentables and :authors" do
        dl = [ d100, d101, d102 ]
        
        xl = [ 'd100 - a10 - t1', 'd100 - a10 - t2' ]
        q = cc.build_query(filters: {
                             commentables: { only: [ d100.to_global_id.to_s ] },
                             authors: { only: a10.fingerprint }
                           })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd100 - a11 - t1', 'd100 - a13 - t1',
               'd101 - a11 - t1', 'd101 - a11 - t2' ]
        q = cc.build_query(filters: {
                             commentables: { except: [ d102.to_global_id.to_s ] },
                             authors: { only: [ a11, a13.to_global_id ] }
                           })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        xl = [ 'd101 - a10 - t1', 'd101 - a12 - t1' ]
        q = cc.build_query(filters: {
                             commentables: { except: [ d100.to_global_id.to_s ] },
                             authors: { except: [ a11, a13.to_global_id ] }
                           })
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support sorting" do
        dl = [ d100, d101, d102 ]

        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1',
               'd101 - a10 - t1', 'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query(order: "title asc")
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to eql(xl.sort)

        q = cc.build_query(order: "title desc")
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to eql(xl.sort.reverse)
      end

      it "should support pagination" do
        dl = [ d100, d101, d102 ]

        xl = [ 'd100 - a10 - t1', 'd100 - a11 - t1', 'd100 - a10 - t2', 'd100 - a12 - t1', 'd100 - a12 - t2', 'd100 - a13 - t1',
               'd101 - a10 - t1', 'd101 - a11 - t1', 'd101 - a11 - t2', 'd101 - a12 - t1' ]
        q = cc.build_query(order: "title asc", limit: 2, offset: 2)
        expect(q.count).to eql(2)
        expect(_clist(q)).to eql(xl.sort[2, 2])
      end
    end

    context "#comments_query" do
      let(:d100) { create(:test_datum_comment, owner: a10, title: 'd100.title', content: 'd100.content') }
      let(:c100) do
        c = d100.add_comment(a10, 'a10 - c1', { ops: [ { insert: '' } ] }, 'a10 - t1')
        c.add_comment(a10, 'a10 - sc1', { ops: [ { insert: '' } ] }, 'a10 - st1')
        c.add_comment(a11, 'a11 - sc1', { ops: [ { insert: '' } ] }, 'a11 - st1')
        c.add_comment(a10, 'a10 - sc2', { ops: [ { insert: '' } ] }, 'a10 - st2')
        c.add_comment(a12, 'a12 - sc1', { ops: [ { insert: '' } ] }, 'a12 - st1')
        c.add_comment(a12, 'a12 - sc2', { ops: [ { insert: '' } ] }, 'a12 - st2')
        c.add_comment(a13, 'a13 - sc1', { ops: [ { insert: '' } ] }, 'a13 - st1')
        
        c
      end

      it "should return all comments with default (empty) options" do
        q = c100.comments_query

        xl = [ 'a10 - st1', 'a11 - st1', 'a10 - st2', 'a12 - st1', 'a12 - st2', 'a13 - st1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support :only_authors" do
        q = c100.comments_query(filters: { authors: { only: a10 } })
        xl = [ 'a10 - st1', 'a10 - st2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = c100.comments_query(filters: { authors: { only: [ a10.fingerprint, a13.to_global_id.to_s ] } })
        xl = [ 'a10 - st1', 'a10 - st2', 'a13 - st1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support :except_authors" do
        q = c100.comments_query(filters: { authors: { except: a10 } })
        xl = [ 'a11 - st1', 'a12 - st1', 'a12 - st2', 'a13 - st1' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)

        q = c100.comments_query(filters: { authors: { except: [ a10.fingerprint, a13.to_global_id.to_s ] } })
        xl = [ 'a11 - st1', 'a12 - st1', 'a12 - st2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end

      it "should support both :authors:only and :authors:except" do
        q = c100.comments_query(filters: {
                                  authors: { only: [ a10, a12.fingerprint ], except: a10 }
                                })
        xl = [ 'a12 - st1', 'a12 - st2' ]
        expect(q.count).to eql(xl.count)
        expect(_clist(q)).to match_array(xl)
      end
    end
  end
end
