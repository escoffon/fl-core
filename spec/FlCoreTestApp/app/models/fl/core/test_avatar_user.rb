module Fl::Core
  # This class is marked as an actor

  class TestAvatarUser < ApplicationRecord
    include Fl::Core::ModelHash
    include Fl::Core::Actor::Actor
    include Fl::Core::Attachment::ActiveStorage

    is_actor title: :my_name

    has_one_attached :avatar, Fl::Core::Attachment.config.defaults(:fl_avatar)
    has_attached_validate_content_type :avatar, content_types: [ 'image/*' ]

    validates :name, presence: true

    # This is for testing the actor API

    def my_name()
      self.name
    end
  
    protected
  
    def to_hash_options_for_verbosity(actor, verbosity, opts)
      if (verbosity != :id) && (verbosity != :ignore)
        {
          :include => [ :name, :avatar ]
        }
      else
        {}
      end
    end

    DEFAULT_AVATAR_STYLES = :all

    def to_hash_local(actor, keys, opts = {})
      to_hash_opts = opts[:to_hash] || {}

      rv = {
      }
      keys.each do |k|
        sk = k.to_sym
        case sk
        when :avatar
          styles = (opts.has_key?(:avatar_styles)) ? opts[:avatar_styles] : DEFAULT_AVATAR_STYLES
          rv[sk] = to_hash_active_storage_proxy(self.avatar, styles)
        else
          rv[sk] = self.send(sk) if self.respond_to?(sk)
        end
      end

      rv
    end
  end
end
