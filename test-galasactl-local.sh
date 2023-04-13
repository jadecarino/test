#!/bin/bash

echo "Running script test-galasactl-local.sh"

# This script can be ran locally or executed in a pipeline to test the various built binaries of galasactl
# This script tests the 'galasactl project create' and 'galasactl runs submit local' commands
# Pre-requesite: the CLI must have been built first so the binaries are present in the /bin directory


# Where is this script executing from ?
BASEDIR=$(dirname "$0");pushd $BASEDIR 2>&1 >> /dev/null ;BASEDIR=$(pwd);popd 2>&1 >> /dev/null
export ORIGINAL_DIR=$(pwd)
cd "${BASEDIR}/.."


#--------------------------------------------------------------------------
#
# Set Colors
#
#--------------------------------------------------------------------------
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

red=$(tput setaf 1)
green=$(tput setaf 76)
white=$(tput setaf 7)
tan=$(tput setaf 202)
blue=$(tput setaf 25)

#--------------------------------------------------------------------------
#
# Headers and Logging
#
#--------------------------------------------------------------------------
underline() { printf "${underline}${bold}%s${reset}\n" "$@"
}
h1() { printf "\n${underline}${bold}${blue}%s${reset}\n" "$@"
}
h2() { printf "\n${underline}${bold}${white}%s${reset}\n" "$@"
}
debug() { printf "${white}%s${reset}\n" "$@"
}
info() { printf "${white}➜ %s${reset}\n" "$@"
}
success() { printf "${green}✔ %s${reset}\n" "$@"
}
error() { printf "${red}✖ %s${reset}\n" "$@"
}
warn() { printf "${tan}➜ %s${reset}\n" "$@"
}
bold() { printf "${bold}%s${reset}\n" "$@"
}
note() { printf "\n${underline}${bold}${blue}Note:${reset} ${blue}%s${reset}\n" "$@"
}


#-----------------------------------------------------------------------------------------                   
# Functions
#-----------------------------------------------------------------------------------------                   
function usage {
    info "Syntax: test-galasactl-local.sh --binary [OPTIONS]"
    cat << EOF
Options are:
galasactl-darwin-amd64 : Use the galasactl-darwin-amd64 binary
galasactl-darwin-arm64 : Use the galasactl-darwin-arm64 binary
galasactl-linux-amd64 : Use the galasactl-linux-amd64 binary
galasactl-linux-s390x : Use the galasactl-linux-s390x binary
galasactl-windows-amd64.exe : Use the galasactl-windows-amd64.exe binary
EOF
}

#-----------------------------------------------------------------------------------------                   
# Process parameters
#-----------------------------------------------------------------------------------------                   
binary=""
buildTool=""

while [ "$1" != "" ]; do
    case $1 in
        --binary )                        shift
                                          binary="$1"
                                          ;;
        --buildTool )                    shift
                                          buildTool="$1"
                                          ;;
        -h | --help )                     usage
                                          exit
                                          ;;
        * )                               error "Unexpected argument $1"
                                          usage
                                          exit 1
    esac
    shift
done

if [[ "${binary}" != "" ]]; then
    case ${binary} in
        galasactl-darwin-amd64 )            echo "Using the galasactl-darwin-amd64 binary"
                                            ;;
        galasactl-darwin-arm64 )            echo "Using the galasactl-darwin-arm64 binary"
                                            ;;
        galasactl-linux-amd64 )             echo "Using the galasactl-linux-amd64 binary"
                                            ;;
        galasactl-linux-s390x )             echo "Using the galasactl-linux-s390x binary"
                                            ;;
        galasactl-windows-amd64.exe )       echo "Using the galasactl-windows-amd64.exe binary"
                                            ;;
        * )                                 error "Unrecognised galasactl binary ${binary}"
                                            usage
                                            exit 1
    esac
else
    error "Need to specify which binary of galasactl to use."
    usage
    exit 1  
fi

if [[ "${buildTool}" != "" ]]; then
    case ${buildTool} in
        maven  )            echo "Using Maven"
                            ;;
        gradle )            echo "Using Gradle"
                            ;;
        * )                 error "Unrecognised build tool ${buildTool}"
                            usage
                            exit 1
    esac
else
    error "Need to specify which build tool to use to build the generated project."
    usage
    exit 1  
fi

#--------------------------------------------------------------------------
# Initialise Galasa home
function galasa_home_init {
    h2 "Initialising galasa home directory"

    rm -rf ${BASEDIR}/../temp
    mkdir -p ${BASEDIR}/../temp
    cd ${BASEDIR}/../temp

    cmd="${BASEDIR}/../bin/${binary} local init --development \
    --log -"

    info "Command is: $cmd"

    $cmd
    rc=$?
    if [[ "${rc}" != "0" ]]; then 
        error "Failed to initialise galasa home"
        exit 1
    fi
    success "Galasa home initialised"
}

