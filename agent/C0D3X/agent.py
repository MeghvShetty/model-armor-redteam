from google.adk.agents.llm_agent import Agent
import os
from .util import load_instruction_from_file 
from C0D3X.tools.findings_logs import log_finding, get_summary 


C0D3X = Agent(
    model='gemini-2.5-flash',
    name='C0D3X',
    description='A helpful assistant for user questions.',
    instruction= load_instruction_from_file("./C0D3X_instruction_trigger.txt"),
    tools=  [log_finding, get_summary],
)

root_agent = C0D3X
