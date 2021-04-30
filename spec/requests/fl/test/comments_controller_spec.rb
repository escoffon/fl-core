require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe "Fl::Test::CommentsController", type: :request do
  let(:a10) { create(:test_actor, name: 'a10') }
  let(:a11) { create(:test_actor, name: 'a11') }
  let(:a12) { create(:test_actor, name: 'a12') }
  let(:a13) { create(:test_actor, name: 'a13') }

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

  let(:d200) do
    g = { }
    g[a10.fingerprint] = [ Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    g[a11.fingerprint] = [ Fl::Core::Access::Permission::Owner::NAME,
                           Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Access::Permission::Write::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    g[a12.fingerprint] = [ Fl::Core::Access::Permission::Read::NAME ]
    d = create(:test_datum_comment_two, owner: a10, content: 'd200.content', grants: g)
    d.add_comment(a10, 'd200 - a10 - c1', { ops: [ { insert: '' } ] }, 'd200 - a10 - t1')
    d.add_comment(a12, 'd200 - a12 - c1', { ops: [ { insert: '' } ] }, 'd200 - a12 - t1')
    d.add_comment(a13, 'd200 - a13 - c1', { ops: [ { insert: '' } ] }, 'd200 - a13 - t1')
        
    d
  end

  let(:d201) do
    g = { }
    g[a10.fingerprint] = [ Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    g[a11.fingerprint] = [ Fl::Core::Access::Permission::Owner::NAME,
                           Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Access::Permission::Write::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    g[a12.fingerprint] = [ Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    d = create(:test_datum_comment_two, owner: a10, content: 'd201.content', grants: g)
    d.add_comment(a11, 'd201 - a11 - c1', { ops: [ { insert: '' } ] }, 'd201 - a11 - t1')
    d.add_comment(a11, 'd201 - a11 - c2', { ops: [ { insert: '' } ] }, 'd201 - a11 - t2')
    d.add_comment(a12, 'd201 - a12 - c1', { ops: [ { insert: '' } ] }, 'd201 - a12 - t1')
        
    d
  end

  let(:d202) do
    g = { }
    g[a10.fingerprint] = [ Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    g[a11.fingerprint] = [ Fl::Core::Access::Permission::Owner::NAME,
                           Fl::Core::Access::Permission::Read::NAME,
                           Fl::Core::Access::Permission::Write::NAME,
                           Fl::Core::Comment::Permission::IndexComments::NAME,
                           Fl::Core::Comment::Permission::CreateComments::NAME ]
    create(:test_datum_comment_two, owner: a10, content: 'd202.content', grants: g)
  end

  def _contents(rl)
    rl.map do |r|
      if r.respond_to?(:contents)
        r.contents
      elsif r.is_a?(Hash)
        r['contents_html'] || r[:contents]
      else
        nil
      end
    end
  end
  
  def comments_url(fmt = :json)
    Rails.application.routes.url_helpers.fl_test_comments_path(format: fmt)
  end

  describe "GET /fl/core/comments" do
    it "should return an empty array with default query parameters" do
      dl = [ d100, d101, d102 ]
        
      get comments_url()
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(0)

      get comments_url(), headers: { currentUser: a10.fingerprint }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(0)
    end

    it "should return comments if the commentables:only filter is present" do
      dl = [ d100, d101, d102, d200, d201, d202 ]
        
      xl = [ 'd100 - a10 - c1', 'd100 - a11 - c1', 'd100 - a10 - c2', 'd100 - a12 - c1', 'd100 - a12 - c2', 'd100 - a13 - c1' ]
      get comments_url(), headers: { currentUser: a10.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d100.to_global_id.to_s ] } }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(p['comments']).to be_a(Array)
      expect(p['comments'][0]).to be_a(Hash)
      expect(p['comments'][0]).to include('commentable', 'author', 'title', 'contents_html', 'contents_json')
      expect(p['comments'][0]['commentable']).to be_a(Hash)
      expect(p['comments'][0]['author']).to be_a(Hash)
      expect(_contents(p['comments'])).to match_array(xl)
    end

    it "should return :num_comments in the :commentable hash" do
      dl = [ d100, d101, d102, d200, d201, d202 ]
        
      xl = [ 'd100 - a10 - c1', 'd100 - a11 - c1', 'd100 - a10 - c2', 'd100 - a12 - c1', 'd100 - a12 - c2', 'd100 - a13 - c1' ]
      get comments_url(), headers: { currentUser: a10.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d100.fingerprint ] } }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      cl = jr['payload']['comments']
      expect(cl[0]['commentable']).to include('num_comments')
    end

    it "should return comments if commentable does not support access control" do
      dl = [ d100, d101, d102, d200, d201, d202 ]

      xl = [ 'd100 - a10 - c1', 'd100 - a11 - c1', 'd100 - a10 - c2', 'd100 - a12 - c1', 'd100 - a12 - c2', 'd100 - a13 - c1' ]
      get comments_url(), params: {
            _q: {
              filters: { commentables: { only: [ d100.fingerprint ] } }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      xl = [ 'd101 - a10 - c1', 'd101 - a11 - c1', 'd101 - a11 - c2', 'd101 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a13.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d101.fingerprint, d102.to_global_id.to_s ] } }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)
    end

    it "should fail is user has no index_comments permission (1)" do
      dl = [ d100, d101, d102, d200, d201, d202 ]

      xl = [ 'd200 - a10 - c1', 'd200 - a12 - c1', 'd200 - a13 - c1' ]
      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint ] } } }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      get comments_url(), headers: { currentUser: a12.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint ] } } }
          }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')

      get comments_url(), headers: { currentUser: a13.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint ] } } }
          }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')

      get comments_url(), params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint ] } } }
          }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')
    end

    it "should fail is user has no index_comments permission (2)" do
      dl = [ d100, d101, d102, d200, d201, d202 ]

      get comments_url(), params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint, d201.to_global_id.to_s ] } } }
          }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')

      xl = [ 'd200 - a10 - c1', 'd200 - a12 - c1', 'd200 - a13 - c1',
             'd201 - a11 - c1', 'd201 - a11 - c2', 'd201 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint, d201.to_global_id.to_s ] } } }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      get comments_url(), headers: { currentUser: a12.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint, d201.fingerprint ] } } }
          }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')

      xl = [ 'd201 - a11 - c1', 'd201 - a11 - c2', 'd201 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a12.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d201.fingerprint ] } } }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      get comments_url(), headers: { currentUser: a13.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d200.fingerprint, d201.fingerprint, d101.fingerprint ] } } }
          }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')

      xl = [ 'd101 - a10 - c1', 'd101 - a11 - c1', 'd101 - a11 - c2', 'd101 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a13.fingerprint }, params: {
            _q: { filters: { commentables: { only: [ d101.fingerprint ] } } }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      xl = [ 'd101 - a10 - c1', 'd101 - a11 - c1', 'd101 - a11 - c2', 'd101 - a12 - c1' ]
      get comments_url(), params: {
            _q: { filters: { commentables: { only: [ d101.fingerprint ] } } }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)
    end

    it "should process the authors:only filter" do
      dl = [ d100, d101, d102, d200, d201, d202 ]

      xl = [ 'd201 - a11 - c1', 'd201 - a11 - c2' ]
      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: {
                commentables: { only: [ d200.fingerprint, d201.to_global_id.to_s ] },
                authors: { only: [ a11.fingerprint ] }
              }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      xl = [ 'd201 - a12 - c1', 'd101 - a10 - c1', 'd101 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a12.fingerprint }, params: {
            _q: {
              filters: {
                commentables: { only: [ d101.fingerprint, d201.fingerprint ] },
                authors: { only: [ a10.fingerprint, a12.to_global_id.to_s ] }
              }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)
    end

    it "should process :except_authors" do
      dl = [ d100, d101, d102, d200, d201, d202 ]

      xl = [ 'd101 - a11 - c1', 'd101 - a11 - c2', 'd101 - a12 - c1',
             'd200 - a12 - c1', 'd200 - a13 - c1',
             'd201 - a11 - c1', 'd201 - a11 - c2', 'd201 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: {
                commentables: { only: [ d200.fingerprint, d201.fingerprint, d101.fingerprint ] },
                authors: { except: [ a10.fingerprint ] }
              }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      xl = [ 'd101 - a11 - c1', 'd101 - a11 - c2', 'd101 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a13.fingerprint }, params: {
            _q: {
              filters: {
                commentables: { only: [ d101.fingerprint ] },
                authors: { except: [ a10.fingerprint ] }
              }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)

      xl = [ 'd101 - a10 - c1' ]
      get comments_url(), headers: { currentUser: a12.fingerprint }, params: {
            _q: {
              filters: {
                commentables: { only: [ d201.fingerprint, d101.fingerprint ] },
                authors: { except: [ a11.to_global_id.to_s, a12.fingerprint ] }
              }
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to match_array(xl)
    end

    it "should support the :order option" do
      dl = [ d100, d101, d102, d200, d201, d202 ]

      xl = [ 'd100 - a10 - c1', 'd100 - a11 - c1', 'd100 - a10 - c2', 'd100 - a12 - c1', 'd100 - a12 - c2', 'd100 - a13 - c1',
             'd201 - a11 - c1', 'd201 - a11 - c2', 'd201 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d201.fingerprint, d100.fingerprint ] } },
              order: 'contents_html asc'
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to eql(xl.sort)

      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d201.fingerprint, d100.fingerprint ] } },
              order: 'contents_html desc'
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(xl.count)
      expect(_contents(p['comments'])).to eql(xl.sort.reverse)
    end

    it "should support pagination" do
      dl = [ d100, d101, d102, d200, d201, d202 ]

      xl = [ 'd100 - a10 - c1', 'd100 - a11 - c1', 'd100 - a10 - c2', 'd100 - a12 - c1', 'd100 - a12 - c2', 'd100 - a13 - c1',
             'd201 - a11 - c1', 'd201 - a11 - c2', 'd201 - a12 - c1' ]
      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d201.fingerprint, d100.fingerprint ] } },
              order: 'contents_html asc', limit: 4, offset: 2
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(4)
      expect(_contents(p['comments'])).to eql(xl.sort[2, 4])

      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d201.fingerprint, d100.fingerprint ] } },
              order: 'contents_html asc', limit: 4
            }
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(4)
      expect(_contents(p['comments'])).to eql(xl.sort[0, 4])
      expect(p['_pg']).to be_a(Hash)
      expect(p['_pg']).to include('_s', '_p', '_c')
      expect(p['_pg']['_s']).to eql(4)
      expect(p['_pg']['_p']).to eql(2)
      expect(p['_pg']['_c']).to eql(4)

      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d201.fingerprint, d100.fingerprint ] } },
              order: 'contents_html asc'
            },
            _pg: p['_pg']
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(4)
      expect(_contents(p['comments'])).to eql(xl.sort[4, 4])
      expect(p['_pg']).to be_a(Hash)
      expect(p['_pg']).to include('_s', '_p', '_c')
      expect(p['_pg']['_s']).to eql(4)
      expect(p['_pg']['_p']).to eql(3)
      expect(p['_pg']['_c']).to eql(4)

      get comments_url(), headers: { currentUser: a11.fingerprint }, params: {
            _q: {
              filters: { commentables: { only: [ d201.fingerprint, d100.fingerprint ] } },
              order: 'contents_html asc'
            },
            _pg: p['_pg']
          }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      p = jr['payload']
      expect(p).to include('comments', '_pg')
      expect(p['comments']).to be_a(Array)
      expect(p['comments'].count).to eql(1)
      expect(_contents(p['comments'])).to eql(xl.sort[8, 1])
      expect(p['_pg']).to be_a(Hash)
      expect(p['_pg']).to include('_s', '_p', '_c')
      expect(p['_pg']['_s']).to eql(4)
      expect(p['_pg']['_p']).to eql(4)
      expect(p['_pg']['_c']).to eql(1)
    end
  end
  
  describe "POST /fl/core/comments" do
    let(:d100_params) do
      {
        commentable: d100.fingerprint,
        title: 'c.d100 - t1',
        contents_html: 'c.d100 - c1',
        contents_json: JSON.generate({ "ops" => [ { "insert" => 'c.d100 - c1' } ] })
      }
    end

    let(:d200_params) do
      {
        commentable: d200.fingerprint,
        title: 'c.d200 - t1',
        contents_html: 'c.d200 - c1',
        contents_json: JSON.generate({ "ops" => [ { "insert" => 'c.d200 - c1' } ] })
      }
    end

    it "should fail if not authenticated" do
      post comments_url, params: { fl_test_comment: d100_params }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')
    end

    it "should create a comment if authenticated and commentable does not support access control" do
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d100_params }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      expect(jr).to include('_status', 'payload')
      expect(jr['_status']).to be_a(Hash)
      expect(jr['payload']).to be_a(Hash)
      expect(jr['payload']).to include('comment')
      c = jr['payload']['comment']
      expect(c).to be_a(Hash)
      expect(c).to include('fingerprint', 'commentable', 'author', 'title', 'contents_html', 'contents_json')
      expect(c['commentable']).to be_a(Hash)
      expect(c['commentable']['fingerprint']).to eql(d100.fingerprint)
      expect(c['author']).to be_a(Hash)
      expect(c['author']['fingerprint']).to eql(a10.fingerprint)
      expect(c['title']).to eql(d100_params[:title])
      expect(c['contents_html']).to eql(d100_params[:contents_html])
      expect(c['contents_json']).to be_a(String)
      expect(JSON.parse(c['contents_json'])).to eql(JSON.parse(d100_params[:contents_json]))
    end

    it "should create a comment if user has create permission" do
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d200_params }
      expect(response).to have_http_status(:ok)
      jr = JSON.parse(response.body)
      c = jr['payload']['comment']
      expect(c['commentable']['fingerprint']).to eql(d200.fingerprint)
      expect(c['author']['fingerprint']).to eql(a10.fingerprint)
      expect(c['title']).to eql(d200_params[:title])
      expect(c['contents_html']).to eql(d200_params[:contents_html])
      expect(c['contents_json']).to be_a(String)
      expect(JSON.parse(c['contents_json'])).to eql(JSON.parse(d200_params[:contents_json]))
    end

    it "should fail if user does not have create permission" do
      post comments_url, headers: { currentUser: a12.fingerprint }, params: { fl_test_comment: d200_params }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')

      post comments_url, headers: { currentUser: a13.fingerprint }, params: { fl_test_comment: d200_params }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')
    end
    
    it "should fail on a missing :commentable param" do
      d = d200_params.dup
      d.delete(:commentable)
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')

      d = d100_params.dup
      d.delete(:commentable)
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:forbidden)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message')
    end
    
    it "should fail on a missing :contents_html param" do
      d = d200_params.dup
      d.delete(:contents_html)
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:unprocessable_entity)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']).to include('type', 'message', 'details')
      expect(jr['_error']['details']).to be_a(Hash)
      expect(jr['_error']['details']).to include('messages', 'full_messages')
      expect(jr['_error']['details']['messages']).to be_a(Hash)
      expect(jr['_error']['details']['messages']).to include('contents_html')

      d = d100_params.dup
      d.delete(:contents_html)
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:unprocessable_entity)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']['details']).to include('messages', 'full_messages')
      expect(jr['_error']['details']['messages']).to be_a(Hash)
      expect(jr['_error']['details']['messages']).to include('contents_html')
    end
    
    it "should fail on a missing :contents_json param" do
      d = d200_params.dup
      d.delete(:contents_json)
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:unprocessable_entity)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']['details']).to include('messages', 'full_messages')
      expect(jr['_error']['details']['messages']).to be_a(Hash)
      expect(jr['_error']['details']['messages']).to include('contents_json')

      d = d100_params.dup
      d.delete(:contents_json)
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:unprocessable_entity)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']['details']).to include('messages', 'full_messages')
      expect(jr['_error']['details']['messages']).to be_a(Hash)
      expect(jr['_error']['details']['messages']).to include('contents_json')
    end
    
    it "should fail on an invalid :contents_json param" do
      d = d200_params.dup
      d[:contents_json] = JSON.generate([ 1 ])
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:unprocessable_entity)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']['details']).to include('messages', 'full_messages')
      expect(jr['_error']['details']['messages']).to be_a(Hash)
      expect(jr['_error']['details']['messages']).to include('contents_json')

      d = d100_params.dup
      d[:contents_json] = JSON.generate("string value")
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:unprocessable_entity)
      jr = JSON.parse(response.body)
      expect(jr).to include('_error')
      expect(jr['_error']).to be_a(Hash)
      expect(jr['_error']['details']).to include('messages', 'full_messages')
      expect(jr['_error']['details']['messages']).to be_a(Hash)
      expect(jr['_error']['details']['messages']).to include('contents_json')

      # the validation is now much more lenient, since we don't make any assumptions about the structure
      # of the JSON contents
      
      d = d100_params.dup
      d[:contents_json] = JSON.generate({ foo: 10 })
      post comments_url, headers: { currentUser: a10.fingerprint }, params: { fl_test_comment: d }
      expect(response).to have_http_status(:ok)
    end
  end
end
