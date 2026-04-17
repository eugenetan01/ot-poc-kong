# Orang Tua Security RFP Demo Guide

Use this as the live presentation runbook for the Security must-have rows and the selected Next items in `OTGroup_Kong_POC_Requirements_Capabilities-v0.1.xlsx`.

The quick smoke-test script is still available:

```bash
./scripts/demo-security.sh
```

This guide is the step-by-step version: what to say, what to run, and what outcome proves each capability.

## Demo Setup

Start the local Kong 3.13 Konnect data plane:

```bash
docker compose up -d
```

Confirm the Kong container is running:

```bash
docker compose ps
```

Expected result:

```text
kong-security-poc    kong/kong-gateway:3.13   Up ... healthy
```

Confirm the Kong data plane status endpoint is live:

```bash
curl -s http://localhost:8100/status
```

Expected result:

```text
Server: kong/3.13.0.0-enterprise-edition
```

The upstream routes to:

```text
https://wolu-master-service-175096896148.asia-southeast2.run.app
```

The security must-have scenes now use WOLU Master API endpoints from the published Swagger document, including Products, Store Data, and Members.

## Entity Tagging

All POC entities in `kong/security-poc.yaml` are tagged with:

```text
security
orangtua
```

The Konnect sync should be scoped to those tags:

```bash
./scripts/sync-security.sh
```

The sync helper reads `google-sso.json` locally and injects the Google OAuth client ID and secret into decK through environment variables, so the secret is not stored directly in `kong/security-poc.yaml`.

## Scene 1: OAuth2.0 & Advanced JWT Validation

Route:

```text
/security/oidc
```

What this proves:

- Google OIDC issuer is configured.
- Google authorization-code login is required for browser access.
- Kong creates a secure session after Google login.
- Consumer mapping uses the Google `email` claim for demo readability.

Presenter line:

```text
First, I will show that unauthenticated browser traffic is redirected to Google SSO before it can reach the backend.
```

Run:

```bash
curl -i https://apidev-kong.ot.id/security/oidc
```

Expected result:

```text
HTTP/2 302
location: https://accounts.google.com/o/oauth2/v2/auth?...
```

Presenter line:

```text
Now I will open the route in a browser and complete the Google login.
```

Run:

```bash
open https://apidev-kong.ot.id/security/oidc
```

Expected result:

```text
Google prompts for login. After successful login, Kong validates the code, creates a session, maps the Google email to a Kong Consumer, redirects the browser back to a clean `/security/oidc` request, and forwards that clean request to the WOLU Menus backend.
```

Customer setup note:

```text
The Google OAuth client in `google-sso.json` must have this exact authorized redirect URI:
https://apidev-kong.ot.id/security/oidc
Scopes: openid email profile
```

Close:

```text
This satisfies the SSO enforcement requirement: unauthenticated browser traffic is intercepted at Kong and sent to Google before the upstream service sees it.
```

## Scene 2: JSON/XML Bomb Protection

Route:

```text
/security/threat-protection
```

What this proves:

- JSON Threat Protection sets `max_body_size`, `max_container_depth`, `max_array_element_count`, and `max_string_value_length`.
- XML Threat Protection sets `max_depth`, `max_children`, and `max_attributes`.
- Violations return HTTP `400`.
- The POC applies these controls at route level; production can move them to service or global level.

Presenter line:

```text
First, I will show that normal JSON still works. The gateway should not block legitimate payloads.
```

Run:

```bash
curl -i http://localhost:8000/security/threat-protection \
  -H "Content-Type: application/json" \
  -d '{"id_company":"CM01KP7H0DCS2QG774N7KVNQY806"}'
```

Expected result:

```text
HTTP/1.1 200 OK
Body contains the WOLU Store Data response.
```

Presenter line:

```text
Now I will send a deeply nested JSON payload. Kong blocks it before the application parses it.
```

Run:

```bash
curl -i http://localhost:8000/security/threat-protection \
  -H "Content-Type: application/json" \
  -d '{"a":{"b":{"c":{"d":{"e":"too deep"}}}}}'
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Presenter line:

```text
The same pattern applies to XML payloads, which is important for XML bomb protection.
```

Run:

```bash
curl -i http://localhost:8000/security/threat-protection \
  -H "Content-Type: application/xml" \
  -d '<a><b><c><d><e>too deep</e></d></c></b></a>'
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Close:

```text
This satisfies the malicious payload blocking requirement for JSON and XML.
```

## Scene 3: Strict Schema Validation And L7 Injection

Route:

```text
/security/schema-validation/products
/security/schema-validation/stores-data
```

What this proves:

