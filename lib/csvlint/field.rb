require 'set'

module Csvlint
  
  class Field
    include Csvlint::ErrorCollector

    attr_reader :name, :constraints

    TYPE_VALIDATIONS = {
        'http://www.w3.org/2001/XMLSchema#int'     => lambda { |field, value, row, column| Integer value },
        'http://www.w3.org/2001/XMLSchema#float'   => lambda { |field, value, row, column| Float value },
        'http://www.w3.org/2001/XMLSchema#double'   => lambda { |field, value, row, column| Float value },
        'http://www.w3.org/2001/XMLSchema#anyURI'  => lambda do |field, value, row, column|
          u = URI.parse value
          field.build_errors(:invalid_type, :schema, row, column) unless u.kind_of?(URI::HTTP) || u.kind_of?(URI::HTTPS)
          u
        end,
        'http://www.w3.org/2001/XMLSchema#boolean' => lambda do |field, value, row, column|
          return true if ['true', '1'].include? value
          return false if ['false', '0'].include? value
          raise ArgumentError.new 'Not a Boolean type'
        end,
        'http://www.w3.org/2001/XMLSchema#nonPositiveInteger' => lambda do |field, value, row, column|
          i = Integer value
          field.build_errors(:invalid_type, :schema, row, column) unless i <= 0
          i
        end,
        'http://www.w3.org/2001/XMLSchema#negativeInteger' => lambda do |field, value, row, column|
          i = Integer value
          field.build_errors(:invalid_type, :schema, row, column) unless i < 0
          i
        end,
        'http://www.w3.org/2001/XMLSchema#nonNegativeInteger' => lambda do |field, value, row, column|
          i = Integer value
          field.build_errors(:invalid_type, :schema, row, column) unless i >= 0
          i
        end,
        'http://www.w3.org/2001/XMLSchema#positiveInteger' => lambda do |field, value, row, column|
          i = Integer value
          field.build_errors(:invalid_type, :schema, row, column) unless i > 0
          i
        end
    }

    def initialize(name, constraints={})
      @name = name
      @constraints = constraints || {}
      @uniques = Set.new
      reset
    end
    
    def validate_column(value, row=nil, column=nil)
      reset
      if constraints["required"] == true
        build_errors(:missing_value, :schema, row, column) if value.nil? || value.length == 0
      end
      if constraints["minLength"]
        build_errors(:min_length, :schema, row, column) if value.nil? || value.length < constraints["minLength"]
      end
      if constraints["maxLength"]
          build_errors(:max_length, :schema, row, column) if !value.nil? && value.length > constraints["maxLength"]
      end
      if constraints["pattern"]
          build_errors(:pattern, :schema, row, column) if !value.nil? && !value.match( constraints["pattern"] )
      end
      if constraints["unique"] == true
        if @uniques.include? value
          build_errors(:unique, :schema, row, column)
        else
          @uniques << value
        end
      end

      tv = TYPE_VALIDATIONS[constraints["type"]]

      if tv
        begin
          tv.call self, value, row, column
        rescue ArgumentError => e
          build_errors(:invalid_type, :schema, row, column)
        end
      end

      return valid?
    end

  end
end