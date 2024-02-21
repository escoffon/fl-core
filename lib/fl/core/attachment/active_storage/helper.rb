module Fl::Core::Attachment::ActiveStorage
  # Helper for ActiveStorage.
  # If this module is included, wrappers for the class methods in this module are installed as instance methods
  # of the including class. For example, an instance method called `to_hash_attachment_styles`
  # is defined that wraps around a call to {.to_hash_attachment_styles}.
  
  module Helper
    # Get the URL path component for a blob.
    #
    # @param blob [ActiveStorage::Blob] The blob object.
    #
    # @return [String,nil] Returns a string containing the path component of the URL to the blob.

    def self.blob_path(blob)
      Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    end

    # Get the URL for a blob.
    #
    # @param blob [ActiveStorage::Blob] The blob object.
    # @param rest [Array] An array containing additional arguments to the method.
    #  Currently the array is expected to contain up to one element,
    #  an optional parmeter containing options for the URL method.
    #  A common option is **:host**, to specify the host
    #  name (which may include the scheme component `http` or `https`).
    #
    # @return [String,nil] Returns a string containing the URL to the blob.

    def self.blob_url(blob, *rest)
      Rails.application.routes.url_helpers.rails_blob_url(blob, *rest)
    end

    # Get the URL path component for a given variant.
    #
    # @deprecated Use {.representation_path} instead.
    #
    # @param v [ActiveStorage::Variant] The variant for which to generate the URL path.
    #
    # @return [String,nil] Returns a string containing the path component of the variant *v*.

    def self.variant_path(v)
      Rails.application.routes.url_helpers.rails_blob_representation_path(v.blob.signed_id,
                                                                          v.variation.key,
                                                                          v.blob.filename)
    end

    # Get the URL to a given variant.
    #
    # @deprecated Use {.representation_url} instead.
    #
    # @param v [ActiveStorage::Variant] The variant for which to generate the URL path.
    # @param rest [Array] An array containing additional arguments to the method.
    #  Currently the array is expected to contain up to one element,  an optional parmeter containing
    #  options for the URL method.
    #  A common option is **:host**, to specify the host
    #  name (which may include the scheme component `http` or `https`).
    #
    # @return [String,nil] Returns a string containing the URL of the variant *v*.
          
    def self.variant_url(v, *rest)
      Rails.application.routes.url_helpers.rails_blob_representation_url(v.blob.signed_id,
                                                                         v.variation.key,
                                                                         v.blob.filename,
                                                                         *opts)
    end

    # Get the URL path component for a given representation.
    #
    # @param rep [ActiveStorage::Variant,ActiveStorage::Preview] The representation (variant or preview)
    #  for which to generate the URL path.
    #
    # @return [String,nil] Returns a string containing the path component of the representation *rep*.

    def self.representation_path(rep)
      Rails.application.routes.url_helpers.rails_blob_representation_path(rep.blob.signed_id,
                                                                          rep.variation.key,
                                                                          rep.blob.filename)
    end

    # Get the URL to a given representation.
    #
    # @param rep [ActiveStorage::Variant,ActiveStorage::Preview] The representation (variant or preview)
    #  for which to generate the URL path.
    # @param rest [Array] An array containing additional arguments to the method.
    #  Currently the array is expected to contain up to one element,  an optional parmeter containing
    #  options for the URL method.
    #  A common option is **:host**, to specify the host
    #  name (which may include the scheme component `http` or `https`).
    #
    # @return [String,nil] Returns a string containing the URL of the representation *rep*.
          
    def self.representation_url(rep, *rest)
      Rails.application.routes.url_helpers.rails_blob_representation_url(rep.blob.signed_id,
                                                                         rep.variation.key,
                                                                         rep.blob.filename,
                                                                         *opts)
    end

    # Expand the *styles* option for an ActiveStorage hash representation.
    # This method expands and filters the variant styles as appropriate for the given attachment.
    # Any styles not supported by the attachment are filtered out, except that `:all`
    # is converted to all the supported styles.
    #
    # This method looks up the styles listed in *styles* as follows. If *styles* is a symbol, it is
    # converted to a one-element array; if it is a string, it is assumed to be a comma-separated list
    # of style names, and is converted to an array of style names; if it is an array, it is left as is.
    # The method then iterates over the contents of the array. If the element is a symbol, it is looked
    # up in the known styles for *attachment*; if one is found, it is added to the return value.
    # Otherwise, if the value is a hash, it must contain a **:name** key that will be used to place the
    # hash in the return value.
    #
    # Note that style names that are not in the attachment's known styles are not placed in the return
    # value. If you want to define a custom variant, use the hash format of the element and don't forget
    # the **:name** key. The only exceptions to this rule are the two style names **:original** and
    # **:blob**, which are allowed event though they may not be in the known styles.
    #
    # @param attachment [ActiveStorage::Attached::One] The attachment proxy; this is the value of the
    #  attachment attribute registered with `has_one_attached`.
    # @param styles [Array, String, Symbol] The list of styles to return.
    #  A string value is a comma-separated list of style names.
    #  Each element of the array value is either a style name, or a hash containing processing parameters
    #  for a variant.
    #  The symbol `:all` indicates that all supported styles should be returned.
    #
    # @return [Hash] Returns a hash where the keys are style names, and the values are hashes containing
    #  the variant parameters.

    def self.to_hash_attachment_styles(attachment, styles = :all)
      implicit_styles = [ :original, :blob ]
      known_styles = attachment.record.class.attachment_styles(attachment.name)
      sl = case styles
           when String
             styles.split(/\s*,\s*/).map { |sn| sn.to_sym }
           when Array
             styles.reduce([ ]) do |acc, sn|
               if sn.is_a?(Symbol)
                 acc.push(sn)
               elsif sn.is_a?(String)
                 acc.push(sn.to_sym)
               elsif sn.is_a?(Hash)
                 acc.push(sn)
               end
               acc
             end
           when :all
             known_styles.keys
           else
             [ ]
           end

      has_original = false
      rv = sl.reduce({ }) do |acc, sn|
        if sn.is_a?(Symbol)
          if known_styles.has_key?(sn)
            acc[sn] = known_styles[sn]
          elsif implicit_styles.include?(sn)
            acc[sn] = { }
          end
        elsif sn.has_key?(:name)
          n = sn[:name].to_sym
          acc[n] = sn
        end
        acc
      end
      
      rv
    end

    # Generate a `to_hash` representation of an attachment.
    # This method generates a representation for an ActiveStorage attachment (one that was
    # defined via the `has_one_attached` or `hash_many_attached` directive).
    #
    # @param proxy [ActiveStorage::Attached::One,ActiveStorage::Attached::Many] The attachment proxy;
    #  this is the value of the attachment attribute registered with `has_one_attached`
    #  or `has_many_attached`.
    # @param styles [Array, String, Symbol] The list of styles to return.
    #  See {.to_hash_attachment_styles} for a description of how this argument is processed.
    #
    # @return [Hash,nil] If *attachment* is not currently attached, returns `nil`.
    #  Otherwise, returns a hash containing the following keys:
    #
    #  - **:type** is a string containing the class name of *proxy*.
    #  - **:name** is a string containing the attachment's name.
    #  - **:attachments** is an array containing the attached file info. If *proxy* is a
    #    `ActiveStorage::Attached::One`, this array contains one element.
    #    See {.to_hash_attachment_variants} for a description of the contents of these elements.

    def self.to_hash_active_storage_proxy(proxy, styles = :all)
      return nil unless proxy.attached?
      
      sl = to_hash_attachment_styles(proxy, styles)
      record = proxy.record
      aname = proxy.name.to_sym
      
      h = {
        type: proxy.class.name,
        name: proxy.name,
        attachments: [ ]
      }

      # Since both proxies respond to `attachments`, we can collapse the load into a common statement:

      proxy.attachments.each do |a|
        h[:attachments] << to_hash_attachment_variants(a, sl)
      end
      
      h
    end

    # Generate a `to_hash` representation of an attachment element.
    # This method is typically **not** called standalone, but rather from inside
    # {.to_hash_active_storage_proxy}.
    #
    # @param attachment [ActiveStorage::Attachment] The attachment.
    # @param styles [Hash,Symbol] The list of styles to return; the value is a hash where keys are symbols
    #  containing the style names, and values are hashes containing the configuration for the variant
    #  corresponding to the style.
    #  See {.to_hash_attachment_styles} for a description of how this argument is generated.
    #  The `:blob` special style contains the URL to the original file, as obtained from the blob; no style
    #  is applied.
    #  You can define an `:original` style to contain the URL to the original file, but processed according to the
    #  variant parameters specified by the style; for example, `:original` does not resize the image, but it might
    #  autorotate it.
    #  Note that all styles except for `:blob` are ignored if the attachment's record
    #  is not representable (*i.e.* if `attachment.representable?` returns `false`).
    #  If *styles* is the symbol `:all`, it is converted to a hash containing all the available styles
    #  via a call to {.to_hash_attachment_styles}. The `:blob` style is always returned.
    #
    # @return [Hash] Returns a hash containing the following keys:
    #
    #  - **:type** is a string containing the name of the attachment class.
    #  - **:id** is an integer containing the object identifier of the attachment.
    #  - **:fingerprint** is a string containing the object fingerprint of the attachment.
    #  - **:name** is a string containing the name of the attachment.
    #  - **:record** is a string containing the fingerprint of the record containing the attachment.
    #  - **:blob_id** is an integer containing the object identifier of the attachment's blob object.
    #  - **:content_type** is a string containing the MIME type for the original.
    #  - **:original_file_name** is a string containing the original file name for the attachment.
    #  - **:original_byte_size** is a string containing the original byte size for the attachment.
    #  - **:metadata** is a hash containing metadata about the attachment.
    #  - **:variants** is an array of hashes, where each hash contains three keys: **:style** is the style
    #    name or hash, **:params** is the hash of the style parameters, **:url** the corresponding URL.
    #    This property is mislabeled for historical reasons; if the attachment supports previews, the elements
    #    in the array correspond to previews instead of variants.

    def self.to_hash_attachment_variants(attachment, styles = :all)
      styles = to_hash_attachment_styles(attachment) if styles == :all
      record = attachment.record
      aname = attachment.name.to_sym
      has_blob = false
      
      variants = styles.reduce([ ]) do |acc, skv|
        s, p = skv
        if s == :blob
          has_blob = true
          acc << {
            style: :blob,
            params: p,
            url: blob_path(attachment.blob)
          }
        elsif attachment.representable?
          acc << {
            style: s,
            params: p,
            url: representation_path(attachment.representation(p))
          }
        end
        
        acc
      end

      variants << {
        style: :blob,
        params: p,
        url: blob_path(attachment.blob)
      } unless has_blob

      h = {
        type: attachment.class.name,
        id: attachment.id,
        fingerprint: attachment.fingerprint,
        name: attachment.name,
        record: ActiveRecord::Base.fingerprint(attachment.record_type, attachment.record_id),
        blob_id: attachment.blob_id,
        content_type: attachment.content_type,
        original_filename: attachment.filename.sanitized,
        original_byte_size: attachment.byte_size,
        metadata: attachment.metadata,
        variants: variants
      }
      
      [ :created_at, :updated_at ].each do |k|
        if attachment.respond_to?(k)
          tz = ActiveSupport::TimeZone.new('UTC')
          h[k] = tz.at(attachment.send(k))
        end
      end

      h
    end

    # Perform actions when the module is included.
    #
    # - Registers instance methods with the same name and functionality as the module helper methods.
    
    def self.included(base)
      base.class_eval do
        def to_hash_attachment_styles(attachment, styles = :all)
          Fl::Core::Attachment::ActiveStorage::Helper.to_hash_attachment_styles(attachment, styles)
        end

        def to_hash_active_storage_proxy(proxy, styles = :all)
          Fl::Core::Attachment::ActiveStorage::Helper.to_hash_active_storage_proxy(proxy, styles)
        end
      end
    end
  end
end
