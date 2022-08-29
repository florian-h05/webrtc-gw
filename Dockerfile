FROM debian:11.4-slim

ARG BUILD_DATE
ARG VCS_REF

# Basic build-time metadata as defined at http://label-schema.org
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.license="MIT" \
    org.label-schema.name="WebRTC SIP Gateway" \
    org.label-schema.version=$VERSION \
    org.label-schema.description="A WebRTC-SIP gateway for Fritzbox based on Kamailio and rtpengine" \
    org.label-schema.url="https://github.com/florian-h05/webrtc-sip-gw" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/florian-h05/webrtc-sip-gw.git" \
    maintainer="Florian Hotze <florianh_dev@icloud.com>"

# Install requirements
RUN \
 apt-get update \
 && apt-get install -y --no-install-recommends wget curl gnupg2 ca-certificates iproute2 supervisor nano

# Add Kamailio source
RUN \
   curl -sL https://deb.kamailio.org/kamailiodebkey.gpg | gpg --dearmor | tee /usr/share/keyrings/kamailiodebkey.gpg >/dev/null \
    && echo 'deb [signed-by=/usr/share/keyrings/kamailiodebkey.gpg] https://deb.kamailio.org/kamailio56 bullseye main' > /etc/apt/sources.list.d/kamailio.list \
    && echo 'deb-src [signed-by=/usr/share/keyrings/kamailiodebkey.gpg] https://deb.kamailio.org/kamailio56 bullseye main' > /etc/apt/sources.list.d/kamailio.list
# Add rtpengine source
RUN \
   wget https://dfx.at/rtpengine/latest/pool/main/r/rtpengine-dfx-repo-keyring/rtpengine-dfx-repo-keyring_1.0_all.deb \
    && dpkg -i rtpengine-dfx-repo-keyring_1.0_all.deb \
    && echo 'deb [signed-by=/usr/share/keyrings/dfx.at-rtpengine-archive-keyring.gpg] https://dfx.at/rtpengine/10.5 bullseye main' > /etc/apt/sources.list.d/rtpengine.list
# Install Kamailio and rtpengine
RUN \
   apt-get update \
    && apt-get install -y --no-install-recommends rtpengine \
    && apt-get install -y --no-install-recommends kamailio kamailio-websocket-modules kamailio-tls-modules

VOLUME ["/tmp"]

# Expose UDP ports for WebRTC communication
EXPOSE 23400-23500/udp
# Expose unsecured and secured WebSocket port
EXPOSE 8090 4443

# Set healthcheck
HEALTHCHECK --interval=5m --timeout=5s --retries=3 CMD curl --include --no-buffer --header "Connection: Upgrade" --header "Upgrade: websocket" http://localhost:8090 || exit 1

COPY ./entrypoint.sh /entrypoint.sh
# Copy configuration
COPY ./config/supervisor-rtpengine.conf /etc/supervisor/conf.d/rtpengine.conf
COPY ./config/supervisor-kamailio.conf /etc/supervisor/conf.d/kamailio.conf
COPY ./config/rtpengine.conf /etc/rtpengine/rtpengine.conf
COPY ./config/kamailio.cfg /etc/kamailio/kamailio.cfg
COPY ./config/tls.cfg /etc/kamailio/tls.cfg

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf -u root"]
