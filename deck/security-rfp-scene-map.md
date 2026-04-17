# Security RFP Scene To decK Config Map

This file maps each customer test scene in `customer-guides/security-rfp-test-guide.md` to the Kong decK configuration that implements it.

All security scenes are configured in:

```text
kong/security-poc.yaml
```

## 1. Google SSO Enforcement

Customer guide section:

```text
1. Google SSO Enforcement
```

decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-oidc-menu-service
Route: security-oidc-route
Path: /security/oidc
Plugin: openid-connect
Plugin instance: security-oidc-google-auth-code
```

## 2. JSON And XML Bomb Protection

Customer guide section:

```text
2. JSON And XML Bomb Protection
```

decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-store-data-service
Route: security-threat-protection-route
Path: /security/threat-protection
Plugin: json-threat-protection
Plugin instance: security-json-threat-protection
Plugin: xml-threat-protection
Plugin instance: security-xml-threat-protection
```

## 3. API Schema Validation

Customer guide section:

```text
3. API Schema Validation
```

Product query validation decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-products-service
Route: security-schema-validation-products-route
Path: /security/schema-validation/products
Plugin: oas-validation
Plugin instance: security-products-oas-validation
```

Store Data body validation decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-store-data-service
Route: security-schema-validation-stores-data-route
Path: /security/schema-validation/stores-data
Plugin: oas-validation
Plugin instance: security-stores-data-oas-validation
Plugin: request-validator
Plugin instance: security-stores-data-request-validator
```

## 4. Layer 7 Injection Protection

Customer guide section:

```text
4. Layer 7 Injection Protection
```

decK config used by the customer curl in this guide:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-products-service
Route: security-schema-validation-products-route
Path: /security/schema-validation/products
Plugin: injection-protection
Plugin instance: security-products-injection-protection
```

Additional Store Data injection protection is also configured:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-store-data-service
Route: security-schema-validation-stores-data-route
Path: /security/schema-validation/stores-data
Plugin: injection-protection
Plugin instance: security-stores-data-injection-protection
```

## 5. Brute-Force Rate Limiting

Customer guide section:

```text
5. Brute-Force Rate Limiting
```

decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-products-service
Route: security-brute-force-route
Path: /security/brute-force
Plugin: rate-limiting-advanced
Plugin instance: security-brute-force-rate-limiting
```

## 6. Bot Detection

Customer guide section:

```text
6. Bot Detection
```

decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-products-service
Route: security-brute-force-route
Path: /security/brute-force
Plugin: bot-detection
Plugin instance: security-brute-force-bot-detection
```

## 7. Context-Aware Temporary Ban Logic

Customer guide section:

```text
7. Context-Aware Temporary Ban Logic
```

decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-products-service
Route: security-brute-force-route
Path: /security/brute-force
Plugin: pre-function
Plugin instance: security-brute-force-pre-function
```

## 8. IP Restriction

Customer guide section:

```text
8. IP Restriction
```

decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-products-service
Route: security-brute-force-ip-blocked-route
Path: /security/brute-force-ip-blocked
Plugin: ip-restriction
Plugin instance: security-brute-force-ip-restriction
```

## 9. PII Masking

Customer guide section:

```text
9. PII Masking
```

Live Members API decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-members-service
Route: security-pii-masking-route
Path: /security/pii-masking
Plugin: response-transformer-advanced
Plugin instance: security-pii-regex-masking
```

Controlled demo payload decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-members-service
Route: security-pii-masking-test-route
Path: /security/pii-masking-test
Plugin: request-termination
Plugin instance: security-pii-test-demo-payload
Plugin: response-transformer-advanced
Plugin instance: security-pii-test-regex-masking
```

## 10. mTLS Client Certificate Enforcement

Customer guide section:

```text
10. mTLS Client Certificate Enforcement
```

decK config:

```text
File: kong/security-poc.yaml
Service: ot-wolu-security-products-service
Route: security-mtls-route
Path: /security/mtls
SNI: mtls.localhost
Plugin: mtls-auth
Plugin instance: security-mtls-auth
CA certificate id: 75691535-236b-4bf6-93c7-502258d5b164
```
