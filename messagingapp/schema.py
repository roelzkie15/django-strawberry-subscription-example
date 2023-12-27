from typing import AsyncGenerator

import strawberry
from channels.layers import get_channel_layer


@strawberry.type
class Message:
    content: str


@strawberry.type
class Query:
    @strawberry.field
    def meta(self, info) -> str:
        return "Meta"


@strawberry.type
class Mutation:
    @strawberry.mutation
    async def send_message(self, info, room: str, message: str) -> Message:
        channel_layer = get_channel_layer()

        await channel_layer.group_send(
            room,
            {
                "type": "room.message",
                "room_id": room,
                "message": message,
            },
        )
        return Message(content=message)


@strawberry.type
class Subscription:
    @strawberry.subscription
    async def on_room_message_update(
        self, info, room: str
    ) -> AsyncGenerator[Message, None] | None:
        ws = info.context["ws"]
        async with ws.listen_to_channel("room.message", groups=[room]) as listener:
            yield None
            async for event in listener:
                yield Message(content=event["message"])


schema = strawberry.Schema(query=Query, mutation=Mutation, subscription=Subscription)
