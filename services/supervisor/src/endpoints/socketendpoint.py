import logging
import json
import uuid
from typing import Dict, Any
from ag_ui.core import (
    TextMessageStartEvent,
    TextMessageContentEvent, 
    TextMessageEndEvent,
    CustomEvent,
    RunAgentInput,
    UserMessage
)

from middleware.adk import ADKAgent
from tools.agui import taskApproval

logger = logging.getLogger(__name__)

class SocketEndpoint:
    """
    Socket.IO endpoint for handling client connections.    
    """

    _instance = None

    def __init__(self, sio, adk_agent: ADKAgent = None):
        logger.info("SocketEndpoint init")

        SocketEndpoint._instance = self

        self.sio = sio
        self.adk_agent = adk_agent
        self.active_sessions: Dict[str, Dict[str, Any]] = {}  # sid -> session info
        self.callbacks()

    async def emit_agui_event(self, event, sid):
        """Helper method to emit ag-ui events with proper serialization"""
        try:
            # Use mode='json' and by_alias=True for proper camelCase field names
            event_data = event.model_dump(mode='json', by_alias=True)
            logger.info("Emitting ag-ui event: %s", event_data)
            await self.sio.emit('agui_event', event_data, room=sid)
        except Exception as e:
            logger.error("Failed to emit ag-ui event: %s", e)
            raise

    def callbacks(self):
        @self.sio.event
        async def connect(sid, environ, auth):
            logger.info("connected client %s", sid)

        @self.sio.event
        async def agui_event(sid, data):
            logger.info("agui event from %s: %s", sid, data)
            
            # Handle custom events from Flutter client
            if isinstance(data, dict) and data.get('name') == 'user_message':
                await self._handle_user_message(sid, data)
            else:
                logger.warning("Received unhandled event: %s", data)

        @self.sio.event
        async def disconnect(sid):
            logger.info("disconnected from %s", sid)
            # Clean up session data
            if sid in self.active_sessions:
                del self.active_sessions[sid]

    async def _handle_user_message(self, sid: str, data: Dict[str, Any]):
        """Handle user message from Flutter client and process through ADK agent"""
        try:
            if not self.adk_agent:
                logger.error("No ADK agent configured")
                await self._send_error(sid, "No agent configured")
                return

            user_message_data = data.get('value', {})
            message_id = user_message_data.get('id', str(uuid.uuid4()))
            content = user_message_data.get('content', '')
            
            logger.info(f"Processing user message from {sid}: {content}")
            
            # Get or create session info
            session_info = self._get_or_create_session(sid)
            thread_id = session_info['thread_id']
            
            # Create UserMessage for the conversation
            user_message = UserMessage(
                id=str(uuid.uuid4()),
                role="user",
                content=content
            )
            
            # Add to session history
            session_info['messages'].append(user_message)
            
            # Create RunAgentInput
            run_input = RunAgentInput(
                thread_id=thread_id,
                run_id=str(uuid.uuid4()),
                state=session_info.get('state', {}),
                messages=session_info['messages'],
                tools=[taskApproval],  # Add tools if needed
                context=[],  # Add context if needed
                forwarded_props={}
            )
            
            # Run the ADK agent and stream events back to client
            async for event in self.adk_agent.run(run_input):
                await self.emit_agui_event(event, sid)
                
        except Exception as e:
            logger.error(f"Error handling user message: {e}", exc_info=True)
            await self._send_error(sid, f"Error processing message: {str(e)}")

    def _get_or_create_session(self, sid: str) -> Dict[str, Any]:
        """Get or create session info for a Socket.IO session"""
        if sid not in self.active_sessions:
            thread_id = str(uuid.uuid4())
            self.active_sessions[sid] = {
                'thread_id': thread_id,
                'messages': [],
                'state': {},
                'created_at': None  # Could add timestamp if needed
            }
            logger.info(f"Created new session for {sid}: {thread_id}")
        
        return self.active_sessions[sid]

    async def _send_error(self, sid: str, message: str):
        """Send error event to client"""
        error_event = CustomEvent(
            name="error",
            value={"message": message}
        )
        await self.emit_agui_event(error_event, sid)
