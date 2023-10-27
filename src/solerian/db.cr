require "granite/adapter/sqlite"
Granite::Connections << Granite::Adapter::Sqlite.new(name: "solhttp", url: "sqlite3://./data.db")
require "granite"
