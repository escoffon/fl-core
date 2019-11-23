class FlCoreTestDatumTwo < ApplicationRecord
  include Fl::Core::ModelHash
  include Fl::Core::TitleManagement
  
  belongs_to :master, class_name: 'FlCoreTestDatumOne', inverse_of: :details

  before_save :check_title
  
  def to_hash_options_for_verbosity(actor, verbosity, opts)
    case verbosity
    when :id
      { include: [ ] }
    when :minimal, :standard, :verbose, :complete
      { include: [ :title, :content, :master ] }
    end
  end

  def to_hash_local(actor, keys, opts)
    rv = { }

    keys.each do |k|
      case k
      when :title, :content
        rv[k] = self.send(k)
      when :master
        unless self.master.nil?
          opts_master = to_hash_options_for_key(:master, opts, { verbosity: :id })
          rv[k] = self.master.to_hash(actor, opts_master)
        end
      end
    end

    rv
  end

  def check_title()
    populate_title_if_needed(:title, 10)
  end
end
