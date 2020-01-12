module Fl
  module Core
    class Engine < ::Rails::Engine
      isolate_namespace Fl::Core

      initializer "fl-core.test_initializer" do
      end
    end
  end
end
