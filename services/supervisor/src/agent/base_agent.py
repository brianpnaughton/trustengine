from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
from tools.agui import taskApproval
from tools.tasks import runtask

# Create a basic agent - you can customize this based on your needs
# This is a simple example agent that can respond to messages
basic_agent = Agent(
    name="ChatAgent",
    model=LiteLlm(model="ollama_chat/gemma3:1b"),
    instruction="""You are a helpful assistant that executes user tasks. Use your tools 
    to implement tasks and also ensure the user approves all tasks before your execute them.
    """,
    tools=[runtask]
)

