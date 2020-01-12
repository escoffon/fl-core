require 'json'

module Fl::Core
  class JsAssetsGenerator < Rails::Generators::Base
    include Fl::Core::GeneratorHelper
    
    desc <<-DESC
  This generator installs the Javascript core assets into vendor/javascript.
  Some gems (for example, webpacker) do not support accessing assets outside of the
  directory structure of the Rails application, and therefore you have to copy
  those files over.

  The generator also installs a starter documentation configuration directory and
  the necessary Yard package references.

  It takes one optional flag:
    --nodoc    If present, the documentation configuration is not created.
               By default, the documentation configuration is created.

  For example, given this command:
    rails generate fl:core:js_assets
  The generator will create:
    vendor/javascript/fl/core
  as a copy of app/javascript/fl/core in the gem.

  It will also create a package.json file, or modify an existing one, to register
  Yarn packages used by the Javascript assets (many of which are used by the
  documentation system).

  Finally, unless the --nodoc flag is given, a default configuration file is
  created in
    doc/dgeni/conf.js
  Template API and Guide content files are created under
    doc/dgeni/contents
  And a Gulp driver file
    gulpfile.js
  is created in the app's root directory. Running the Gulp tool generates
  documentation in
    public/doc/js
  that documents the assets that were installed above, and any other sources in
    app/javascript
  (You can modify much of this behavior by editing the conf.js file.)
