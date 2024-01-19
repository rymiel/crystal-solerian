# NOTE: These giant tables could be a lot more performant, by being individual lookup tables or exhaustive switches
# or whatever, but instead, I chose to keep it more compact, more "configurable". All of this code is either only
# run once, or only when the database changes, doesn't need to be that performant.

module Solerian::Inflection
  enum Part
    Noun
    Verb
  end

  # This enum should be in the same order as the entries in TABLE
  enum Type
    # Noun types
    F1t
    F1d
    F2i
    F2x
    F2
    M1
    M2
    N1
    N2

    # Verb types
    I
    II
    III
    IV
    O

    def class_name(*, long = false) : String
      long ? TABLE[to_i].long_name : TABLE[to_i].short_name
    end
  end

  record Prop, part : Part, type : Type, match : Regex, long_name : String, short_name : String, forms : Array(String)

  TABLE = StaticArray[
    # Noun forms
    Prop.new(:noun, :f1t, /^.*([àá]t)$/, "Feminine type 1t", "F1t",
      ["àt", "en", "is", "àtún", "etin", "iis"]),

    Prop.new(:noun, :f1d, /^.*([àá]d)$/, "Feminine type 1d", "F1d",
      ["àd", "ein", "is", "ánd", "etin", "iis"]),

    Prop.new(:noun, :f2i, /^.*[ií](à)$/, "Feminine type 2i", "F2i",
      ["à", "e", "r", "áin", "ein", "ir"]),

    Prop.new(:noun, :f2x, /^.*([àá]x)$/, "Feminine type 2x", "F2x",
      ["àx", "ox", "ir", "áxi", "oxe", "ixir"]),

    Prop.new(:noun, :f2, /^(?!(?:.*[ií])?[àá]$).*([àá])$/, "Feminine type 2", "F2",
      ["à", "e", "ir", "áin", "ein", "iir"]),

    Prop.new(:noun, :m1, /^.*([eé]n)$/, "Masculine type 1", "M1",
      ["en", "ean", "yr", "enét", "eant", "esyr"]),

    Prop.new(:noun, :m2, /^.*(m)$/, "Masculine type 2", "M2",
      ["m", "m", "mer", "mas", "mas", "ǹir"]),

    Prop.new(:noun, :n1, /^.*([eé]l)$/, "Neuter type 1", "N1",
      ["el", "aln", "eler", "eek", "alnek", "elsar"]),

    Prop.new(:noun, :n2, /^.*(r)$/, "Neuter type 2", "N2",
      ["r", "rin", "ràr", "àr", "rinse", "riser"]),

    # Verb forms
    Prop.new(:verb, :i, /^.*(élus)$/, "Type I verb (e-class, IT CONT)", "I",
      ["élus", "érà", "<à", "eké", "ités", "amét", "anég", "anés", "ét", "ég", "ésa", "ámo", "ánà", "ánà", "í"]),

    Prop.new(:verb, :ii, /^.*[aeiouyàáéíóúý](las)$/, "Type II verb (a-class, TRANS)", "II",
      ["las", "lar", "lý", "laké", "lités", "làté", "lànég", "láns", "ld", "leg", "lsa", "làmo", "lànà", "lànà", "li"]),

    Prop.new(:verb, :iii, /^.*(lud)$/, "Type III verb (d-class, ONCE)", "III",
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lomà", "lonà", "lonà", ""]),

    Prop.new(:verb, :iv, /^(?!.*[áéíóúý].*[nm][úu]$)^.*([nm][úu])$/, "Type IV verb (n-class, ADJ)", "IV",
      ["@ú", "@ár", "ǹý", "ǹék", ">n", "ǹám", "ǹág", "ǹán", "@út", "@úek", "@úsa", "@ámo", "@ánà", "@ánà", "@"]),

    Prop.new(:verb, :o, /^.*(lus)$/, "Type 0 verb (0-class, T CONT)", "0",
      ["lus", "là", "r", "lék", "léts", "lát", "lág", "lás", "ret", "reg", "ras", "làmo", "lànà", "lona", "lí"]),
  ]

  NOUN_FORMS = [:nom_sg, :acc_sg, :gen_sg, :nom_pl, :acc_pl, :gen_pl]
  VERB_FORMS = [:"1_inf", :"2_inf", :"1sg_prs", :"2sg_prs", :"3sg_prs", :"1pl_prs", :"2pl_prs", :"3pl_prs",
                :"1sg_pst", :"2sg_pst", :"3sg_pst", :"1pl_pst", :"2pl_pst", :"3pl_pst", :"2sg_imp"]

  def self.determine_prop(word : String, part : Part) : Prop?
    TABLE.find { |i| i.part == part && i.match.matches? word }
  end

  def self.determine_type(word : String, part : Part) : Type?
    self.determine_prop(word, part).try &.type
  end

  module Word
    extend self

    ANY_VOWEL  = /[aeiouyàáéíóúý]/
    FULL_VOWEL = /[eiouyàáéíóúý]/
    STRESSED   = /[áéíóúý]/

    DESTRESS         = {'á' => 'à', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ý' => 'y'}
    APPLY_LAX_STRESS = DESTRESS.invert
    APPLY_STRESS     = APPLY_LAX_STRESS.merge({'a' => 'á'})

    def stressed?(word : String) : Bool
      STRESSED.matches? word
    end

    def syllable_count(word : String) : Int32
      word.scan(ANY_VOWEL).size
    end

    def full_vowel_count(word : String) : Int32
      word.scan(FULL_VOWEL).size
    end

    def stress_first!(word : String) : String
      destress!(word).sub(APPLY_STRESS)
    end

    def stress_lax!(word : String) : String
      destress!(word).sub(APPLY_LAX_STRESS)
    end

    def stress_last!(word : String) : String
      word = destress!(word)
      word.rindex(ANY_VOWEL).try { |idx| word.sub(idx, APPLY_STRESS[word[idx]]) } || word
    end

    def destress!(word : String) : String
      word.gsub(DESTRESS)
    end

    def normalize!(word : String) : String
      if stressed?(word)
        if syllable_count(word) == 1 || full_vowel_count(word) == 1
          return destress!(word)
        end
      else
        if full_vowel_count(word) == 0
          return stress_first!(word)
        elsif full_vowel_count(word) > 1
          return stress_lax!(word)
        end
      end

      word
    end

    def apply_from(word : String, prop : Prop, *, mark_stress : Bool = true) : Array(String)
      match = prop.match.match(word)
      raise "Invalid prop, it doesn't match" if match.nil?
      cutoff = match[1].size
      base_root = word[...-cutoff]
      ending = word[-cutoff..]

      stress_suffix = stressed?(ending)

      prop.forms.map do |suffix|
        stress_first = suffix.starts_with?('<')
        stress_last = suffix.starts_with?('>')
        suffix = suffix.lstrip("<>")

        # NOTE: this could be more flexible like it was in the dartc version. Realistically, though, it will be only
        # used for only type IV verbs.
        suffix = suffix.gsub("@", ending[0])

        root = base_root
        if stress_first
          root = stress_first!(root)
        elsif stress_last
          root = stress_last!(root)
        elsif stressed?(suffix)
          root = destress!(root)
        elsif stress_suffix
          suffix = stress_lax!(suffix)
        end

        mark_stress ? normalize!(root + suffix) : destress!(root + suffix)
      end
    end

    def auto_apply(word : String, part : Part, *, mark_stress : Bool = true) : Array(String)?
      prop = Inflection.determine_prop(word, part)
      return nil if prop.nil?
      apply_from(word, prop, mark_stress: mark_stress)
    end
  end
end
