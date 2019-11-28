RSpec.configure do |c|
#  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe Fl::Core::ModelHash do
  describe '#to_hash' do
    let(:o1) do
      o1 = Fl::Core::TestDatumOne.create(title: 'o1 title', content: 'o1 content')
      o1.details << o1.details.create(title: 'o1_t1 title', content: 'o1_t1 content')
      o1.details << o1.details.create(title: 'o1_t2 title', content: 'o1_t2 content')
      o1
    end

    let(:id_keys) { [ :id, :type, :api_root, :fingerprint ] }
    let(:min_keys) { id_keys | [ :created_at, :updated_at, :title, :content ] }
    let(:complete_keys) { min_keys | [ :details ] }

    it 'should list properties based on verbosity' do
      h = o1.to_hash(nil, { verbosity: :id })
      expect(h.keys.sort).to match_array(id_keys.sort)
      expect(h[:id]).to eql(o1.id)
      expect(h[:type]).to eql(o1.class.name)

      min_keys = id_keys | [ :created_at, :updated_at, :title, :content ]
      h = o1.to_hash(nil, { verbosity: :minimal })
      expect(h.keys).to match_array(min_keys)
      expect(h[:title]).to eql(o1.title)

      std_keys = min_keys | [ ]
      h = o1.to_hash(nil, { verbosity: :standard })
      expect(h.keys).to match_array(std_keys)

      vrb_keys = std_keys | [ :details ]
      h = o1.to_hash(nil, { verbosity: :verbose })
      expect(h.keys).to match_array(vrb_keys)
      expect(h[:details]).to be_a(Array)
      expect(h[:details].count).to eql(o1.details.count)
      d0 = h[:details][0]
      expect(d0[:type]).to eql(Fl::Core::TestDatumSub.name)
      
      cmp_keys = vrb_keys | [ ]
      h = o1.to_hash(nil, { verbosity: :complete })
      expect(h.keys).to match_array(cmp_keys)

      h = o1.to_hash(nil, { verbosity: :ignore })
      expect(h.keys).to match_array(id_keys)
    end
    
    it 'allows customization of key lists' do
      c_keys = id_keys | [ :title ]
      h = o1.to_hash(nil, { verbosity: :id, include: [ :title ] })
      expect(h.keys).to match_array(c_keys)

      c_keys = id_keys | [ :content ]
      h = o1.to_hash(nil, { verbosity: :id, only: [ :content ] })
      expect(h.keys).to match_array(c_keys)

      c_keys = min_keys - [ :content ]
      h = o1.to_hash(nil, { verbosity: :minimal, except: [ :content ] })
      expect(h.keys).to match_array(c_keys)

      c_keys = complete_keys - [ :content ]
      h = o1.to_hash(nil, { verbosity: :complete, except: [ :content ] })
      expect(h.keys).to match_array(c_keys)
    end

    it 'customizes key list for subobjects' do
      t_std_keys = id_keys | [ :created_at, :updated_at, :title, :content, :master ]
      
      h = o1.to_hash(nil, { verbosity: :complete })
      expect(h.keys).to match_array(complete_keys)
      expect(h[:details]).to be_a(Array)
      expect(h[:details].count).to eql(o1.details.count)
      d0 = h[:details][0]
      expect(d0.keys).to match_array(t_std_keys)
      m = d0[:master]
      expect(m.keys).to match_array(id_keys)

      h = o1.to_hash(nil, { verbosity: :complete, to_hash: { details: { verbosity: :id } } })
      d0 = h[:details][0]
      expect(d0.keys).to match_array(id_keys)

      h = o1.to_hash(nil, {
                       verbosity: :complete,
                       to_hash: {
                         details: {
                           verbosity: :id,
                           include: [ :content, :master ],
                           to_hash: {
                             master: { verbosity: :id, include: [ :title ] }
                           }
                         }
                       }
                     })
      d0 = h[:details][0]
      expect(d0.keys).to match_array(id_keys | [ :content, :master ])
      m = d0[:master]
      expect(m.keys).to match_array(id_keys | [ :title ])

      h = o1.to_hash(nil, {
                       verbosity: :complete,
                       to_hash: {
                         details: {
                           verbosity: :standard,
                           except: [ :content ],
                           to_hash: {
                             master: { verbosity: :id, include: [ :title ] }
                           }
                         }
                       }
                     })
      d0 = h[:details][0]
      expect(d0.keys).to match_array(t_std_keys - [ :content ])
      m = d0[:master]
      expect(m.keys).to match_array(id_keys | [ :title ])
    end
  end
end
