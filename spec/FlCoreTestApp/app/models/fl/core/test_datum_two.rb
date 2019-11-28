module Fl::Core
  class TestDatumTwo < ApplicationRecord
    include Fl::Core::ModelHash
    include Fl::Core::TitleManagement
    include Fl::Core::AttributeFilters

    self.table_name = :fl_core_test_datum_twos
    
    belongs_to :owner, class_name: 'Fl::Core::TestActor', optional: true
    
    has_many :details, class_name: 'FlCoreTestDatumTwo', autosave: true, dependent: :destroy,
             foreign_key: :master_id, inverse_of: :master

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
        { include: [ :title, :content, :details ] }
      end
    end

    def to_hash_local(actor, keys, opts)
      rv = { }

      keys.each do |k|
        case k
        when :title, :content
          rv[k] = self.send(k)
        when :details
          opts_details = to_hash_options_for_key(:details, opts)
          rv[k] = self.details.map do |d|
            d.to_hash(actor, opts_details)
          end
        end
      end

      rv
    end

    def check_title()
      populate_title_if_needed(:title, 10)
    end
  end
end
