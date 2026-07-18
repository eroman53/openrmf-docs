# UBI runtime base for the STOOGE fork's .NET services (RHEL 8 derivative,
# per accreditation preference; swap the FROM to ubi10/ubi-minimal for a
# RHEL 10 base). Mirrors the upstream Alpine openrmf-base: current packages,
# .NET self-contained runtime deps, and the DoD CA certificate bundle.
# Build with the ca-root folder as context:
#   docker build -f base-container-image-ubi/Dockerfile -t eroman53/openrmf-base-ubi:8.10 base-container-image
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.10
RUN microdnf update -y \
 && microdnf install -y ca-certificates libicu libstdc++ krb5-libs openssl-libs zlib shadow-utils \
 && microdnf clean all
# DoD CA root/intermediate bundle into the RHEL trust store
COPY ./ca-root/ /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust
# shrink the attack surface: self-contained .NET services never call system
# curl or glib; these base packages carry vendor-unfixed HIGH CVEs on RHEL 8
# (rpm -e last, since removing libcurl breaks microdnf itself)
RUN rpm -e --nodeps curl libcurl glib2 2>/dev/null || true

LABEL org.opencontainers.image.source=https://github.com/eroman53/openrmf-docs
LABEL org.opencontainers.image.description="UBI8-minimal runtime base with DoD CA certificates for STOOGE OpenRMF fork services"
LABEL org.opencontainers.image.title="STOOGE OpenRMF Fork UBI Base"
