#!/bin/bash

set -e

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# install core and development Python dependencies into the currently activated venv
function install {
    python -m pip install --upgrade pip
    python -m pip install cookiecutter pytest pre-commit
}

function generate-project {
    cookiecutter ./ \
        --output-dir "$THIS_DIR/sample"
    cd "$THIS_DIR/sample"
    cd $(ls)
    git init
    git add --all
    git branch -M main
    git commit -m "feat: generated sample project with python-template-cookiecutter-v1"
}

# run linting, formatting, and other static code quality tools
function lint {
    pre-commit run --all-files
}

# same as `lint` but with any special considerations for CI
function lint:ci {
    # We skip no-commit-to-branch since that blocks commits to `main`.
    # All merged PRs are commits to `main` so this must be disabled.
    SKIP=no-commit-to-branch pre-commit run --all-files
}

# execute tests that are not marked as `slow`
function test:quick {
    run-tests -m "not slow" ${@:-"$THIS_DIR/tests/"}
}

function run-tests {
    PYTEST_EXIT_STATUS=0
    python -m pytest ${@:-"$THIS_DIR/tests_repo/"}
}

function clean {
    rm -rf dist build coverage.xml test-reports sample/
    find . \
      -type d \
      \( \
        -name "*cache*" \
        -o -name "*.dist-info" \
        -o -name "*.egg-info" \
        -o -name "*htmlcov" \
      \) \
      -not -path "*env/*" \
      -exec rm -r {} + || true

    find . \
      -type f \
      -name "*.pyc" \
      -not -path "*env/*" \
      -exec rm {} +
}

# export the contents of .env as environment variables
function try-load-dotenv {
    if [ ! -f "$THIS_DIR/.env" ]; then
        echo "no .env file found"
        return 1
    fi

    while read -r line; do
        export "$line"
    done < <(grep -v '^#' "$THIS_DIR/.env" | grep -v '^$')
}

# args:
#   REPO_NAME - name of the repository
#   GITHUB_USERNAME - name of my github user
#   IS_PUBLIC_REPO - if true, the repository will be public, otherwise private
function create-repo-if-not-exist {
    local IS_PUBLIC_REPO=${IS_PUBLIC_REPO:-true}
    # check if the repository already exists, if it does, return
    echo "Checking to see if $GITHUB_USERNAME/$REPO_NAME exists..."
    if gh repo view "$GITHUB_USERNAME/$REPO_NAME" > /dev/null 2>&1; then
        echo "Repository exists, exiting..."
        return 0
    fi

    echo "Repository does not exist, creating..."
    # otherwise create the repository
    # if [[ "$IS_PUBLIC_REPO" == "false" ]]; then
    #     PUBLIC_OR_PRIVATE="private"
    # else
    #     PUBLIC_OR_PRIVATE="public"
    # fi
    echo "creating repository..."
    gh repo create "$GITHUB_USERNAME/$REPO_NAME" --"public"

    push-initial-readme-to-repo
}

# args:
#   REPO_NAME - name of the repository
#   GITHUB_USERNAME - name of the github user
function push-initial-readme-to-repo {
    gh repo clone "$GITHUB_USERNAME/$REPO_NAME"
    cd "$REPO_NAME"
    echo "# $REPO_NAME" > "README.md"
    git branch -M main || true
    git add --all
    git commit -m "feat: created repositry"
    echo "repo_name: ${REPO_NAME}"
    git remote set-url origin https://${GH_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git
    git push origin main
}

