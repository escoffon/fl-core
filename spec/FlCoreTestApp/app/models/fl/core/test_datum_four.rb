module Fl::Core
  class TestDatumFour < ApplicationRecord
    include Fl::Core::ModelHash
    include Fl::Core::TitleManagement
    include Fl::Core::AttributeFilters

    self.table_name = :fl_core_test_datum_fours
    
    belongs_to :owner, class_name: 'Fl::Core::TestActor', optional: true
    
    before_save :check_title

    filtered_attribute :title, [ FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :content, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]
    
    protected

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      case verbosity
      when :id
        { include: [ ] }
      when :minimal, :standard
        { include: [ :title, :content ] }
      when :verbose, :complete
        { include: [ :title, :content ] }
      end
    end

    def to_hash_local(actor, keys, opts)
      rv = { }

      keys.each do |k|
        case k
        when :title, :content
          rv[k] = self.send(k)
        end
      end

      rv
    end

    def check_title()
      populate_title_if_needed(:title, 10)
    end
  end
end
