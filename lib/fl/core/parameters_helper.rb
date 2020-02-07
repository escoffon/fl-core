require 'fl/core/i18n'

module Fl::Core
  # Helper for parameter management.

  module ParametersHelper
    # Exception raised by conversion utilities.

    class ConversionError < RuntimeError
    end

    # Convert a parameter to an object.
    # The value can be one of the following:
    #
    # - A [https://github.com/rails/globalid][GlobalID], which is used to look up the object.
    # - A string containing a [https://github.com/rails/globalid][GlobalID], which is used to look up
    #   the object.
    # - A string in the format _classname_/_id_, where _classname_ is the name of the class for the object,
    #   and _id_ is its object identifier. The method uses the class' +find+ method to look up the object.
    # - A Hash containing the key _key_. In this case, the method fetches the value from that key, and tries
    #   again.
    # - If the hash does not contain _key_, then the method checks for **:global_id**, which it tries to resolve
    #   as a [https://github.com/rails/globalid][GlobalID].
    #   Otherwise, it looks for the key **:fingerprint**, and tries to resolve the fingerprint.
    #   Finally, it tries the two keys **:id** and **:type**, which
    #   will be used to look up the object via the +find+ method (**:type** is the class name).
    # - An object instance, which will be used as-is.
    #
    # @param p The parameter value. See above for a description of its format.
    # @param key [Symbol] The key to look up, if _p_ is a Hash.
    # @param expect [String, Class, Proc, Array<String, Class>] An object check. If a string,
    #  it is the name of the class for the object. If a class, it is the class itself.
    #  If an array, it contains a list of class names or classes to check: if the object is an instance
    #  of one of them, the check succeeds.
    #  Finally, if it is a Proc, the proc is called with a single argument, the object; a falsy return
    #  value fails the conversion.
    # @param strict [Boolean] If `true`, the *expect* check uses `instance_of` for the type checking;
    #  if `false`, it uses `is_a?`, which matches the given class and subclasses.
    #
    # @return Returns an object, or +nil+ if no object was found.
    #
    # @raise [ConversionError] if +p+ maps to a +nil+, or if the check fails.
    #
    # @example Using a string parameter.
    #  Fl::Core::ParametersHelper.object_from_parameter('MyClass/1234')
    #  Fl::Core::ParametersHelper.object_from_parameter('gid://app/MyClass/1234')
    #
    # @example Using an object parameter.
    #  o = MyClass.new
    #  Fl::Core::ParametersHelper.object_from_parameter(c)
    #  p = { obj: o, key: 'value' }
    #  Fl::Core::ParametersHelper.object_from_parameter(p, :obj)
    #
    # @example Using a hash.
    #  h = { type: 'MyClass', id: 1234 }
    #  Fl::Core::ParametersHelper.object_from_parameter(h)
    #  h = { type: 'MyClass', id: '1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.object_from_parameter(h, nil, [ MyClass ])
    #  h = { fingerprint: 'MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.object_from_parameter(h)
    #  h = { global_id: 'gid://app/MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.object_from_parameter(h)
    #
    # @example Using a nested hash.
    #  h = { type: 'MyClass', id: 1234, key: 'value' }
    #  Fl::Core::ParametersHelper.object_from_parameter({ obj: h }, :obj)
    #  h = { fingerprint: 'MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.object_from_parameter({ obj: h }, :obj)
    #  h = { global_id: 'gid://app/MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.object_from_parameter({ obj: h }, :obj)
    #
    # @example Check if the parameter includes the module +Foo+.
    #  Fl::Core::ParametersHelper.object_from_parameter(h, nil, Proc.new { |o| o.class.include?(Foo) })
    #
    # @example Include the helper.
    #  module SampleModule
    #  end
    #
    #  class SampleClass
    #    include SampleModule
    #  end
    #
    #  class MyClass
    #    include Fl::Core::ParametersHelper
    #    attr_reader :obj
    #
    #    def initialize(params)
    #      @obj = object_from_parameter(params, :obj, Proc.new { |obj| obj.class.include?(SampleModule) })
    #    end
    #  end
    #
    #  o = MyClass.new(obj: 'SampleClass/10', key: 'value', other: 'other')

    def self.object_from_parameter(p, key = nil, expect = nil, strict = false)
      obj = nil
      h = nil

      case p
      when GlobalID
        begin
          obj = GlobalID::Locator.locate(p)
        rescue NameError => x
          raise ConversionError, I18n.tx('fl.core.conversion.missing_class', :class => x.message)
        rescue ActiveRecord::RecordNotFound => ax
          raise ConversionError, I18n.tx('fl.core.conversion.no_object', id: "#{p.to_s}")
        end
      when String
        gid = GlobalID.parse(p)
        if gid.is_a?(GlobalID)
          begin
            obj = GlobalID::Locator.locate(gid)
          rescue NameError => x
            raise ConversionError, I18n.tx('fl.core.conversion.missing_class', :class => x.message)
          rescue ActiveRecord::RecordNotFound => ax
            raise ConversionError, I18n.tx('fl.core.conversion.no_object', id: "#{gid.to_s}")
          end
        else
          fc, fid = ActiveRecord::Base.split_fingerprint(p)
          h = { type: fc, id: fid }
        end
      when Hash, ActionController::Parameters
        if !key.nil? && p.has_key?(key.to_sym)
          case p[key.to_sym]
          when GlobalID
            begin
              obj = GlobalID::Locator.locate(p[key.to_sym])
            rescue NameError => x
              raise ConversionError, I18n.tx('fl.core.conversion.missing_class', :class => x.message)
            rescue ActiveRecord::RecordNotFound => ax
              raise ConversionError, I18n.tx('fl.core.conversion.no_object', id: "#{p[key.to_sym].to_s}")
            end
          when String
            gid = GlobalID.parse(p[key.to_sym])
            if gid.is_a?(GlobalID)
              begin
                obj = GlobalID::Locator.locate(gid)
              rescue NameError => x
                raise ConversionError, I18n.tx('fl.core.conversion.missing_class', :class => x.message)
              rescue ActiveRecord::RecordNotFound => ax
                raise ConversionError, I18n.tx('fl.core.conversion.no_object', id: "#{gid.to_s}")
              end
            else
              fc, fid = ActiveRecord::Base.split_fingerprint(p[key.to_sym])
              h = { type: fc, id: fid }
            end
          when Hash
            h = p[key.to_sym]
          else
            obj = p[key.to_sym]
          end
        else
          h = p
        end
      else
        obj = p
      end

      unless obj
        if !h.nil? && h.has_key?(:type) && h.has_key?(:id)
          if h[:type].nil?
            raise ConversionError, I18n.tx('fl.core.conversion.missing_type', param: p)
          end
          
          if h[:id].nil? || (h[:id].is_a?(String) && (h[:id] !~ /^[0-9]+$/))
            raise ConversionError, I18n.tx('fl.core.conversion.missing_id', param: p)
          end
          
          begin
            klass = h[:type].constantize
          rescue => exc
            raise ConversionError, I18n.tx('fl.core.conversion.missing_class', :class => h[:type])
          end

          begin
            obj = klass.find(h[:id])
          rescue => exc
            raise ConversionError, I18n.tx('fl.core.conversion.no_object', id: "#{h[:type]}/#{h[:id]}")
          end
        else
          raise ConversionError, I18n.tx('fl.core.conversion.incomplete', :class => h[:type], :id => h[:id])
        end
      end

      # OK, we have the object. Now see if it is one of the expected ones

      check_method = (strict) ? 'instance_of?'.to_sym : 'is_a?'.to_sym
      case expect
      when String
        begin
          klass = expect.constantize
        rescue => exc
          raise ConversionError, I18n.tx('fl.core.conversion.missing_class', :class => expect)
        end
        
        if !obj.send(check_method, klass)
          raise ConversionError, I18n.tx('fl.core.conversion.unexpected', :class => obj.class, :expect => expect)
        end
      when Class
        if !obj.send(check_method, expect)
          raise ConversionError, I18n.tx('fl.core.conversion.unexpected', :class => obj.class, :expect => expect)
        end
      when Array
        found = expect.any? do |x|
          case x
          when String
            begin
              klass = x.constantize
              obj.send(check_method, klass)
            rescue => exc
            end
          when Class
            obj.send(check_method, x)
          end
        end
        
        unless found
          xl = expect.map { |x| x.to_s }
          raise ConversionError, I18n.tx('fl.core.conversion.unexpected',
                                         :class => obj.class, :expect => xl.join(', '))
        end
      when Proc
        unless expect.call(obj)
          raise ConversionError, I18n.tx('fl.core.conversion.unexpected_proc', :class => obj.class)
          
        end
      end

      obj
    end

    # Convert a parameter to a fingerprint.
    # The value can be one of the following:
    #
    # - An object that responds to the *:fingerprint* method, whose return value is returned.
    # - An object that responds to the *:to_global_id* method, whose return value is used to extract the fingerprint.
    # - A [https://github.com/rails/globalid][GlobalID], which is used to extract the fingerprint.
    # - A string containing a [https://github.com/rails/globalid][GlobalID], which is used to 
    #   extract the fingerprint.
    # - A string in the format _classname_/_id_, where _classname_ is the name of the class for the object,
    #   and _id_ is its object identifierK (in other words, a string containing a fingerprint).
    # - A Hash containing the key _key_. In this case, the method fetches the value from that key, and tries
    #   again.
    # - If the hash does not contain _key_, then the method checks for **:global_id**, which it tries to resolve
    #   as a [https://github.com/rails/globalid][GlobalID].
    #   Otherwise, it looks for the key **:fingerprint**, and tries to resolve the fingerprint.
    #   Finally, it tries the two keys **:id** and **:type**, which
    #   will be used to generate the fingerprint.
    #
    # @param p The parameter value. See above for a description of its format.
    # @param key [Symbol] The key to look up, if _p_ is a Hash.
    # @param expect [String,Class,Array<String,Class>] A type check. If a string,
    #  it is the name of the class for the fingerprint. If a class, it is the class itself.
    #  If it is an array, the class name in the fingerprint must match at least one of the elements.
    #  If this parameter is present, the class name in the fingerprint must match the value of *expect*.
    #
    # @return [String,nil] Returns a string containing the fingerprint, or +nil+ if no fingerprint was found.
    #
    # @raise [ConversionError] if +p+ maps to a +nil+, or if the check fails.
    #
    # @example Using a string parameter.
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter('MyClass/1234')
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter('gid://app/MyClass/1234')
    #
    # @example Using a hash.
    #  h = { type: 'MyClass', id: 1234 }
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter(h)
    #  h = { type: 'MyClass', id: '1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter(h, nil, MyClass)
    #  h = { fingerprint: 'MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter(h)
    #  h = { global_id: 'gid://app/MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter(h, nil, 'MyClass')
    #
    # @example Using a nested hash.
    #  h = { type: 'MyClass', id: 1234, key: 'value' }
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter({ obj: h }, :obj)
    #  h = { fingerprint: 'MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter({ obj: h }, :obj)
    #  h = { global_id: 'gid://app/MyClass/1234', mykey: 'value' }
    #  Fl::Core::ParametersHelper.fingerprint_from_parameter({ obj: h }, :obj)
    #
    # @example Include the helper.
    #  module SampleModule
    #  end
    #
    #  class SampleClass
    #    include SampleModule
    #  end
    #
    #  class MyClass
    #    include Fl::Core::ParametersHelper
    #    attr_reader :obj
    #
    #    def initialize(params)
    #      @fp = fingerprint_from_parameter(params, :fp, 'SampleClass')
    #    end
    #  end
    #
    #  o = MyClass.new(fp: 'SampleClass/10', key: 'value', other: 'other')

    def self.fingerprint_from_parameter(p, key = nil, expect = nil)
      fcn = nil
      fid = nil
      h = nil

      if p.respond_to?(:fingerprint)
        fcn, fid = ActiveRecord::Base.split_fingerprint(p.fingerprint)
      elsif p.respond_to?(:to_global_id)
        uri = p.to_global_id.uri
        fcn, fid = ActiveRecord::Base.split_fingerprint(uri.path.slice(1, uri.path.length))
      elsif p.is_a?(String)
        if p =~ /^gid:/i
          uri = URI.parse(p)
          if uri.path.is_a?(String) && (uri.path.length > 0)
            fcn, fid = ActiveRecord::Base.split_fingerprint(uri.path.slice(1, uri.path.length))
          end
        else
          fcn, fid = ActiveRecord::Base.split_fingerprint(p)
        end
      elsif p.is_a?(GlobalID)
        fcn, fid = ActiveRecord::Base.split_fingerprint(p.uri.path.slice(1, p.uri.path.length))
      elsif p.is_a?(Hash) || p.is_a?(ActionController::Parameters)
        if !key.nil? && !p[key].nil?
          return fingerprint_from_parameter(p[key], nil, expect) 
        end
        if p.has_key?(:global_id)
          gid = p[:global_id]
          if gid.is_a?(GlobalID)
            fcn, fid = ActiveRecord::Base.split_fingerprint(gid.uri.path.slice(1, gid.uri.path.length))
          elsif gid.is_a?(String) && (gid =~ /^gid:/i)
            uri = URI.parse(gid)
            fcn, fid = ActiveRecord::Base.split_fingerprint(uri.path.slice(1, uri.path.length))
          end
        elsif p.has_key?(:fingerprint)
          fcn, fid = ActiveRecord::Base.split_fingerprint(p[:fingerprint])
        elsif p.has_key?(:type) && p.has_key?(:id)
          fcn = (p[:type].is_a?(Class)) ? p[:type].name : p[:type]
          fid = p[:id]
        end
      end

      if fcn.nil? || (fcn.length < 1)
        raise ConversionError, I18n.tx('fl.core.conversion.incomplete', :class => fcn, :id => fid)
      end

      if !expect.nil?
        x = ((expect.is_a?(Array)) ? expect : [ expect ]).map { |e| (e.is_a?(Class)) ? e.name : e }
        found = x.find_index { |e| e == fcn }
        if found.nil?
          raise ConversionError, I18n.tx('fl.core.conversion.unexpected', :class => fcn, :expect => x.join(', '))
        end
      end

      (fid.nil?) ? fcn : "#{fcn}/#{fid}"
    end

    # Include hook.
    # Adds to the including class an instance method +object_from_parameter+ that forwards the call
    # to {Fl::Core::ParametersHelper.object_from_parameter}.

    def self.included(base)
      base.class_eval do
        def object_from_parameter(p, key = nil, expect = nil, strict = false)
          Fl::Core::ParametersHelper.object_from_parameter(p, key, expect, strict)
        end
      end
    end
  end
end