- OAS Validation is attached with WOLU-shaped OpenAPI 3.0 contracts.
- Product query parameters are validated against the Swagger shape.
- Store Data JSON bodies are validated against the Swagger shape.
- Request Validator is attached with an equivalent route-level JSON Schema for the POST body.
- JSON/XML Threat Protection is combined on the Store Data route for L7 defense.
- Injection Protection is attached for SQL, Java exception, JavaScript, SSI, and XPath-style patterns.
- Schema violations return HTTP `400`.

Presenter line:

```text
First, I will send a WOLU Products query that matches the API contract.
```

Run:

```bash
curl -i "http://localhost:8000/security/schema-validation/products/?status=active&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
Body contains the WOLU Products response.
```

Presenter line:

```text
Now I will send invalid query parameters. Kong rejects the request before it reaches the backend.
```

Run:

```bash
curl -i "http://localhost:8000/security/schema-validation/products/?status=deleted&page=abc&size=1"
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Presenter line:

```text
Next, I will send a WOLU Store Data payload that matches the documented request body.
```

Run:

```bash
curl -i http://localhost:8000/security/schema-validation/stores-data \
  -H "Content-Type: application/json" \
  -d '{"id_company":"CM01KP7H0DCS2QG774N7KVNQY806"}'
```

Expected result:

```text
HTTP/1.1 200 OK
Body contains the WOLU Store Data response.
```

Presenter line:

```text
Now I will remove a required field. Kong rejects the request before it reaches the backend.
```

Run:

```bash
curl -i http://localhost:8000/security/schema-validation/stores-data \
  -H "Content-Type: application/json" \
  -d '{"company":"wrong-field"}'
```

Expected result:

```text
HTTP/1.1 400 Bad Request
{"message":"property id_company is required"}
```

Presenter line:

```text
Now I will add an SQL-like query string to show L7 injection protection.
```

Run:

```bash
curl -i "http://localhost:8000/security/schema-validation/products/?search=OR%201%3D1&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Close:

```text
This satisfies the strict API contract validation and L7 injection-blocking requirement.
```

## Scene 4: Context-Aware Throttling And Brute Force Protection

Routes:

```text
/security/brute-force
/security/brute-force-ip-blocked
```

What this proves:

- Rate Limiting Advanced is attached with a short five-requests-per-minute demo threshold.
- Rate Limiting Advanced is keyed by client IP.
- Bot Detection blocks configured bad user agents.
- IP Restriction blocks only the configured current IP: `103.252.202.41`.
- Pre-function applies custom Lua logic for pattern-based blocking.
- The route represents an auth endpoint such as login or token issuance.
- GCP Cloud Armor is the production perimeter integration point; this local demo proves Kong-side enforcement.

Presenter line:

```text
First, I will simulate repeated auth traffic from one client IP. Kong allows the first five requests and throttles the burst.
```

Run:

```bash
for i in 1 2 3 4 5 6 7; do
  curl -s -o /dev/null -w "request $i -> %{http_code}\n" \
    http://localhost:8000/security/brute-force/ \
    -H "X-Forwarded-For: 198.51.100.10"
done
```

Expected result:

```text
request 1 -> 200
request 2 -> 200
request 3 -> 200
request 4 -> 200
request 5 -> 200
request 6 -> 429
request 7 -> 429
```

Presenter line:

```text
Next, I will simulate a known bad bot user agent.
```

Run:

```bash
curl -i http://localhost:8000/security/brute-force/ \
  -H "X-Forwarded-For: 198.51.100.20" \
  -H "User-Agent: BadBot"
```

Expected result:

```text
HTTP/1.1 403 Forbidden
```

Presenter line:

```text
Now I will show the custom Pre-function rule for pattern-based blocking, representing a temporary ban trigger after suspicious login failures.
```

Run:

```bash
curl -i "http://localhost:8000/security/brute-force/?login_failed=true" \
  -H "X-Forwarded-For: 198.51.100.30"
```

Expected result:

```text
HTTP/1.1 403 Forbidden
{"message":"Pattern-based temporary ban triggered"}
```

Presenter line:

```text
Finally, I will show IP Restriction. This route blocks only the configured current IP and allows other IPs.
```

Run:

```bash
curl -i http://localhost:8000/security/brute-force-ip-blocked/ \
  -H "X-Forwarded-For: 103.252.202.41"
```

Expected result:

```text
HTTP/1.1 403 Forbidden
{"message":"IP address not allowed: 103.252.202.41", ...}
```

Run:

```bash
curl -i http://localhost:8000/security/brute-force-ip-blocked/ \
  -H "X-Forwarded-For: 198.51.100.40"
```

