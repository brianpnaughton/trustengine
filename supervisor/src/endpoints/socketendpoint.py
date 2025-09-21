import logging
import json
from ag_ui.core import (
    TextMessageStartEvent,
    TextMessageContentEvent, 
    TextMessageEndEvent,
    CustomEvent
)

logger = logging.getLogger(__name__)

class SocketEndpoint:
    """
    Socket.IO endpoint for handling client connections.    
    """

    _instance = None

    def __init__(self, sio):
        logger.info("SocketEndpoint init")

        SocketEndpoint._instance = self

        self.sio = sio
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
                user_message_data = data.get('value', {})
                message_id = user_message_data.get('id', 'unknown')
                content = user_message_data.get('content', '')
                
                logger.info("Processing user message: %s", content)
                
                # Create and emit ag-ui SDK events
                start_event = TextMessageStartEvent(
                    message_id=message_id,
                    role="assistant"
                )
                await self.emit_agui_event(start_event, sid)

                # Send TEXT_MESSAGE_CONTENT event with echo response
                content_event = TextMessageContentEvent(
                    message_id=message_id,
                    delta=f"Echo: {content}"
                )
                await self.emit_agui_event(content_event, sid)

                # Send TEXT_MESSAGE_END event
                end_event = TextMessageEndEvent(
                    message_id=message_id
                )
                await self.emit_agui_event(end_event, sid)
            else:
                logger.warning("Received unhandled event: %s", data)

        @self.sio.event
        async def disconnect(sid):
            logger.info("disconnected from %s", sid)
