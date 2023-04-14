local BasePlugin = require "kong.plugins.base_plugin"
local json = require "cjson.safe"
local jwt_parser = require "kong.plugins.jwt.jwt_parser"
local http = require "resty.http"

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
  local httpc = http.new()
  httpc:set_timeouts(5000, 5000, 5000) -- timeout de 5 segundos para cada fase (connect, send, read)
  local res, err = httpc:request_uri(conf.introspection_endpoint, {
    method = "POST",
    ssl_verify = false,
    headers = {
      ["Content-Type"] = "application/x-www-form-urlencoded",
      ["Authorization"] = "Basic " .. ngx.encode_base64(conf.client_id .. ":" .. conf.client_secret),
    },
    body = "token=" .. token .. "&token_type_hint=access_token",
  })

  if not res then
    return false, err
  end

  if res.status ~= 200 then
    return false, res.body
  end

  local token_info, decode_err = json.decode(res.body)
  if decode_err then
    return false, decode_err
  end

  if not token_info.active then
    return false, "Token is not active"
  end

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

  ngx.req.set_header("Authorization", "Bearer " .. token)
end

return KeycloakHandler
