"""
ASGI config for messagingapp project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/4.2/howto/deployment/asgi/
"""

import os

from django.core.asgi import get_asgi_application
from strawberry.channels import GraphQLProtocolTypeRouter

from messagingapp.schema import schema

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "messagingapp.settings")

django_asgi_app = get_asgi_application()

application = GraphQLProtocolTypeRouter(
    schema, django_application=django_asgi_app, url_pattern="^graphql"
)
