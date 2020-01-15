# Created by the fl:core:attachments:initializer generator
#
# Standard configurations for various fl-core attachment types.
#
# Defines these types:
# :fl_images configures images used for pictures: creates large preview thumbnails
# :fl_avatar configures images used for avatars: creates smaller preview thumbnails
# :fl_thumbnail configures images used as thumbnails: similar to avatar, but with smaller sizes
# :fl_document configures a general document attachment
#

require 'fl/core/attachment/configuration'

cfg = Fl::Core::Attachment.config

cfg.defaults(:fl_image, {
               styles: {
                 xlarge: { resize: "1200x1200>", strip: true, background: 'rgba(255,255,255,0)' },
                 large: { resize: "600x600>", strip: true, background: 'rgba(255,255,255,0)' },
                 medium: { resize: "400x400>", strip: true, background: 'rgba(255,255,255,0)' },
                 small: { resize: "200x200>", strip: true, background: 'rgba(255,255,255,0)' },
                 thumb: { resize: "100x100>", strip: true, background: 'rgba(255,255,255,0)' },
                 iphone: { resize: "64x64>", strip: true, background: 'rgba(255,255,255,0)' },
                 original: { }
               },
               default_style: :thumb
             })

cfg.defaults(:fl_avatar, {
               styles: {
                 xlarge: { resize: "200x200>", extent: "200x200", gravity: "center", strip: true, background: 'rgba(255,255,255,0)' },
                 large: { resize: "72x72>", extent: "72x72", gravity: "center", strip: true, background: 'rgba(255,255,255,0)' },
                 medium: { resize: "48x48>", extent: "48x48", gravity: "center", strip: true, background: 'rgba(255,255,255,0)' },
                 thumb: { resize: "32x32>", extent: "32x32", gravity: "center", strip: true, background: 'rgba(255,255,255,0)' },
                 list: { resize: "24x24>", extent: "24x24", gravity: "center", strip: true, background: 'rgba(255,255,255,0)' },
                 original: { strip: true, background: 'rgba(255,255,255,0)' }
               },
               default_style: :medium
             })

cfg.defaults(:fl_thumbnail, {
               styles: {
                 snapshot: { resize: "100x100>", background: 'rgba(255,255,255,0)' },
                 large: { resize: "72x72>", background: 'rgba(255,255,255,0)' },
                 medium: { resize: "48x48>", background: 'rgba(255,255,255,0)' },
                 thumb: { resize: "32x32>", background: 'rgba(255,255,255,0)' }
               },
               default_style: :snapshot,
             })

cfg.defaults(:fl_document, {
               styles: {
                 original: { }
               },
               default_style: :original
             })
