#!/bin/bash -ex

TOOLS_PREFIX='/opt/tools'
JAVA_PREFIX="${TOOLS_PREFIX}/java/oracle"
MVN_HOME="${TOOLS_PREFIX}/apache-maven/latest"
JAVA_HOME="${JAVA_PREFIX}/jdk-8/latest"
PATH="${MVN_HOME}/bin:${JAVA_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Maven plugins
HELP_PLUGIN='org.apache.maven.plugins:maven-help-plugin:3.1.0'
NEXUS_PLUGIN='org.sonatype.plugins:nexus-staging-maven-plugin:1.6.7'
NEXUS_PLUGIN_PARAMS='-DnexusUrl=https://oss.sonatype.org/ -DserverId=ossrh'

case "${PROJECT}" in

  'Enterprise-Deployment')
    GIT_REPO='git@github.com:eclipse-ee4j/enterprise-deployment.git'
    STAGING_NAME='jakartaenterprisedeploy'
  ;;

  'JAX-RPC-API')
    GIT_REPO='git@github.com:eclipse-ee4j/jax-rpc-api.git'
    STAGING_NAME='jakartaxmlrpc'
  ;;

  'JAXR-API')
    GIT_REPO='git@github.com:eclipse-ee4j/jaxr-api.git'
    STAGING_NAME='jakartaxmlregistry'
  ;;

  'Management-API')
    GIT_REPO='git@github.com:eclipse-ee4j/management-api.git'
    STAGING_NAME='jakartamanagementj2ee'
  ;;

  *)
    if [ "${ACTION}" != 'list' ]; then
      echo '-[ Error ]----------------------------------------------------------------------'
      echo 'No project selected, exitting.'
      exit 1
    else
      GIT_REPO=''
    fi
  ;;

esac

if [ -n "${GIT_REPO}" ]; then
  echo '-[ Cloning Project Repository ]-------------------------------------------------'
  git clone ${GIT_REPO} . && git checkout ${BRANCH}
  echo '-[ Reading project identifiers ]------------------------------------------------'
  if [ -n "${BUILD_DIR}" ]; then
    cd ${BUILD_DIR}
  fi
  # Project identifiers
  ARTIFACT_ID=$(mvn -B ${HELP_PLUGIN}:evaluate -Dexpression=project.artifactId | grep -Ev '(^\[)')
  GROUP_ID=$(mvn -B ${HELP_PLUGIN}:evaluate -Dexpression=project.groupId | grep -Ev '(^\[)')
fi


echo "Project:              ${PROJECT} API"
echo "Action:               ${ACTION}"
echo "Repository ID prefix: ${STAGING_NAME}"
echo "Artifact:             ${GROUP_ID}:${ARTIFACT_ID}"


case "${ACTION}" in

  'list')

    echo '-[ Profiles List ]--------------------------------------------------------------'
    mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list-profiles
    echo '-[ Staging Repository List ]----------------------------------------------------'
    if [ -n "${STAGING_NAME}" ]; then
      mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list | egrep "^\[INFO\] ${STAGING_NAME}\-[0-9]+[ ]+[A-Z]+[ ]" || true
    else
      mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list
    fi
    ;;

  'close')

    if [ -z "${VERSION}" ]; then
      echo '-[ Missing version number ]-----------------------------------------------------'
      exit 1
    fi
    STAGING_DESC="${GROUP_ID}:${ARTIFACT_ID}:${VERSION}"
    echo "Project description:  ${STAGING_DESC}"
    echo '-[ Searching for open deployment ]----------------------------------------------'

    # Get the ID of the opem staging repository
#    if [ "${PROJECT}" = 'JAX-RPC-API' ]; then
#      STAGING_REPO_ID=$(mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list | \
#        egrep "^\[INFO\] .*\-[0-9]+[ ]+OPEN[ ]+.*${STAGING_NAME}" | \
#        awk '{print $2}' | head -1)
#    else
      STAGING_REPO_ID=$(mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list | \
        egrep "^\[INFO\] ${STAGING_NAME}\-[0-9]+[ ]+OPEN[ ]" | \
        awk '{print $2}' | head -1)
#    fi
    echo "Nexus staging repository ID: ${STAGING_REPO_ID}"

    if [ -n "${STAGING_REPO_ID}" ]; then
      echo '-[ Closing Nexus staging repository ]-------------------------------------------'
      mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-close \
          -DstagingRepositoryId="${STAGING_REPO_ID}" \
          -DstagingDescription="${STAGING_DESC}"
    else
      echo '-[ Delpoyment '${STAGING_NAME}' was not found ]------------------------------------'
    fi
    ;;

  'drop')

    if [ -z "${VERSION}" ]; then
      echo '-[ Searching for deployments ]----------------------------------------------'
      for REPO_ID in $(mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list | \
        egrep "^\[INFO\] ${STAGING_NAME}\-[0-9]+[ ]+[A-Z]+[ ]" | \
        awk '{print $2}' | head -1); do
        echo '-[ Dropping Nexus staging repository ]------------------------------------------'
        echo "Deployment: ${REPO_ID}"
        mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-drop \
            -DstagingRepositoryId="${REPO_ID}"
      done
    else
      mvn -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-drop \
          -DstagingRepositoryId="${VERSION}"
    fi
    ;;

  release)
    echo '-[ Action denied for security reasons ]-------------------------------------'
    ;;

esac
