RSpec.configure do |c|
#  c.include Fl::Core::Test::ObjectHelpers
end

class TestHarness
  include Fl::Core::TitleManagement

  def x_title(contents, max = nil, tail = nil)
    if tail.nil?
      (max.nil?) ? extract_title(contents) : extract_title(contents, max)
    elsif max.nil?
      (tail.nil?) ? extract_title(contents) : extract_title(contents, max, tail)
    else
      extract_title(contents, max, tail)
    end
  end
end

RSpec.describe Fl::Core::TitleManagement do
  let(:th) { TestHarness.new }
  
  describe 'InstanceMethods#extract_title' do
    it 'should extract from plain text' do
      c = 'this is contents that will be extracted into a title'

      t = th.x_title(c, 10)
      expect(t).to eql(c[0, 7] + '...')

      t = th.x_title(c, 10, ' [more]')
      expect(t).to eql(c[0, 3] + ' [more]')

      c = 'this is short contents'
      t = th.x_title(c, 40)
      expect(t).to eql(c)
    end

    it 'should extract from HTML' do
      c = '<p>this is <b>contents</b> that <span style="font-weight: bold;">will be</span> extracted into a title</p>'

      t = th.x_title(c, 10)
      expect(t).to eql('this is...')

      t = th.x_title(c, 10, ' [more]')
      expect(t).to eql('thi [more]')

      t = th.x_title(c, 60, ' [more]')
      expect(t).to eql('this is contents that will be extracted into a title')

      c = 'this is <b>short</b> contents'
      t = th.x_title(c, 40)
      expect(t).to eql('this is short contents')
    end
  end
end
