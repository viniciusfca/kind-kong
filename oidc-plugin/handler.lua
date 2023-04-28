local BasePlugin = require "kong.plugins.base_plugin"
local json = require("cjson")
local jwt_parser = require "kong.plugins.jwt.jwt_parser"
local http = require("socket.http")
local ltn12 = require("ltn12")

local KeycloakHandler = BasePlugin:extend()

KeycloakHandler.PRIORITY = 1000

function KeycloakHandler:new()
  KeycloakHandler.super.new(self, "keycloak-plugin")
end

local function retrieve_token(request, conf)
  local uri_parameters = request.get_uri_args()

  for _, v in ipairs(conf.uri_param_names) do
    if uri_parameters[v] then
      return uri_parameters[v]
    end
  end

  local authorization_header = request.get_headers()["authorization"]
  if authorization_header then
    local iterator, iter_err = ngx.re.gmatch(authorization_header, "\\s*[Bb]earer\\s+(.+)")
    if not iterator then
      return nil, iter_err
    end

    local m, err = iterator()
    if err then
      return nil, err
    end

    if m and #m > 0 then
      return m[1]
    end
  end

  return nil, "Token not found"
end

local function introspect_token(conf, token)

  local url = conf.introspection_endpoint
  local payload = 'client_id=' .. conf.client_id .. '&client_secret=' .. conf.client_secret .. '&token=' .. token

  local response = {}
  local res, code, headers = http.request{
      url = url,
      method = "POST",
      headers = {
          ["Content-Type"] = "application/x-www-form-urlencoded",
          ["Content-Length"] = payload:len()
      },
      source = ltn12.source.string(payload),
      sink = ltn12.sink.table(response)
  }

  if not res then
    return false, "Failed to make request: " .. err
  end

  local response_body = table.concat(response)

  if code ~= 200 then
    return false, "Received non-200 response code: " .. response_body
  end

  local ok, token_info = pcall(json.decode, response_body)

  if not ok then
    return false, "Failed to decode JSON response: " .. token_info
  end

  if not token_info.active then
    print("Token is not active: " .. payload .. " response: " .. response_body)
    return false, "Token is not active: " .. payload .. " response: " .. response_body
  end
    print('Sucesso ' .. response_body)
    return true, token_info
end

function KeycloakHandler:access(conf)
  local token, err = retrieve_token(ngx.req, conf)
  if err then
    return kong.response.exit(401, { message = err })
  end

  local ok, token_info_or_err = introspect_token(conf, token)
  if not ok then
    return kong.response.exit(401, { message = token_info_or_err })
  end

  ngx.log(ngx.DEBUG, "Token info: ", json.encode(token_info_or_err))

  local user = {
    
  }
  ngx.req.set_header("Authorization", "Bearer " .. token)
end

return KeycloakHandler
