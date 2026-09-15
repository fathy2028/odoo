# Odoo 19.0 built from this source checkout.
# Ubuntu 24.04 (Noble) ships Python 3.12, which is what requirements.txt pins against.

########################################
# Stage 1: build the Python virtualenv
########################################
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        python3-dev \
        python3-venv \
        libpq-dev \
        libldap2-dev \
        libsasl2-dev \
        libxml2-dev \
        libxslt1-dev \
        libjpeg-dev \
        zlib1g-dev \
        libffi-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copied alone so the dependency layer stays cached until requirements change
COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r /tmp/requirements.txt

########################################
# Stage 2: runtime image
########################################
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    ODOO_RC=/etc/odoo/runtime.conf

# Runtime libraries, fonts for PDF reports, psql client (backup/restore), nodejs for rtlcss (RTL languages such as Arabic)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        python3 \
        libpq5 \
        libldap2 \
        libsasl2-2 \
        libxml2 \
        libxslt1.1 \
        libjpeg-turbo8 \
        libmagic1 \
        postgresql-client \
        fonts-noto-core \
        fonts-noto-cjk \
        fonts-dejavu-core \
        fonts-inconsolata \
        fonts-font-awesome \
        fonts-roboto-unhinted \
        gsfonts \
        xfonts-75dpi \
        xfonts-base \
        nodejs \
        npm \
    && npm install -g rtlcss \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# wkhtmltopdf with patched Qt (required for correct headers/footers in invoices, quotations, etc.)
RUN ARCH="$(dpkg --print-architecture)" \
    && curl -fsSL -o /tmp/wkhtmltox.deb \
        "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${ARCH}.deb" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/wkhtmltox.deb \
    && rm -rf /tmp/wkhtmltox.deb /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv

# Unprivileged user that owns the filestore
RUN useradd --system --create-home --home-dir /var/lib/odoo --shell /usr/sbin/nologin odoo \
    && mkdir -p /etc/odoo \
    && chown odoo:odoo /etc/odoo

COPY --chown=odoo:odoo . /opt/odoo
COPY --chown=odoo:odoo config/odoo.conf /etc/odoo/odoo.conf
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER odoo
WORKDIR /opt/odoo

VOLUME ["/var/lib/odoo"]
EXPOSE 8069 8072

ENTRYPOINT ["/entrypoint.sh"]
