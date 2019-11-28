module Fl::Core
  # Helper methods for generators.

  module GeneratorHelper
    protected
    
    # Split a class name into its components.
    # The name is split with the `::` separator, and a hash is returned with the following properties:
    #
    # - **full_class_name** is the value of *cname*.
    # - **class_name** is the last component in *cname*.
    # - **plural_class_name** is the pluralized value of **class_name**.
    # - **module_name** is the concatenation of all other components, separated by `::`.
    # - **modules** is an array containing the names of all the other components.
    # - **open_module** is the statement that declares the enclosing module. For example, a class
    #   name `My::Mod::Name` results in the value `module My::Mod`. If no module is present in the
    #   class name, this value is an empty string.
    # - **close_module** is the statement that terminates the module declaration. It is `end` if there
    #   is a nonempty module, and an empty string otherwise.
    #
    # @param cname [String] The class name.
    #
    # @return [Hash] Returns a hash as described above.
    
    def split_class_name(cname)
      parts = cname.split('::')
      class_name = parts.pop

      rv = {
        full_name: cname,
        plural_full_name: ActiveSupport::Inflector.pluralize(cname),
        name: class_name,
        plural_name: ActiveSupport::Inflector.pluralize(class_name),
        module_name: parts.join('::'),
        modules: parts
      }

      if rv[:module_name].length > 0
        rv[:open_module] = "module #{rv[:module_name]}"
        rv[:close_module] = 'end'
      else
        rv[:open_module] = ''
        rv[:close_module] = ''
      end

      return rv
    end

    # Copy a migration file into the application's migrations directory.
    # The method checks if the file *name* is already in the target directory, and if so
    # issues a warning and skips the operation. Otherwise, it copies the original into the target,
    # appending `.fl_framework` to the file name.
    #
    # @param migration_dir [String] THe location of the target migrations directory.
    # @param name [String] The file "name;" this is used to find the file, independently of the
    #  timestamp embedded in the complete name.
    
    def create_migration_file(migration_dir, name)
      out_dir = File.join(destination_root, 'db', 'migrate')
      ts = generate_timestamp(out_dir)
      
      in_name, in_file = find_migration_file(migration_dir, name)
      if in_name.nil?
        say_status('error', 'could not find the template migration file')
      else
        out_name, out_file = find_migration_file(out_dir, "#{name}.fl_framework")
        if out_name
          say_status('warn', "migration file exists: #{File.basename(out_file)}")
        else
          out_file = File.join(out_dir, "#{ts}_#{in_name}.fl_framework.rb")
          say_status('create', "Creating migration file #{File.basename(out_file)}")
          self.class.source_root File.expand_path(migration_dir)
          copy_file(in_file, out_file)
        end
      end
    end

    # Find a migration file in a target directory.
    # This method finds a file that matches the name *n*, ignoring the migration file timestamp.
    #
    # @param d [String] The path to the directory to search.
    # @param n [String] The template to match.
    #
    # @return [Array] Returns an array containing two string elements: the matched template, and the
    #  complete file name (including timestamp and extension).
    #  If the file is not found, the two elements have value `nil`.
    
    def find_migration_file(d, n)
      migration_file_re = Regexp.new("[0-9]+_(#{n}).rb$")
      name = nil
      infile = nil
      curdir = Dir.getwd
      Dir.chdir(d)
      Dir.glob('*.rb') do |fn|
        if fn =~ migration_file_re
          name = Regexp.last_match[1]
          infile = fn
          break
        end
      end
      Dir.chdir(curdir)

      [ name, infile ]
    end

    # Generate a migration timestamp in a target directory.
    # This method starts with a timestamp corresponding to the current time; it then scans the target
    # directry to ensure that the timestamp is not already in use, and if so bumps it by one second and
    # then tries again.
    # It is necessary to do this when a generator creates multiple migration files: in this case, it is
    # possible (even likely!) that the files would be all created during the same second, and therefore
    # with the same timestamp.
    #
    # @param d [String] The path to the directory to search.
    #
    # @return [String] Returns the timestamp.
    
    def generate_timestamp(d)
      utc = Time.new.utc
      ts = utc.strftime('%Y%m%d%H%M%S')

      curdir = Dir.getwd
      Dir.chdir(d)

      while true
        ts_m = ts + '_'
        match = Dir.glob('*.rb').find { |fn| fn.start_with?(ts_m) }
        if match.nil?
          Dir.chdir(curdir)
          return ts
        end
        
        utc += 1.second
        ts = utc.strftime('%Y%m%d%H%M%S')
      end
    end
  end
end
