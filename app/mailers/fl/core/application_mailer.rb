module Fl
  module Core
    # Base class for mailers in the {Fl::Core} engine.
    
    class ApplicationMailer < ActionMailer::Base
      default from: 'from@example.com'
      layout 'mailer'
    end
  end
end
