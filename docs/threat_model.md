# Threat Model: AI Firewall Bypass — Google Model Armor

## Scope
- Asset: Model Garden endpoints fronted by Model Armor
- Attacker persona: External adversary with API access / insider with prompt authoring rights

## Attack Surface
| Surface          | Vector                     | Control Tested       |
|------------------|----------------------------|----------------------|
| User prompt      | Direct injection           | Prompt injection     |
| Tool output      | Indirect injection via RAG | Prompt injection     |
| System prompt    | Jailbreak via role framing | Jailbreak            |
...

## STRIDE Mapping
...

## Findings Summary
| Control               | Bypass Found | Severity | Notes |
...
