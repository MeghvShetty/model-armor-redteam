import json
import os
from datetime import date

FINDINGS_PATH = os.path.join(os.path.dirname(__file__), "../results/findings.json")

def _load() -> dict:
    if not os.path.exists(FINDINGS_PATH):
        return {
            "test_run": str(date.today()),
            "model_armor_config": "floor_settings_enabled",
            "findings": []
        }
    with open(FINDINGS_PATH, "r") as f:
        return json.load(f)

def _save(data: dict):
    os.makedirs(os.path.dirname(FINDINGS_PATH), exist_ok=True)
    with open(FINDINGS_PATH, "w") as f:
        json.dump(data, f, indent=2)

def log_finding(
    category: str,
    input_text: str,
    filter_triggered: str,
    expected: str,
    actual: str,
    note: str,
    severity: str = "medium"
) -> str:
    """
    Log a test result to findings.json.
    
    Use this after EVERY test — pass or block.
    expected and actual must be one of: PASS, BLOCK, PARTIAL
    severity must be one of: low, medium, high, critical
    """
    data = _load()
    
    # Determine category prefix for ID
    prefix_map = {
        "false_positive": "FP",
        "prompt_injection": "PI",
        "jailbreak": "JB",
        "hate_speech": "HS",
        "malicious_url": "URL",
        "sensitive_data": "SD",
         "baseline": "BL",
    }
    prefix = prefix_map.get(category, "T")
    
    # Auto-increment ID within category
    existing = [f for f in data["findings"]
        if f["id"].startswith(prefix)
    ]
    finding_id = f"{prefix}-{str(len(existing) + 1).zfill(3)}"
    
    finding = {
        "id": finding_id,
        "category": category,
        "severity": severity,
        "input": input_text,
        "filter_triggered": filter_triggered,
        "expected": expected,
        "actual": actual,
        "is_finding": expected != actual,  # True = something unexpected happened
        "note": note
    }
    
    data["findings"].append(finding)
    _save(data)
    
    status = "⚠️ FINDING" if finding["is_finding"] else "✅ Expected"
    result = (
        f"{status}\n"
        f"ID       : {finding_id}\n"
        f"Category : {category}\n"
        f"Expected : {expected}\n"
        f"Actual   : {actual}\n"
        f"Input    : {input_text[:80]}{'...' if len(input_text) > 80 else ''}\n"
        f"Note     : {note}"
    )

    ## Force output regarless of agent behaviour 
    print(result)
    return result 


def get_summary() -> str:
    """
    Return a summary of all test results so far.

    """
    
    data = _load()
    findings = data["findings"]
    
    if not findings:
        return "No tests logged yet."
    
    total = len(findings)
    real_findings = [f for f in findings if f.get("is_finding")]
    false_positives = [f for f in real_findings if f["category"] == "false_positive"]
    bypasses = [f for f in real_findings if f["actual"] == "PASS" and f["expected"] == "BLOCK"]
    
    by_category = {}
    for f in findings:
        by_category.setdefault(f["category"], []).append(f)
    
    # lines = [
    #     f"Total tests: {total}",
    #     f"Real findings: {len(real_findings)}",
    #     f"  → False positives: {len(false_positives)}",
    #     f"  → Bypasses (should block, didn't): {len(bypasses)}",
    #     "",
    #     "By category:"
    # ]
    # for cat, items in by_category.items():
    #     lines.append(f"  {cat}: {len(items)} tests")
    #
    # return "\n".join(lines)

    result = "\n".join([
        "=" * 40,
        f"TOTAL TESTS    : {total}",
        f"REAL FINDINGS  : {len(real_findings)}",
        f"  False positives : {len(false_positives)}",
        f"  Bypasses        : {len(bypasses)}",
        "",
        "BY CATEGORY:",
        *[f"  {cat:<20} {len(items)} tests" for cat, items in by_category.items()],
        "=" * 40,
    ])
    
    print(result)
    return result


def delete_finding(finding_id: str) -> str:
    """Delete a finding by its ID (e.g. FP-003)."""
    data = _load()
    before = len(data["findings"])
    data["findings"] = [
        f for f in data["findings"] 
        if f["id"] != finding_id
    ]
    after = len(data["findings"])
    _save(data)
    
    if before == after:
        return f"No finding found with ID {finding_id}."
    return f"Deleted {finding_id}. Total tests now: {after}"
