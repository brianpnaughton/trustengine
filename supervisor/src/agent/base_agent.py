from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm

# Create a basic agent - you can customize this based on your needs
# This is a simple example agent that can respond to messages
basic_agent = Agent(
    name="ChatAgent",
    model=LiteLlm(model="ollama_chat/gemma3:1b"),
    instruction="You are a helpful assistant that responds to user messages. Be concise and helpful.",
)

