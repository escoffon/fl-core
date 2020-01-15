module Fl::Core::Attachment::ActiveStorage
  # Namespace for ActiveStorage macros.
  # This module extends the `has_one_attached` and `has_many_attached` ActiveStorage macros to support
  # registration of standard "styles" (variants, in ActiveStorage terminology) for the attachment.
  # The extended macros support configuration options, and define a set of helper methods you can use to
  # perform standard operations on the attachment and its variants.
  
  module Macros
    # Methods to be registered as class methods of the including module/class.

    module ClassMethods
      # Wraps the ActiveStorage `has_one_attached` to add the **:styles** option.
      # This method is a replacement for the standard ActiveStorage `has_one_attached` macro;
      # it performs the following actions:
      #
      # 1. Calls the original implementation of `has_one_attached` to set up the ActiveStorage
      #    attachment.
      # 2. Registers the value of *opts* with the class object.
      # 3. Registers the value of *opts\[:styles\]* with the class object.
      # 4. Defines a number of attachment instance methods, as listed below.
      #
      # #### Styles
      #
      # This feature is similar to the notion of *styles* in the
      # Paperclip[https://github.com/thoughtbot/paperclip] gem. It makes it possible to define a
      # standard set of ActiveStorage variant parameters, and obtain variants based on the style
      # name. When coupled with the {Fl::Core::Attachment.config} object, it enables building
      # "libraries" of standard variant definitions.
      #
      # For example, the following `has_one_attached` defines an **avatar** attachment that provides
      # a number of canned variants:
      #
      # ```
      # class User < ActiveRecord::Base
      #   include Fl::Core::Attachment::ActiveStorage
      #
      #   has_one_attached :avatar, styles: {
      #     xlarge: { resize: "200x200>", format: 'png' },
      #     large: { resize: "72x72>", format: 'png' },
      #     medium: { resize: "48x48>", format: 'png' },
      #     thumb: { resize: "32x32>", format: 'png' },
      #     list: { resize: "24x24>", format: 'png' }
      #   }
      # end
      # ```
      # To get the variant for a given style, or the path to the variant URL:
      #
      # ```
      # u = get_user()
      # variant = u.avatar_variant(:medium)
      # variant_path = u.avatar_variant_path(:thumb)
      # ```
      # You can use styles defined in the configuration:
      #
      # ```
      # cfg = Fl::Core::Attachment.config
      # cfg.defaults(:my_styles, {
      #       xlarge: { resize: "200x200>", format: 'png' },
      #       large: { resize: "72x72>", format: 'png' },
      #       medium: { resize: "48x48>", format: 'png' },
      #       thumb: { resize: "32x32>", format: 'png' },
      #       list: { resize: "24x24>", format: 'png' }
      #     })
      #
      # class User < ActiveRecord::Base
      #   include Fl::Core::Attachment::ActiveStorage
      #
      #   has_one_attached :avatar, styles: Fl::Core::Attachment.config.defaults(:my_styles)
      # end
      # ```
      # or even:
      #
      # ```
      # cfg = Fl::Core::Attachment.config
      # cfg.defaults(:my_config, {
      #       style: {
      #         xlarge: { resize: "200x200>", format: 'png' },
      #         large: { resize: "72x72>", format: 'png' },
      #         medium: { resize: "48x48>", format: 'png' },
      #         thumb: { resize: "32x32>", format: 'png' },
      #         list: { resize: "24x24>", format: 'png' }
      #       }
      #     })
      #
      # class User < ActiveRecord::Base
      #   include Fl::Core::Attachment::ActiveStorage
      #
      #   has_one_attached :avatar, Fl::Core::Attachment.config.defaults(:my_config)
      # end
      # ```
      #
      # You can make styles dynamic by defining a Proc as the **:styles** property. For example,
      # to generate watermarked variants if the attachment is set to be watermarked, use a setup like this:
      #
      # ```
      # class MyObject < ActiveRecord::Base
      #   include Fl::Core::Attachment::ActiveStorage
      #
      #   has_one_attached :image, styles: ->(a, o) { (a.record.image_watermarked) ? o[:wms] : o[:rs] }, rs: {
      #       small: { resize: '64x64>' },
      #       medium: { resize: '100x100>' },
      #       large: { resize: '400x400>' }
      #     }, wms: {
      #       small: { resize: '64x64>', draw: "image SrcOver 0,0 0,0 'src/images/watermarks/wm200.png'" },
      #       medium: { resize: '100x100>', draw: "image SrcOver 0,0 0,0 'src/images/watermarks/wm200.png'" },
      #       large: { resize: '400x400>', draw: "image SrcOver 0,0 0,0 'src/images/watermarks/wm200.png'" },
      #       original: { draw: "image SrcOver 0,0 0,0 'src/images/watermarks/wm200.png'" }
      #     }
      # end
      # ```
      # This class has an **image_watermarked** attribute that controls if the image should be watermarked.
      #
      # The style names **:original** and **:blob** are reserved to indicate the "original" file data, and
      # are treated specially by various methods, but in general **:blob** is used when the blob data
      # are requested (for example, from a `<i>name</i>_blob_url`), and **:original** is used to request
      # a variant that is functionally identical to the original file data (for example, a variant of
      # the same size as the original, but with a watermark). See the dynamic styles example above for
      # an illustration of how to add a watermark to an image identical to the original.
      #
      # #### The generated methods.
      #
      # The following instance methods are defined. In the following, `<i>name</i>` is the
      # attachment name; for example, `has_one_attached :avatar` results in the definition of the instance
      # methods `avatar_options`, `avatar_styles`, `avatar_style`, `avatar_variant`, `avatar_blob_path`,
      # `avatar_blob_url`, `avatar_variant_path`, and `avatar_variant_url`.
      #
      # - `<i>name</i>_options()` returns a hash containing the options that were passed
      #   to `has_one_attached`.
      # - `<i>name</i>_styles()` returns a hash containing the attribute's styles.
      # - `<i>name</i>_style(sname)` returns a hash containing a requested style.
      #   The style name is *sname*, and the result value is a hash that contains processing parameters
      #   for the style's variant.
      # - `<i>name</i>_variant(sname)` returns the variant for style *sname*.
      #   If *sname* is a string or a symbol, the variant parameters are looked up in the registered styles;
      #   otherwise, if it is a hash, it is passed to the `variant` call directly.
      # - `<i>name</i>_blob_path()` returns the path component of the URL to the attachment's blob
      #   (the original file).
      # - `<i>name</i>_blob_url(opts)` returns the URL to the attachment's blob
      #   (the original file). The *opts* argument is a hash of options for URL generation; the most
      #   common is **:host**, the hostname and scheme component of the URL.
      # - `<i>name</i>_variant_path(sname)` returns the path component of the URL to the attachment's
      #   variant for style *sname*.
      #   If *sname* is a string or a symbol, the variant parameters are looked up in the registered styles;
      #   otherwise, if it is a hash, it is passed to the `variant` call directly.
      # - `<i>name</i>_variant_url(sname, opts)` returns the URL to the attachment's variant for style
      #   *sname*.
      #   If *sname* is a string or a symbol, the variant parameters are looked up in the registered styles;
      #   otherwise, if it is a hash, it is passed to the `variant` call directly.
      #   The *opts* argument is a hash of options for URL generation; the most
      #   common is **:host**, the hostname and scheme component of the URL.
      #
      # For example, to get the path to the **:medium** variant of an **avatar** attachment,
      # or to a nonstandard variant:
      #
      # ```
      # u = get_user()
      # path1 = u.avatar_variant_path(:medium)
      # path2 = u.avatar_variant_path(resize: '40x40')
      # ```
      #
      # @param name [Symbol,String] The name of the attachment attribute.
      # @param opts [Hash] Options for the macro.
      #
      # @option opts [Symbol] :dependent Controls when the attachment is purged; see the documentation
      #  for `ActiveStorage::Attached::Macros`.
      #  Defaults to `:purge_later`.
      # @option opts [Hash,Proc] :styles The styles for this attachment.
      #  If the value is a hash, keys are style names, and values are hashes
      #  containing the processing parameters for variations.
      #  If the value is a Proc, it will be called with two arguments: the attachment object
      #  (an instance of `ActiveStorage::Attached::One`), and the value of *opts*.
      #  This Proc is expected to return a hash containing the styles.
      #  Note that this option is only meaningful with images.
    
      def has_one_attached(name, opts = {})
        dependent = opts[:dependent] || :purge_later
        send(:has_one_attached_orig, name, dependent: dependent)

        styles = opts[:styles] || { }
        class_eval do
          self.attachment_options[name.to_sym] = opts

          self.attachment_styles[name.to_sym] = case styles
                                                when Hash
                                                  styles.reduce({ }) do |acc, kvp|
                                                    rk, rv = kvp
                                                    acc[rk.to_sym] = rv
                                                    acc
                                                  end
                                                when Proc
                                                  styles
                                                else
                                                  { }
                                                end

          define_method("#{name}_options") do
            self.class.attachment_options(self.send(name))
          end

          define_method("#{name}_styles") do
            self.class.attachment_styles(self.send(name))
          end

          define_method("#{name}_style") do |sname|
            self.class.attachment_style(self.send(name), sname)
          end
          
          define_method("#{name}_variant") do |sname|
            self.attachment_variant(self.send(name), sname)
          end
          
          define_method("#{name}_blob_path") do
            self.attachment_blob_path(self.send(name))
          end
          
          define_method("#{name}_blob_url") do |*opts|
            self.attachment_blob_url(self.send(name), *opts)
          end
          
          define_method("#{name}_variant_path") do |sname|
            self.attachment_variant_path(self.send(name), sname)
          end
          
          define_method("#{name}_variant_url") do |sname, *opts|
            self.attachment_variant_url(self.send(name), sname, *opts)
          end
        end
      end
    
      # Wraps the ActiveStorage `has_many_attached` to add the **:styles** option.
      # This method is a replacement for the standard ActiveStorage `has_many_attached` macro;
      # it performs the following actions:
      #
      # 1. Calls the original implementation of `has_many_attached` to set up the ActiveStorage
      #    attachment.
      # 2. Registers the value of *opts* with the class object.
      # 3. Registers the value of *opts\[:styles\]* with the class object.
      # 4. Defines a number of attachment instance methods, as listed below.
      #
      # #### Styles
      #
      # See the documentation for {#has_one_attached} for a description of the **:styles** functionality.
      #
      # #### The generated methods.
      #
      # The following instance methods are defined. In the following, `<i>name</i>` is the
      # attachment name; for example, `has_many_attached :images` results in the definition of the instance
      # methods `images_options`, `images_styles`, `images_style`, `images_variant`, `images_blob_path`,
      # `images_blob_url`, `images_variant_path`, and `images_variant_url`.
      #
      # - `<i>name</i>_options()` returns a hash containing the options that were passed
      #   to `has_many_attached`.
      # - `<i>name</i>_styles()` returns a hash containing the attribute's styles.
      # - `<i>name</i>_style(sname)` returns a hash containing a requested style.
      #   The style name is *sname*, and the result value is a hash that contains processing parameters
      #   for the style's variant.
      # - `<i>name</i>_variant(sname, idx)` returns the variant for style *sname*.
      #   If *sname* is a string or a symbol, the variant parameters are looked up in the registered styles;
      #   otherwise, if it is a hash, it is passed to the `variant` call directly.
      #   The *idx* parameter is the index of the requested attachment item.
      # - `<i>name</i>_blob_path()` returns the path component of the URL to the attachment's blob
      #   (the original file).
      # - `<i>name</i>_blob_url(opts)` returns the URL to the attachment's blob
      #   (the original file). The *opts* argument is a hash of options for URL generation; the most
      #   common is **:host**, the hostname and scheme component of the URL.
      # - `<i>name</i>_variant_path(sname, idx)` returns the path component of the URL to the attachment's
      #   variant for style *sname*.
      #   If *sname* is a string or a symbol, the variant parameters are looked up in the registered styles;
      #   otherwise, if it is a hash, it is passed to the `variant` call directly.
      #   The *idx* parameter is the index of the requested attachment item.
      # - `<i>name</i>_variant_url(sname, idx, opts)` returns the URL to the attachment's variant for style
      #   *sname*.
      #   If *sname* is a string or a symbol, the variant parameters are looked up in the registered styles;
      #   otherwise, if it is a hash, it is passed to the `variant` call directly.
      #   The *idx* parameter is the index of the requested attachment item.
      #   The *opts* argument is a hash of options for URL generation; the most
      #   common is **:host**, the hostname and scheme component of the URL.
      #
      # For example, to get the path to the **:medium** variant of the second element of an **images**
      # attachment, or to a nonstandard variant:
      #
      # ```
      # class MyObject < ActiveRecord::Base
      #   include Fl::Core::Attachment::ActiveStorage
      #
      #   has_many_attached :images, styles: {
      #     xlarge: { resize: "200x200>", format: 'png' },
      #     large: { resize: "72x72>", format: 'png' },
      #     medium: { resize: "48x48>", format: 'png' },
      #     thumb: { resize: "32x32>", format: 'png' },
      #     list: { resize: "24x24>", format: 'png' }
      #   }
      # end
      #
      # o = get_my_object()
      # path1 = o.images_variant_path(:medium, 1)
      # path2 = o.images_variant_path({ resize: '40x40' }, 1)
      # ```
      #
      # @param name [Symbol,String] The name of the attachment attribute.
      # @param opts [Hash] Options for the macro.
      #
      # @option opts [Symbol] :dependent Controls when the attachment is purged; see the documentation
      #  for `ActiveStorage::Attached::Macros`.
      #  Defaults to `:purge_later`.
      # @option opts [Hash,Proc] :styles The styles for this attachment.
      #  If the value is a hash, keys are style names, and values are hashes
      #  containing the processing parameters for variations.
      #  If the value is a Proc, it will be called with two arguments: the attachment object
      #  (an instance of `ActiveStorage::Attached::Many`), and the value of *opts*.
      #  This Proc is expected to return a hash containing the styles.
      #  Note that this option is only meaningful with images.

      def has_many_attached(name, opts = {})
        dependent = opts[:dependent] || :purge_later
        send(:has_many_attached_orig, name, dependent: dependent)

        styles = opts[:styles] || { }
        class_eval do
          self.attachment_options[name.to_sym] = opts

          self.attachment_styles[name.to_sym] = case styles
                                                when Hash
                                                  styles.reduce({ }) do |acc, kvp|
                                                    rk, rv = kvp
                                                    acc[rk.to_sym] = rv
                                                    acc
                                                  end
                                                when Proc
                                                  styles
                                                else
                                                  { }
                                                end

          define_method("#{name}_options") do
            self.class.attachment_options(self.send(name))
          end

          define_method("#{name}_styles") do
            self.class.attachment_styles(self.send(name))
          end

          define_method("#{name}_style") do |sname|
            self.class.attachment_style(self.send(name), sname)
          end
          
          define_method("#{name}_variant") do |sname, idx|
            self.attachment_variant(self.send(name), sname, idx)
          end
          
          define_method("#{name}_blob_path") do
            self.attachment_blob_path(self.send(name))
          end
          
          define_method("#{name}_blob_url") do |*opts|
            self.attachment_blob_url(self.send(name), *opts)
          end
          
          define_method("#{name}_variant_path") do |sname, idx|
            self.attachment_variant_path(self.send(name), sname, idx)
          end
          
          define_method("#{name}_variant_url") do |sname, idx, *opts|
            self.attachment_variant_url(self.send(name), sname, idx, *opts)
          end
        end
      end
    end

    # Perform actions when the module is included.
    #
    # - Injects the class methods to extend the ActiveStorage macros.

    def self.included(base)
      base.instance_eval do
        alias has_one_attached_orig has_one_attached
        alias has_many_attached_orig has_many_attached
      end
      
      base.extend ClassMethods

      base.instance_eval do
      end

      base.class_eval do
      end
    end
  end
end
