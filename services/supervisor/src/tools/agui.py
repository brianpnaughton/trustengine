from ag_ui.core import Tool

networkTopology=Tool(
    name="network_topology",
    description="Useful to show a network topology.",
    parameters={
        "type": "object",
        "properties": {
            "nodes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "label": {"type": "string"}
                    },
                    "required": ["id", "label"]
                }
            },
            "edges": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "source": {"type": "string"},
                        "target": {"type": "string"}
                    },
                    "required": ["source", "target"]
                }
            }
        },
        "required": ["nodes", "edges"]
    }
)

confirmChange=Tool(
    name="confirm_change",
    description="Confirm the changes made to the network topology.",
    parameters={
        "type": "object",
        "properties": {
            "steps": {
                "type": "array",
                "items": {
                    "type": "string"
                }
            }
        },
        "required": ["steps"]
    }
)

taskApproval=Tool(
    name="task_approval",
    description="Request user approval for a list of tasks before execution. Returns a structured JSON response that will be rendered as an interactive approval widget in the chat interface.",
    parameters={
        "type": "object",
        "properties": {
            "message": {
                "type": "string",
                "description": "Context message explaining why approval is needed"
            },
            "tasks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": "Unique identifier for the task"
                        },
                        "title": {
                            "type": "string",
                            "description": "Brief title of the task"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description of what the task will do"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"],
                            "description": "Priority level of the task"
                        },
                        "estimated_duration": {
                            "type": "string",
                            "description": "Estimated time to complete the task"
                        },
                        "risks": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Potential risks or side effects"
                        }
                    },
                    "required": ["id", "title", "description", "priority"]
                }
            }
        },
        "required": ["message", "tasks"]
    }
)
