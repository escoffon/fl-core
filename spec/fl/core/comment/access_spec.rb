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
  let(:d21) do
    g = { }
    g[a10.fingerprint] = [ Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    g[a11.fingerprint] = [ Fl::Core::Access::Permission::Owner::NAME,
                           Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Access::Permission::Write::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]


    create(:test_datum_comment_two, owner: a11, content: d21_content, grants: g)
  end

  let(:c_d10_a10) { d10.add_comment(a10, 'c - d10 - a10', { ops: [ { insert: '' } ] }, 't - d10 - a10') }
  let(:c_d10_a11) { d10.add_comment(a11, 'c - d10 - a11', { ops: [ { insert: '' } ] }, 't - d10 - a11') }

  let(:c_d20_a10) { d20.add_comment(a10, 'c - d20 - a10', { ops: [ { insert: '' } ] }, 't - d20 - a10') }
  let(:c_d20_a11) { d20.add_comment(a11, 'c - d20 - a11', { ops: [ { insert: '' } ] }, 't - d20 - a11') }

  let(:c_d21_a10) { d21.add_comment(a10, 'c - d21 - a10', { ops: [ { insert: '' } ] }, 't - d21 - a10') }
  let(:c_d21_a11) { d21.add_comment(a11, 'c - d21 - a11', { ops: [ { insert: '' } ] }, 't - d21 - a11') }

  let(:sc1_d10_a10) { c_d10_a10.add_comment(a10, 'sc1 - d10 - a10', { ops: [ { insert: '' } ] }, 'st1 - d10 - a10') }
  let(:sc2_d10_a10) { c_d10_a10.add_comment(a11, 'sc2 - d10 - a11', { ops: [ { insert: '' } ] }, 'st2 - d10 - a11') }

  let(:sc1_d20_a10) { c_d20_a10.add_comment(a10, 'sc1 - d20 - a10', { ops: [ { insert: '' } ] }, 'st1 - d20 - a10') }
  let(:sc2_d20_a10) { c_d20_a10.add_comment(a11, 'sc2 - d20 - a11', { ops: [ { insert: '' } ] }, 'st2 - d20 - a11') }

  let(:sc1_d21_a10) { c_d21_a10.add_comment(a10, 'sc1 - d21 - a10', { ops: [ { insert: '' } ] }, 'st1 - d21 - a10') }
  let(:sc2_d21_a10) { c_d21_a10.add_comment(a11, 'sc2 - d21 - a11', { ops: [ { insert: '' } ] }, 'st2 - d21 - a11') }

  describe "access check" do
    context "comments" do
      it "should grant read access to a comment if actor can read the commentable" do
        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)

        expect(c_d21_a10.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)
        expect(c_d21_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)

        expect(c_d21_a11.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)
        expect(c_d21_a11.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)
      end

      it "should not grant read access to a comment if actor cannot read the commentable" do
        expect(d20.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(false)
        expect(c_d20_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(false)
        # This is true because a11 is the author of c_d20_a11
        expect(c_d20_a11.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)

        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
        expect(c_d21_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
        expect(c_d21_a11.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
      end

      it "should grant read access to a comment if commentable is not under access control" do
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(true)

        expect(c_d10_a11.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)
        expect(c_d10_a11.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)
        expect(c_d10_a11.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(true)
      end

      it "should not grant write access to a comment" do
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Write, a10)).to eql(false)
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Write, a11)).to eql(false)
      end

      it "should not grant write delete to a comment" do
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Delete, a10)).to eql(false)
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Delete, a11)).to eql(false)
      end

      it "should grant comment index access to a comment if actor can read the commentable" do
        expect(d21.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)

        expect(c_d21_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)
        expect(c_d21_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)

        expect(c_d21_a11.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)
        expect(c_d21_a11.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)
      end

      it "should not grant comment index access to a comment if actor cannot read the commentable" do
        expect(d20.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(false)
        expect(c_d20_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(false)
        # This is true because a11 is the author of c_d20_a11
        expect(c_d20_a11.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)

        expect(d21.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(false)
        expect(c_d21_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(false)
        expect(c_d21_a11.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(false)
      end

      it "should grant comment index access to a comment if commentable is not under access control" do
        expect(c_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)
        expect(c_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(true)

        expect(c_d10_a11.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)
        expect(c_d10_a11.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)
        expect(c_d10_a11.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(true)
      end

      it "should grant comment create access to a comment if actor can read the commentable" do
        expect(d21.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)

        expect(c_d21_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)
        expect(c_d21_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)

        expect(c_d21_a11.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)
        expect(c_d21_a11.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)
      end

      it "should not grant comment create access to a comment if actor cannot read the commentable" do
        expect(d20.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(false)
        expect(c_d20_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(false)
        # This is true because a11 is the author of c_d20_a11
        expect(c_d20_a11.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)

        expect(d21.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(false)
        expect(c_d21_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(false)
        expect(c_d21_a11.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(false)
      end

      it "should grant comment create access to a comment if commentable is not under access control" do
        expect(c_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)
        expect(c_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)
        expect(c_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(true)

        expect(c_d10_a11.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)
        expect(c_d10_a11.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)
        expect(c_d10_a11.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(true)
      end
    end

    context "nested comments" do
      it "should grant read access to a nested comment if actor can read the comment" do
        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)

        expect(sc1_d21_a10.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)
        expect(sc2_d21_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)
      end

      it "should not grant read access to a nested comment if actor cannot read the comment" do
        expect(d20.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(false)
        expect(sc1_d20_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(false)
        # this is true because a11 is the subcomment's author
        expect(sc2_d20_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)

        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
        expect(sc1_d21_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
        expect(sc2_d21_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
      end

      it "should grant read access to a nested comment if the top level commentable is not under access control" do
        expect(sc1_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)
        expect(sc1_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)
        expect(sc1_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(true)

        expect(sc2_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)
        expect(sc2_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(true)
        expect(sc2_d10_a10.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(true)
      end

      it "should grant index comments access to a nested comment if actor can read the comment" do
        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)

        expect(sc1_d21_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)
        expect(sc2_d21_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)
      end

      it "should not grant index comments access to a nested comment if actor cannot read the comment" do
        expect(d20.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(false)
        expect(sc1_d20_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(false)
        # this is true because a11 is the subcomment's author
        expect(sc2_d20_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)

        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
        expect(sc1_d21_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(false)
        expect(sc2_d21_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(false)
      end

      it "should grant index comments access to a nested comment if the top level commentable is not under access control" do
        expect(sc1_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)
        expect(sc1_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)
        expect(sc1_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(true)

        expect(sc2_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a10)).to eql(true)
        expect(sc2_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a11)).to eql(true)
        expect(sc2_d10_a10.has_permission?(Fl::Core::Comment::Permission::IndexComments, a12)).to eql(true)
      end

      it "should grant create comments access to a nested comment if actor can read the comment" do
        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a10)).to eql(true)

        expect(sc1_d21_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)
        expect(sc2_d21_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)
      end

      it "should not grant create comments access to a nested comment if actor cannot read the comment" do
        expect(d20.has_permission?(Fl::Core::Access::Permission::Read, a11)).to eql(false)
        expect(sc1_d20_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(false)
        # this is true because a11 is the subcomment's author
        expect(sc2_d20_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)

        expect(d21.has_permission?(Fl::Core::Access::Permission::Read, a12)).to eql(false)
        expect(sc1_d21_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(false)
        expect(sc2_d21_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(false)
      end

      it "should grant create comments access to a nested comment if the top level commentable is not under access control" do
        expect(sc1_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)
        expect(sc1_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)
        expect(sc1_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(true)

        expect(sc2_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a10)).to eql(true)
        expect(sc2_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a11)).to eql(true)
        expect(sc2_d10_a10.has_permission?(Fl::Core::Comment::Permission::CreateComments, a12)).to eql(true)
      end
    end
  end
end
