#!/bin/bash
#
# ThingsBoard, Inc. ("COMPANY") CONFIDENTIAL
#
# Copyright © 2016-2022 ThingsBoard, Inc. All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains
# the property of ThingsBoard, Inc. and its suppliers,
# if any.  The intellectual and technical concepts contained
# herein are proprietary to ThingsBoard, Inc.
# and its suppliers and may be covered by U.S. and Foreign Patents,
# patents in process, and are protected by trade secret or copyright law.
#
# Dissemination of this information or reproduction of this material is strictly forbidden
# unless prior written permission is obtained from COMPANY.
#
# Access to the source code contained herein is hereby forbidden to anyone except current COMPANY employees,
# managers or contractors who have executed Confidentiality and Non-disclosure agreements
# explicitly covering such access.
#
# The copyright notice above does not evidence any actual or intended publication
# or disclosure  of  this source code, which includes
# information that is confidential and/or proprietary, and is a trade secret, of  COMPANY.
# ANY REPRODUCTION, MODIFICATION, DISTRIBUTION, PUBLIC  PERFORMANCE,
# OR PUBLIC DISPLAY OF OR THROUGH USE  OF THIS  SOURCE CODE  WITHOUT
# THE EXPRESS WRITTEN CONSENT OF COMPANY IS STRICTLY PROHIBITED,
# AND IN VIOLATION OF APPLICABLE LAWS AND INTERNATIONAL TREATIES.
# THE RECEIPT OR POSSESSION OF THIS SOURCE CODE AND/OR RELATED INFORMATION
# DOES NOT CONVEY OR IMPLY ANY RIGHTS TO REPRODUCE, DISCLOSE OR DISTRIBUTE ITS CONTENTS,
# OR TO MANUFACTURE, USE, OR SELL ANYTHING THAT IT  MAY DESCRIBE, IN WHOLE OR IN PART.
#

function deploymentFolder() {
    source .env
    DEPLOYMENT_FOLDER=""
    case $TB_SETUP in
        monolith)
        DEPLOYMENT_FOLDER="monolith"
        ;;
        basic)
        DEPLOYMENT_FOLDER="basic"
        ;;
        advanced)
        DEPLOYMENT_FOLDER="advanced"
        ;;
        *)
        echo "Unknown or missing TB_SETUP value specified in the .env file: '${TB_SETUP}'. Should be either 'monolith' or 'basic' or 'advanced'." >&2
        exit 1
    esac
    echo $DEPLOYMENT_FOLDER
}

function mainServiceName() {
    source .env
    MAIN_SERVICE_NAME=""
    case $TB_SETUP in
        monolith)
        MAIN_SERVICE_NAME="tb-monolith"
        ;;
        basic)
        MAIN_SERVICE_NAME="tb-monolith"
        ;;
        advanced)
        MAIN_SERVICE_NAME="tb-core1"
        ;;
        *)
        echo "Unknown or missing TB_SETUP value specified in the .env file: '${TB_SETUP}'. Should be either 'monolith' or 'basic' or 'advanced'." >&2
        exit 1
    esac
    echo $MAIN_SERVICE_NAME
}

function additionalComposeArgs() {
    source .env
    ADDITIONAL_COMPOSE_ARGS=""
    case $DATABASE in
        postgres)
        ADDITIONAL_COMPOSE_ARGS="-f docker-compose.postgres.yml"
        ;;
        hybrid)
        ADDITIONAL_COMPOSE_ARGS="-f docker-compose.hybrid.yml"
        ;;
        *)
        echo "Unknown DATABASE value specified in the .env file: '${DATABASE}'. Should be either 'postgres' or 'hybrid'." >&2
        exit 1
    esac
    echo $ADDITIONAL_COMPOSE_ARGS
}

function additionalComposeQueueArgs() {
    source .env
    ADDITIONAL_COMPOSE_QUEUE_ARGS=""
    case $TB_QUEUE_TYPE in
        kafka)
        ADDITIONAL_COMPOSE_QUEUE_ARGS="-f docker-compose.kafka.yml"
        ;;
        confluent)
        ADDITIONAL_COMPOSE_QUEUE_ARGS="-f docker-compose.confluent.yml"
        ;;
        aws-sqs)
        ADDITIONAL_COMPOSE_QUEUE_ARGS="-f docker-compose.aws-sqs.yml"
        ;;
        pubsub)
        ADDITIONAL_COMPOSE_QUEUE_ARGS="-f docker-compose.pubsub.yml"
        ;;
        rabbitmq)
        ADDITIONAL_COMPOSE_QUEUE_ARGS="-f docker-compose.rabbitmq.yml"
        ;;
        service-bus)
        ADDITIONAL_COMPOSE_QUEUE_ARGS="-f docker-compose.service-bus.yml"
        ;;
        *)
        echo "Unknown Queue service TB_QUEUE_TYPE value specified in the .env file: '${TB_QUEUE_TYPE}'. Should be either 'kafka' or 'confluent' or 'aws-sqs' or 'pubsub' or 'rabbitmq' or 'service-bus'." >&2
        exit 1
    esac
    echo $ADDITIONAL_COMPOSE_QUEUE_ARGS
}

function additionalComposeMonitoringArgs() {
    source .env

    if [ "$MONITORING_ENABLED" = true ]
    then
      ADDITIONAL_COMPOSE_MONITORING_ARGS="-f docker-compose.prometheus-grafana.yml"
      echo $ADDITIONAL_COMPOSE_MONITORING_ARGS
    else
      echo ""
    fi
}

