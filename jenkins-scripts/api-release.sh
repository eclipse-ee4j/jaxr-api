#!/bin/bash -ex

TOOLS_PREFIX='/opt/tools'
JAVA_PREFIX="${TOOLS_PREFIX}/java/oracle"
MVN_HOME="${TOOLS_PREFIX}/apache-maven/latest"
JAVA_HOME="${JAVA_PREFIX}/jdk-8/latest"
PATH="${MVN_HOME}/bin:${JAVA_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Maven plugins
VERSIONS_PLUGIN='org.codehaus.mojo:versions-maven-plugin:2.7'
HELP_PLUGIN='org.apache.maven.plugins:maven-help-plugin:3.1.0'

# Top level pom.xml is  in root directory
# Check whether top level pom.xml contains SNAPSHOT version
if ! grep '<version>' pom.xml | grep 'SNAPSHOT' ; then
  echo '-[ Missing SNAPSHOT version in POM! ]-------------------------------------------'
  exit 1
fi

# Compute release versions
SNAPSHOT_VERSION=`mvn -B ${HELP_PLUGIN}:evaluate -Dexpression=project.version 2> /dev/null | grep -E '^[0-9]+(\.[0-9]+)+-SNAPSHOT$'`

if [ -z "${RELEASE_VERSION}" ]; then
  if [ -z ${SNAPSHOT_VERSION} ]; then
    echo '-[ Missing required snapshot version number! ]----------------------------------'
  fi
  RELEASE_VERSION=`echo ${SNAPSHOT_VERSION} | sed -e 's/-SNAPSHOT//'`
fi

# Bash specific code
if [ -z "${NEXT_VERSION}" ]; then
  NEXT_VERSION=`echo ${RELEASE_VERSION} | sed -e 's/\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`
  set -f
  NEXT_COMPONENTS=(${RELEASE_VERSION//\./ })
  LAST_INDEX=$((${#NEXT_COMPONENTS[@]} - 1))
  NEXT_COMPONENTS[${LAST_INDEX}]=$((${NEXT_COMPONENTS[${LAST_INDEX}]} + 1))
  NEXT_VERSION=`echo ${NEXT_COMPONENTS[@]} | tr ' ' '.'`'-SNAPSHOT'
fi

RELEASE_TAG="${RELEASE_VERSION}"
RELEASE_BRANCH="${RELEASE_VERSION}"-BRANCH

echo "Current version: ${SNAPSHOT_VERSION}"
echo "Release version: ${RELEASE_VERSION}"
echo "Next version:    ${NEXT_VERSION}"
echo "Release tag:     ${RELEASE_TAG}"

if [ -z "${SNAPSHOT_VERSION}" -o -z "${RELEASE_VERSION}" -o -z "${NEXT_VERSION}" ]; then
  echo '-[ Missing required version numbers! ]------------------------------------------'
  exit 1
fi

if [ ${DRY_RUN} = 'true' ]; then
  echo '-[ Dry run turned on ]----------------------------------------------------------'
  MVN_DEPLOY_ARGS=''
  echo '-[ Skipping GitHub branch and tag checks ]--------------------------------------'
else
  MVN_DEPLOY_ARGS='deploy:deploy'
  GIT_ORIGIN=`git remote`
  echo '-[ Prepare branch ]-------------------------------------------------------------'
  if [[ -n `git branch -r | grep "${GIT_ORIGIN}/${RELEASE_BRANCH}"` ]]; then
    if [ "${OVERWRITE}" = 'true' ]; then
      echo "${GIT_ORIGIN}/${RELEASE_BRANCH} branch already exists, deleting"
      git push --delete origin "${RELEASE_BRANCH}" && true
    else
      echo "Error: ${GIT_ORIGIN}/${RELEASE_BRANCH} branch already exists"
      exit 1
    fi
  fi
  echo '-[ Release tag cleanup ]--------------------------------------------------------'
  if [[ -n `git ls-remote --tags ${GIT_ORIGIN} | grep "${RELEASE_TAG}"` ]]; then
    if [ "${OVERWRITE}" = 'true' ]; then
      echo "${RELEASE_TAG} tag already exists, deleting"
      git push --delete origin "${RELEASE_TAG}" && true
    else
      echo "Error: ${RELEASE_TAG} tag already exists"
      exit 1
    fi
  fi
fi

# Always delete local branch if exists
git branch --delete "${RELEASE_BRANCH}" && true
git checkout -b ${RELEASE_BRANCH}
# Always delete local tag if exists
git tag --delete "${RELEASE_TAG}" && true

# Setup jakartaee-stable-bot account information
git config --global user.email "jakartaee-stable-bot@eclipse.org"
git config --global user.name "Eclipse jakartaee-stable Bot"
# Workaround: GPG initialization
gpg --batch --import ${KEYRING}
for fpr in $(gpg --list-keys --with-colons  | awk -F: '/fpr:/ {print $10}' | sort -u);
do
  echo -e "5\ny\n" |  gpg --batch --command-fd 0 --expert --edit-key $fpr trust;
done

# Project identifiers
ARTIFACT_ID=$(mvn -B ${HELP_PLUGIN}:evaluate -Dexpression=project.artifactId | grep -Ev '(^\[)')
GROUP_ID=$(mvn -B ${HELP_PLUGIN}:evaluate -Dexpression=project.groupId | grep -Ev '(^\[)')

echo '-[ Set release version ]--------------------------------------------------------'
# Set release version
mvn -U -C \
    -DnewVersion="${RELEASE_VERSION}" \
    -DgenerateBackupPoms=false \
    clean ${VERSIONS_PLUGIN}:set

echo '-[ Commit modified pom.xml files ]----------------------------------------------'
POM_FILES=`git status | grep -E 'modified:.*pom\.xml' | sed -e 's/[[:space:]][[:space:]]*modified:[[:space:]][[:space:]]*//'`
git add ${POM_FILES} && \
git commit -m "Prepare release ${GROUP_ID}:${ARTIFACT_ID}:${RELEASE_VERSION}"

echo '-[ Deploy artifacts to staging repository ]-------------------------------------'
mvn -U -C -s /home/jenkins/.m2/settings-jakartaee-stable.xml \
    -DskipTests -Ddoclint=none -Dstatus="${STATUS}" -Poss-release -Pstaging \
    clean package source:jar javadoc:jar gpg:sign install:install ${MVN_DEPLOY_ARGS}

echo '-[ Tag release ]----------------------------------------------------------------'
git tag "${RELEASE_TAG}" -m "Release ${GROUP_ID}:${ARTIFACT_ID}:${RELEASE_VERSION}"

echo '-[ Set next snapshot version ]--------------------------------------------------'
mvn -U -C \
    -DnewVersion="${NEXT_VERSION}" \
    -DgenerateBackupPoms=false \
    clean ${VERSIONS_PLUGIN}:set

echo '-[ Commit modified pom.xml files ]----------------------------------------------'
POM_FILES=`git status | grep -E 'modified:.*pom\.xml' | sed -e 's/[[:space:]][[:space:]]*modified:[[:space:]][[:space:]]*//'`
git add ${POM_FILES} && \
git commit -m "Prepare next development cycle for ${NEXT_VERSION}"

if [ ${DRY_RUN} = 'true' ]; then
  echo '-[ Skipping GitHub update ]-----------------------------------------------------'
else
  echo '-[ Push branch and tag to GitHub ]----------------------------------------------'
  git push origin "${RELEASE_BRANCH}"
  git push origin "${RELEASE_TAG}"
fi
