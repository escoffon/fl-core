module TestAccess
  # A permission with name `:p1`, permission bits 0x01000000, and no composite grants.

  class P1 < Fl::Core::Access::Permission
    NAME = :p1
    GRANTS = [ ]
    
    def initialize()
      super(NAME, GRANTS)
    end
  end

  # A permission with name `:p2`, permission bits 0x02000000, and no composite grants.

  class P2 < Fl::Core::Access::Permission
    NAME = :p2
    GRANTS = [ ]
    
    def initialize()
      super(NAME, GRANTS)
    end
  end

  # A permission with name `:p3`, permission bits 0x04000000, and no composite grants.

  class P3 < Fl::Core::Access::Permission
    NAME = :p3
    GRANTS = [ ]
    
    def initialize()
      super(NAME, GRANTS)
    end
  end

  # A permission with name `:p4` that grants {P1} and {P2}.

  class P4 < Fl::Core::Access::Permission
    NAME = :p4
    GRANTS = [ P1::NAME, P2::NAME]
    
    def initialize()
      super(NAME, GRANTS)
    end
  end

  # A permission with name `:p5` that grants {P4} and {P3}.

  class P5 < Fl::Core::Access::Permission
    NAME = :p5
    GRANTS = [ P4::NAME, P3::NAME ]
    
    def initialize()
      super(NAME, GRANTS)
    end
  end

  # A permission with name `:p4` that grants {P5}.

  class P6 < Fl::Core::Access::Permission
    NAME = :p6
    GRANTS = [ P5::NAME ]
    
    def initialize()
      super(NAME, GRANTS)
    end
  end
end
