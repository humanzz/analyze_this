class String #:nodoc:
  def blank?
    self == ""
  end
end

class NilClass #:nodoc:
  def blank?
    true
  end
end
