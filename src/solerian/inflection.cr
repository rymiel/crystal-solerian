module Solerian::Inflection
  enum Type
    # Noun types
    F1t
    F1d
    F2
    F2i
    F2x
    M1
    M2
    N1
    N2

    # Verb types
    O
    I
    II
    III
    IV

    def class_name(long = true) : String
      case self
      in .f1t? then long ? "Feminine type 1t" : "F1t"
      in .f1d? then long ? "Feminine type 1t" : "F1t"
      in .f2?  then long ? "Feminine type 2" : "F2"
      in .f2i? then long ? "Feminine type 2i" : "F2i"
      in .f2x? then long ? "Feminine type 2x" : "F2x"
      in .m1?  then long ? "Masculine type 1" : "M1"
      in .m2?  then long ? "Masculine type 2" : "M2"
      in .n1?  then long ? "Neuter type 1" : "N1"
      in .n2?  then long ? "Neuter type 2" : "N2"
      in .o?   then long ? "Type 0 verb (0-class, T CONT)" : "0"
      in .i?   then long ? "Type I verb (e-class, IT CONT)" : "I"
      in .ii?  then long ? "Type II verb (a-class, TRANS)" : "II"
      in .iii? then long ? "Type III verb (d-class, ONCE)" : "III"
      in .iv?  then long ? "Type IV verb (n-class, ADJ)" : "IV"
      end
    end
  end

  module Noun
    def self.determine_class(word : String) : Type?
      case word
      when /^.*[àá]t$/                  then Type::F1t
      when /^.*[àá]d$/                  then Type::F1d
      when /^.*[ií]à$/                  then Type::F2i
      when /^.*[àá]x$/                  then Type::F2x
      when /^(?!(.*[ií])?[àá]$).*[àá]$/ then Type::F2
      when /^.*[eé]n$/                  then Type::M1
      when /^.*m$/                      then Type::M2
      when /^.*[eé]l$/                  then Type::N1
      when /^.*r$/                      then Type::N2
      else                                   nil
      end
    end
  end

  module Verb
    def self.determine_class(word : String) : Type?
      case word
      when /^.*élus$/                               then Type::O
      when /^.*[aeiouyàáéíóúý]las$/                 then Type::I
      when /^.*lud$/                                then Type::II
      when /^(?!.*[áéíóúý].*[nm][úu]$)^.*[nm][úu]$/ then Type::III
      when /^.*lus$/                                then Type::IV
      else                                               nil
      end
    end
  end
end
