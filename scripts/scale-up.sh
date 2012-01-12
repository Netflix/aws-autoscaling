#!/bin/sh

    #  Copyright (C) 2011 Netflix
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    #
    #    http://www.apache.org/licenses/LICENSE-2.0
    #
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.

    # scale-up.sh
    # Justin Becker
    # Creates AWS policies and alarms neccessary to enable auto-scaling
    # Optionally can create the alarm to send an email notification on 
    # an auto-scaling event.
    # 
    # Also creates a rollback.sh script to delete all the policies and
    # alarms created.

    if [ $# -lt 8 ]; then 
      echo "usage: scale-up asgname percentage namespace metric threshold period occurrences cooldown [topic-arn]"
        exit
    fi

    # COOLDOWN : 
    # PERCENTAGE : Number of machines to scale by
    # NAMESPACE : Cloudwatch namespace.  Example, "AWS/EC2"
    # METRIC : Cloudwatch metric.  Example, "CPUUtilization"
    # THRESHOLD : Metric threshold.  Example, 60 -- CPU greater than 60%
    # PERIOD :  Time in seconds, must be greater than 60
    # OCCURRENCES : Number of occurrences of metric crossing threshold in period
    # COOLDOWN : Amount of time to wait before policy is active again, allows a time-buffer before firing another capacity event.

    ASG=$1
    ROLLBACK="rollback-"$ASG"-scale-up.sh"
    PERCENTAGE=$2
    NAMESPACE=$3
    METRIC=$4
    THRESHOLD=$5
    PERIOD=$6
    OCCURRENCES=$7
    COOLDOWN=$8
    
    POLICY_NAME=scale-up-$ASG-$PERCENTAGE-$COOLDOWN
    POLICY_ALARM_NAME=scale-up-alarm-$ASG-$METRIC-$THRESHOLD

    echo "Creating policy: "$POLICY_NAME
    ARN_POLICY=`as-put-scaling-policy $POLICY_NAME --auto-scaling-group $ASG  --adjustment=$PERCENTAGE --type PercentChangeInCapacity  --cooldown $COOLDOWN`
    echo "Policy created: "$ARN_POLICY
    echo "Creating alarm: "$POLICY_ALARM_NAME 
    # Check if topic-arn passed in, if so, add as an action
    if [ $# -eq 9 ]; then
        TOPIC_ARN=$9
        ARN_POLICY_ALARM=`mon-put-metric-alarm $POLICY_ALARM_NAME  --dimensions "AutoScalingGroupName=$ASG" --comparison-operator  GreaterThanThreshold  --evaluation-periods  $OCCURRENCES --metric-name  $METRIC  --namespace  $NAMESPACE  --period  $PERIOD  --statistic Average --threshold  $THRESHOLD --alarm-actions $ARN_POLICY,$TOPIC_ARN`
    else
        ARN_POLICY_ALARM=`mon-put-metric-alarm $POLICY_ALARM_NAME  --dimensions "AutoScalingGroupName=$ASG" --comparison-operator  GreaterThanThreshold  --evaluation-periods  $OCCURRENCES --metric-name  $METRIC  --namespace  $NAMESPACE  --period  $PERIOD  --statistic Average --threshold  $THRESHOLD --alarm-actions $ARN_POLICY`
    fi
    echo "Alarm created: "$POLICY_ALARM_NAME 
    echo "Creating rollback file: "$ROLLBACK
   
    # ROLLBACK DATA
    echo "#!/bin/sh" > $ROLLBACK
    echo "echo 'Deleting alarm: '"$POLICY_ALARM_NAME >> $ROLLBACK
    echo "mon-delete-alarms "$POLICY_ALARM_NAME >> $ROLLBACK
    
    # ROLLBACK DATA
    echo "echo 'Deleting policy: '"$POLICY_NAME >> $ROLLBACK
    echo "as-delete-policy "$ARN_POLICY >> $ROLLBACK
