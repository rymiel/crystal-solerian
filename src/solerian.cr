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

  get "/" do |ctx|
    templ "index"
  end

  get "/login" do |ctx|
    templ "login"
  end

  get "/user" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx
    templ "user"
  end

  get "/logout" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx
    ctx.session.destroy
    ctx.redirect "/"
  end

  get "/dict" do |ctx|
    entries = [] of FullDictEntry
    d = Dict.get
    i = 0
    d.each do |j|
      i += 1
      entries << Dict.fill(j, i)
    end
    templ "dict"
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
      dict = [] of FullDictEntry
      i = start
      d = Dict.get.offset(start)
      d = d.limit(amount) if amount > 0
      d.each do |j|
        i += 1
        dict << Dict.fill(j, i)
      end
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
      index = Entry.raw_nonmodel(num: Int64) { |table| {"select num from ( select row_number () over ( order by extra ASC, eng ASC ) num, hash from #{table} ) where hash = ?;", [ctx.params.url["hash"]]} }.first?
      raise (ArgumentError.new "Hash not found") unless index
    rescue ex : ArgumentError
      ctx.response.status_code = 400
      error = ex.message
    rescue ex
      error = "Unknown #{ex}"
    else
      ctx.response.status_code = 200
      next {
        "status"   => "ok",
        "response" => index[:num],
      }.to_json
    end
    {
      "status"   => "error",
      "response" => error,
    }.to_json
  end

  macro entries_common(render)
    entries = Dict.get(lusarian: true)
    templ {{render}}, "entries"
  end

  get "/user/entries" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx

    include_input = true
    edit = nil
    entries_common "make_entry"
  end

  get "/user/entries/edit" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx

    include_input = false
    edit = ctx.params.query["s"]
    entries_common "edit_entry"
  end

  post "/user/entries" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx

    lusarian = ctx.params.body.has_key?("lusarian")
    entry = Entry.create! eng: ctx.params.body["en"], sol: ctx.params.body["sol"], extra: ctx.params.body["ex"], l: lusarian

    ctx.redirect "/user/entries##{entry.hash}", 303
  end

  post "/user/entries/edit" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx

    lusarian = ctx.params.body.has_key?("lusarian")
    edit = ctx.params.query["s"]
    entry = Entry.find! edit
    entry.update! eng: ctx.params.body["en"], sol: ctx.params.body["sol"], extra: ctx.params.body["ex"], l: lusarian

    ctx.redirect "/user/entries##{entry.hash}", 303
  end

  get "/user/entries/import" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx

    templ "import"
  end

  post "/user/entries/import" do |ctx|
    next unless SolHTTP::Auth.assert_auth ctx

    lines = ctx.params.body["s"]
    lines.split("\n").each do |i|
      next if i.strip.empty?
      fields = i.strip.split("\t")
      Entry.create! eng: fields[0], sol: fields[1], extra: fields[2], l: false
    end
    ctx.redirect "/user/entries", 303
  end
end

::Log.setup(:trace)
SolHTTP.run
