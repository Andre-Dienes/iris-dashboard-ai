# IRIS Data Copilot - data + AI tier (InterSystems IRIS AI Hub)
#
# The %AI.* classes only exist in the AI Hub Early Access builds:
#   https://evaluation.intersystems.com/Eval/early-access/AIHub
# Load the image with `docker load -i <file>.tar.gz` and set IRIS_IMAGE in .env to the tag it prints.
# Community AI Hub images need no license key. Non-Community images: put the .key file (e.g. iris-container-x64.key) in ./keys
# (mounted at /external/keys and passed with -k at startup).
ARG IMAGE=docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.3.0AI.136.0
FROM $IMAGE

# 1 = create the demo dataset (US retail chain); 0 = empty install for your own tables
ARG COPILOT_DEMO=1
ENV COPILOT_DEMO=${COPILOT_DEMO}

USER root
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris/iris.script /home/irisowner/copilot/iris.script
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris/entrypoint.sh /copilot-entrypoint.sh
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} src /src
RUN sed -i 's/\r$//' /copilot-entrypoint.sh /home/irisowner/copilot/iris.script && chmod +x /copilot-entrypoint.sh

USER ${ISC_PACKAGE_MGRUSER}
WORKDIR /home/irisowner
RUN iris start IRIS quietly \
 && iris session IRIS < /home/irisowner/copilot/iris.script \
 && iris stop IRIS quietly

EXPOSE 1972 52773
ENTRYPOINT ["/tini", "--", "/copilot-entrypoint.sh"]
