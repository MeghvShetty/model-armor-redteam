import os
import google.cloud.modelarmor_v1 as modelarmor

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT")
LOCATION = os.environ.get("MODEL_ARMOR_LOCATION","europe-west4")

def test_prompt(payload: str, template_id: str ="confidence-level-low") -> str:
    """
    Send a payload to Model Armor and return the real verdict.
    Always call this before log_finding. Never assume an outcome.

    template_id options:
        - confidence-level-low
        - confidence-level-medium
        - confidence-level-high
        - confidence-multi-language
        - confidence-inspect-only
    """
    try:
        template_name =(
            f"projects/{PROJECT_ID}/locations/{LOCATION}/templates/{template_id}"
        )
        client = modelarmor.ModelArmorClient(
            client_options={
                "api_endpoint": f"modelarmor.{LOCATION}.rep.googleapis.com"
            }
        )

        request = modelarmor.SanitizeUserPromptRequest(
            name=template_name,
            user_prompt_data=modelarmor.DataItem(text=payload)
        )

        response = client.sanitize_user_prompt(request)
        result = response.sanitization_result
        state = result.filter_match_state.name

        filters_triggered = []

        for key, value in result.filter_results.items():
            if key == "pi_and_jailbreak":
                if value.pi_and_jailbreak_filter_result.match_state.name == "MATCH_FOUND":
                    filters_triggered.append("PROMPT_INJECTION_AND_JAILBREAK")
            elif key == "rai":
                rai = value.rai_filter_result
                if rai.match_state.name == "MATCH_FOUND":
                    for rai_key, rai_val in rai.rai_filter_type_results.items():
                        if rai_val.match_state.name == "MATCH_FOUND":
                            filters_triggered.append(f"RAI:{rai_key.upper()}")
            elif key == "sdp":
                sdp = value.sdp_filter_result.inspect_result
                if sdp.match_state.name == "MATCH_FOUND":
                    filters_triggered.append("SENSITIVE_DATA")
            elif key == "malicious_uris":
                if value.malicious_uri_filter_result.match_state.name == "MATCH_FOUND":
                    filters_triggered.append("MALICIOUS_URL")
            elif key == "csam":
                if value.csam_filter_filter_result.match_state.name == "MATCH_FOUND":
                    filters_triggered.append("CSAM")

        verdict = "BLOCK" if state == "MATCH_FOUND" else "PASS"

        output = (
            f"VERDICT  : {verdict}\n"
            f"TEMPLATE:{template_id}\n"
            f"FILTERS  : {', '.join(filters_triggered) if filters_triggered else 'NONE'}\n"
            f"RAW STATE: {state}"
        )
        print(output)
        return output

    except Exception as e:
        error = f"TOOL_ERROR: {str(e)}"
        print(error)
        return error
