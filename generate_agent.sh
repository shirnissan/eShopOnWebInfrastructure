#!/bin/bash

set -xe

NODE_NAME=`hostname`
NUM_EXECUTORS=1

# Download CLI jar from the master
curl ${jenkins_url}/jnlpJars/jenkins-cli.jar -o ~/jenkins-cli.jar

# Create node according to parameters passed in
cat <<EOF | java -jar ~/jenkins-cli.jar -auth "${MASTER_USERNAME}:${MASTER_PASSWORD}" -s "${jenkins_url}" create-node "${NODE_NAME}" |true
<slave>
  <name>${NODE_NAME}</name>
  <description></description>
  <remoteFS>/home/jenkins/agent</remoteFS>
  <numExecutors>${NUM_EXECUTORS}</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
  </launcher>
  <label></label>
  <nodeProperties/>
  <userId>${USER}</userId>
</slave>
EOF
# Creating the node will fail if it already exists, so |true to suppress the
# error. This probably should check if the node exists first but it should be
# possible to see any startup errors if the node doesn't attach as expected.


# Download slave.jar
curl ${jenkins_url}/jnlpJars/slave.jar -o /usr/share/jenkins/slave.jar

# Run jnlp launcher
java -jar /usr/share/jenkins/slave.jar -jnlpUrl ${jenkins_url}/computer/${NODE_NAME}/slave-agent.jnlp -jnlpCredentials "${MASTER_USERNAME}:${MASTER_PASSWORD}"

