module Fl
  module Core
    # Base class for {Fl::Core} ActiveRecord objects.

    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