function additionalComposeCacheArgs() {
    source .env
    CACHE_COMPOSE_ARGS=""
    CACHE="${CACHE:-redis}"
    case $CACHE in
        redis)
        CACHE_COMPOSE_ARGS="-f docker-compose.redis.yml"
        ;;
        redis-cluster)
        CACHE_COMPOSE_ARGS="-f docker-compose.redis-cluster.yml"
        ;;
        *)
        echo "Unknown CACHE value specified in the .env file: '${CACHE}'. Should be either 'redis' or 'redis-cluster'." >&2
        exit 1
    esac
    echo $CACHE_COMPOSE_ARGS
}

function additionalStartupServices() {
    source .env
    ADDITIONAL_STARTUP_SERVICES=""
    case $DATABASE in
        postgres)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES postgres"
        ;;
        hybrid)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES postgres cassandra"
        ;;
        *)
        echo "Unknown DATABASE value specified in the .env file: '${DATABASE}'. Should be either 'postgres' or 'hybrid'." >&2
        exit 1
    esac

    CACHE="${CACHE:-redis}"
    case $CACHE in
        redis)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES redis"
        ;;
        redis-cluster)
        ADDITIONAL_STARTUP_SERVICES="$ADDITIONAL_STARTUP_SERVICES redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5"
        ;;
        *)
        echo "Unknown CACHE value specified in the .env file: '${CACHE}'. Should be either 'redis' or 'redis-cluster'." >&2
        exit 1
    esac

    echo $ADDITIONAL_STARTUP_SERVICES
}

function permissionList() {
    PERMISSION_LIST="
      799  799  tb-node/log
      799  799  tb-transports/coap/log
      799  799  tb-transports/lwm2m/log
      799  799  tb-transports/http/log
      799  799  tb-transports/mqtt/log
      799  799  tb-transports/snmp/log
      799  799  tb-transports/coap/log
      799  799  tb-vc-executor/log
      999  999  tb-node/postgres
      "

    PERMISSION_LIST="$PERMISSION_LIST
      799  799  tb-node/data
      799  799  tb-integration-executor/log
      "

    source .env

    if [ "$DATABASE" = "hybrid" ]; then
      PERMISSION_LIST="$PERMISSION_LIST
      999  999  tb-node/cassandra
      "
    fi

    CACHE="${CACHE:-redis}"
    case $CACHE in
        redis)
          PERMISSION_LIST="$PERMISSION_LIST
          1001 1001 tb-node/redis-data
          "
        ;;
        redis-cluster)
          PERMISSION_LIST="$PERMISSION_LIST
          1001 1001 tb-node/redis-cluster-data-0
          1001 1001 tb-node/redis-cluster-data-1
          1001 1001 tb-node/redis-cluster-data-2
          1001 1001 tb-node/redis-cluster-data-3
          1001 1001 tb-node/redis-cluster-data-4
          1001 1001 tb-node/redis-cluster-data-5
          "
        ;;
        *)
        echo "Unknown CACHE value specified in the .env file: '${CACHE}'. Should be either 'redis' or 'redis-cluster'." >&2
        exit 1
    esac

    echo "$PERMISSION_LIST"
}

function checkFolders() {
  EXIT_CODE=0
  PERMISSION_LIST=$(permissionList) || exit $?
  set -e
  while read -r USR GRP DIR
  do
    if [ -z "$DIR" ]; then # skip empty lines
          continue
    fi
    MESSAGE="Checking user ${USR} group ${GRP} dir ${DIR}"
    if [[ -d "$DIR" ]] &&
       [[ $(ls -ldn "$DIR" | awk '{print $3}') -eq "$USR" ]] &&
       [[ $(ls -ldn "$DIR" | awk '{print $4}') -eq "$GRP" ]]
    then
      MESSAGE="$MESSAGE OK"
    else
      if [ "$1" = "--create" ]; then
        echo "Create and chown: user ${USR} group ${GRP} dir ${DIR}"
        mkdir -p "$DIR" && sudo chown -R "$USR":"$GRP" "$DIR"
      else
        echo "$MESSAGE FAILED"
        EXIT_CODE=1
      fi
    fi
  done < <(echo "$PERMISSION_LIST")
  return $EXIT_CODE
}

function composeVersion() {
    #Checking whether "set -e" shell option should be restored after Compose version check
    FLAG_SET=false
    if [[ $SHELLOPTS =~ errexit ]]; then
        set +e
        FLAG_SET=true
    fi

    #Checking Compose V1 availablity
    docker-compose version >/dev/null 2>&1
    if [ $? -eq 0 ]; then status_v1=true; else status_v1=false; fi

    #Checking Compose V2 availablity
    docker compose version >/dev/null 2>&1
    if [ $? -eq 0 ]; then status_v2=true; else status_v2=false; fi

    COMPOSE_VERSION=""

    if $status_v2 ; then
        COMPOSE_VERSION="V2"
    elif $status_v1 ; then
        COMPOSE_VERSION="V1"
    else
        echo "Docker Compose plugin is not detected. Please check your environment." >&2
        exit 1
    fi

    echo $COMPOSE_VERSION

    if $FLAG_SET ; then set -e; fi
}
