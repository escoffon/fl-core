module Fl
  module Core
    # Engine class for the `fl-core` gem.
    
    class Engine < ::Rails::Engine
      isolate_namespace Fl::Core

#      initializer "fl-core.initializer", before: :load_config_initializers do
#      end
    end
  end
end
