require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the Nkp::Core::TrackingDirectivesHelper. For example:
#
# describe Nkp::Core::TrackingDirectivesHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end

RSpec.configure do |c|
end

RSpec.describe Fl::Core::ProseMirror::Helper, type: :helper do
  let(:pmh) { Fl::Core::ProseMirror::Helper }

  let(:content_1) do
    {
      "type" => "doc",
      "content" => [
	{
	  "type" => "paragraph",
	  "attrs" => {
	    "clearFloat" => "none"
	  },
	  "content" => [
	    {
	      "type" => "text",
	      "text" => "Another: "
	    }, {
	      "type" => "image",
	      "attrs" => {
		"src" => "724-thumb",
		"alt" => nil,
		"title" => nil,
		"class" => "nkp-image nkp-image-size-100",
		"data-align" => "none",
		"data-ty" => "li",
		"data-sz" => "100",
		"data-vr" => "thumb",
		"data-ou" => "724-original",
		"data-aid" => "724",
		"data-afp" => "ActiveStorage::Attachment/724"
	      }
	    }, {
	      "type" => "image",
	      "attrs" => {
		"src" => "725-thumb",
		"alt" => nil,
		"title" => nil,
		"class" => "nkp-image nkp-image-size-100",
		"data-align" => "none",
		"data-ty" => "li",
		"data-sz" => "100",
		"data-vr" => "thumb",
		"data-ou" => "725-original",
		"data-aid" => "725",
		"data-afp" => "ActiveStorage::Attachment/725"
	      }
	    }, {
	      "type" => "image",
	      "attrs" => {
		"src" => "727-thumb",
		"alt" => nil,
		"title" => nil,
		"class" => "nkp-image nkp-image-size-100",
		"data-align" => "none",
		"data-ty" => "li",
		"data-sz" => "100",
		"data-vr" => "thumb",
		"data-ou" => "727-original",
		"data-aid" => "727",
		"data-afp" => "ActiveStorage::Attachment/727"
	      }
	    }, {
	      "type" => "image",
	      "attrs" => {
		"src" => "728-thumb",
		"alt" => nil,
		"title" => nil,
		"class" => "nkp-image nkp-image-size-original nkp-float-none",
		"data-align" => "none",
		"data-ty" => "li",
		"data-sz" => "original",
		"data-vr" => "original",
		"data-ou" => "728-original",
		"data-aid" => "728",
		"data-afp" => "ActiveStorage::Attachment/728"
	      }
	    }
	  ]
	}
      ]
    } 
  end

  let(:content_2) do
    "{\"type\":\"doc\",\"content\":[{\"type\":\"paragraph\",\"attrs\":{\"clearFloat\":\"none\"},\"content\":[{\"type\":\"text\",\"text\":\"The images will go in a paragraph here: \"},{\"type\":\"image\",\"attrs\":{\"src\":\"858-thumb\",\"alt\":null,\"title\":null,\"class\":\"nkp-image nkp-image-size-100\",\"data-align\":\"none\",\"data-ty\":\"li\",\"data-sz\":\"100\",\"data-vr\":\"thumb\",\"data-ou\":\"858-original\",\"data-aid\":\"858\",\"data-afp\":\"ActiveStorage::Attachment/858\"}}]},{\"type\":\"paragraph\",\"attrs\":{\"clearFloat\":\"none\"},\"content\":[{\"type\":\"text\",\"text\":\"in a list here:\"}]},{\"type\":\"bulletList\",\"content\":[{\"type\":\"listItem\",\"content\":[{\"type\":\"paragraph\",\"attrs\":{\"clearFloat\":\"none\"},\"content\":[{\"type\":\"text\",\"text\":\"one: \"},{\"type\":\"image\",\"attrs\":{\"src\":\"860-iphone\",\"alt\":null,\"title\":null,\"class\":\"nkp-image nkp-image-size-64\",\"data-align\":\"none\",\"data-ty\":\"li\",\"data-sz\":\"64\",\"data-vr\":\"iphone\",\"data-ou\":\"860-original\",\"data-aid\":\"860\",\"data-afp\":\"ActiveStorage::Attachment/860\"}}]}]},{\"type\":\"listItem\",\"content\":[{\"type\":\"paragraph\",\"attrs\":{\"clearFloat\":\"none\"},\"content\":[{\"type\":\"text\",\"text\":\"two: \"},{\"type\":\"image\",\"attrs\":{\"src\":\"862-iphone\",\"alt\":null,\"title\":null,\"class\":\"nkp-image nkp-image-size-64\",\"data-align\":\"none\",\"data-ty\":\"li\",\"data-sz\":\"64\",\"data-vr\":\"iphone\",\"data-ou\":\"862-original\",\"data-aid\":\"862\",\"data-afp\":\"ActiveStorage::Attachment/862\"}}]}]},{\"type\":\"listItem\",\"content\":[{\"type\":\"paragraph\",\"attrs\":{\"clearFloat\":\"none\"},\"content\":[{\"type\":\"text\",\"text\":\"three: \"},{\"type\":\"image\",\"attrs\":{\"src\":\"863-iphone\",\"alt\":null,\"title\":null,\"class\":\"nkp-image nkp-image-size-64\",\"data-align\":\"none\",\"data-ty\":\"li\",\"data-sz\":\"64\",\"data-vr\":\"iphone\",\"data-ou\":\"863-original\",\"data-aid\":\"863\",\"data-afp\":\"ActiveStorage::Attachment/863\"}}]}]}]},{\"type\":\"blockquote\",\"content\":[{\"type\":\"paragraph\",\"attrs\":{\"clearFloat\":\"none\"},\"content\":[{\"type\":\"text\",\"text\":\"In a quotation: \"},{\"type\":\"image\",\"attrs\":{\"src\":\"866-thumb\",\"alt\":null,\"title\":null,\"class\":\"nkp-image nkp-image-size-100\",\"data-align\":\"none\",\"data-ty\":\"li\",\"data-sz\":\"100\",\"data-vr\":\"thumb\",\"data-ou\":\"866-original\",\"data-aid\":\"866\",\"data-afp\":\"ActiveStorage::Attachment/866\"}}]}]},{\"type\":\"paragraph\",\"attrs\":{\"clearFloat\":\"none\"},\"content\":[{\"type\":\"text\",\"text\":\"And back in a paragraph: \"},{\"type\":\"image\",\"attrs\":{\"src\":\"868-iphone\",\"alt\":null,\"title\":null,\"class\":\"nkp-image nkp-image-size-64\",\"data-align\":\"none\",\"data-ty\":\"li\",\"data-sz\":\"64\",\"data-vr\":\"iphone\",\"data-ou\":\"/868-original\",\"data-aid\":\"868\",\"data-afp\":\"ActiveStorage::Attachment/868\"}},{\"type\":\"image\",\"attrs\":{\"src\":\"870-iphone\",\"alt\":null,\"title\":null,\"class\":\"nkp-image nkp-image-size-64\",\"data-align\":\"none\",\"data-ty\":\"li\",\"data-sz\":\"64\",\"data-vr\":\"iphone\",\"data-ou\":\"870-original\"}}]}]}"
  end
  
  describe '.traverse' do
    it 'should traverse a hash representation' do
      c = { types: [ ] }
      rv = pmh.traverse(content_1, c) do |node, level, ctx|
        ctx[:types].push("#{level}-#{node['type']}")
      end
      expect(rv).to eql(true)
      x = [ "0-doc", "1-paragraph", "2-text", "2-image", "2-image", "2-image", "2-image" ]
      expect(c[:types]).to eql(x)
    end

    it 'should traverse a string representation' do
      c = { types: [ ] }
      rv = pmh.traverse(content_2, c) do |node, level, ctx|
        ctx[:types].push("#{level}-#{node['type']}")
      end
      expect(rv).to eql(true)
      x = [ "0-doc",
            "1-paragraph", "2-text", "2-image",
            "1-paragraph", "2-text",
            "1-bulletList",
            "2-listItem", "3-paragraph", "4-text", "4-image",
            "2-listItem", "3-paragraph", "4-text", "4-image",
            "2-listItem", "3-paragraph", "4-text", "4-image",
            "1-blockquote", "2-paragraph", "3-text", "3-image",
            "1-paragraph", "2-text", "2-image", "2-image" ]
      expect(c[:types]).to eql(x)
    end

    it 'should terminate early if the callback value is false' do
      # The block here terminates at the first image inside a list item
      
      c = { inListItem: false, image: nil }
      rv = pmh.traverse(content_2, c) do |node, level, ctx|
        if node['type'] == 'listItem'
          ctx[:inListItem] = true
        elsif (node['type'] == 'image') && ctx[:inListItem]
          ctx[:image] = node
          false
        else
          true
        end
      end
      expect(rv).to eql(false)
      expect(c[:image]).to be_a(Hash)
      expect(c[:image]).to include('type', 'attrs')
      expect(c[:image]['attrs']['data-aid']).to eql('860')
    end
  end
end
