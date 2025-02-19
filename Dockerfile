FROM ruby:3.1.2-slim

LABEL "maintainer"="Patrick Jahns <github@patrickjahns.de>" \
      "repository"="https://github.com/patrickjahns/dependabot-terraform-action" \
      "homepage"="https://github.com/patrickjahns/dependabot-terraform-action" \
      "com.github.actions.name"="dependabot-terraform-action" \
      "com.github.actions.description"="Run dependabot for terraform as github action" \
      "com.github.actions.icon"="check-circle" \
      "com.github.actions.color"="package"

WORKDIR /usr/src/app
ENV DEPENDABOT_NATIVE_HELPERS_PATH="/usr/src/app/native-helpers"

COPY ./src /usr/src/app
COPY ./src/run-action /usr/local/bin/run-action
RUN apt-get update && \
    apt-get install -y libxml2 libxml2-dev libxslt1-dev build-essential  && \
    apt-get install -y curl git wget && \
    gem update --system && \
    export PATH="$PATH:$DEPENDABOT_NATIVE_HELPERS_PATH/terraform/bin" && \
    bundle install   && \
    mkdir -p $DEPENDABOT_NATIVE_HELPERS_PATH/terraform && \
    cp -r $(bundle show dependabot-terraform)/helpers $DEPENDABOT_NATIVE_HELPERS_PATH/terraform/helpers && \
    $DEPENDABOT_NATIVE_HELPERS_PATH/terraform/helpers/build $DEPENDABOT_NATIVE_HELPERS_PATH/terraform && \
   
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/*

CMD ["run-action"]