#--------------------------------------------------------------------------
# Invoke the galasactl command to create a project.
function generate_sample_code {
    h2 "Invoke the tool to create a sample project."

    cd ${BASEDIR}/../temp

    export PACKAGE_NAME="dev.galasa.example.banking"
    ${BASEDIR}/../bin/${binary} project create --package ${PACKAGE_NAME} --features payee --obr --${buildTool} --force --development
    rc=$?
    if [[ "${rc}" != "0" ]]; then
        error " Failed to create the galasa test project using galasactl command. rc=${rc}"
        exit 1
    fi
    success "OK"
}

# #--------------------------------------------------------------------------
# # Rewrite pom.xml to allow Maven to point to our remote maven repository
# function rewrite_pom {
#     h2 "Rewriting the pom.xml file so Maven can use our remote maven repository."
#     cd ${BASEDIR}/../temp/${PACKAGE_NAME}

#     tee pom.xml << EOF
# <?xml version="1.0" encoding="UTF-8"?>
# <project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
# 	<modelVersion>4.0.0</modelVersion>
# 	<groupId>dev.galasa.example.banking</groupId>
# 	<artifactId>dev.galasa.example.banking</artifactId>
# 	<version>0.0.1-SNAPSHOT</version>
#   	<packaging>pom</packaging>
#   	<name>dev.galasa.example.banking</name>
# 	<properties>
# 		<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
# 		<project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
# 		<java.version>11</java.version>
# 		<maven.compiler.source>11</maven.compiler.source>
# 		<maven.compiler.target>11</maven.compiler.target>
# 		<maven.build.timestamp.format>yyyyMMddHHmm</maven.build.timestamp.format>
# 		<unpackBundle>true</unpackBundle>
# 	</properties>
# 	<modules>
# 		<module>dev.galasa.example.banking.payee</module>
# 		<module>dev.galasa.example.banking.obr</module>
# 	</modules>
# 	<dependencyManagement>
# 		<dependencies>
# 			<dependency>
# 				<groupId>dev.galasa</groupId>
# 				<artifactId>galasa-bom</artifactId>
# 				<version>0.27.0</version>
# 				<type>pom</type>
# 				<scope>import</scope>
# 			</dependency>
# 		</dependencies>
# 	</dependencyManagement>
# 	<dependencies>
# 		<dependency>
# 			<groupId>dev.galasa</groupId>
# 			<artifactId>dev.galasa</artifactId>
# 			<scope>provided</scope>
# 		</dependency>
# 		<dependency>
# 			<groupId>dev.galasa</groupId>
# 			<artifactId>dev.galasa.core.manager</artifactId>
# 			<scope>provided</scope>
# 		</dependency>
# 		<dependency>
# 			<groupId>dev.galasa</groupId>
# 			<artifactId>dev.galasa.artifact.manager</artifactId>
# 			<scope>provided</scope>
# 		</dependency>
# 		<dependency>
# 			<groupId>org.assertj</groupId>
# 			<artifactId>assertj-core</artifactId>
# 		</dependency>
# 	</dependencies>	
# 	<build>
# 		<pluginManagement>
# 			<plugins>
# 				<plugin>
# 					<groupId>org.apache.felix</groupId>
# 					<artifactId>maven-bundle-plugin</artifactId>
# 					<version>4.1.0</version>
# 				</plugin>
# 				<plugin>
# 					<groupId>org.apache.maven.plugins</groupId>
# 					<artifactId>maven-plugin-plugin</artifactId>
# 					<version>3.6.0</version>
# 				</plugin>
# 				<plugin>
# 					<groupId>dev.galasa</groupId>
# 					<artifactId>galasa-maven-plugin</artifactId>
# 					<version>0.20.0</version>
# 				</plugin>
# 			</plugins>
# 		</pluginManagement>
# 		<plugins>
# 			<plugin>
# 				<groupId>org.apache.felix</groupId>
# 				<artifactId>maven-bundle-plugin</artifactId>
# 				<extensions>true</extensions>
# 			</plugin>
# 			<plugin>
# 				<groupId>dev.galasa</groupId>
# 				<artifactId>galasa-maven-plugin</artifactId>
# 				<extensions>true</extensions>
# 				<executions>
# 					<execution>
# 						<id>build-testcatalog</id>
# 						<phase>package</phase>
# 						<goals>
# 						<goal>bundletestcat</goal>
# 						</goals>
# 					</execution>
# 				</executions>
# 			</plugin>
# 		</plugins>
# 	</build>
#     <repositories>
#         <repository>
#             <id>galasa.dev.repo</id>
#             <url>https://development.galasa.dev/main/maven-repo/obr</url>
#         </repository>
#     </repositories>
# </project>
# EOF

# }

# #--------------------------------------------------------------------------
# # Rewrite gradle files to allow Gradle to point to our remote maven repository
# function rewrite_settings_gradle {
#     h2 "Rewriting the settings.gradle file so Gradle can use our remote maven repository."
#     cd ${BASEDIR}/../temp/${PACKAGE_NAME}

