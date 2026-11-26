#!/bin/bash
# Creates the target tracking and step scaling policies for the web Auto Scaling Group.
# Usage: SNS_TOPIC_ARN=arn:aws:sns:... ./scaling-policies.sh
set -euo pipefail
ASG_NAME="${ASG_NAME:-web-asg}"
: "${SNS_TOPIC_ARN:?Set SNS_TOPIC_ARN to the alerts topic ARN}"

aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name cpu-target-50 \
  --policy-type TargetTrackingScaling \
  --estimated-instance-warmup 300 \
  --target-tracking-configuration '{"PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":50.0}'

# Step bounds are relative to the 70% alarm threshold: 70-85% adds 1, 85%+ adds 2.
STEP_ARN=$(aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "$ASG_NAME" \
  --policy-name cpu-burst-step \
  --policy-type StepScaling \
  --adjustment-type ChangeInCapacity \
  --metric-aggregation-type Average \
  --estimated-instance-warmup 300 \
  --step-adjustments \
    MetricIntervalLowerBound=0,MetricIntervalUpperBound=15,ScalingAdjustment=1 \
    MetricIntervalLowerBound=15,ScalingAdjustment=2 \
  --query PolicyARN --output text)

aws cloudwatch put-metric-alarm \
  --alarm-name "$ASG_NAME-high-cpu" \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value="$ASG_NAME" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 3 \
  --threshold 70 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions "$STEP_ARN" "$SNS_TOPIC_ARN"
