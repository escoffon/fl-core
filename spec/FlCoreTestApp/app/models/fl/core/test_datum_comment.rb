module Fl::Core
  # TestDatumComment includes comments.

  class TestDatumComment < ApplicationRecord
    include Fl::Core::ModelHash
    include Fl::Core::TitleManagement
    include Fl::Core::AttributeFilters
    include Fl::Core::Comment::Commentable
    include Fl::Core::Comment::ActiveRecord::Commentable

    self.table_name = :fl_core_test_datum_comments

    belongs_to :owner, class_name: 'Fl::Core::TestActor', optional: true

    has_comments counter: :num_comments
    
    validates :owner, :title, :content, presence: true

    before_save :check_title

    filtered_attribute :title, [ FILTER_HTML_TEXT_ONLY ]
    filtered_attribute :content, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    protected

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity != :id) && (verbosity != :ignore)
        if verbosity == :minimal
          {
            :include => [ :title, :content ]
          }
        else
          {
            :include => [ :owner, :title, :content ]
          }
        end
      else
        {}
      end
    end

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {
      }
      keys.each do |k|
        case k.to_sym
        when :owner
          if self.owner
            o_opts = to_hash_opts_with_defaults(to_hash_opts[:owner], { verbosity: :minimal })
            rv[:owner] = self.owner.to_hash(actor, o_opts)
          else
            rv[:owner] = nil
          end
        else
          rv[k] = self.send(k) if self.respond_to?(k)
        end
      end

      rv
    end

    def check_title()
      populate_title_if_needed(:title, 10)
    end
  end
end
