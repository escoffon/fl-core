module Fl::Core::Comments
  class InstallGenerator < Rails::Generators::Base
    include Fl::Core::GeneratorHelper
    
    PWD = File.expand_path('.')
    DB_MIGRATE = File.expand_path('../../../../../../../db/migrate', __FILE__)
    MIGRATION_FILE_NAMES = [ 'create_fl_core_comments' ]
    NAMESPACE = <<EOD
  namespace :fl do
    namespace :core do
      resources :comments, only: [ :index, :create ]
    end
  end

EOD
    RESOURCES = "      resources :comments, only: [ :index, :create ]\n"
    
    source_root File.expand_path('../templates', __FILE__)

    def self.source_paths
      [ File.expand_path('../templates', __FILE__) ]
    end

    def create_migration_files
      MIGRATION_FILE_NAMES.each { |fn| create_migration_file(DB_MIGRATE, fn) }
    end

    def create_controller_file
      outfile = File.join(destination_root, 'app', 'controllers', 'fl', 'core', 'comments_controller.rb')
      copy_file('../templates/controller.rb', outfile)
    end

    def add_route
      route_file = 'config/routes.rb'

      if File.exist?(route_file)
        if !_has_route?(route_file)
          _add_route(route_file)
        else
          say_status('status', "the fl:core:comments route is already defined")
        end
      else
        say_status('warning', "missing config.routes.el; creating one")
        File.open(route_file, "w") do |fd|
          fd.print "Rails.application.routes.draw do\n#{NAMESPACE}\nend\n"
        end
      end
    end

    private

    def _scan_route(route_file)
      ns_re = /^\s*(namespace)\s+[':]?([a-zA-Z0-9_]+)'?\s+do/
      res_do_re = /^\s*(resources)\s+[':]?([a-zA-Z0-9_]+)'?(.*)\s+do/
      res_re = /^\s*resources\s+[':]?([a-zA-Z0-9_]+)'?(.*)/
      mem_re = /^\s*(member)(.*)\s+do/
      coll_re = /^\s*(collection)(.*)\s+do/
      end_re = /^\s*end/
      nested = [ ]
      
      File.open(route_file, 'r') do |fd|
        fd.each_line do |line|
          type = :line
          name = nil
          if (line =~ ns_re) || (line =~ res_do_re)
            m = Regexp.last_match
            nested.push(m[2])
            #print("  ++++++++ nested: #{nested}\n")
            yield line, :enter, m[1], nested
          elsif (line =~ mem_re) || (line =~ coll_re)
            m = Regexp.last_match
            nested.push(m[1])
            #print("  ++++++++ nested: #{nested}\n")
            yield line, m[1].to_sym, nil, nested
          elsif line =~ res_re
            m = Regexp.last_match
            #print("  ++++++++ res: #{m[1]}\n")
            yield line, :resources, m[1], nested
          elsif line =~ end_re
            nested.pop()
            #print("  ++++++++ nested: #{nested}\n")
            yield line, :exit, nil, nested
          else
            yield line, :line, nil, nested
          end
        end
      end
    end

    def _has_route?(route_file)
      found = false
      _scan_route(route_file) do |line, type, name, namespaces|
        if (type == :resources) && (name == 'comments') && (namespaces[0] == 'fl') && (namespaces[1] == 'core')
          found = true
        end
      end

      found
    end

    def _add_route(route_file)
      # since route files are not large, we store it all in memory so that we don't have to deal with tempfiles
      routes = [ ]
      added = false
      has_ns = false

      _scan_route(route_file) do |line, type, name, namespaces|
        routes.push(line)
          
        if type == :enter
          has_ns = true
          if (namespaces[0] == 'fl') && (namespaces[1] == 'core')
            routes.push(RESOURCES)
            added = true
          end
        end
      end

      if !added
        routes = [ ]
        emitted = false
        if has_ns
          # There is at least a namespace, so add the fl:core one right before the first one

          _scan_route(route_file) do |line, type, name, namespaces|
            if (type == :enter) && !emitted
              routes.push(NAMESPACE)
              emitted = true
            end
            
            routes.push(line)
          end
        else
          # There are no namespaces, so let's add the fl:core one at the very top of the file 

          _scan_route(route_file) do |line, type, name, namespaces|
            routes.push(line)
            
            if line =~ /routes.draw/
              routes.push(NAMESPACE)
            end
          end
        end
      end

      backup_file = "#{route_file}.original"
      File.rename(route_file, backup_file)
      say_status('status', "created backup file #{backup_file}")
      File.open(route_file, "w") do |fd|
        fd.write(routes.join(''))
      end
      say_status('modify', "added the fl:core:comments route to #{route_file}")
    end
  end
end
