module Fl::Core::ProseMirror
  # Helpers for the Prosemirror module.

  module Helper
    # Generate a simple content structure for plain text.
    # The method generates the ProseMirror representation of *content*, which is assumed to be a plain text string.
    #
    # @param text [String] The plain text to wrap in a ProseMirror content structure.
    #
    # @return [Hash] Returns a hash containing two keys: **:json** is the JSON representation, and **:html**
    #  the corresponding HTML representation.

    def self.content(text)
      return {
        html: "<p>#{text}</p>",
        json: {
          "type" => "doc",
          "content" =>  [
            {
              "type" => "paragraph",
              "attrs" => { "textAlign" => "left", "clearFloat" => "none" },
              "content" => [
                {
                  "type" => "text",
                  "text" => "#{text}"
                }
              ]
            }
          ]
        }
      }
    end

    # Traverse content (depth-first).
    # This method iterates over the value of the key `content` in *node* (if present), which should be an array of
    # content nodes.
    # For each element in the array, it calls the block *callback*, passing the node element, the node level, and the
    # *context* argument. The node level starts at 0 and is bumped by one with each traversal to the contents of
    # the node.
    #
    # If the callback's value is `false`, the traverse stops and the method return `false`.
    #
    # @param node [Hash,String] The content node to traverse; a string value is assumed to be JSON, and converted to
    #  a hash.
    # @param context [any] A context object to pass to the block; this is often a Hash.
    #
    # @yieldparam [Hash] node The node element; this is a Hash representation of the JSON node.
    # @yieldparam [Integer] level The traversal depth of the node; starts at 0 and increases by 1 with each call
    #  into child elements.
    # @context [any] The value of *context*.
    #
    # @yieldreturn [Boolean,any] The block returns `false` to terminate the traversal early. With any other return
    #  value, traversal continues.
    #
    # @return [Boolean,nil] If the traversal completes, the method returns `true`; if it exits early due to the value
    #  of *callback*, it returns `false`; with errors or invalid arguments, it returns `nil`.

    def self.traverse(node, context = { }, &callback)
      return nil if callback.nil?

      hn = (node.is_a?(String)) ? JSON.parse(node) : node
      return nil unless hn.is_a?(Hash)

      level = 0
      return _traverse(hn, level, context, callback)
    end

    private

    def self._traverse(node, level, context, callback)
      # first, the node itself
      
      return false if callback.call(node, level, context) == false

      # now the contents, if any

      if node['content'].is_a?(Array)
        level += 1
        node['content'].each do |n|
          return false if _traverse(n, level, context, callback) == false
        end
      end

      return true
    end

    public
    
    # Perform actions when the module is included.

    def self.included(base)
      base.class_eval do
        # include InstanceMethods
      end
    end
  end
end
