
# NOTE: this class "teaches" rails how to handle vectors as a type, so it will be transparent
#       to the model when working with a attribute of this type. So it implements the methods
#       defined by ActiveModel::Type::Value to work as a type.
# A type class works as a translation layer that works on both ways, from database to model and
# from the model to the database
class VectorType < ActiveRecord::Type::Value
  def initialize(dimensions:)
    @dimensions = dimensions
    super()
  end

  def type
    :vector
  end

  # runs whenever a value is assigned to the attribute
  def cast(value)
    case value
    when ActiveModel::Type::Binary::Data then value.to_s.unpack("f*") # unpack convert from binary to a float array
    when String then value.unpack("f*")
    else value
    end
  end

  # runs when writting in the database
  def serialize(value)
    return value unless value.is_a?(Array)

    # Wrap in ActiveModel::Type::Binary::Data so the connection adapter quotes
    # this as a SQLite blob literal (x'...') instead of inlining the raw packed
    # bytes as a quoted string, which breaks on embedded NUL/control bytes.
    ActiveModel::Type::Binary::Data.new(value.pack("f*")) # pack convert a array into a single binary string
  end

  # runs when the data is loaded from the database
  def deserialize(value)
    cast(value)
  end
end
