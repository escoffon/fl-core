module Fl
  module Core
    class Engine < ::Rails::Engine
      isolate_namespace Fl::Core
    end
  end
end
