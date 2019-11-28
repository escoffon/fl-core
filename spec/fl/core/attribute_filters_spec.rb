RSpec.describe Fl::Core::AttributeFilters do
  describe '.filtered_attribute' do
    describe "FILTER_HTML_TEXT_ONLY" do
      it 'should extract text nodes' do
        o1 = Fl::Core::TestDatumOne.new(title: 'plain title', content: 'plain content')
        expect(o1.save).to eql(true)

        s = 'This is <code>HTML</code>'
        o1.title = s
        expect(o1.title).to eql('This is HTML')
        
        s = '<p>This is <b>HTML</b></p>'
        o1.title = s
        expect(o1.title).to eql('This is HTML')

        s = '<p>This <i>is</i> <b>more <i>complex</i> HTML</b</p>'
        o1.title = s
        expect(o1.title).to eql('This is more complex HTML')
        
        s = '<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>'
        o1.title = s
        expect(o1.title).to eql('This is a link in HTML')
      end
    end
  
    describe "FILTER_HTML_STRIP_DANGEROUS_ELEMENTS" do
      it 'should strip dangerous elements' do
        o1 = Fl::Core::TestDatumOne.new(title: 'plain title', content: 'plain content')
        expect(o1.save).to eql(true)

        html = '<p>This is HTML</p>'
        o1.content = html
        expect(o1.content).to eql(html)
        
        html = '<p>This <i>is</i> <b>more <i>complex</i> HTML</b></p>'
        o1.content = html
        expect(o1.content).to eql(html)

        html = '<p>Script: <script type="text/javascript">script contents</script> here</p>'
        nhtm = '<p>Script:  here</p>'
        o1.content = html
        expect(o1.content).to eql(nhtm)

        html = '<p>Script: <script>script contents</script> here</p>'
        nhtm = '<p>Script:  here</p>'
        o1.content = html
        expect(o1.content).to eql(nhtm)

        html = '<p>Object: <object type="text/javaobject">object contents</object> here</p>'
        nhtm = '<p>Object:  here</p>'
        o1.content = html
        expect(o1.content).to eql(nhtm)

        html = '<p>Object: <object>object contents</object> here</p>'
        nhtm = '<p>Object:  here</p>'
        o1.content = html
        expect(o1.content).to eql(nhtm)

        html = '<p>This <i>is</i> <a href="foo">a <i>link</i></a> in HTML</p>'
        nhtm = '<p>This <i>is</i> <a href="#">a <i>link</i></a> in HTML</p>'
        o1.content = html
        expect(o1.content).to eql(nhtm)

        html = '<p>This <i>is</i> <a href="/foo">a <i>link</i></a> in HTML</p>'
        o1.content = html
        expect(o1.content).to eql(html)

        html = '<p>This <i>is</i> <a href="http://foo">a <i>link</i></a> in HTML</p>'
        o1.content = html
        expect(o1.content).to eql(html)

        html = '<p>This <i>is</i> <a href="https://foo">a <i>link</i></a> in HTML</p>'
        o1.content = html
        expect(o1.content).to eql(html)

        html = '<p>Link: <a href="foo"><img src="bar"></a> here</p>'
        nhtm = '<p>Link: <a href="#"><img src=""></a> here</p>'
        o1.content = html
        expect(o1.content).to eql(nhtm)

        html = '<p>Link: <a href="/foo"><img src="/bar"></a> here</p>'
        o1.content = html
        expect(o1.content).to eql(html)

        html = '<p>Link: <a href="http://foo"><img src="https://bar"></a> here</p>'
        o1.content = html
        expect(o1.content).to eql(html)

        html = '<p>Link: <a href="https://foo"><img src="http://bar"></a> here</p>'
        o1.content = html
        expect(o1.content).to eql(html)
      end
    end
    
    describe "custom filter" do
      it 'should process the custom filter' do
        o1 = Fl::Core::TestDatumOne.new(title: 'plain title', content: 'plain content')
        expect(o1.save).to eql(true)

        html = '<p>This is <span>HTML</span></p>'
        nhtml = '<p>This is <span style="color: #ff0080;">HTML</span></p>'
        o1.content = html
        expect(o1.content).to eql(nhtml)
      end
    end

    it 'should process multiple filters' do
      o1 = Fl::Core::TestDatumOne.new(title: 'plain title', content: 'plain content')
      expect(o1.save).to eql(true)

      html = '<p>This is <span>HTML</span> with a script tag <script type="text/javascript">script contents</script> here</p>'
      nhtml = '<p>This is <span style="color: #ff0080;">HTML</span> with a script tag  here</p>'
      o1.content = html
      expect(o1.content).to eql(nhtml)
    end
  end
end
