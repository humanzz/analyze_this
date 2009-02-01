class String
  def blank?
    self == ""
  end
end

class NilClass
  def blank?
    true
  end
end