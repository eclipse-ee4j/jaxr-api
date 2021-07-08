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


mvnq() {
    # filter out progress reports (-B) and download details
    mvn -B "$@" | grep -v '^\[INFO\] Download'
}

#
# List all the profiles, then for each profile,
# list all the repositories and release them.
# XXX - Assumes we want to release everything that's currently staged.
#
for name in $(mvnq -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list-profiles | \
    grep -v 'Central Bundles' | \
    awk '$3 == "BOTH" {print $4}')
do
    name=${name//./}    # squash out all the dots
    for id in $(mvnq -B ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-list | \
        awk '$1 ~ /\[INFO\]/ && $2 ~ /^'"${name}"'\-[0-9]+$/ {print $2}')
    do
        echo "Releasing $id"
        mvnq -DstagingRepositoryId="$id" ${NEXUS_PLUGIN_PARAMS} ${NEXUS_PLUGIN}:rc-release
    done
done 
