# Adapted from the original Dockerfile
# Changes:
# Use RedHat UBI 
# Remove Infracost and HCLEdit hooks
FROM registry.access.redhat.com/ubi9/python-39 as builder
USER root

WORKDIR /bin_dir

# Upgrade pip for be able get latest Checkov
RUN python3 -m pip install --no-cache-dir --upgrade pip

ARG PRE_COMMIT_VERSION=${PRE_COMMIT_VERSION:-latest}
ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-latest}

# Install pre-commit
RUN [ ${PRE_COMMIT_VERSION} = "latest" ] && pip3 install --no-cache-dir pre-commit \
    || pip3 install --no-cache-dir pre-commit==${PRE_COMMIT_VERSION}

# Install terraform because pre-commit needs it
RUN if [ "${TERRAFORM_VERSION}" = "latest" ]; then \
        TERRAFORM_VERSION="$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep tag_name | grep -o -E -m 1 "[0-9.]+")" \
    ; fi && \
    curl -L "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" > terraform.zip && \
    unzip terraform.zip terraform && rm terraform.zip

#
# Install tools
#
ARG CHECKOV_VERSION=${CHECKOV_VERSION:-false}
ARG TERRAFORM_DOCS_VERSION=${TERRAFORM_DOCS_VERSION:-false}
ARG TERRASCAN_VERSION=${TERRASCAN_VERSION:-false}
ARG TFLINT_VERSION=${TFLINT_VERSION:-false}
ARG TFSEC_VERSION=${TFSEC_VERSION:-false}
ARG TFUPDATE_VERSION=${TFUPDATE_VERSION:-false}

# Tricky thing to install all tools by set only one arg.
# In RUN command below used `. /.env` <- this is sourcing vars that
# specified in step below
ARG INSTALL_ALL=${INSTALL_ALL:-false}
RUN if [ "$INSTALL_ALL" != "false" ]; then \
        echo "export CHECKOV_VERSION=latest" >> /.env && \
        echo "export TERRAFORM_DOCS_VERSION=latest" >> /.env && \
        echo "export TERRASCAN_VERSION=latest" >> /.env && \
        echo "export TFLINT_VERSION=latest" >> /.env && \
        echo "export TFSEC_VERSION=latest" >> /.env && \
        echo "export TFUPDATE_VERSION=latest" >> /.env  \
    ; else \
        touch /.env \
    ; fi

# Checkov
RUN . /.env && \
    if [ "$CHECKOV_VERSION" != "false" ]; then \
    ( \
        [ "$CHECKOV_VERSION" = "latest" ] && pip3 install --no-cache-dir checkov \
        || pip3 install --no-cache-dir checkov==${CHECKOV_VERSION}; \
    ) \
    ; fi

# Terraform docs
RUN . /.env && \
    if [ "$TERRAFORM_DOCS_VERSION" != "false" ]; then \
    ( \
        TERRAFORM_DOCS_RELEASES="https://api.github.com/repos/terraform-docs/terraform-docs/releases" && \
        [ "$TERRAFORM_DOCS_VERSION" = "latest" ] && curl -L "$(curl -s ${TERRAFORM_DOCS_RELEASES}/latest | grep -o -E -m 1 "https://.+?-linux-amd64.tar.gz")" > terraform-docs.tgz \
        || curl -L "$(curl -s ${TERRAFORM_DOCS_RELEASES} | grep -o -E "https://.+?v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz")" > terraform-docs.tgz \
    ) && tar -xzf terraform-docs.tgz terraform-docs && rm terraform-docs.tgz && chmod +x terraform-docs \
    ; fi

# Terrascan
RUN . /.env && \
    if [ "$TERRASCAN_VERSION" != "false" ]; then \
    ( \
        TERRASCAN_RELEASES="https://api.github.com/repos/tenable/terrascan/releases" && \
        [ "$TERRASCAN_VERSION" = "latest" ] && curl -L "$(curl -s ${TERRASCAN_RELEASES}/latest | grep -o -E -m 1 "https://.+?_Linux_x86_64.tar.gz")" > terrascan.tar.gz \
        || curl -L "$(curl -s ${TERRASCAN_RELEASES} | grep -o -E "https://.+?${TERRASCAN_VERSION}_Linux_x86_64.tar.gz")" > terrascan.tar.gz \
    ) && tar -xzf terrascan.tar.gz terrascan && rm terrascan.tar.gz && \
    ./terrascan init \
    ; fi

