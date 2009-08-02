class String #:nodoc: all
  def blank?
    self == ""
  end
end

class NilClass #:nodoc: all
  def blank?
    true
  end
end
