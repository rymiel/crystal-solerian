require "db"
require "sqlite3"
require "json"
require "solhttp"
require "./solerian/*"

module Solerian
  VERSION   = {{ `shards version #{__DIR__}`.chomp.stringify }}
  FOX_IDENT = ENV["FOX_IDENT"]?
  FOX_HREF  = ENV["FOX_HREF"]?
  Log       = ::Log.for self

  INCLUDE_SOL = false # idk

  def self.sol_p(word : InflectedEntry)
    INCLUDE_SOL ? %(<p class="sol">#{word.script}</p>) : ""
  end

  def self.noun_table_entry(word : InflectedEntry)
    return %(<td><a href="/poss/?s=#{word.sol}"><i>#{word.sol}</i></a><p>#{word.ipa}</p>#{sol_p word}</td>)
  end

  def self.verb_table_entry(word : InflectedEntry)
    return %(<td><i>#{word.sol}</i><p>#{word.ipa}</p>#{sol_p word}</td>)
  end

  get "/" do |ctx|
    templ "index"
  end

  get "/login" do |ctx|
    templ "login"
  end

  post "/login" do |ctx|
    next Auth.check_login ctx
  end

  get "/user" do |ctx|
    next unless Auth.assert_auth ctx
    templ "user"
  end

  get "/logout" do |ctx|
    next unless Auth.assert_auth ctx
    ctx.session.destroy
    ctx.redirect "/"
  end

  get "/dict" do |ctx|
    sort = case ctx.params.query["sort"]?
           when "eng" then :eng_num
           when "sol" then :sol_num
           else            :num
           end
    entries = Dict.get order: sort
    templ "dict"
  end

  get "/noun" do |ctx|
    word = ctx.params.query["s"]?.try { |w| HTML.escape w }
    fail = false
    if word
      forms = InflectedEntry
        .where(raw: word, part: Inflection::Part::Noun.to_i)
        .order(:form)
        .select
      if forms.size > 0
        summary = "#{Inflection::Type.new(forms.first.type).class_name(long: true)} noun #{word}"
        table = Inflection::NOUN_FORMS.zip(forms).to_h
      else
        fail = true
      end
    end

    templ "noun"
  end

  get "/verb" do |ctx|
    word = ctx.params.query["s"]?.try { |w| HTML.escape w }
    fail = false
    if word
      forms = InflectedEntry
        .where(raw: word, part: Inflection::Part::Verb.to_i)
        .order(:form)
        .select
      if forms.size > 0
        summary = "#{Inflection::Type.new(forms.first.type).class_name(long: true)} #{word}"
        table = Inflection::VERB_FORMS.zip(forms).to_h
      else
        fail = true
      end
    end

    templ "verb"
  end

  get "/docs" do |ctx|
    templ "doc"
  end

  get "/api/jsemb/v2/dict" do |ctx|
    ctx.response.content_type = "application/json"
    ctx.response.status_code = 500
    error = "Unknown error"
    begin
      start = (ctx.params.query["s"]? || 0).to_i
      amount = (ctx.params.query["l"]? || 25).to_i
      raise ArgumentError.new "Parameters can't be negative" if start < 0 || amount < 0
      raise ArgumentError.new "Too many results requested per page" if amount > 100
      d = Dict.get.offset(start)
      d = d.limit(amount) if amount > 0
      dict = d.select
    rescue ex : ArgumentError
      ctx.response.status_code = 400
      error = ex.message
    rescue ex
      error = "Unknown #{ex}"
    else
      ctx.response.status_code = 200
      next {
        "status"   => "ok",
        "response" => {
          "start": start,
          "max":   Dict.get.count.run,
          "limit": amount,
          "dict":  dict,
        },
      }.to_json
    end
    Log.error { error } if ctx.response.status_code == 500
    {
      "status"   => "error",
      "response" => error,
    }.to_json
  end

  get "/api/jsemb/v2/locate/:hash" do |ctx|
    ctx.response.content_type = "application/json"
    ctx.response.status_code = 500
    error = "Unknown error"
    begin
      index = FullEntry.find_by(hash: ctx.params.url["hash"]).try &.num
      raise(ArgumentError.new "Hash not found") unless index
    rescue ex : ArgumentError
      ctx.response.status_code = 400
      error = ex.message
    rescue ex
      error = "Unknown #{ex}"
    else
      ctx.response.status_code = 200
      next {
        "status"   => "ok",
        "response" => index,
      }.to_json
    end
    {
      "status"   => "error",
      "response" => error,
    }.to_json
  end

  macro entries_common(render)
    entries = Dict.get_raw(lusarian: true)
    templ {{render}}, "entries"
  end

  get "/user/entries" do |ctx|
    next unless Auth.assert_auth ctx

    include_input = true
    edit = nil
    entries_common "make_entry"
  end

  get "/user/entries/edit" do |ctx|
    next unless Auth.assert_auth ctx

    include_input = false
    edit = ctx.params.query["s"]
    entries_common "edit_entry"
  end

  post "/user/entries" do |ctx|
    next unless Auth.assert_auth ctx

    lusarian = ctx.params.body.has_key?("lusarian")
    entry = RawEntry.create! eng: ctx.params.body["en"], sol: ctx.params.body["sol"], extra: ctx.params.body["ex"], l: lusarian
    Dict.expand_entries

    ctx.redirect "/user/entries##{entry.hash}", 303
  end

  post "/user/entries/edit" do |ctx|
    next unless Auth.assert_auth ctx

    lusarian = ctx.params.body.has_key?("lusarian")
    edit = ctx.params.query["s"]
    entry = RawEntry.find! edit
    entry.update! eng: ctx.params.body["en"], sol: ctx.params.body["sol"], extra: ctx.params.body["ex"], l: lusarian
    Dict.expand_entries

    ctx.redirect "/user/entries##{entry.hash}", 303
  end

  get "/user/entries/import" do |ctx|
    next unless Auth.assert_auth ctx

    templ "import"
  end

  post "/user/entries/import" do |ctx|
    next unless Auth.assert_auth ctx

    lines = ctx.params.body["s"]
    lines.split("\n").each do |i|
      next if i.strip.empty?
      fields = i.strip.split("\t")
      RawEntry.create! eng: fields[0], sol: fields[1], extra: fields[2], l: false
    end
    Dict.expand_entries
    ctx.redirect "/user/entries", 303
  end
end

Log.setup do |c|
  backend = Log::IOBackend.new

  c.bind "*", :trace, backend
  c.bind "db.*", :info, backend
  c.bind "granite", :info, backend
end
Solerian::Dict.expand_entries
SolHTTP.run