Expected result:

```text
HTTP/1.1 200 OK
Body contains the WOLU Products response.
```

Close:

```text
This satisfies the brute-force protection requirement: rate limits, bot blocking, IP restriction, and custom request-context logic all run at the gateway edge.
```

## Scene 5: Regex PII Masking

Route:

```text
/security/pii-masking
/security/pii-masking-test
```

What this proves:

- Response Transformer Advanced is attached on the response path.
- PII is identified by regex patterns, not by fixed JSON field names.
- The route forwards to the WOLU Members API.
- The masking rules cover email addresses, Indonesian phone numbers, KTP/NIK-style 16-digit IDs, and card-like numbers.
- The backend does not need to change; Kong masks sensitive values before the client receives the response.
- `/security/pii-masking-test` is a controlled presentation route with a fake member payload, used only to make the masking visible when the live Members dataset is empty.

Presenter line:

```text
First, I will call the WOLU Members endpoint through Kong. If member/customer payloads contain sensitive values, Kong masks them by regex before the response reaches the client.
```

Run:

```bash
curl -i "http://localhost:8000/security/pii-masking/?status=all&page=1&size=5"
```

Expected result:

```text
HTTP/1.1 200 OK
Body contains the WOLU Members response. Any email, phone, KTP/NIK-style ID, or card-like value in the payload is masked before returning to the client.
```

Close:

```text
This proves the masking is pattern-driven and can protect sensitive member payloads without backend changes.
```

Presenter line:

```text
If the live Members API does not currently contain sensitive test data, I will use a controlled demo route. The payload is fake, but the same response-transformer regex logic masks it.
```

Run:

```bash
curl -i http://localhost:8000/security/pii-masking-test
```

Expected result:

```text
HTTP/1.1 200 OK
{
  "name": "Budi Santoso",
  "email": "b***@example.com",
  "phone_number": "0812****90",
  "reference": "NIK 317302********01 card 411111******1111",
  ...
}
```

## Scene 6: mTLS Client Certificate Enforcement

Route:

```text
/security/mtls
```

What this proves:

- Kong requests and validates a client certificate at the gateway.
- The mTLS Auth plugin trusts the demo CA in `kong/security-poc.yaml`.
- A request without a trusted client certificate returns HTTP `401`.
- A request with the generated `pos-terminal-001` client certificate reaches the upstream.
- The route uses SNI `mtls.localhost`; the curl `--resolve` option points that name to the local Kong listener.

Presenter line:

```text
First, I will call the mTLS route without a client certificate. Kong rejects the request before it reaches the upstream.
```

Run:

```bash
curl -k -i --resolve mtls.localhost:8443:127.0.0.1 \
  https://mtls.localhost:8443/security/mtls/
```

Expected result:

```text
HTTP/1.1 401 Unauthorized
{"message":"No required TLS certificate was sent"}
```

Presenter line:

```text
Now I will send the same request using the trusted POS terminal client certificate.
```

Run:

```bash
curl -k -i --resolve mtls.localhost:8443:127.0.0.1 \
  --cert certs/pos-terminal-001.crt \
  --key certs/pos-terminal-001.key \
  https://mtls.localhost:8443/security/mtls/
```

Expected result:

```text
HTTP/1.1 200 OK
Body contains the WOLU Products response.
```

Close:

```text
This proves device or application clients can be required to present trusted certificates before Kong forwards the request.
```

## One-Command Rehearsal

Run the complete rehearsal:

```bash
BASE_URL=http://localhost:8000 \
BLOCKED_IP=103.252.202.41 \
RATE_LIMIT_IP=198.51.100.77 \
./scripts/demo-security.sh
```

Expected summary:

```text
OIDC missing token -> 401
OIDC invalid token -> 401
Safe JSON -> 200
Nested JSON -> 400
Nested XML -> 400
Valid schema -> 200
Invalid schema -> 400
Injection pattern -> 400
Rate limit burst -> 200, 200, 200, 200, 200, 429, 429
BadBot -> 403
Pre-function marker -> 403
Blocked IP -> 403
Different IP -> 200
PII masking -> 200, with sensitive WOLU member values masked when present
mTLS without client cert -> 401
mTLS with trusted client cert -> 200
```

## Reset Between Rehearsals

The rate-limit scene uses a per-IP counter. If you rerun the demo immediately and want the first five requests to pass again, use a new `RATE_LIMIT_IP`:

```bash
RATE_LIMIT_IP=198.51.100.88 ./scripts/demo-security.sh
```

To restart the local stack:

```bash
docker compose down
docker compose up -d
```
