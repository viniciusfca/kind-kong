local BasePlugin = require "kong.plugins.base_plugin"
local constants = require "kong.constants"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"
local socket = require "socket"

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
end

local function introspect_token(conf, token)
  local http = require "resty.http"
  local httpc = http.new()
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

  local json = require("cjson")
  local token_info = json.decode(res.body)

  if not token_info.active then
    return false, "Token is not active"
  end

  return true, token_info
end

function KeycloakHandler:access(conf)
  KeycloakHandler.super.access(self)

  ngx.log(ngx.DEBUG, "KeycloakHandler:access() called")
  local token, err = retrieve_token(ngx.req, conf)
  if err then
    return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
  end

  local ok, token_info_or_err = introspect_token(conf, token)
  ngx.log(ngx.DEBUG, "introspect_token() result: ", json.encode(token_info_or_err))
  if not ok then
    return responses.send_HTTP_UNAUTHORIZED(token_info_or_err)
  end
  

ngx.req.set_header("Authorization", "Bearer " .. token)

end

return KeycloakHandler