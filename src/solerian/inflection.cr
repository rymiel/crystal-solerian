# NOTE: These giant tables could be a lot more performant, by being individual lookup tables or exhaustive switches
# or whatever, but instead, I chose to keep it more compact, more "configurable". All of this code is either only
# run once, or only when the database changes, doesn't need to be that performant.

module Solerian::Inflection
  enum Part
    Noun
    Verb

    def form(idx : Int32) : Symbol
      PART_FORMS[to_i][idx]
    end

    def self.from_extra(extra : String) : Part?
      if extra.starts_with?('N') || extra == "pron."
        Inflection::Part::Noun
      elsif extra.starts_with?('V')
        Inflection::Part::Verb
      else
        nil
      end
    end
  end

  # This enum should be in the same order as the entries in TABLE
  enum Type
    # Noun types
    N1 # F1t
    N2 # F1d
    N3 # F2i
    N4 # F2x
    N5 # F2
    N6 # M1
    N7 # M2
    N8 # N1
    N9 # N2

    # Verb types
    # Ia
    V1  # I
    V2  # II
    V3n # III
    V3r # III
    V3  # III
    V4s # IV
    V4  # IV
    V5t # O
    V5r # O
    V5  # O

    def long_name : String
      prop = TABLE[to_i]
      "Pattern #{prop.type.to_s[1..]} #{prop.part.to_s.downcase}#{prop.suffix.nil? ? "" : " (#{prop.suffix})"}"
    end

    def pattern_number : String
      TABLE[to_i].type.to_s[1..]
    end

    def pattern_name : String
      "Pattern #{TABLE[to_i].type.to_s[1..]}"
    end

    def old_class_name : String
      "Old class #{OLD_CLASSES[to_i].to_s}"
    end

    def old_class_long_name : String
      prop = TABLE[to_i]
      "Old class #{OLD_CLASSES[to_i].to_s} #{prop.part.to_s.downcase}#{prop.suffix.nil? ? "" : " (#{prop.suffix})"}"
    end
  end

  OLD_CLASSES = StaticArray[
    :F1t, :F1d, :F2i, :F2x, :F2, :M1, :M2, :N1, :N2,
    :I, :II, :III, :III, :III, :IV, :IV, :O, :O, :O
  ]

  record Prop, part : Part, type : Type, match : Regex, suffix : String?, forms : Array(String)

  TABLE = StaticArray[
    # Noun forms
    Prop.new(:noun, :N1, /^.*([àá]t)$/, nil,
      ["àt", "en", "i", "àtún", "ent", "is"] +
      ["àt", "en", "is", "àtún", "etin", "iis"]),

    Prop.new(:noun, :N2, /^.*([àá]d)$/, nil,
      ["àd", "ein", "i", "ánd", "end", "is"] +
      ["àd", "ein", "is", "ánd", "etin", "iis"]),

    Prop.new(:noun, :N3, /^.*([ií]à)$/, nil,
      ["ià", "ie", "i", "áin", "ein", "ir"] +
      ["ià", "ie", "ir", "iáin", "iein", "iir"]),

    Prop.new(:noun, :N4, /^.*([àá]x)$/, nil,
      ["àx", "ox", "i", "áxi", "oxe", "ixr"] +
      ["àx", "ox", "ir", "áxi", "oxe", "ixir"]),

    Prop.new(:noun, :N5, /^(?!(?:.*[ií])?[àá]$).*([àá])$/, nil,
      ["à", "e", "i", "án", "en", "ir"] +
      ["à", "e", "ir", "áin", "ein", "iir"]),

    Prop.new(:noun, :N6, /^.*([eé]n)$/, nil,
      ["en", "àan", "yr", "etén", "ànt", "yrs"] +
      ["en", "ean", "yr", "enét", "eant", "esyr"]),

    Prop.new(:noun, :N7, /^.*(m)$/, nil,
      ["m", "m", "mi", "mas", "mas", "ǹir"] +
      ["m", "m", "mer", "mas", "mas", "ǹir"]),

    Prop.new(:noun, :N8, /^.*([eé]l)$/, nil,
      ["el", "aln", "il", "iEk", "elk", "ilar"] +
      ["el", "aln", "eler", "eek", "alnek", "elsar"]),

    Prop.new(:noun, :N9, /^.*(r)$/, nil,
      ["r", "ren", "ir", "àr", "rins", "rir"] +
      ["r", "rin", "ràr", "àr", "rinse", "riser"]),

    # Verb forms
    # Prop.new(:verb, :ia, /^.*a(élus)$/, "Type Ia verb (ae-class, IT CONT a)", "Ia",
    #   ["élus", "érà", "<à", "eké", "éts", "ànt", "àng", "àns", "ét", "ég", "ésa", "ámo", "ánà", "ánà", "í"] +
    #   ["élus", "érà", "<à", "eké", "ités", "amét", "anég", "anés", "ét", "ég", "ésa", "ámo", "ánà", "ánà", "í"]),

    Prop.new(:verb, :V1, /^.*(élus)$/, "IT CONT",
      ["élus", "érà", "<à", "eké", "éts", "án", "áig", "áste", "é", "élg", "ésa", "àmó", "ánà", "ánà", "í"] +
      ["élus", "érà", "<à", "eké", "ités", "amét", "anég", "anés", "ét", "ég", "ésa", "ámo", "ánà", "ánà", "í"]),

    Prop.new(:verb, :V2, /^.*[aeiouyàáéíóúý](las)$/, "CHANGE",
      ["las", "lar", "lý", "laké", "láts", "lánt", "lànég", "láns", "ld", "leg", "lsa", "làmo", "lànà", "lànà", "li"] +
      ["las", "lar", "lý", "laké", "lités", "làté", "lànég", "láns", "ld", "leg", "lsa", "làmo", "lànà", "lànà", "li"]),

    Prop.new(:verb, :V3n, /^.*[nm](lud)$/, "ONCE",
      ["lud", "rad", "d", "lék", "la", "deté", "dég", "dés", "lut", "lek", "lusa", "lumà", "lonà", "lonà", ""] +
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lomà", "lonà", "lonà", ""]),

    Prop.new(:verb, :V3r, /^.*r(lud)$/, "ONCE",
      ["lud", "ad", "d", "lék", "la", "deté", "dég", "dés", "lut", "lek", "lusa", "lumà", "lonà", "lonà", ""] +
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lomà", "lonà", "lonà", ""]),

    Prop.new(:verb, :V3, /^.*(lud)$/, "ONCE",
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lumà", "lonà", "lonà", ""] +
      ["lud", "rad", "d", "lék", "ld", "deté", "dég", "dés", "lut", "lek", "lusa", "lomà", "lonà", "lonà", ""]),

    Prop.new(:verb, :V4s, /^(?!.*[áéíóúý].*[nm][úu]$)^.*(s(n|m)[úu])$/, "ADJ",
      ["s@ú", "s@ár", "sǹý", "sǹék", ">ns", "sǹá@", "sǹál", "sǹást", "s@í", "s@ék", "s@úsa", "s@ámo", "s@ánà", "s@ánà", "@s"] +
      ["s@ú", "s@ár", "sǹý", "sǹék", ">sn", "sǹám", "sǹág", "sǹán", "s@út", "s@úek", "s@úsa", "s@ámo", "s@ánà", "s@ánà", "s@"]),

    Prop.new(:verb, :V4, /^(?!.*[áéíóúý].*[nm][úu]$)^.*((n|m)[úu])$/, "ADJ",
      ["@ú", "@ár", "ǹý", "ǹék", ">n", "ǹá@", "ǹál", "ǹást", "@í", "@ék", "@úsa", "@ámo", "@ánà", "@ánà", "@"] +
      ["@ú", "@ár", "ǹý", "ǹék", ">n", "ǹám", "ǹág", "ǹán", "@út", "@úek", "@úsa", "@ámo", "@ánà", "@ánà", "@"]),

    Prop.new(:verb, :V5t, /^.*((t|n|m)lus)$/, "T CONT",
      ["@lus", "@là", "r@", "@lék", "@léts", "@lán", "@láig", "@lást", "@re", "@reg", "@ras", "@làmo", "@lànà", "@lànà", "@lí"] +
      ["@lus", "@là", "@r", "@lék", "@léts", "@lát", "@lág", "@lás", "@ret", "@reg", "@ras", "@làmo", "@lànà", "@lona", "@lí"]),

    Prop.new(:verb, :V5r, /^.*r(lus)$/, "T CONT",
      ["lus", "là", "", "lék", "léts", "lán", "láig", "lást", "e", "eg", "as", "làmo", "lànà", "lànà", "lí"] +
      ["lus", "là", "r", "lék", "léts", "lát", "lág", "lás", "ret", "reg", "ras", "làmo", "lànà", "lona", "lí"]),

    Prop.new(:verb, :V5, /^.*(lus)$/, "T CONT",
      ["lus", "là", "r", "lék", "léts", "lán", "láig", "lást", "re", "reg", "ras", "làmo", "lànà", "lànà", "lí"] +
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
  PART_FORMS = [NOUN_FORMS, VERB_FORMS]

  POSS_FORMS = [:"1sg", :"2sg", :"3sg", :"1pl", :"2pl", :"3pl"] +
               [:old_1sg, :old_2sg, :old_3sg_m, :old_3sg_f, :old_3sg_n, :old_1pl, :old_2pl, :old_3pl]
  POSS_SUFFIXES = ["àl", "it", "ys", "erd", "itar", "usd"] +
                  ["elm", "etr", "usd", "usan", "ys", "elmes", "etres", "usdes"]

  OLD_FORMS_COMBINED = Set{
    :old_nom_sg, :old_acc_sg, :old_gen_sg, :old_nom_pl, :old_acc_pl, :old_gen_pl,
    :old_1_inf, :old_2_inf, :old_1sg_prs, :old_2sg_prs, :old_3sg_prs, :old_1pl_prs, :old_2pl_prs, :old_3pl_prs,
    :old_1sg_pst, :old_2sg_pst, :old_3sg_pst, :old_1pl_pst, :old_2pl_pst, :old_3pl_pst, :old_2sg_imp,
    :old_1sg, :old_2sg, :old_3sg_m, :old_3sg_f, :old_3sg_n, :old_1pl, :old_2pl, :old_3pl,
  }
  TRIVIAL_FORMS = Set{:nom_sg, :old_nom_sg, :"1_inf", :old_1_inf}

  def self.determine_prop(word : String, part : Part) : Prop
    TABLE.find! { |i| i.part == part && i.match.matches? word }
  end

  def self.determine_type(word : String, part : Part) : Type
    self.determine_prop(word, part).type
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

      stress_suffix = stressed?(ending) || full_vowel_count(base_root) == 0

      prop.forms.map do |suffix|
        stress_first = suffix.starts_with?('<')
        stress_last = suffix.starts_with?('>')
        suffix = suffix.lstrip("<>")

        # NOTE: this could be more flexible like it was in the dartc version. Realistically, though, it will be only
        # used for only pattern 4 verbs.
        # NOTE: now also used for pattern 5t verbs, but using the same system
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

  def self.inflected_entry_description(entry : InflectedEntry) : String
    part = Inflection::Part.new(entry.part)
    form_symbol = part.form entry.form
    form_name = form_symbol.to_s.gsub('_', ' ')
    old = form_symbol.in? Inflection::OLD_FORMS_COMBINED
    type = Inflection::Type.new(entry.type)
    type_name = old ? type.old_class_name : type.pattern_name
    part_name = part.to_s.downcase

    "\"#{entry.sol}\": #{form_name} of #{type_name} #{part_name} \"#{entry.raw}\""
  end

  Type.each do |t|
    if TABLE.size != OLD_CLASSES.size != Type.values.size
      raise "Table size mismatch: Type #{Type.values.size}, TABLE #{TABLE.size}, OLD_CLASSES #{OLD_CLASSES.size}"
    end
    if TABLE[t.to_i].type != t
      raise "Invalid order: TABLE index #{t.to_i} should be #{t}, but was #{TABLE[t.to_i].type}"
    end
  end
end