# TFLint
RUN . /.env && \
    if [ "$TFLINT_VERSION" != "false" ]; then \
    ( \
        TFLINT_RELEASES="https://api.github.com/repos/terraform-linters/tflint/releases" && \
        [ "$TFLINT_VERSION" = "latest" ] && curl -L "$(curl -s ${TFLINT_RELEASES}/latest | grep -o -E -m 1 "https://.+?_linux_amd64.zip")" > tflint.zip \
        || curl -L "$(curl -s ${TFLINT_RELEASES} | grep -o -E "https://.+?/v${TFLINT_VERSION}/tflint_linux_amd64.zip")" > tflint.zip \
    ) && unzip tflint.zip && rm tflint.zip \
    ; fi

# TFSec
RUN . /.env && \
    if [ "$TFSEC_VERSION" != "false" ]; then \
    ( \
        TFSEC_RELEASES="https://api.github.com/repos/aquasecurity/tfsec/releases" && \
        [ "$TFSEC_VERSION" = "latest" ] && curl -L "$(curl -s ${TFSEC_RELEASES}/latest | grep -o -E -m 1 "https://.+?/tfsec-linux-amd64")" > tfsec \
        || curl -L "$(curl -s ${TFSEC_RELEASES} | grep -o -E -m 1 "https://.+?v${TFSEC_VERSION}/tfsec-linux-amd64")" > tfsec \
    ) && chmod +x tfsec \
    ; fi

# TFUpdate
RUN . /.env && \
    if [ "$TFUPDATE_VERSION" != "false" ]; then \
    ( \
        TFUPDATE_RELEASES="https://api.github.com/repos/minamijoyo/tfupdate/releases" && \
        [ "$TFUPDATE_VERSION" = "latest" ] && curl -L "$(curl -s ${TFUPDATE_RELEASES}/latest | grep -o -E -m 1 "https://.+?_linux_amd64.tar.gz")" > tfupdate.tgz \
        || curl -L "$(curl -s ${TFUPDATE_RELEASES} | grep -o -E -m 1 "https://.+?${TFUPDATE_VERSION}_linux_amd64.tar.gz")" > tfupdate.tgz \
    ) && tar -xzf tfupdate.tgz tfupdate && rm tfupdate.tgz \
    ; fi

# Checking binaries versions and write it to debug file
RUN . /.env && \
    F=tools_versions_info && \
    pre-commit --version >> $F && \
    ./terraform --version | head -n 1 >> $F && \
    (if [ "$CHECKOV_VERSION"        != "false" ]; then echo "checkov $(checkov --version)" >> $F;     else echo "checkov SKIPPED" >> $F        ; fi) && \
    (if [ "$TERRAFORM_DOCS_VERSION" != "false" ]; then ./terraform-docs --version >> $F;              else echo "terraform-docs SKIPPED" >> $F ; fi) && \
    (if [ "$TERRASCAN_VERSION"      != "false" ]; then echo "terrascan $(./terrascan version)" >> $F; else echo "terrascan SKIPPED" >> $F      ; fi) && \
    (if [ "$TFLINT_VERSION"         != "false" ]; then ./tflint --version >> $F;                      else echo "tflint SKIPPED" >> $F         ; fi) && \
    (if [ "$TFSEC_VERSION"          != "false" ]; then echo "tfsec $(./tfsec --version)" >> $F;       else echo "tfsec SKIPPED" >> $F          ; fi) && \
    (if [ "$TFUPDATE_VERSION"       != "false" ]; then echo "tfupdate $(./tfupdate --version)" >> $F; else echo "tfupdate SKIPPED" >> $F       ; fi) && \
    echo -e "\n\n" && cat $F && echo -e "\n\n"

FROM registry.access.redhat.com/ubi9/python-39

# Copy tools
COPY --from=builder \
    # Needed for all hooks
    /opt/app-root/bin/pre-commit \
    # Hooks and terraform binaries
    /bin_dir/ \
    /opt/app-root/bin/checkov* \
        /opt/app-root/bin/
# Copy pre-commit packages
COPY --from=builder /opt/app-root/lib/python3.9/site-packages/ /opt/app-root/lib/python3.9/site-packages/
# Copy terrascan policies

COPY --from=builder /root/ /root/

    # Fix git runtime fatal:
    # unsafe repository ('/lint' is owned by someone else)
RUN git config --global --add safe.directory /lint

# Setup talisman - https://github.com/thoughtworks/talisman#readme
COPY --chmod=777 tools/install-talisman.bash install-talisman.sh 
RUN ./install-talisman.sh

# LOOGW:
# chmod is needed if we are performing the build from Windows.
# Need to ensure the eol is set to LF (not CRLF) or else the script will fail to execute
COPY --chmod=777 tools/entrypoint2.sh /entrypoint.sh 

ENV PRE_COMMIT_COLOR=${PRE_COMMIT_COLOR:-always}

ENTRYPOINT [ "/entrypoint.sh" ]