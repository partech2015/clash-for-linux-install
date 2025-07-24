FROM alpine:latest

WORKDIR /opt/clash

# Install dependencies
RUN apk add --no-cache curl gzip tar bash iproute2 iptables xz

# Copy resources
COPY resources/zip/mihomo-linux-amd64-compatible-v1.19.2.gz /opt/clash/mihomo.gz
COPY resources/zip/subconverter_linux64.tar.gz /opt/clash/subconverter.tar.gz
COPY resources/zip/yacd.tar.xz /opt/clash/yacd.tar.xz
COPY resources/zip/yq_linux_amd64.tar.gz /opt/clash/yq.tar.gz
COPY resources/Country.mmdb /opt/clash/Country.mmdb
COPY resources/mixin.yaml /opt/clash/mixin.yaml
COPY script /opt/clash/script

# Create bin directory
RUN mkdir -p /opt/clash/bin

# Extract binaries
RUN gzip -dc /opt/clash/mihomo.gz > /opt/clash/bin/mihomo && \
    tar -xf /opt/clash/subconverter.tar.gz -C /opt/clash/bin && \
    tar -xf /opt/clash/yq.tar.gz -C /opt/clash/bin && \
    mv /opt/clash/bin/yq_* /opt/clash/bin/yq && \
    tar -xf /opt/clash/yacd.tar.xz -C /opt/clash

# Set permissions
RUN chmod +x /opt/clash/bin/mihomo /opt/clash/bin/subconverter/subconverter /opt/clash/bin/yq

# Create initial config files
RUN touch /opt/clash/config.yaml && \
    touch /opt/clash/url

# Expose ports (default Clash mixed-port and UI port)
EXPOSE 7890 9090

# Copy and set up the entrypoint script
COPY entrypoint.sh /opt/clash/entrypoint.sh
RUN chmod +x /opt/clash/entrypoint.sh

# Set environment variables for scripts
ENV CLASH_BASE_DIR=/opt/clash
ENV BIN_KERNEL=/opt/clash/bin/mihomo
ENV BIN_SUBCONVERTER=/opt/clash/bin/subconverter/subconverter
ENV BIN_YQ=/opt/clash/bin/yq
ENV CLASH_CONFIG_RUNTIME=/opt/clash/runtime.yaml
ENV CLASH_CONFIG_MIXIN=/opt/clash/mixin.yaml
ENV CLASH_CONFIG_RAW=/opt/clash/config.yaml
ENV CLASH_CONFIG_URL=/opt/clash/url

# Set the entrypoint
ENTRYPOINT ["/opt/clash/entrypoint.sh"]