local typedefs = require "kong.db.schema.typedefs"

return {
  name = "keycloak-plugin",
  fields = {
    { consumer = typedefs.no_consumer },
    { config = {
        type = "record",
        fields = {
          { uri_param_names = { type = "array", elements = { type = "string" }, default = { "jwt" } } },
          { client_id = { type = "string", required = true } },
          { client_secret = { type = "string", required = true } },
          { introspection_endpoint = { type = "string", required = true } },
        }
      }
    }
  }
}