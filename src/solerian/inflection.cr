# NOTE: These giant tables could be a lot more performant, by being individual lookup tables or exhaustive switches
# or whatever, but instead, I chose to keep it more compact, more "configurable". All of this code is either only
# run once, or only when the database changes, doesn't need to be that performant.

module Solerian::Inflection
  enum Part
    Noun
    Verb

    def form(idx : Int32)
      (noun? ? Inflection::NOUN_FORMS : verb? ? Inflection::VERB_FORMS : raise "Invalid part")[idx]
    end
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
    # Ia
    I
    II
    IIIn
    III
    IVs
    IV
    O

    def class_name(*, long = false) : String
      long ? Prop[self].long_name : Prop[self].short_name
    end
  end

  record Prop, part : Part, type : Type, match : Regex, long_name : String, short_name : String, forms : Array(String) do
    def self.[](type : Type) : Prop
      TABLE[type.to_i]
    end
  end

  TABLE = StaticArray[
    # Noun forms
    Prop.new(:noun, :F1t, /^.*([àá]t)$/, "Feminine type 1t noun", "F1t",
      ["àt", "en", "i", "àtún", "ent", "is"] +
      ["àt", "en", "is", "àtún", "etin", "iis"]),

    Prop.new(:noun, :F1d, /^.*([àá]d)$/, "Feminine type 1d noun", "F1d",
      ["àd", "ein", "i", "ánd", "end", "is"] +
      ["àd", "ein", "is", "ánd", "etin", "iis"]),

    Prop.new(:noun, :F2i, /^.*([ií]à)$/, "Feminine type 2i noun", "F2i",
      ["ià", "ie", "i", "áin", "ein", "ir"] +
      ["ià", "ie", "ir", "iáin", "iein", "iir"]),

    Prop.new(:noun, :F2x, /^.*([àá]x)$/, "Feminine type 2x noun", "F2x",
      ["àx", "ox", "i", "áxi", "oxe", "ixr"] +
      ["àx", "ox", "ir", "áxi", "oxe", "ixir"]),

    Prop.new(:noun, :F2, /^(?!(?:.*[ií])?[àá]$).*([àá])$/, "Feminine type 2 noun", "F2",
      ["à", "e", "i", "án", "en", "ir"] +
      ["à", "e", "ir", "áin", "ein", "iir"]),

    Prop.new(:noun, :M1, /^.*([eé]n)$/, "Masculine type 1 noun", "M1",
      ["en", "àan", "yr", "etén", "ànt", "yrs"] +
      ["en", "ean", "yr", "enét", "eant", "esyr"]),

    Prop.new(:noun, :M2, /^.*(m)$/, "Masculine type 2 noun", "M2",
      ["m", "m", "mi", "mas", "mas", "ǹir"] +
      ["m", "m", "mer", "mas", "mas", "ǹir"]),

    Prop.new(:noun, :N1, /^.*([eé]l)$/, "Neuter type 1 noun", "N1",
      ["el", "aln", "il", "iEk", "elk", "ilar"] +
      ["el", "aln", "eler", "eek", "alnek", "elsar"]),

    Prop.new(:noun, :N2, /^.*(r)$/, "Neuter type 2 noun", "N2",
      ["r", "ren", "ir", "àr", "rins", "rir"] +
      ["r", "rin", "ràr", "àr", "rinse", "riser"]),

    # Verb forms
    # Prop.new(:verb, :ia, /^.*a(élus)$/, "Type Ia verb (ae-class, IT CONT a)", "Ia",
    #   ["élus", "érà", "<à", "eké", "éts", "ànt", "àng", "àns", "ét", "ég", "ésa", "ámo", "ánà", "ánà", "í"] +
    #   ["élus", "érà", "<à", "eké", "ités", "amét", "anég", "anés", "ét", "ég", "ésa", "ámo", "ánà", "ánà", "í"]),

    Prop.new(:verb, :I, /^.*(élus)$/, "Type I verb (e-class, IT CONT)", "I",
      ["élus", "érà", "<à", "eké", "éts", "án", "ág", "áste", "é", "élg", "ésa", "àmó", "ánà", "ánà", "í"] +
      ["élus", "érà", "<à", "eké", "ités", "amét", "anég", "anés", "ét", "ég", "ésa", "ámo", "ánà", "ánà", "í"]),

    Prop.new(:verb, :II, /^.*[aeiouyàáéíóúý](las)$/, "Type II verb (a-class, TRANS)", "II",
      ["las", "lar", "lý", "laké", "láts", "lánt", "lànég", "láns", "ld", "leg", "lsa", "làmo", "lànà", "lànà", "li"] +
      ["las", "lar", "lý", "laké", "lités", "làté", "lànég", "láns", "ld", "leg", "lsa", "làmo", "lànà", "lànà", "li"]),

    Prop.new(:verb, :IIIn, /^.*[rnm](lud)$/, "Type IIIn verb (dn-class, ONCE n)", "IIIn",
      ["lud", "rad", "d", "lék", "d", "deté", "dég", "dés", "lut", "lek", "lusa", "lumà", "lonà", "lonà", ""] +
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lomà", "lonà", "lonà", ""]),

    Prop.new(:verb, :III, /^.*(lud)$/, "Type III verb (d-class, ONCE)", "III",
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lumà", "lonà", "lonà", ""] +
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lomà", "lonà", "lonà", ""]),

    Prop.new(:verb, :IVs, /^(?!.*[áéíóúý].*[nm][úu]$)^.*(s(n|m)[úu])$/, "Type IVs verb (ns-class, ADJ s)", "IVs",
      ["s@ú", "s@ár", "sǹý", "sǹék", ">ns", "sǹá@", "sǹál", "sǹást", "s@í", "s@ék", "s@úsa", "s@ámo", "s@ánà", "s@ánà", "@s"] +
      ["s@ú", "s@ár", "sǹý", "sǹék", ">sn", "sǹám", "sǹág", "sǹán", "s@út", "s@úek", "s@úsa", "s@ámo", "s@ánà", "s@ánà", "s@"]),

    Prop.new(:verb, :IV, /^(?!.*[áéíóúý].*[nm][úu]$)^.*((n|m)[úu])$/, "Type IV verb (n-class, ADJ)", "IV",
      ["@ú", "@ár", "ǹý", "ǹék", ">n", "ǹá@", "ǹál", "ǹást", "@í", "@ék", "@úsa", "@ámo", "@ánà", "@ánà", "@"] +
      ["@ú", "@ár", "ǹý", "ǹék", ">n", "ǹám", "ǹág", "ǹán", "@út", "@úek", "@úsa", "@ámo", "@ánà", "@ánà", "@"]),

    Prop.new(:verb, :O, /^.*(lus)$/, "Type 0 verb (0-class, T CONT)", "0",
      ["lus", "là", "r", "lék", "léts", "lán", "lág", "lást", "re", "reg", "ras", "làmo", "lànà", "lànà", "lí"] +
      ["lus", "là", "r", "lék", "léts", "lát", "lág", "lás", "ret", "reg", "ras", "làmo", "lànà", "lona", "lí"]),
  ]

  NOUN_FORMS = (
    [:nom_sg, :acc_sg, :gen_sg, :nom_pl, :acc_pl, :gen_pl] +
    [:old_nom_sg, :old_acc_sg, :old_gen_sg, :old_nom_pl, :old_acc_pl, :old_gen_pl]
  )
  VERB_FORMS = (
    [:"1_inf", :"2_inf", :"1sg_prs", :"2sg_prs", :"3sg_prs", :"1pl_prs", :"2pl_prs", :"3pl_prs",
     :"1sg_pst", :"2sg_pst", :"3sg_pst", :"1pl_pst", :"2pl_pst", :"3pl_pst", :"2sg_imp"] +
    [:old_1_inf, :old_2_inf, :old_1sg_prs, :old_2sg_prs, :old_3sg_prs, :old_1pl_prs, :old_2pl_prs, :old_3pl_prs,
     :old_1sg_pst, :old_2sg_pst, :old_3sg_pst, :old_1pl_pst, :old_2pl_pst, :old_3pl_pst, :old_2sg_imp]
  )
  POSS_FORMS    = [:"1sg", :"2sg", :"3sg_m", :"3sg_f", :"3sg_n", :"1pl", :"2pl", :"3pl"]
  POSS_SUFFIXES = ["elm", "etr", "usd", "usan", "ys", "elmes", "etres", "usdes"]

  OLD_FORMS_COMBINED = [
    :old_nom_sg, :old_acc_sg, :old_gen_sg, :old_nom_pl, :old_acc_pl, :old_gen_pl,
    :old_1_inf, :old_2_inf, :old_1sg_prs, :old_2sg_prs, :old_3sg_prs, :old_1pl_prs, :old_2pl_prs, :old_3pl_prs,
    :old_1sg_pst, :old_2sg_pst, :old_3sg_pst, :old_1pl_pst, :old_2pl_pst, :old_3pl_pst, :old_2sg_imp,
  ]

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
    STRESS_MARKERS   = APPLY_LAX_STRESS.transform_keys &.upcase

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

    def mark_stress!(word : String) : String
      destress!(word).sub(STRESS_MARKERS)
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
          return normalize!(stress_first!(word))
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
        if suffix.includes? '@'
          suffix = suffix.gsub("@", match[2])
        end

        root = base_root
        if stress_first
          root = stress_first!(root)
        elsif stress_last
          root = stress_last!(root)
        elsif stressed?(suffix)
          root = destress!(root)
        elsif stress_suffix
          if STRESS_MARKERS.keys.any? &.in? suffix
            suffix = mark_stress!(suffix)
          else
            suffix = stress_lax!(suffix)
          end
        end

        if STRESS_MARKERS.keys.any? &.in? suffix
          suffix = suffix.downcase
        end

        mark_stress ? normalize!(root + suffix) : destress!(root + suffix)
      end
    end

    def apply_poss(word : String) : Array(String)
      POSS_SUFFIXES.map do |suffix|
        normalize!(word + suffix)
      end
    end

    def auto_apply(word : String, part : Part, *, mark_stress : Bool = true) : Array(String)?
      prop = Inflection.determine_prop(word, part)
      return nil if prop.nil?
      apply_from(word, prop, mark_stress: mark_stress)
    end
  end
end
