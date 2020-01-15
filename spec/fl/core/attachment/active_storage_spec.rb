require 'rails_helper'

RSpec.configure do |c|
  c.include FactoryBot::Syntax::Methods
  c.include Fl::Core::Test::ObjectHelpers
end

RSpec.describe Fl::Core::Attachment::ActiveStorage::Base, type: :model do
  describe '.attachment_options' do
    it 'should be defined for all classes with attachments' do
      expect(Fl::Core::TestAvatarUser.methods).to include(:attachment_options)
      expect(Fl::Core::TestDatumAttachment.methods).to include(:attachment_options)
    end

    it 'should return the correct list of configurations' do
      expect(Fl::Core::TestAvatarUser.attachment_options.keys).to match_array([ :avatar ])
      expect(Fl::Core::TestDatumAttachment.attachment_options.keys).to match_array([ :image, :plain ])
    end

    it 'should return the expected configurations' do
      cfg = Fl::Core::Attachment.config
      
      expect(Fl::Core::TestAvatarUser.attachment_options(:avatar)).to include(cfg.defaults(:fl_avatar))
      expect(Fl::Core::TestDatumAttachment.attachment_options(:image)).to include(cfg.defaults(:fl_image))
      expect(Fl::Core::TestDatumAttachment.attachment_options(:plain)).to include(cfg.defaults(:fl_document))
    end
  end

  describe '.attachment_styles' do
    it 'should be defined for all classes with attachments' do
      expect(Fl::Core::TestAvatarUser.methods).to include(:attachment_styles)
      expect(Fl::Core::TestDatumAttachment.methods).to include(:attachment_styles)
    end

    it 'should return the correct list of styles' do
      expect(Fl::Core::TestAvatarUser.attachment_styles.keys).to match_array([ :avatar ])
      expect(Fl::Core::TestDatumAttachment.attachment_styles.keys).to match_array([ :image, :plain ])
    end

    it 'should return the expected styles' do
      cfg = Fl::Core::Attachment.config
      
      expect(Fl::Core::TestAvatarUser.attachment_styles(:avatar)).to include(cfg.defaults(:fl_avatar)[:styles])
      expect(Fl::Core::TestDatumAttachment.attachment_styles(:image)).to include(cfg.defaults(:fl_image)[:styles])
      expect(Fl::Core::TestDatumAttachment.attachment_styles(:plain)).to include(cfg.defaults(:fl_document)[:styles])
    end
  end

  describe '.attachment_style' do
    it 'should be defined for all classes with attachments' do
      expect(Fl::Core::TestAvatarUser.methods).to include(:attachment_style)
      expect(Fl::Core::TestDatumAttachment.methods).to include(:attachment_style)
    end

    it 'should return the expected style' do
      cfg = Fl::Core::Attachment.config

      s = cfg.defaults(:fl_avatar)[:styles]
      expect(Fl::Core::TestAvatarUser.attachment_style(:avatar, :thumb)).to include(s[:thumb])
      expect(Fl::Core::TestAvatarUser.attachment_style(:avatar, :unknown)).to be_a(Hash)
      expect(Fl::Core::TestAvatarUser.attachment_style(:avatar, :unknown).count).to eql(0)

      s = cfg.defaults(:fl_image)[:styles]
      expect(Fl::Core::TestDatumAttachment.attachment_style(:image, :small)).to include(s[:small])
      expect(Fl::Core::TestDatumAttachment.attachment_style(:image, :unknown)).to be_a(Hash)
      expect(Fl::Core::TestDatumAttachment.attachment_style(:image, :unknown).count).to eql(0)

      s = cfg.defaults(:fl_document)[:styles]
      expect(Fl::Core::TestDatumAttachment.attachment_style(:plain, :original)).to include(s[:original])
    end
  end
end
