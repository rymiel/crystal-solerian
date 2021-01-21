module Solerian::Script
  extend self

  LETTERS = {
    's' => 0x00, 'm' => 0x01, 'n' => 0x02, 'ǹ' => 0x03,
    'r' => 0x04, 'l' => 0x05, 't' => 0x06, 'd' => 0x07,
    'k' => 0x08, 'g' => 0x09, 'f' => 0x0a, 'p' => 0x0b,
    'j' => 0x0c, 'x' => 0x0d, 'e' => 0x11, 'i' => 0x12,
    'o' => 0x13, 'à' => 0x14, 'u' => 0x15, 'y' => 0x16,
  }
  record LetterContext, letter : Int32, form : Int32 do
    def final
      @form |= 0x1
      self
    end

    def initial
      @form |= 0x2
      self
    end

    def with_a
      @form |= 0x4
      self
    end

    def stress
      @form |= 0x8
      self
    end
  end

  def to_suffixed(s)
    s.gsub({'á' => "à'", 'é' => "e'", 'í' => "i'", 'ó' => "o'", 'ú' => "u'", 'ý' => "y'"})
  end

  def html(text)
    res = [] of LetterContext
    flag = false # "detaching" flag
    text.each_char do |i|
      first = res.empty? 
      if i == 'a' && first # Initial 'a' has a special form
        res << LetterContext.new 0x10, 0
      elsif i == 'a' # Attach 'a' diacritic if it doesn't exist
        res[-1] = res.last.with_a
      elsif i == '\'' && !first && res.last.letter >= 0x10 # Only stress vowels
        res[-1] = res.last.stress
      else
        next unless LETTERS.has_key?(i) # Skip nonexistent letters
        res[-1] = res.last.final if i == 'm' && !first # Detach last letter
        res << LetterContext.new(LETTERS[i], flag ? 2 : 0) # Detach this letter (flag)
        flag = i == 'à' || i == 'm' # Letters which will detach next letter (flag)
      end
    end

    return "" if res.empty?
    res[0] = res.first.initial
    res[-1] = res.last.final
    String.build do |s|
      s << "&#x202e" # RTL
      res.each do |i|
        s << "&#xe" + (i.letter.to_s 16).rjust(2, '0') + (i.form.to_s 16)
      end
    end
  end

  def multi(words)
    words = words.strip
    return "" if words.empty?
    String.build { |s|
      (words.split " ").each do |w|
        s << html(w) + " "
      end
    }.strip
  end
end
