require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe Fl::Core::Attachment::ActiveStorage::Helper, type: :model do
  let(:helper) { Fl::Core::Attachment::ActiveStorage::Helper }

  describe '.to_hash_attachment_styles' do
    it 'should generate all known styles' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      styles = Fl::Core::Attachment.config.defaults(:fl_image)[:styles]
      h = helper.to_hash_attachment_styles(a1.image, :all)
      expect(h.keys).to match_array(styles.keys)
    end

    it 'should filter out unknown style names' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_attachment_styles(a1.image, [ :small, 'medium', :unknwon, ':no_style' ])
      expect(h.keys).to match_array([ :small, :medium ])
    end

    it 'should accept hash elements' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      custom = { name: 'custom', resize: '100x100' }
      h = helper.to_hash_attachment_styles(a1.image, [ custom ])
      expect(h.keys).to match_array([ :custom ])
      expect(h[:custom]).to include(custom)
    end

    it 'should override default styles' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      styles = Fl::Core::Attachment.config.defaults(:fl_image)[:styles]
      custom = { name: 'thumb', resize: '100x100' }
      h = helper.to_hash_attachment_styles(a1.image, [ :small, custom ])
      expect(h.keys).to match_array([ :small, :thumb ])
      expect(h[:thumb]).to include(custom)
      expect(h[:small]).to include(styles[:small])
    end
  end

  describe '.to_hash_attachment_variants' do
    it 'should generate all variants for all known styles' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_attachment_variants(a1.image.attachment,
                                             helper.to_hash_attachment_styles(a1.image, :all))
      expect(h).to be_a(Hash)
      expect(h.keys).to match_array([ :type, :name, :content_type, :original_filename,
                                      :original_byte_size, :metadata, :variants, :created_at,
                                      :blob_id, :fingerprint, :id, :record ])
      vk = h[:variants].map { |v| v[:style] }
      styles = Fl::Core::Attachment.config.defaults(:fl_image)[:styles]
      expect(vk).to match_array(styles.keys)
    end

    it 'should generate variants only for known styles' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_attachment_variants(a1.image.attachment,
                                             helper.to_hash_attachment_styles(a1.image,
                                                                              [ :small, 'medium', :unknwon,
                                                                                ':no_style' ]))
      vk = h[:variants].map { |v| v[:style] }
      expect(vk).to match_array([ :small, :medium ])
    end

    it 'should generate a pseudovariant for the :blob style' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_attachment_variants(a1.image.attachment, { blob: { } })
      vk = h[:variants].map { |v| v[:style] }
      expect(vk).to match_array([ :blob ])
    end

    it 'should generate a variant for the :original style' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_attachment_variants(a1.image.attachment, { original: { } })
      vk = h[:variants].map { |v| v[:style] }
      expect(vk).to match_array([ :original ])

      h = helper.to_hash_attachment_variants(a1.image.attachment, [ :original ])
      vk = h[:variants].map { |v| v[:style] }
      expect(vk).to match_array([ :original ])
    end

    it 'should override variant configuration for the :original style' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      original = { resize: '100x100>' }
      h = helper.to_hash_attachment_variants(a1.image.attachment, { original: original })
      vk = h[:variants].map { |v| v[:style] }
      expect(vk).to match_array([ :original ])
      v0 = h[:variants][0]
      expect(v0[:style]).to eql(:original)
      expect(v0[:params]).to include(original)
    end
  end

  describe '.to_hash_active_storage_proxy' do
    it 'should generate all variants for all known styles' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_active_storage_proxy(a1.image, :all)
      expect(h).to be_a(Hash)
      expect(h.keys).to match_array([ :type, :name, :attachments ])
      vk0 = h[:attachments][0][:variants].map { |v| v[:style] }
      styles = Fl::Core::Attachment.config.defaults(:fl_image)[:styles]
      expect(vk0).to match_array(styles.keys)
    end

    it 'should generate variants only for known styles' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_active_storage_proxy(a1.image, [ :small, 'medium', :unknwon, ':no_style' ])
      expect(h).to be_a(Hash)
      expect(h.keys).to match_array([ :type, :name, :attachments ])
      vk0 = h[:attachments][0][:variants].map { |v| v[:style] }
      expect(vk0).to match_array([ :small, :medium ])
    end

    it 'should generate a pseudovariant for the :blob style' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_active_storage_proxy(a1.image, [ { name: :blob } ])
      expect(h).to be_a(Hash)
      expect(h.keys).to match_array([ :type, :name, :attachments ])
      vk0 = h[:attachments][0][:variants].map { |v| v[:style] }
      expect(vk0).to match_array([ :blob ])
    end

    it 'should generate a variant for the :original style' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      h = helper.to_hash_active_storage_proxy(a1.image, [ { name: :original } ])
      expect(h).to be_a(Hash)
      expect(h.keys).to match_array([ :type, :name, :attachments ])
      vk0 = h[:attachments][0][:variants].map { |v| v[:style] }
      expect(vk0).to match_array([ :original ])

      h = helper.to_hash_active_storage_proxy(a1.image, [ :original ])
      expect(h).to be_a(Hash)
      expect(h.keys).to match_array([ :type, :name, :attachments ])
      vk0 = h[:attachments][0][:variants].map { |v| v[:style] }
      expect(vk0).to match_array([ :original ])
    end

    it 'should override variant configuration for the :original style' do
      u1 = create(:test_avatar_user)
      a1 = create(:test_datum_attachment, title: 'a1 title', owner: u1,
                  image: { io: File.open(File.join(Rails.root, 'src/images/hummingbird.jpg')),
                           filename: 'hummingbird.jpg' },
                  plain: { io: File.open(File.join(Rails.root, 'src/README.md')),
                           filename: 'README.md' })

      original = { name: :original, resize: '100x100>' }
      h = helper.to_hash_active_storage_proxy(a1.image, [ original ])
      expect(h).to be_a(Hash)
      expect(h.keys).to match_array([ :type, :name, :attachments ])
      vk0 = h[:attachments][0][:variants].map { |v| v[:style] }
      expect(vk0).to match_array([ :original ])
      a0 = h[:attachments][0][:variants][0]
      expect(a0[:style]).to eql(:original)
      expect(a0[:params]).to include(original)
    end
  end
end
