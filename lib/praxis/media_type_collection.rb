module Praxis

  module StructCollection
    def self.included(klass)
      klass.instance_eval do
        include(Enumerable)
      end
    end

    def _members=(members)
      @members = members
    end

    def _members
      @members || []
    end

    def each
      _members.each { |member| yield(member) }
    end
  end

  class MediaTypeCollection < MediaType
    include Enumerable

    def self._finalize!
      super

      if const_defined?(:Struct, false)
        self::Struct.instance_eval do
          include StructCollection
        end
      end

    end

    def self.member_type(type=nil)
      return @media_type unless type
      raise ArgumentError, "invalid type: #{type.name}" unless type < MediaType

      @member_type = type
    end

    def self.example(context=nil, options: {})
      result = super

      context = case context
      when nil
        ["#{self.name}-#{values.object_id.to_s}"]
      when ::String
        [context]
      else
        context
      end

      members = []
      size = rand(3) + 1


      size.times do |i|
        subcontext = context + ["at(#{i})"]
        members << @member_type.example(subcontext)
      end

      
      result.object._members = members
      result
    end

    def self.load(value,context=Attributor::DEFAULT_ROOT_CONTEXT, **options)
      if value.kind_of?(String)
        value = JSON.parse(value)
      end

      case value
      when nil, self
        value
      when Hash
        # Need to parse/deserialize first
        self.new(self.attribute.load(value,context, **options))
      when Array
        object = self.attribute.load({})
        object._members = value.collect { |subvalue| @member_type.load(subvalue) }
        self.new(object)
      else
        # Just wrap whatever value
        self.new(value)
      end
    end


    def render(view_name=:default, context: Attributor::DEFAULT_ROOT_CONTEXT)
      if (view = self.class.views[view_name])
        # we have the view ourselves, use it with our atrributes
        super
      else
        # render each member with the view
        @object.collect.with_index do |member, i| 
          subcontext = context + ["at(#{i})"]
          member.render(view_name, context: subcontext)
        end
      end
    end


    def each
      @object.each { |member| yield(member) }
    end


    def validate(context=Attributor::DEFAULT_ROOT_CONTEXT)
      errors = super

      @object.each_with_object(errors) do |member, errors|
        errors.push(*member.validate(context))
      end
    end

  end
end