# args:
#   TEST_PYPI_TOKEN, PROD_PYPI_TOKEN - auth token for test and prod pypi
#   REPO_NAME - name of the repository
#   GITHUB_USERNAME - name of the github user
function configure-repo {
    # configure github action secrets
    gh secret set TEST_PYPI_TOKEN \
        --body "$TEST_PYPI_TOKEN" \
        --repo "$GITHUB_USERNAME/$REPO_NAME"
    gh secret set PROD_PYPI_TOKEN \
        --body "$PROD_PYPI_TOKEN" \
        --repo "$GITHUB_USERNAME/$REPO_NAME"

    # protect main branch, enforcing passing build on feature branch before merge
    BRANCH_NAME="main"
    gh api -X PUT "repos/$GITHUB_USERNAME/$REPO_NAME/branches/$BRANCH_NAME/protection" \
        -H "Accept: application/vnd.github+json" \
        -F "required_status_checks[strict]=true" \
        -F "required_status_checks[checks][][context]=check-version-txt" \
        -F "required_status_checks[checks][][context]=lint-format-and-static-code-checks" \
        -F "required_status_checks[checks][][context]=build-wheel-and-sdist" \
        -F "required_status_checks[checks][][context]=execute-tests" \
        -F "required_pull_request_reviews[required_approving_review_count]=0" \
        -F "enforce_admins=null" \
        -F "restrictions=null" > /dev/null
}
# args:
#   REPO_NAME - name of the repository
#   GITHUB_USERNAME - name of the github user
#   $PACKAGE_IMPORT_NAME - e.g. if "example_pkg" then "import example_pkg"
function open-pr-with-generated-project {
    rm -rf "$REPO_NAME" ./outdir

    install

    # clone the repository
    gh repo clone "$GITHUB_USERNAME/$REPO_NAME"

    # delete reposity contents
    mv "$REPO_NAME/.git" "./$REPO_NAME.git.bak"
    rm -rf "$REPO_NAME"
    mkdir "$REPO_NAME"
    mv "./$REPO_NAME.git.bak" "$REPO_NAME/.git"

    # generate the project into the repository folder
    OUTDIR="./outdir/"
    CONFIG_FILE_PATH="./$REPO_NAME.ymal"
    cat <<EOF> "$CONFIG_FILE_PATH"
default_context:
    repo_name: $REPO_NAME
    package_import_name: $PACKAGE_IMPORT_NAME
EOF

    cookiecutter ./ \
        --output-dir "$OUTDIR" \
        --no-input \
        --config-file "$CONFIG_FILE_PATH"
    rm $CONFIG_FILE_PATH

    # stage the generated files on a new feature branch
    mv "$REPO_NAME/.git" "$OUTDIR/$REPO_NAME/"
    cd "$OUTDIR/$REPO_NAME"

    UUID=$(uuidgen)
    UNIQUE_BRANCH_NAME=feat/populating-from-template-${UUID:0:6}

    git checkout -b "$UNIQUE_BRANCH_NAME"
    git add --all

    # apply formatting and linting autofixes to the generated files
    lint:ci || true

    # restage the files modified by pre-commit
    git add --all

    # commit the changes and push them to remote feature branch
    git commit -m "feat: populated from python-template-cookiecutter-v1"
    git remote set-url origin https://${GH_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git
    git push origin "$UNIQUE_BRANCH_NAME"

    # open a PR from the feature branch into main
    gh pr create \
        --title "feat: populated from \`python-template-cookiecutter-v1\` template" \
        --body "This PR was generated by \`python-template-cookiecutter-v1\`" \
        --base main \
        --head "$UNIQUE_BRANCH_NAME" \
        --repo "$GITHUB_USERNAME/$REPO_NAME"
}

# args:
#   REPO_NAME - name of the repository
#   GITHUB_USERNAME - name of the github user
function create-sample-repo {
    git add .github/
    git commit -m "fix: debugging the create-or-update-repo.yaml"
    git remote set-url origin https://${GH_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git
    git push origin main

    gh repo set-default "$GITHUB_USERNAME/$REPO_NAME"

    gh workflow run .github/workflows/create-or-update-repo.yaml \
        -f repo_name=autogenerated-repo-6 \
        -f package_import_name=autogenerated_repo_6 \
        -f is_public_repo=false \
        --ref main
}

TIMEFORMAT="Task completed in %3lR"
time ${@:-help}
