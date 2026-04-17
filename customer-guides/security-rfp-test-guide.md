# Security Requirements Customer Test Guide

This guide is for customer validation of the Security POC. Kong Gateway, Konnect configuration, routes, plugins, certificates, and infrastructure are assumed to already be set up.

The customer only needs to run the curl commands below and compare the result with the expected outcome.

## Test Endpoint

All curl examples use the public load balancer hostname:

```text
https://apidev-kong.ot.id
```

## 1. Google SSO Enforcement

Requirement: unauthenticated browser traffic must be redirected to Google SSO before the backend API is reached.

Route:

```text
/security/oidc
```

decK config: `kong/security-poc.yaml` -> route `security-oidc-route`, plugin instance `security-oidc-google-auth-code`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 1.1: Unauthenticated Request Is Redirected To Google

Run:

```bash
curl -i https://apidev-kong.ot.id/security/oidc
```

Expected result:

```text
HTTP/2 302
location: https://accounts.google.com/o/oauth2/v2/auth?...
```

Pass criteria:

```text
Kong redirects the unauthenticated request to Google SSO.
```

### Test 1.2: Authenticated Browser Session Can Reach The Backend

Run:

```bash
open https://apidev-kong.ot.id/security/oidc
```

Expected result:

```text
Google prompts for login. After successful login, Kong validates the authorization code, creates a secure session, maps the Google email claim to a Kong Consumer, and forwards the request to the backend.
```

Pass criteria:

```text
The protected backend is reachable only after successful Google login.
```

## 2. JSON And XML Bomb Protection

Requirement: malicious JSON and XML payloads must be blocked at the gateway before the application parses them.

Route:

```text
/security/threat-protection
```

decK config: `kong/security-poc.yaml` -> route `security-threat-protection-route`, plugin instances `security-json-threat-protection` and `security-xml-threat-protection`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 2.1: Safe JSON Payload Is Allowed

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/threat-protection" \
  -H "Content-Type: application/json" \
  -d '{"id_company":"CM01KP7H0DCS2QG774N7KVNQY806"}'
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
Normal JSON payloads are allowed through Kong.
```

### Test 2.2: Deeply Nested JSON Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/threat-protection" \
  -H "Content-Type: application/json" \
  -d '{"a":{"b":{"c":{"d":{"e":"too deep"}}}}}'
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Pass criteria:

```text
Kong blocks the nested JSON payload.
```

### Test 2.3: Deeply Nested XML Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/threat-protection" \
  -H "Content-Type: application/xml" \
  -d '<a><b><c><d><e>too deep</e></d></c></b></a>'
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Pass criteria:

```text
Kong blocks the nested XML payload.
```

## 3. API Schema Validation

Requirement: Kong must validate query parameters and request bodies against the expected API contract.

Routes:

```text
/security/schema-validation/products
/security/schema-validation/stores-data
```

decK config: `kong/security-poc.yaml` -> routes `security-schema-validation-products-route` and `security-schema-validation-stores-data-route`, plugin instances `security-products-oas-validation`, `security-stores-data-oas-validation`, and `security-stores-data-request-validator`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 3.1: Valid Product Query Is Allowed

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/schema-validation/products/?status=active&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
Valid query parameters are accepted.
```

### Test 3.2: Invalid Product Query Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/schema-validation/products/?status=deleted&page=abc&size=1"
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Pass criteria:

```text
Invalid query parameters are rejected before reaching the backend.
```

### Test 3.3: Valid Store Data Body Is Allowed

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/schema-validation/stores-data" \
  -H "Content-Type: application/json" \
  -d '{"id_company":"CM01KP7H0DCS2QG774N7KVNQY806"}'
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
Valid JSON request bodies are accepted.
```

### Test 3.4: Missing Required Field Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/schema-validation/stores-data" \
  -H "Content-Type: application/json" \
  -d '{"company":"wrong-field"}'
```

Expected result:

```text
HTTP/1.1 400 Bad Request
{"message":"property id_company is required"}
```

Pass criteria:

```text
Kong rejects the request because the required id_company field is missing.
```

## 4. Layer 7 Injection Protection

Requirement: Kong must block common Layer 7 injection patterns.

Route:

```text
/security/schema-validation/products
```

decK config: `kong/security-poc.yaml` -> route `security-schema-validation-products-route`, plugin instance `security-products-injection-protection`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 4.1: SQL-Like Query Pattern Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/schema-validation/products/?search=OR%201%3D1&page=1&size=1"
```

Expected result:

```text
HTTP/1.1 400 Bad Request
```

Pass criteria:

```text
Kong blocks the SQL-like query pattern.
```

## 5. Brute-Force Rate Limiting

Requirement: repeated auth-style requests from the same client IP must be throttled.

Route:

```text
/security/brute-force
```

decK config: `kong/security-poc.yaml` -> route `security-brute-force-route`, plugin instance `security-brute-force-rate-limiting`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 5.1: Burst From Same IP Is Rate Limited

Run:

```bash
for i in 1 2 3 4 5 6 7; do
  curl -s -o /dev/null -w "request $i -> %{http_code}\n" \
    "https://apidev-kong.ot.id/security/brute-force/" \
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

