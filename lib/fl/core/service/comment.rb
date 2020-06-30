module Fl::Core::Service
  # Namespace for service objects for comments.
  # Comment service objects come in Active Record and Neo4j implementations.

  module Comment
  end
end

if Module.const_defined?('ActiveRecord')
  require 'fl/core/service/comment/active_record'
end
if Module.const_defined?('Neo4j')
  require 'fl/core/service/comment/neo4j'
end
