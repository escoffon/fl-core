module Fl::Core::Comments
  class InstallGenerator < Rails::Generators::Base
    include Fl::Core::GeneratorHelper
    
    PWD = File.expand_path('.')
    DB_MIGRATE = File.expand_path('../../../../../../../db/migrate', __FILE__)
    MIGRATION_FILE_NAMES = [ 'create_fl_core_comments' ]

    RESOURCES = "resources :<resource_name>, only: [ :index, :create, :update ]"

    class_option :object_class, type: :string, default: 'Fl::Core::Comment::Comment'
    class_option :service_class, type: :string, default: 'Fl::Core::Comment::Service'
    class_option :controller_class, type: :string, default: 'Fl::Core::CommentsController'

    source_root File.expand_path('../templates', __FILE__)
    
    def self.source_paths
      [ File.expand_path('../templates', __FILE__) ]
    end

    def run_generator()
      @gem_root = File.expand_path('../../../../../..', __dir__)

      init_variables()
      create_migration_files()
      create_initializer_file()
      create_object_file()
      create_service_file()
      create_controller_file()
      create_object_js_file()
      create_api_service_file()
      add_route()
    end

    private

    def init_variables()
      @comment_object_class = options['object_class']
      @comment_service_class = options['service_class']
      @comment_controller_class = options['controller_class']

      path = @comment_controller_class.underscore.split('/')
      file_root = path.pop.gsub('_controller', '')
      path << file_root
      
      @api_service_root = "/#{path.join('/')}"
      @api_service_class_name = "#{@comment_controller_class.gsub('Controller', '').gsub('::', '')}APIService"

      l = path.pop.singularize
      path << l
      @api_namespace = path.join('_')
      @api_pathname = path.join('/')
      @api_class_name = @comment_object_class.gsub(':', '')
    end
    
    def create_migration_files
      MIGRATION_FILE_NAMES.each { |fn| create_migration_file(DB_MIGRATE, fn) }
    end

    def create_initializer_file
      outfile = File.join(destination_root, 'config', 'initializers', 'comment.rb')
      template('initializer.rb', outfile)
    end

    def create_object_file
      outfile = File.join(destination_root, 'app', 'extensions', @comment_object_class.underscore + '.rb')
      template('comment.rb', outfile)
    end

    def create_service_file
      outfile = File.join(destination_root, 'app', 'extensions', @comment_service_class.underscore + '.rb')
      template('service.rb', outfile)
    end

    def create_controller_file
      outfile = File.join(destination_root, 'app', 'controllers', @comment_controller_class.underscore + '.rb')
      template('controller.rb', outfile)
    end

    def create_object_js_file()
      path = @comment_controller_class.underscore.split('/')
      file_root = path.pop.gsub('_controller', '')
      outfile = File.join(destination_root, 'vendor', 'javascript', path.join('/'), "#{file_root}.js")
      
      template('comment.js', outfile)
    end

    def create_api_service_file()
      path = @comment_controller_class.underscore.split('/')
      file_root = path.pop.gsub('_controller', '')
      outfile = File.join(destination_root, 'vendor', 'javascript', path.join('/'), "#{file_root}_api_service.js")
      
      template('comments_api_service.js', outfile)
    end

    def add_route
      route_file = 'config/routes.rb'

      if File.exist?(route_file)
        route = _route_from_class(@comment_controller_class)
        if !_has_route?(route_file, route)
          _add_route(route_file, route)
        else
          say_status('status', "the #{route.join(':')} route is already defined")
        end
      else
        say_status('warning', "missing config.routes.el; creating one")
        File.open(route_file, "w") do |fd|
          fd.print "Rails.application.routes.draw do\n#{_namespace_for_route(route)}\nend\n"
        end
      end
    end

    def _route_from_class(cname)
      components = @comment_controller_class.underscore.split('/')
      return components.push(components.pop.gsub('_controller', ''))
    end
    
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

    def _namespace_for_route(route)
      level = 2
      resource = route.last
      namespace = route[0, route.count-1]
      rv = [ ]
      
      namespace.each do |ns|
        indent = sprintf("%#{level}s", '')
        rv.push("#{indent}namespace :#{ns} do")
        level += 2
      end

      indent = sprintf("%#{level}s", '')
      rv.push("#{indent}#{RESOURCES.gsub('<resource_name>', resource)}")

      namespace.each do |ns|
        level -= 2
        indent = sprintf("%#{level}s", '')
        rv.push("#{indent}end")
      end

      return rv.push('').join("\n")
    end
    
    def _has_route?(route_file, route)
      namespace = route[0, route.count-1].join(':')
      resource = route.last
      
      found = false
      _scan_route(route_file) do |line, type, name, ns|
        if (type == :resources) && (name == resource) && (ns.join(':') == namespace)
          found = true
        end
      end

      found
    end

    def _add_route(route_file, route)
      # since route files are not large, we store it all in memory so that we don't have to deal with tempfiles
      routes = [ ]
      added = false
      has_ns = false

      namespace = route[0, route.count-1].join(':')
      resource = route.last

      _scan_route(route_file) do |line, type, name, ns|
        routes.push(line)
          
        if type == :enter
          has_ns = true
          if ns.join(':') == namespace
            indent = sprintf("%#{(ns.count + 1) * 2}s", '')
            routes.push("#{indent}#{RESOURCES.gsub('<resource_name>', resource)}\n")
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
              routes.push(_namespace_for_route(route)).push('')
              emitted = true
            end
            
            routes.push(line)
          end
        else
          # There are no namespaces, so let's add the fl:core one at the very top of the file 

          _scan_route(route_file) do |line, type, name, namespaces|
            routes.push(line)
            
            if line =~ /routes.draw/
              routes.push(_namespace_for_route(route)).push('')
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
      say_status('modify', "added the #{route.join(':')} route to #{route_file}")
    end
  end
end
