RSpec.describe Fl::Core::HtmlHelper do
  describe '.text_only' do
    it 'should extract text nodes' do
      expect(Fl::Core::HtmlHelper.text_only('This is <code>HTML</code>')).to eql('This is HTML')
      expect(Fl::Core::HtmlHelper.text_only('<p>This is HTML</p>')).to eql('This is HTML')
      expect(Fl::Core::HtmlHelper.text_only('<p>This <i>is</i> <b>more <i>complex</i> HTML</b</p>')).to eql('This is more complex HTML')
      expect(Fl::Core::HtmlHelper.text_only('<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>')).to eql('This is a link in HTML')
      expect(Fl::Core::HtmlHelper.text_only('<p>This is HTML</p>', 4)).to eql('This')
      expect(Fl::Core::HtmlHelper.text_only('<p>This <i>is</i> <b>more <i>complex</i> HTML</b></p>', 14)).to eql('This is more c')
      expect(Fl::Core::HtmlHelper.text_only('<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>', 12)).to eql('This is a li')
    end
  end
  
  describe '.strip_dangerous_elements' do
    it 'should strip dangerous elements' do
      html = '<p>This is HTML</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)
      html = '<p>This <i>is</i> <b>more <i>complex</i> HTML</b></p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)

      html = '<p>Script: <script type="text/javascript">script contents</script> here</p>'
      nhtm = '<p>Script:  here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(nhtm)

      html = '<p>Script: <script>script contents</script> here</p>'
      nhtm = '<p>Script:  here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(nhtm)

      html = '<p>Object: <object type="text/javaobject">object contents</object> here</p>'
      nhtm = '<p>Object:  here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(nhtm)

      html = '<p>Object: <object>object contents</object> here</p>'
      nhtm = '<p>Object:  here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(nhtm)

      html = '<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>'
      nhtm = '<p>This <i>is</i> <a href="#">a <i>link</i></a> in HTML</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(nhtm)

      html = '<p>This <i>is</i> <a href="/foo">a <i>link</i></a> in HTML</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)

      html = '<p>This <i>is</i> <a href="http://foo">a <i>link</i></a> in HTML</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)

      html = '<p>This <i>is</i> <a href="https://foo">a <i>link</i></a> in HTML</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)

      html = '<p>Link: <a href="foo"><img src="bar"></a> here</p>'
      nhtm = '<p>Link: <a href="#"><img src=""></a> here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(nhtm)

      html = '<p>Link: <a href="/foo"><img src="/bar"></a> here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)

      html = '<p>Link: <a href="http://foo"><img src="https://bar"></a> here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)

      html = '<p>Link: <a href="https://foo"><img src="http://bar"></a> here</p>'
      expect(Fl::Core::HtmlHelper.strip_dangerous_elements(html)).to eql(html)
    end
  end
end
