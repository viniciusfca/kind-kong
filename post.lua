local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")


local introspection_endpoint = 'https://stg-sso.solfacil.com.br/realms/General/protocol/openid-connect/token/introspect'
local token = "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJNTzBTSlJHM3BaYU14ZV9BSGI0dnh0NUtKcmc0dE53VjhBcUVGOU9Zd2JNIn0.eyJleHAiOjE2ODE4NDUzMjUsImlhdCI6MTY4MTc1ODkyNSwianRpIjoiMTEyZDk2MzYtOWI3My00OTc1LThiZmEtMDg0ZGIyZjgxN2IzIiwiaXNzIjoiaHR0cHM6Ly9zdGctc3NvLnNvbGZhY2lsLmNvbS5ici9yZWFsbXMvR2VuZXJhbCIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiJlY2Q4ZjYzZC0zMzc1LTQ1ZTMtYjZjOC0zNjA2NWM3NjQxODQiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJzb2xhci1pbm92ZS1tYWNoaW5lIiwiYWNyIjoiMSIsInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJkZWZhdWx0LXJvbGVzLWdlbmVyYWwiLCJvZmZsaW5lX2FjY2VzcyIsInVtYV9hdXRob3JpemF0aW9uIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJwcm9maWxlIGVtYWlsIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJjbGllbnRJZCI6InNvbGFyLWlub3ZlLW1hY2hpbmUiLCJjbGllbnRIb3N0IjoiNTIuNTQuNDkuMTAxIiwicHJlZmVycmVkX3VzZXJuYW1lIjoic2VydmljZS1hY2NvdW50LXNvbGFyLWlub3ZlLW1hY2hpbmUiLCJjbGllbnRBZGRyZXNzIjoiNTIuNTQuNDkuMTAxIn0.LXZuEyrkRJEbvJ_FwutXWtTC5DKiBGK3Q0IAWkP_8_xdJyfmoLerw04v1CtoO0hPB2fLoQrJm8W1lJd8iBVDT9-bnSdIR7tJxY9wMUgXQFO-y653qIKGfsTlnVus4hyyPE1ce9Swf5xwCypH7lxlcbNUmnvSdPAlt06K_lEmxEEXf2pSCv3rKeiv1VzfNvylT_dJCf5HZrSBeI2hKG-zFVnAzZm62EVCMhS2tJPoxS7QkLc7V2wsYnyV-PoAHrrg-F2tXDy-zKSyb-xek8W-qnWoj3emLqIscTE16JnIWhMSHF4JsJgBM2ZVEr3FmY7AoaGYvKe817CWUatyZw3H4g"
local client_id = "solar-inove-machine"
local client_secret = "hdFBGWdEB6nJk9wZX2aypxfbH2SEKyJd"


local url = introspection_endpoint
local payload = 'client_id='.. client_id .. '&client_secret=' .. client_secret .. '&token=' .. token
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
  