{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "parent" => "abstract_note",

    "properties" => {

      "content" => {
        "type" => "array",
        "items" => {"type" => "string"},
        "minItems" => 0,
        "ifmissing" => nil,
      },

      "items" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "properties" => {
            "value" => {"type" => "string", "ifmissing" => "error"},
            "type" => {"type" => "string", "ifmissing" => "error"},
            "reference" => {"type" => "string"},
            "reference_text" => {"type" => "string"},
          }}
      },
    },

    "additionalProperties" => false,
  },
}