Pass criteria:

```text
Kong allows the first five requests and rejects later requests with HTTP 429.
```

Note:

```text
If you rerun this test within 60 seconds, change the X-Forwarded-For value to a new IP such as 198.51.100.77.
```

## 6. Bot Detection

Requirement: requests from configured bad bot user agents must be blocked.

Route:

```text
/security/brute-force
```

decK config: `kong/security-poc.yaml` -> route `security-brute-force-route`, plugin instance `security-brute-force-bot-detection`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 6.1: BadBot User Agent Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/brute-force/" \
  -H "X-Forwarded-For: 198.51.100.20" \
  -H "User-Agent: BadBot"
```

Expected result:

```text
HTTP/1.1 403 Forbidden
```

Pass criteria:

```text
Kong blocks the request because the User-Agent is on the deny list.
```

## 7. Context-Aware Temporary Ban Logic

Requirement: Kong must support custom gateway-side logic for suspicious request patterns, such as repeated failed login markers.

Route:

```text
/security/brute-force
```

decK config: `kong/security-poc.yaml` -> route `security-brute-force-route`, plugin instance `security-brute-force-pre-function`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 7.1: Suspicious Query Marker Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/brute-force/?login_failed=true" \
  -H "X-Forwarded-For: 198.51.100.30"
```

Expected result:

```text
HTTP/1.1 403 Forbidden
{"message":"Pattern-based temporary ban triggered"}
```

Pass criteria:

```text
Kong blocks the request because the suspicious login_failed marker is present.
```

### Test 7.2: Suspicious Header Marker Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/brute-force/" \
  -H "X-Forwarded-For: 198.51.100.31" \
  -H "X-Login-Failed: true"
```

Expected result:

```text
HTTP/1.1 403 Forbidden
{"message":"Pattern-based temporary ban triggered"}
```

Pass criteria:

```text
Kong blocks the request because the suspicious X-Login-Failed header is present.
```

## 8. IP Restriction

Requirement: Kong must block traffic from a configured denied IP while allowing other IPs.

Route:

```text
/security/brute-force-ip-blocked
```

decK config: `kong/security-poc.yaml` -> route `security-brute-force-ip-blocked-route`, plugin instance `security-brute-force-ip-restriction`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 8.1: Denied IP Is Blocked

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/brute-force-ip-blocked/" \
  -H "X-Forwarded-For: 103.252.202.41"
```

Expected result:

```text
HTTP/1.1 403 Forbidden
{"message":"IP address not allowed: 103.252.202.41", ...}
```

Pass criteria:

```text
Kong rejects traffic from the configured denied IP.
```

### Test 8.2: Different IP Is Allowed

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/brute-force-ip-blocked/" \
  -H "X-Forwarded-For: 198.51.100.40"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
Kong allows traffic from IPs that are not on the deny list.
```

## 9. PII Masking

Requirement: Kong must mask sensitive values in API responses before the client receives the response.

Routes:

```text
/security/pii-masking
/security/pii-masking-test
```

decK config: `kong/security-poc.yaml` -> routes `security-pii-masking-route` and `security-pii-masking-test-route`, plugin instances `security-pii-regex-masking`, `security-pii-test-demo-payload`, and `security-pii-test-regex-masking`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 9.1: Live Members API Response Is Masked When PII Is Present

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/pii-masking/?status=all&page=1&size=5"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
If the backend response contains email, phone, KTP/NIK-style ID, or card-like values, Kong masks those values before returning the response to the client.
```

### Test 9.2: Controlled Demo Payload Shows Visible Masking

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/pii-masking-test"
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

Pass criteria:

```text
Kong masks sensitive response values without requiring backend application changes.
```

## 10. mTLS Client Certificate Enforcement

Requirement: protected client or device traffic must present a trusted client certificate.

Route:

```text
/security/mtls
```

decK config: `kong/security-poc.yaml` -> route `security-mtls-route`, plugin instance `security-mtls-auth`. Full mapping: `deck/security-rfp-scene-map.md`.

### Test 10.1: Request Without Client Certificate Is Rejected

Run:

```bash
curl -i "https://apidev-kong.ot.id/security/mtls/"
```

Expected result:

```text
HTTP/1.1 401 Unauthorized
{"message":"No required TLS certificate was sent"}
```

Pass criteria:

```text
Kong rejects the request because no trusted client certificate was provided.
```

### Test 10.2: Request With Trusted Client Certificate Is Allowed

Run:

```bash
curl -i --cert certs/pos-terminal-001.crt \
  --key certs/pos-terminal-001.key \
  "https://apidev-kong.ot.id/security/mtls/"
```

Expected result:

```text
HTTP/1.1 200 OK
```

Pass criteria:

```text
Kong forwards the request when a trusted client certificate is provided.
```