DESC

    class_option :nodoc, aliases: "-n", type: :boolean, required: false,
    	         desc: "Controls generation of documentation configuration"

    APP_ROOT = File.join('app', 'javascript', 'fl', 'core')
    VENDOR_ROOT = File.join('vendor', 'javascript', 'fl', 'core')
    APP_ASSETS = [
      {
        from: File.join(APP_ROOT, 'fl.js'),
        to: File.join(VENDOR_ROOT, 'fl.js'),
      },
      {
        from: File.join(APP_ROOT, 'model_factory.js'),
        to: File.join(VENDOR_ROOT, 'model_factory.js'),
      },
      {
        from: File.join(APP_ROOT, 'object_system.js'),
        to: File.join(VENDOR_ROOT, 'object_system.js'),
      },
      {
        from: File.join(APP_ROOT, 'api_services.js'),
        to: File.join(VENDOR_ROOT, 'api_services.js'),
      },
      {
        from: File.join(APP_ROOT, 'active_storage.js'),
        to: File.join(VENDOR_ROOT, 'active_storage.js'),
      }
    ]

    PACKAGE_FILE = 'package.json'
    
    source_root File.expand_path('templates', __dir__)

    def run_generator()
      @gem_root = File.expand_path('../../../../..', __dir__)

      copy_assets()
      generate_js_index()
      add_yarn_packages()
      unless options[:nodoc]
        add_doc_config()
        add_doc_script()
      end
    end

    private
    
    def copy_assets
      _copy_assets(APP_ASSETS, @gem_root, destination_root)
    end

    def generate_js_index
      outfile = File.join(destination_root, 'vendor', 'javascript', 'fl', 'core', 'index.js')
      template('fl_core_index.js', outfile)
    end

    def _copy_assets(assets, iroot, oroot)
      assets.each do |a|
        ifile = File.join(iroot, a[:from])
        ofile = File.join(oroot, a[:to])
        copy_file(ifile, ofile)
      end
    end

    def _list_packages(root)
      jp = File.open(File.join(root, PACKAGE_FILE)) { |f| JSON.parse(f.read) }

      {
        dependencies: {
          full: jp['dependencies'],
          names: jp['dependencies'].reduce([ ]) do |acc, (k, v)|
            acc << k
            acc
          end
        },

        devDependencies: {
          full: jp['devDependencies'],
          names: jp['devDependencies'].reduce([ ]) do |acc, (k, v)|
            acc << k
            acc
          end
        }
      }
    end

    def _package_entry(name, version, offset)
      "#{offset}    \"#{name}\": \"#{version}\""
    end

    def _format_package_list(pkg, offset)
      d = pkg[:names].sort.reduce([ ]) do |acc, n|
        acc.push(_package_entry(n, pkg[:full][n], offset))
        acc
      end
      d.join(",\n")
    end

    def _update_dependencies(dependencies, gem_p)
      num_updates = 0
      gem_p[:names].each do |n|
        if dependencies.has_key?(n)
          if dependencies[n] != gem_p[:full][n]
            say_status('update', "install new version #{gem_p[:full][n]} for package #{n}")
            dependencies[n] = gem_p[:full][n]
            num_updates += 1
          end
        else
          say_status('create', "add package #{n} with version #{gem_p[:full][n]}")
          dependencies[n] = gem_p[:full][n]
          num_updates += 1
        end
      end

      d = dependencies.keys.sort.reduce({ names: [ ], full: { } }) do |acc, n|
        acc[:names] << n
        acc[:full][n] = dependencies[n]
        acc
      end

      { updated: num_updates, output: d }
    end

    def _emit_dependencies_section(plines, m, dependencies)
      output = ""
      offset = m[1]
      tag = m[2]
      rest = m[3]
      comma = (rest.index(',')) ? ',' : ''

      output << "#{offset}#{tag} {\n"
      output << _format_package_list(dependencies[:output], offset)
      output << "\n#{offset}#{comma}\n"

      if rest.index('}').nil?
        while plines.length > 0
          l = plines.shift
          if l =~ /}/
            output << l
            break
          end
        end
      end

      output
    end
    
    def _update_package_file(gem_p)
      pkg_file = File.join(destination_root, PACKAGE_FILE)
      pkg = File.open(File.join(destination_root, PACKAGE_FILE)) { |f| JSON.parse(f.read()) }
      pkg['dependencies'] = {} unless pkg['dependencies'].is_a?(Hash)
      pkg['devDependencies'] = {} unless pkg['devDependencies'].is_a?(Hash)
      deps = _update_dependencies(pkg['dependencies'], gem_p[:dependencies])
      devDeps = _update_dependencies(pkg['devDependencies'], gem_p[:devDependencies])

      return if (deps[:updated] + devDeps[:updated]) < 1
      
      plines = File.open(pkg_file) { |f| f.readlines() }
      output = ''
      while plines.length > 0
        l = plines.shift
        
        if l =~ /^(\s*)("dependencies":)(.*)/
          output << _emit_dependencies_section(plines, Regexp.last_match, deps)
        elsif l =~ /^(\s*)("devDependencies":)(.*)/
          output << _emit_dependencies_section(plines, Regexp.last_match, devDeps)
        else
          output << l
        end
      end

      say_status('update', "update #{PACKAGE_FILE}")
      File.open(pkg_file, 'w') { |f| f.write(output) }

      say_status('warning', "please run yarn to refresh the package distribution", :yellow)
    end

    def add_yarn_packages()
      gem_p = _list_packages(@gem_root)
      if File.exists?(File.join(destination_root, PACKAGE_FILE))
        _update_package_file(gem_p)
      else
        @app_name = if Rails.application.config.session_options[:key] =~ /^_(.*)_session/
                      Regexp.last_match[1]
                    else
                      'Rails application'
                    end
        @dependencies = _format_package_list(gem_p[:dependencies], '  ')
        @devDependencies = _format_package_list(gem_p[:devDependencies], '  ')

        template('package.json', File.join(destination_root, PACKAGE_FILE))
      end
    end

    def add_doc_config()
      doc_files = [
        { inp: [ 'conf.js' ], outp: [ destination_root, 'doc', 'dgeni', 'conf.js' ] },
        { inp: [ 'content', 'api', 'index.md' ],
          outp: [ destination_root, 'doc', 'dgeni', 'content', 'api', 'index.md' ] },
        { inp: [ 'content', 'guide', 'index.md' ],
          outp: [ destination_root, 'doc', 'dgeni', 'content', 'guide', 'index.md' ] },
        { inp: [ 'content', 'guide', 'model_services.md' ],
          outp: [ destination_root, 'doc', 'dgeni', 'content', 'guide', 'model_services.md' ] },
        
        { inp: [ 'gulpfile.js' ], outp: [ destination_root, 'gulpfile.js' ] },
      ]
        
      doc_files.each do |df|
        template(File.join(df[:inp]), File.join(df[:outp]))
      end
    end

    def add_doc_script()
      script_assets = [
        {
          from: File.join('scripts', 'docs_js.sh'),
          to: File.join('scripts', 'docs_js.sh')
        }
      ]
      _copy_assets(script_assets, @gem_root, destination_root)
    end
  end
end

