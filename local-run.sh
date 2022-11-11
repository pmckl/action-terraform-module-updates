docker build -t action-terraform-module-updates .
docker run -e INPUT_TARGET_BRANCH="master" \
            -e INPUT_GITHUB_DEPENDENCY_TOKEN="" \
            -e INPUT_TOKEN="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" \
            -e GITHUB_REPOSITORY="pmckl/action-terraform-module-updates" \
            -e INPUT_DIRECTORY="/test/terraform" \
            --rm action-terraform-module-updates:latest