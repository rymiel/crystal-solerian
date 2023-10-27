require "granite"

module Granite
  module NonModelQuerying
    def raw_nonmodel(**types : **T, &block : String -> Tuple(String, Array(Granite::Columns::Type))) forall T
      {% begin %}
        rows = [] of NamedTuple(
          {% for name, type in T %}
            {{ name }}: {{type.instance}},
          {% end %}
        )
        container = select_container
        container.custom, params = yield quote(container.table_name)
        adapter.select(container, "", params) do |results|
          results.each do
            rows << results.read(**types)
          end
        end
        rows
      {% end %}
    end
  end

  class Base
    extend NonModelQuerying
  end
end
