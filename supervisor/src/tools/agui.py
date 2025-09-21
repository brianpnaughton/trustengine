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
