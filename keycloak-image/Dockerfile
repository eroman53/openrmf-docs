# syntax=docker/dockerfile:1.7
FROM quay.io/keycloak/keycloak:26.7.4 AS builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# OpenRMF Professional configuration items
ENV KC_HTTP_ENABLED=true
ENV KC_HTTP_PORT=8080
ENV KC_HOSTNAME_STRICT=false
ENV PROXY_ADDRESS_FORWARDING=true
ENV KC_HTTP_RELATIVE_PATH=/auth

# Configure a database vendor
ENV KC_DB=postgres

WORKDIR /opt/keycloak
USER 0
# Keycloak 26.7.4 predates fixes for four Critical dependency findings. Pin
# artifacts and hashes from Maven Central. Keycloak's Quarkus index references
# exact distribution paths, so overwrite the old paths with patched JAR content
# rather than renaming files; verify the embedded Maven versions in the scan.
ADD --chown=keycloak:root --chmod=644 --checksum=sha256:d0e4c6ee4779f59f6ab2fb5d388e4f57147c82270164b37945764bb9bda96a44 https://repo.maven.apache.org/maven2/io/netty/netty-handler/4.1.137.Final/netty-handler-4.1.137.Final.jar /tmp/security-libs/netty-handler.jar
ADD --chown=keycloak:root --chmod=644 --checksum=sha256:20af26bf6060bb8005cc2389916812c1e0e998dc48d2ced7131b89461b54cff7 https://repo.maven.apache.org/maven2/org/bouncycastle/bcprov-jdk18on/1.85/bcprov-jdk18on-1.85.jar /tmp/security-libs/bcprov-jdk18on.jar
ADD --chown=keycloak:root --chmod=644 --checksum=sha256:c9f82b2d4e99c4bbdfccf684e52cc06ea06a0b567bfd0d08f9c5a3f417055996 https://repo.maven.apache.org/maven2/org/bouncycastle/bcpkix-jdk18on/1.85/bcpkix-jdk18on-1.85.jar /tmp/security-libs/bcpkix-jdk18on.jar
ADD --chown=keycloak:root --chmod=644 --checksum=sha256:590f55ed5d68529239898a4a5c4f730b6e37f45d1cfa3fbe51f8485abe32c42d https://repo.maven.apache.org/maven2/org/bouncycastle/bcutil-jdk18on/1.85/bcutil-jdk18on-1.85.jar /tmp/security-libs/bcutil-jdk18on.jar
ADD --chown=keycloak:root --chmod=644 --checksum=sha256:0fac87dddd78f1223139e8ef88e819c7f483c0a3835cdf5982ad5e4576d1d896 https://repo.maven.apache.org/maven2/org/freemarker/freemarker/2.3.35/freemarker-2.3.35.jar /tmp/security-libs/freemarker.jar
RUN cp /tmp/security-libs/netty-handler.jar /opt/keycloak/lib/lib/main/io.netty.netty-handler-4.1.136.Final.jar \
 && cp /tmp/security-libs/bcprov-jdk18on.jar /opt/keycloak/lib/lib/main/org.bouncycastle.bcprov-jdk18on-1.84.jar \
 && cp /tmp/security-libs/bcpkix-jdk18on.jar /opt/keycloak/lib/lib/main/org.bouncycastle.bcpkix-jdk18on-1.84.jar \
 && cp /tmp/security-libs/bcutil-jdk18on.jar /opt/keycloak/lib/lib/main/org.bouncycastle.bcutil-jdk18on-1.84.jar \
 && cp /tmp/security-libs/freemarker.jar /opt/keycloak/lib/lib/main/org.freemarker.freemarker-2.3.32.jar \
 && cp /tmp/security-libs/bcprov-jdk18on.jar /opt/keycloak/bin/client/lib/bcprov-jdk18on-1.84.jar \
 && rm -rf /tmp/security-libs
USER 1000
# Add the theme and welcome page setup
COPY ./themes/openrmf/ /opt/keycloak/themes/openrmf/
# STOOGE fork branding (login/account/admin/welcome); inherits the above
COPY ./themes/stooge/ /opt/keycloak/themes/stooge/
RUN /opt/keycloak/bin/kc.sh build --spi-x509cert-lookup-provider=nginx

FROM quay.io/keycloak/keycloak:26.7.4
COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
