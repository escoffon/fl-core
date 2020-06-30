module Fl::Core
  # TestDatumCommentTwo includes comments with a custom summary.

  class TestDatumCommentTwo < ApplicationRecord
    class MyChecker < Fl::Core::Access::Checker
      def initialize()
        super()
      end

      def access_check(permission, actor, asset, context = nil)
        return false if actor.nil?
        
        asset_grants = asset.grants || { }
        return false if !asset_grants.is_a?(Hash) || (asset_grants.count < 1)

        g = asset_grants[actor.fingerprint] || [ ]
        return g.include?(Fl::Core::Access::Helper.permission_name(permission).to_s)
      end
    end

    include Fl::Core::ModelHash
    include Fl::Core::TitleManagement
    include Fl::Core::AttributeFilters
    include Fl::Core::Comment::Commentable
    include Fl::Core::Comment::ActiveRecord::Commentable
    include Fl::Core::Access::Access

    self.table_name = :fl_core_test_datum_comment_twos

    belongs_to :owner, class_name: 'Fl::Core::TestActor', optional: true

    has_comments summary: :my_summary
    has_access_control MyChecker.new

    validates :owner, :content, presence: true

    filtered_attribute :content, [ FILTER_HTML_STRIP_DANGEROUS_ELEMENTS ]

    serialize :grants, JSON
    
    def initialize(attrs)
      super(attrs)
    end

    def my_summary()
      return self.content
    end
    
    protected

    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity != :id) && (verbosity != :ignore)
        if verbosity == :minimal
          {
            :include => [ :content ]
          }
        else
          {
            :include => [ :owner, :content ]
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
  end
end
