module Fl::Core::Attachments
  class InitializerGenerator < Rails::Generators::Base
#    WATERMARK_FILES = [ 'wm200.psd', 'wm200.png', 'wm400.psd', 'wm400.png' ]

    source_root File.expand_path('../templates', __FILE__)

    def create_initializer
      name = 'attachment_types.rb'
      outfile = File.join(destination_root, 'config', 'initializers', name)
      if File.exists?(outfile)
        say_status('skipped', "The attachments initializer file already exists: #{outfile}")
      else
        say_status('create', "Creating attachments initializer file")
        say_status('', "You may have to modify it as described in the file")
        template(name, outfile)
      end
    end

    # def create_watermark_files
    #   outroot = File.join(destination_root, 'src', 'images', 'watermarks')

    #   WATERMARK_FILES.each do |name|
    #     outfile = File.join(outroot, name)
    #     if File.exists?(outfile)
    #       say_status('skipped', "The watermark file already exists: #{outfile}")
    #     else
    #       template(name, outfile)
    #     end
    #   end
    # end

    private
  end
end

