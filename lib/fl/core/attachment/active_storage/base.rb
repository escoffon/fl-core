module Fl::Core::Attachment::ActiveStorage
  # Base attachment support for ActiveStorage.

  module Base
    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # @!method attachment_options(aname = nil)
      #   @!scope class
      #   Get the attachment style options registered with the class.
      #   If *aname* is `nil`, the method returns the attachment options from all attachments.
      #   Otherwise, it returns the options for the requested attachment.
      #
      #   In order to support class hierarchies rooted at some base class that defines common attachmkents,
      #   the method looks for *aname* up the class hierarchy, until the first hit or the root class.
      #
      #   @param aname [String,Symbol,ActiveStorage::Attached::One,nil] The name of the attachment,
      #    or all attachments if `nil`. If the value is a `ActiveStorage::Attached::One`, the attachment
      #    name is derived from its `name` property.
      #   @return [Hash] Returns a hash as described above.
      #    If *aname* is `nil`, keys are attachment names and values are hashes containing the options
      #    that were passed to `has_one_attached` for that attachment.
      #    If *aname* is not `nil`, the hash contains the options that were passed to `has_one_attached`.
        
      # @!method attachment_styles(aname = nil)
      #   @!scope class
      #   Get the attachment styles registered with the class.
      #   If *aname* is `nil`, the method returns the variant styles from all attachments.
      #   Otherwise, it returns the variant styles for the requested attachment.
      #
      #   In order to support class hierarchies rooted at some base class that defines common attachmkents,
      #   the method looks for *aname* up the class hierarchy, until the first hit or the root class.
      #
      #   @param aname [String,Symbol,ActiveStorage::Attached::One,nil] The name of the attachment,
      #    or all attachments if `nil`. If the value is a `ActiveStorage::Attached::One`, the attachment
      #    name is derived from its `name` property.
      #   @return [Hash] Returns a hash as described above.
      #    If *aname* is `nil`, keys are attachment names and values are hashes containing the styles
      #    associated with that attachment.
      #    If *aname* is not `nil`, keys are style names and values are hashes containing the variant
      #    options; if *aname* is not a registered attachment, an empty hash is returned.
        
      # @!method attachment_style(aname, sname)
      #   @!scope class
      #   Get a style for an attachment.
      #   @param aname [String,Symbol] The name of the attachment.
      #   @param sname [String,Symbol] The name of the style to look up.
      #   @return [Hash] Returns a hash containing the requested style; if no such style is present,
      #    returns an empty hash.
    end

    # The methods in this module are installed as instance method of the including class.

    module InstanceMethods
      # Get the attachment style options registered with an attachment.
      # If *aname* is `nil`, the method returns the attachment options from all attachments.
      # Otherwise, it returns the options for the requested attachment.
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One,nil] The name of the attachment,
      #  or all attachments if `nil`. If the value is a `ActiveStorage::Attached::One`, the attachment
      #  name is derived from its `name` property.
      #
      # @return [Hash] Returns a hash as described above.
      #  If *aname* is `nil`, keys are attachment names and values are hashes containing the options
      #  that were passed to `has_one_attached` for that attachment.
      #  If *aname* is not `nil`, the hash contains the options that were passed to `has_one_attached`.
        
      def attachment_options(aname = nil)
        self.class.attachment_options(aname)
      end

      # Get the attachment styles registered with the class.
      # If *aname* is `nil`, the method returns the variant styles from all attachments.
      # Otherwise, it returns the variant styles for the requested attachment.
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One,nil] The name of the attachment,
      #  or all attachments if `nil`. If the value is a `ActiveStorage::Attached::One`, the attachment
      #  name is derived from its `name` property.
      #
      # @return [Hash] Returns a hash as described above.
      #  If *aname* is `nil`, keys are attachment names and values are hashes containing the styles
      #  associated with that attachment.
      #  If *aname* is not `nil`, keys are style names and values are hashes containing the variant
      #  options; if *aname* is not a registered attachment, an empty hash is returned.
        
      def attachment_styles(aname = nil)
        self.class.attachment_styles(aname)
      end

      # Get a style for an attachment.
      #
      # @param aname [String,Symbol] The name of the attachment.
      # @param sname [String,Symbol] The name of the style to look up.
      #
      # @return [Hash] Returns a hash containing the requested style; if no such style is present,
      #  returns an empty hash.
        
      def attachment_style(aname, sname)
        self.class.attachment_style(aname, sname)
      end

      # Get the variant for an attachment based on a style name.
      # This method handles both `has_one_attachment` and `has_many_attachments` relationships.
      # If *aname* resolves to a `ActiveStorage::Attached::Many`, the *idx* parameter indicates
      # which attachment to target.
      #
      # If *sname* is a string or a symbol, the method looks it up in the styles that were registered for
      # attachment *aname*, and generates a variant based on those processing parameters.
      # Otherwise, it generates the variant using *sname* as the processing parameters.
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One,ActiveStorage::Attached::Many] The name
      #  of the attachment, or the attachment proxy.
      # @param sname [String,Symbol,Hash] The name of the style to look up, or a hash of processing
      #  parameters.
      # @param rest [Array] An array containing additional arguments to the method.
      #  Currently the array is expected to be empty, or to contain a single integer value,
      #  the index of the attachment if *aname* is a `has_many_attachments` relationship.
      #
      # @return [ActiveStorage::Variant,nil] Returns the variant that was requested.
      
      def attachment_variant(aname, sname, *rest)
        pp = (sname.is_a?(Symbol) || sname.is_a?(String)) ? self.class.attachment_style(aname, sname) : sname
        a = (aname.is_a?(String) || aname.is_a?(Symbol)) ? send(aname) : aname
        if a.is_a?(ActiveStorage::Attached::One)
          a.variant(combine_options: pp)
        elsif a.is_a?(ActiveStorage::Attached::Many)
          if rest.count > 0
            idx = rest[0].to_i
            a[idx].variant(combine_options: pp)
          else
            nil
          end
        else
          nil
        end
      end

      # Get the URL path component for the blob (the original file).
      # This method handles both `has_one_attachment` and `has_many_attachments` relationships.
      # If *aname* resolves to a `ActiveStorage::Attached::Many`, the *idx* parameter indicates
      # which attachment to target.
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One] The name of the attachment, or the
      #  attachment proxy.
      # @param rest [Array] An array containing additional arguments to the method.
      #  Currently the array is expected to be empty, or to contain a single integer value,
      #  the index of the attachment if *aname* is a `has_many_attachments` relationship.
      #
      # @return [String,nil] Returns a string containing the path component of the URL to the blob.

      def attachment_blob_path(aname, *rest)
        a = (aname.is_a?(String) || aname.is_a?(Symbol)) ? send(aname) : aname
        if a.is_a?(ActiveStorage::Attached::One)
          Rails.application.routes.url_helpers.rails_blob_path(a, only_path: true)
        elsif a.is_a?(ActiveStorage::Attached::Many)
          if rest.count > 0
            idx = rest[0].to_i
            Rails.application.routes.url_helpers.rails_blob_path(a[idx], only_path: true)
          else
            nil
          end
        else
          nil
        end
      end

      # Get the URL for the blob (the original file).
      # This method handles both `has_one_attachment` and `has_many_attachments` relationships.
      # If *aname* resolves to a `ActiveStorage::Attached::Many`, the *idx* parameter indicates
      # which attachment to target.
      #
      # @param aname [String,Symbol,ActiveStorage::Attached::One] The name of the attachment, or the
      #  attachment proxy.
      # @param rest [Array] An array containing additional arguments to the method.
      #  Currently the array is expected to contain up to two elements. If *aname* is a
      #  `has_many_attachments` relationship, the first is an integer value containing
      #  the index of the attachment, and the second is an optional parmeter containing options for
      #  the URL method.
      #  Is *aname* is a `has_one_attachment`, only the options parameter is present.
      #  A common option is **:host**, to specify the host
      #  name (which may include the scheme component `http` or `https`).
      #
      # @return [String,nil] Returns a string containing the URL to the blob.

      def attachment_blob_url(aname, *rest)
        a = (aname.is_a?(String) || aname.is_a?(Symbol)) ? send(aname) : aname
        if a.is_a?(ActiveStorage::Attached::One)
          Rails.application.routes.url_helpers.rails_blob_url(a, rest[0])
        elsif a.is_a?(ActiveStorage::Attached::Many)
          if rest.count > 0
            idx = rest[0].to_i
            Rails.application.routes.url_helpers.rails_blob_url(a[idx], rest[1])
          else
            nil
          end
        else
          nil
        end
      end

      # Get the URL path component for a given variant, by style.
      # This method handles both `has_one_attachment` and `has_many_attachments` relationships.
      # If *aname* resolves to a `ActiveStorage::Attached::Many`, the *idx* parameter indicates
      # which attachment to target.
      # If *sname* is a string or a symbol, the method looks it up in the styles that were registered for
      # attachment *aname*, and generates the variant path based on those processing parameters.
      # Otherwise, it generates the variant path using *sname* as the processing parameters.
      #
      # @param aname [String,Symbol] The name of the attachment.
      # @param sname [String,Symbol,Hash,ActiveStorage::Variant] The name of the style to look up, a hash
      #  of variant parameters, or a variant.
      # @param rest [Array] An array containing additional arguments to the method.
      #  Currently the array is expected to contain up to one element. If *aname* is a
      #  `has_many_attachments` relationship, the first is an integer value containing
      #  the index of the attachment.
      #  Is *aname* is a `has_one_attachment`, no additional parameters are required..
      #
      # @return [String,nil] Returns a string containing the path component of the variant corresponding
      #  to style *sname*.

      def attachment_variant_path(aname, sname, *rest)
        v = (sname.is_a?(ActiveStorage::Variant)) ? sname : attachment_variant(aname, sname, *rest)
        Rails.application.routes.url_helpers.rails_blob_representation_path(v.blob.signed_id,
                                                                            v.variation.key,
                                                                            v.blob.filename)
      end

      # Get the URL to a given variant, by style.
      # This method handles both `has_one_attachment` and `has_many_attachments` relationships.
      # If *aname* resolves to a `ActiveStorage::Attached::Many`, the *idx* parameter indicates
      # which attachment to target.
      # If *sname* is a string or a symbol, the method looks it up in the styles that were registered for
      # attachment *aname*, and generates the variant URL based on those processing parameters.
      # Otherwise, it generates the variant URL using *sname* as the processing parameters.
      #
      # @param aname [String,Symbol] The name of the attachment.
      # @param sname [String,Symbol,Hash,ActiveStorage::Variant] The name of the style to look up, a hash
      #  of variant parameters, or a variant.
      # @param rest [Array] An array containing additional arguments to the method.
      #  Currently the array is expected to contain up to two elements. If *aname* is a
      #  `has_many_attachments` relationship, the first is an integer value containing
      #  the index of the attachment, and the second is an optional parmeter containing options for
      #  the URL method.
      #  Is *aname* is a `has_one_attachment`, only the options parameter is present.
      #  A common option is **:host**, to specify the host
      #  name (which may include the scheme component `http` or `https`).
      #
      # @return [String,nil] Returns a string containing the URL of the variant corresponding
      #  to style *sname*.
          
      def attachment_variant_url(aname, sname, *rest)
        a = (aname.is_a?(String) || aname.is_a?(Symbol)) ? send(aname) : aname
        opts = if a.is_a?(ActiveStorage::Attached::One)
                 rest[0]
               elsif a.is_a?(ActiveStorage::Attached::Many)
                 rest[1]
               else
                 { }
               end
        v = (sname.is_a?(ActiveStorage::Variant)) ? sname : attachment_variant(a, sname, *rest)
        Rails.application.routes.url_helpers.rails_blob_representation_url(v.blob.signed_id,
                                                                           v.variation.key,
                                                                           v.blob.filename,
                                                                           opts)
      end
    end

    # Perform actions when the module is included.
    #
    # - Injects the class methods.
    # - Injects the instance methods.
    
    def self.included(base)
      base.instance_eval do
        alias has_one_attached_orig has_one_attached
      end
      
      # This is done explicitly below, to get the scope right.
      # The ClassMethods are actually there for doumentation purposes
      # base.extend ClassMethods

      base.instance_eval do
      end

      base.instance_variable_set(:@_attachment_options, { })
      base.instance_variable_set(:@_attachment_styles, { })

      base.class_eval do
        def self.attachment_options(aname = nil)
          if aname.nil?
            # We have to collect attachment options from the superclasses

            sclass = self.superclass
            sopts = (sclass.respond_to?(:attachment_options)) ? sclass.attachment_options(ak) : { }

            return sopts.merge(@_attachment_options || { })
          end

          ak = case aname
               when ActiveStorage::Attached::One
                 aname.name.to_sym
               when String
                 aname.to_sym
               when Symbol
                 aname
               else
                 aname
               end

          if !@_attachment_options || !@_attachment_options.has_key?(ak)
            sclass = self.superclass
            return (sclass.respond_to?(:attachment_options)) ? sclass.attachment_options(ak) : { }
          else
            @_attachment_options[ak]
          end
        end
        
        def self.attachment_styles(aname = nil)
          if aname.nil?
            # We have to collect attachment styles from the superclasses

            sclass = self.superclass
            sstyles = (sclass.respond_to?(:attachment_styles)) ? sclass.attachment_styles(ak) : { }

            return sstyles.merge(@_attachment_styles || { })
          end

          ak = case aname
               when ActiveStorage::Attached::One
                 aname.name.to_sym
               when String
                 aname.to_sym
               when Symbol
                 aname
               else
                 aname
               end

          if !@_attachment_styles || !@_attachment_styles.has_key?(ak)
            sclass = self.superclass
            return (sclass.respond_to?(:attachment_styles)) ? sclass.attachment_styles(ak) : { }
          end

          s = @_attachment_styles[ak]
          case s
          when Hash
            s
          when Proc
            # if :styles was registered as a proc, AND if aname is an attachment proxy, then we can
            # attempt to resolve the styles based on the proc.

            if aname.is_a?(ActiveStorage::Attached::One)
              s.call(aname, attachment_options(aname))
            else
              { }
            end
          else
            { }
          end
        end

        def self.attachment_style(aname, sname)
          return sname if sname.is_a?(Hash)
          attachment_styles(aname)[sname.to_sym] || { }
        end

        protected

        def self.add_attachment_options(aname, opts)
          @_attachment_options = { } unless @_attachment_options.is_a?(Hash)
          @_attachment_options[aname.to_sym] = opts
        end

        def self.add_attachment_styles(aname, styles)
          @_attachment_styles = { } unless @_attachment_styles.is_a?(Hash)
          @_attachment_styles[aname.to_sym] = styles
        end
        
        include InstanceMethods
      end
    end
  end
end
