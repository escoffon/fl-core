module Fl::Core
  # Base class for framework ActiveRecord objects.

  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