#     tee settings.gradle << EOF
# pluginManagement {
# 	repositories {
# 		mavenLocal()
# 		mavenCentral()
# 		maven {
#         	url 'https://development.galasa.dev/main/maven-repo/obr'
# 		}
# 	    gradlePluginPortal()
# 	}
# }
# include 'dev.galasa.example.banking.payee'
# include 'dev.galasa.example.banking.account'
# include 'dev.galasa.example.banking.obr'
# EOF

# }

# function rewrite_build_gradle {
#     h2 "Rewriting the build.gradle file of the test project also."
#     cd ${BASEDIR}/../temp/${PACKAGE_NAME}/${PACKAGE_NAME}.payee

#     tee build.gradle << EOF
# plugins {
#     id 'java'
#     id 'maven-publish'
#     id 'biz.aQute.bnd.builder' version '6.4.0'
# }

# repositories {
#     mavenLocal()
#     mavenCentral()
#     maven {
#       url 'https://development.galasa.dev/main/maven-repo/obr'
#     }
# }

# group = 'dev.galasa.example.banking'
# version = '0.0.1-SNAPSHOT'

# dependencies {
#     implementation platform('dev.galasa:galasa-bom:0.26.0')

#     implementation 'dev.galasa:dev.galasa'
#     implementation 'dev.galasa:dev.galasa.framework'
#     implementation 'dev.galasa:dev.galasa.core.manager'
#     implementation 'dev.galasa:dev.galasa.artifact.manager'
#     implementation 'commons-logging:commons-logging'
#     implementation 'org.assertj:assertj-core'
# }

# publishing {
#     publications {
#         maven(MavenPublication) {
#             from components.java
#         }
#     }
# }
# EOF
# }

#--------------------------------------------------------------------------
# Now build the source it created
function build_generated_source {
    h2 "Building the sample project we just generated."
    cd ${BASEDIR}/../temp/${PACKAGE_NAME}

    if [[ "${buildTool}" == "maven" ]]; then
        mvn clean test install
    elif [[ "${buildTool}" == "gradle" ]]; then
        gradle clean build publishToMavenLocal
    fi

    rc=$?
    if [[ "${rc}" != "0" ]]; then
        error " Failed to build the generated source code which galasactl created."
        exit 1
    fi
    success "OK"
}

#--------------------------------------------------------------------------
# Run test using the galasactl locally in a JVM
function submit_local_test {

    h2 "Submitting a local test using galasactl in a local JVM"

    cd ${BASEDIR}/../temp/*banking

    BUNDLE=$1
    JAVA_CLASS=$2
    OBR_GROUP_ID=$3
    OBR_ARTIFACT_ID=$4
    OBR_VERSION=$5

    # Could get this bootjar from https://development.galasa.dev/main/maven-repo/obr/dev/galasa/galasa-boot/0.26.0/
    export BOOT_JAR_VERSION="0.26.0"

    export GALASA_VERSION="0.26.0"

    export BOOT_JAR_PATH=~/.galasa/lib/${GALASA_VERSION}/galasa-boot-${BOOT_JAR_VERSION}.jar

    export REMOTE_MAVEN=https://development.galasa.dev/main/maven-repo/obr/

    export GALASACTL="${BASEDIR}/../bin/${binary}"

    ${GALASACTL} runs submit local \
    --obr mvn:${OBR_GROUP_ID}/${OBR_ARTIFACT_ID}/${OBR_VERSION}/obr \
    --remoteMaven ${REMOTE_MAVEN} \
    --class ${BUNDLE}/${JAVA_CLASS} \
    --throttle 1 \
    --requesttype automated-test \
    --poll 10 \
    --progress 1 \
    --log -

    # Uncomment this if testing that a test that should fail, fails
    # --noexitcodeontestfailures \

    rc=$?
    if [[ "${rc}" != "0" ]]; then 
        error "Failed to run the test"
        exit 1
    fi
    success "Test ran OK"
}

function run_test_locally_using_galasactl {
    export LOG_FILE=$1
    
    # Run the Payee tests.
    export TEST_BUNDLE=dev.galasa.example.banking.payee
    export TEST_JAVA_CLASS=dev.galasa.example.banking.payee.TestPayee
    export TEST_OBR_GROUP_ID=dev.galasa.example.banking
    export TEST_OBR_ARTIFACT_ID=dev.galasa.example.banking.obr
    export TEST_OBR_VERSION=0.0.1-SNAPSHOT


    submit_local_test $TEST_BUNDLE $TEST_JAVA_CLASS $TEST_OBR_GROUP_ID $TEST_OBR_ARTIFACT_ID $TEST_OBR_VERSION $LOG_FILE
}

function cleanup_local_maven_repo {
    rm -fr ~/.m2/repository/dev/galasa/example
}

# Initialise Galasa home ...
galasa_home_init

# Generate sample project ...
generate_sample_code

if [[ "${buildTool}" == "maven" ]]; then
    cleanup_local_maven_repo
    # rewrite_pom
    build_generated_source
elif [[ "${buildTool}" == "gradle" ]]; then
    cleanup_local_maven_repo
    # rewrite_settings_gradle
    # rewrite_build_gradle
    build_generated_source
fi

run_test_locally_using_galasactl