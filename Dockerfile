# Multi-stage Dockerfile to minimize final image size.
# The env base stage:
#   - Environment variables used for linking essential CLI commands.
# The builder stage:
#   - Dependencies installation and building.
# The application build:
#   - Building of application dependencies that can be used
#     as based image of the final builds (local, production).
# The local build:
#   - Installation of dependencies from build stage including poetry
#     which can be used for development.
# The production build:
#   - Only copy the python setup directory essentials to run the server.


ARG PYTHON_VERSION=3.11.2-slim-bullseye
# Use "--no-root --without dev" on production build
ARG POETRY_INSTALL_OPTS="--no-root"
ARG POETRY_VERSION="1.7.1"

ARG GIT_HASH=none


###################################### 
#       Env base stage
######################################
FROM python:${PYTHON_VERSION} as python-env-base

ARG POETRY_INSTALL_OPTS
ARG POETRY_VERSION

ENV APP_HOME="/app" \
    GIT_HASH=${GIT_HASH:-none} \
    PYTHONUNBUFFERED=1 \
    # prevents python creating .pyc files.
    PYTHONDONTWRITEBYTECODE=1 \
    # pip
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    # poetry configs
    POETRY_HOME="/opt/poetry" \
    POETRY_INSTALL_OPTS=${POETRY_INSTALL_OPTS} \
    POETRY_NO_INTERACTION=1 \
    POETRY_VERSION=${POETRY_VERSION} \
    # Dependency setup.
    PYSETUP="/opt/pysetup/" \
    VIRTUAL_ENV="/opt/pysetup/venv"

ENV PATH="$POETRY_HOME/bin:$VIRTUAL_ENV/bin:$PATH"


###################################### 
#       Build stage
######################################
FROM python-env-base as builder-base

# Install system dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
  # essentials for building libs that dependent to python
  build-essential \
  # psycopg2 dependencies
  libpq-dev \
  # to install poetry
  curl

# Download and install poetry based on the POETRY_VERSION and POETRY_HOME envs.
RUN curl -sSL https://install.python-poetry.org | python - --version $POETRY_VERSION

# Create virtual env for poetry.
RUN python -m venv $VIRTUAL_ENV

COPY ./poetry.lock ./pyproject.toml .

# Install dependency in $VIRTUAL_ENV
RUN poetry install $POETRY_INSTALL_OPTS


###################################### 
#       Application base build
######################################
FROM python-env-base as python-base

# Install required system dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
  # essentials for building libs that dependent to python
  build-essential \
  # psycopg2 dependencies
  libpq-dev \
  # cleaning up unused files
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

# # Copy django server script.
COPY ./compose/django/* /
RUN chmod +x /start

# RUN chmod +x /entrypoint
# # Copy celery server script.
# COPY ./compose/celery/* /start-celeryworker
# RUN chmod +x /start-celeryworker

# Copy built-in venv.
COPY --from=builder-base $VIRTUAL_ENV $VIRTUAL_ENV


###################################### 
#       Development build
######################################
FROM python-base as development

# Enable poetry for development purpose.
COPY --from=builder-base $POETRY_HOME $POETRY_HOME

# Set working directory
WORKDIR $APP_HOME

COPY ./poetry.lock ./pyproject.toml .

# Will have a quicker installation of deps from the builder-base $VIRTUAL_ENV
RUN poetry install $POETRY_INSTALL_OPTS

# Copy the rest of the application code
COPY . .


##################################### 
#      Production build
#####################################
FROM python-base as production

# Set working directory
WORKDIR $APP_HOME

COPY . .