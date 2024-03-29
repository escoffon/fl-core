module Fl::Core::Attachment::ActiveStorage
  # Namespace for ActiveStorage validators.
  # Note that these validators are not quite what we need, since by the time the validators are called,
  # any offending attachment has been created and added to the blob and attachment tables, and the damage
  # is done: we have created an invalid object.
  # The correct approach is to run validations when the underlying associations are modified, but that
  # involves changes to the ActiveStorage code, and we won't do it (yet).
  
  module Validation
    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # Registers a validator for the content type of an attachment relationship.
      # If the attachment named *name* is a `has_one_attached`, it validates that it has a
      # `content_type` property that matches one from *content_types*.
      # If the attachment is a `has_many_attached`, it validates that each element has a
      # `content_type` property that matches one from *content_types*.
      #
      # @param name [Symbol,String] The name of the attachment attribute.
      # @param opts [Hash] Options for the validator.
      #
      # @option opts [Array<String,RegExp>] :content_types An array of content types to match. Each element is
      #  a string containing the content type (for example, `image/jpeg`), or a "glob" pattern like
      #  `image/*`.
      #  Defaults to `[ 'image/*' ]`.
    
      def has_attached_validate_content_type(name, opts = {})
        content_types = opts[:content_types] || [ 'image/*' ]
        lo_content_types = content_types.map { |ct| ct.downcase }

        c = Class.new(ActiveModel::Validator)
        c.class_eval do
          define_method :validate do |record|
            attachment = record.send(name)
            return unless attachment.attached?
            
            if attachment.is_a?(ActiveStorage::Attached::One)
              # a single attachment is pretty straightforward: return as soon as we get a hit
              
              ctype = attachment.content_type.downcase
              lo_content_types.each do |ct|
                return if (ct == ctype) || File.fnmatch(ct, ctype)
              end
              record.errors.add(name.to_sym, I18n.tx('fl.core.attachment.active_storage.model.validate.forbidden_content_type',
                                                     failures: "#{[ ctype, attachment.filename.to_s ]}"))
            elsif attachment.is_a?(ActiveStorage::Attached::Many)
              # a multiple attachment is more complicated, since we have to loop over all attachments
              # and check for each.
              
              failures = [ ]
              
              attachment.each do |a|
                ctype = a.content_type.downcase
                success = false
                lo_content_types.each do |ct|
                  if (ct == ctype) || File.fnmatch(ct, ctype)
                    success = true
                    break
                  end
                end

                failures << [ ctype, a.filename.to_s ] if success == false
              end

              if failures.count > 0
                record.errors.add(name.to_sym, I18n.tx('fl.core.attachment.active_storage.model.validate.forbidden_content_type',
                                                       failures: "#{failures}"))
              end
            end
          end
        end

        validates_with c
      end
    end

    # Perform actions when the module is included.
    # - Injects the class methods.

    def self.included(base)
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
