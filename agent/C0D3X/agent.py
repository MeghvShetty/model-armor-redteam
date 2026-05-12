from google.adk.agents.llm_agent import Agent
import os
from .util import load_instruction_from_file 
from C0D3X.tools.findings_logs import log_finding, get_summary, delete_finding
from C0D3X.tools.armor_client import test_prompt 


C0D3X = Agent(
    model='gemini-2.5-flash',
    name='C0D3X',
    description='A helpful assistant for user questions.',
    instruction= load_instruction_from_file("./C0D3X_instruction_trigger_v3.txt"),
    tools=  [log_finding, get_summary, delete_finding, test_prompt],
)

root_agent = C0D3X
