require File.join(File.dirname(__FILE__), 'hash_behaviours')
require File.join(File.dirname(__FILE__), 'update_behaviours')
require 'active_support/ordered_hash'
require 'active_support/inflector'
require 'json'

module IIIF
  module Presentation
    class AbstractObject

      include IIIF::Presentation::HashBehaviours
      include IIIF::Presentation::UpdateBehaviours

      JSON_LD_PROPS ||= %w{type id context}
      # These types could be anything...right?
      ALLOWED_ANYWHERE_PROPS ||= %w{label description 
        thumbnail attribution license logo see_also service related within}

      CONTEXT ||= 'http://iiif.io/api/presentation/2/context.json'
      INITIALIZABLE_KEYS ||= %w{@id @type}
      # Initialize a Presentation node
      # @param [Hash] hsh - Anything in this hash will be added to the Object. 
      #   Order is only guaranteed if an ActiveSupport::OrderedHash is passed.
      # @param [boolean] include_context (default: false). Pass true if the 
      #   context should be included.
      def initialize(hsh={}, include_context=false)
        @data = ActiveSupport::OrderedHash[hsh]
        unless hsh.has_key?('@context') || !include_context
          self['@context'] = CONTEXT
        end
        if self.class == IIIF::Presentation::AbstractObject
          raise "#{self.class} is an abstract class. Please use one of its subclasses."
        end
      end

      # Static methods and alternative constructors
      class << self
        # Parse from a file name, string, or existing hash
        def parse(s)
          new_instance = new()
          err_message = 
          if s.kind_of?(String) && File.exists?(s)
            new_instance.data = JSON.parse(IO.read(s))
          elsif s.kind_of?(String) && !File.exists?(s)
            new_instance.data = JSON.parse(s)
          elsif s.kind_of?(Hash)
            new_instance.data = ActiveSupport::OrderedHash[s]
          else
            m = '#parse takes a path to a file, a JSON String, or a Hash, ' 
            m += "argument was a #{s.class}."
            if s.kind_of?(String)
              m+= "If you were trying to point to a file, does it exist?"
            end
            raise ArgumentError, m
          end
          new_instance
        end
      end

      # JSON-LD accessor/mutators, can't have '@' :-(. Consider '_' or something else?

      JSON_LD_PROPS.each do |jld_prop|
        # Setters
        define_method("#{jld_prop}=") do |arg|
          self.send('[]=', "@#{jld_prop}", arg) 
        end
        define_method("set_#{jld_prop}".camelize(:lower)) do |arg|
          self.send('[]=', "@#{jld_prop}", arg) 
        end
        # Getters
        define_method("#{jld_prop}") do
          self.send('[]', "@#{jld_prop}") 
        end
        define_method("get_#{jld_prop}".camelize(:lower)) do
          self.send('[]', "@#{jld_prop}") 
        end
      end

      def metadata=(arr)
        self['metadata'] = arr
      end

      def metadata
        self['metadata'] ||= []
        self['metadata']
      end

      # Always a string--are there others?
      # TODO: should the value be validated based on the class?
      def viewing_hint=(t)
        self['viewingHint'] = t 
      end
      alias setViewingHint viewing_hint=      

      # Many of these can be lists! What happens if, e.g.:
      # irb(main):005:0> f = 'foo'
      # => "foo"
      # irb(main):006:0> f << 'x'
      # => "foox"
      # Could assume everything is an Array and then change to
      # a String or Object when we serialize if there's is only one member.
      #  * But what are the implications for round-tripping? Every value that isn't
      # an array would need to become one.
      #  * Need to override []= and [] with the same behavior
      # Maybe you should just know your data.

      ALLOWED_ANYWHERE_PROPS.each do |anywhere_prop|
        # Setters
        define_method("#{anywhere_prop}=") do |arg|
          self.send('[]=', "#{anywhere_prop}", arg) 
        end
        define_method("set_#{anywhere_prop}".camelize(:lower)) do |arg|
          self.send('[]=', "#{anywhere_prop}", arg) 
        end
        # Getters
        define_method("#{anywhere_prop}") do
          self.send('[]', "#{anywhere_prop}") 
        end
        define_method("get_#{anywhere_prop}".camelize(:lower)) do
          self.send('[]', "#{anywhere_prop}") 
        end
      end
      ##

      def to_hash
        # TODO: should there be a list of expected keys so that we can raise 
        # warnings (force: true ?) when unexpected properties are given?
        self.tidy_empties
        @data
      end
      alias to_h to_hash

      def to_json
        self.tidy_empties
        @data.to_json
      end

      def to_pretty_json
        JSON.pretty_generate(self.to_hash)
      end

      def tidy_empties
        # metadata
        if self.has_key?('metadata')
          if self['metadata'].empty?
            self.delete('metadata')
          else
            unless self['metadata'].all? { |entry| entry.kind_of?(Hash) }
              raise TypeError, 'All entries in the metadata list must be a type of Hash' 
            end
          end
        end
      end

      def data=(hsh)
        @data = hsh
      end

    end
  end
end

