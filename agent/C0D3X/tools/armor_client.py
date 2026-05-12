# Custom tool for MA that agent uses to route traffice - Theory 

import os
from google.cloud import modelarmor_v1 as modelarmor 

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT")
LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION")
TEMPLATE_ID = os.environ.get("MODEL_ARMOR_TEMPLATE_ID")


TEMPLATE_NAME = "projects/infantry-480110/locations/europe-west4/templates/test-template-2"

def test_prompt(payload: str) -> str:
    """
    MA sends a playload and returns the real verdict.
    ALways call this before  log_finding, never assume an outcome. 

    Returns a String with verdict and filters triggerd. 
    """
    try:
        client = modelarmor.ModelArmorClient(
            client_options={"api_endpoint": f"modelarmor.{LOCATION}.rep.googleapis.com"}
        )

        request = modelarmor.SanitizeUserPromptRequest(
            name=TEMPLATE_NAME,
            user_prompt_data=modelarmor.DataItem(text=payload)
        )

        response = client.sanitize_user_prompt(request)
        result = response.sanitization_result
        state = result.filter_match_state.name  # MATCH_FOUND or NO_MATCH_FOUND

        filters_triggered = [
            fr.filter_type.name
            for fr in result.filter_results
            if fr.filter_match_state.name == "MATCH_FOUND"
        ]

        verdict = "BLOCK" if state == "MATCH_FOUND" else "PASS"

        output = (
            f"VERDICT  : {verdict}\n"
            f"FILTERS  : {', '.join(filters_triggered) if filters_triggered else 'NONE'}\n"
            f"RAW STATE: {state}"
        )
        print(output)
        return output

    except Exception as e:
        error = f"ERROR: {str(e)}"
        print(error)
        return error
