#!/bin/bash

set -euo pipefail

region="ap-southeast-2"
cluster="kosmos-ecs-cluster"
service=""
limit=20
verbose="false"
target_deployment_id=""
target_task_def_rev=""
target_reference_time=""
bold=""
reset=""
red=""
yellow=""
green=""
blue=""

usage() {
  cat <<'EOF'
Usage: ecs-deploy-diagnose.sh -s <service-name> [-c <cluster>] [-r <region>] [-n <limit>] [-d <deployment-id>] [-t <task-def-rev>] [-a <iso8601>] [-v]

Diagnose likely cause of an ECS deployment rollback/circuit-breaker event.

Options:
  -s  ECS service name (required)
  -c  ECS cluster name (default: kosmos-ecs-cluster)
  -r  AWS region (default: ap-southeast-2)
  -n  Number of recent events/tasks to inspect (default: 20)
  -d  Target ECS deployment id, e.g. ecs-svc/1234567890
  -t  Target task definition revision, e.g. 30
  -a  Target rollback time in ISO8601 format
  -v  Show additional raw JSON snippets
  -h  Show this help

Example:
  bash ~/dotfiles_macos/scripts/ecs-deploy-diagnose.sh \
    -s kosmos-personalisation-PersonalisationClusterServiceBFE45DCC-gGgoakJqgcYE \
    -t 30
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "Missing required command: %s\n" "$1" >&2
    exit 1
  fi
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

print_section() {
  printf "\n%s== %s ==%s\n" "${bold}${blue}" "$1" "$reset"
}

print_emphasis() {
  printf "%s%s%s\n" "$bold" "$1" "$reset"
}

print_warning() {
  printf "%s%s%s\n" "${bold}${yellow}" "$1" "$reset"
}

print_success() {
  printf "%s%s%s\n" "${bold}${green}" "$1" "$reset"
}

print_error() {
  printf "%s%s%s\n" "${bold}${red}" "$1" "$reset"
}

init_styles() {
  if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    bold=$(tput bold 2>/dev/null || true)
    reset=$(tput sgr0 2>/dev/null || true)

    if [ "$(tput colors 2>/dev/null || printf '0')" -ge 8 ]; then
      red=$(tput setaf 1 2>/dev/null || true)
      green=$(tput setaf 2 2>/dev/null || true)
      yellow=$(tput setaf 3 2>/dev/null || true)
      blue=$(tput setaf 4 2>/dev/null || true)
    fi
  fi
}

extract_memory_value() {
  jq -r --arg resource_name "$1" '([.[] | select(.name == $resource_name) | .integerValue] | first) // 0'
}

describe_container_instances_all() {
  local -a arns=("$@")
  local chunk_size=100
  local index=0
  local -a responses=()

  if [ "${#arns[@]}" -eq 0 ]; then
    printf '{"containerInstances":[]}\n'
    return 0
  fi

  while [ "$index" -lt "${#arns[@]}" ]; do
    local chunk=("${arns[@]:index:chunk_size}")
    responses+=("$(aws ecs describe-container-instances \
      --region "$region" \
      --cluster "$cluster" \
      --container-instances "${chunk[@]}" \
      --output json \
      --no-cli-pager)")
    index=$((index + chunk_size))
  done

  printf '%s\n' "${responses[@]}" | jq -s '{containerInstances: [.[].containerInstances[]?]}'
}

build_time_window_json() {
  python3 - "$1" <<'PY'
from datetime import datetime, timedelta, timezone
import json
import sys

source = sys.argv[1]
target = datetime.fromisoformat(source.replace("Z", "+00:00")).astimezone(timezone.utc)
start = target - timedelta(minutes=15)
end = target + timedelta(minutes=15)

print(json.dumps({
    "targetUtc": target.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "targetEpoch": int(target.timestamp()),
    "startUtc": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "endUtc": end.strftime("%Y-%m-%dT%H:%M:%SZ"),
}))
PY
}

get_metric_point() {
  local namespace="$1"
  local metric_name="$2"
  local stat="$3"
  shift 3

  aws cloudwatch get-metric-statistics \
    --region "$region" \
    --namespace "$namespace" \
    --metric-name "$metric_name" \
    --dimensions "$@" \
    --start-time "$rollback_start_utc" \
    --end-time "$rollback_end_utc" \
    --period 60 \
    --statistics "$stat" \
    --output json \
    --no-cli-pager | jq -r \
    --arg stat "$stat" \
    --argjson target "$rollback_target_epoch" '
      if (.Datapoints | length) == 0 then
        ""
      else
        (
          .Datapoints
          | map(select(.[$stat] != null))
          | map({
              value: .[$stat],
              timestamp: .Timestamp,
              delta: (((.Timestamp | sub("\\+00:00$"; "Z") | fromdateiso8601) - $target) | if . < 0 then -. else . end)
            })
          | if length == 0 then "" else (sort_by(.delta)[0] | "\(.value)|\(.timestamp)") end
        )
      end
    '
}

while getopts ":s:c:r:n:d:t:a:vh" flag; do
  case "$flag" in
    s) service="$OPTARG" ;;
    c) cluster="$OPTARG" ;;
    r) region="$OPTARG" ;;
    n) limit="$OPTARG" ;;
    d) target_deployment_id="$OPTARG" ;;
    t) target_task_def_rev="$OPTARG" ;;
    a) target_reference_time="$OPTARG" ;;
    v) verbose="true" ;;
    h)
      usage
      exit 0
      ;;
    :)
      printf "Option -%s requires a value.\n" "$OPTARG" >&2
      usage
      exit 1
      ;;
    *)
      printf "Unknown option: -%s\n" "$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$service" ]; then
  printf "Service name is required.\n" >&2
  usage
  exit 1
fi

if ! [[ "$limit" =~ ^[0-9]+$ ]] || [ "$limit" -le 0 ]; then
  printf "Limit must be a positive integer.\n" >&2
  exit 1
fi

require_cmd aws
require_cmd jq
init_styles

if ! aws sts get-caller-identity --no-cli-pager >/dev/null 2>&1; then
  printf "AWS authentication is unavailable or expired. Refresh your AWS credentials and try again.\n" >&2
  exit 1
fi

service_json=$(aws ecs describe-services \
  --region "$region" \
  --cluster "$cluster" \
  --services "$service" \
  --output json \
  --no-cli-pager)

if [ "$(jq '.failures | length' <<<"$service_json")" -gt 0 ] || [ "$(jq '.services | length' <<<"$service_json")" -eq 0 ]; then
  printf "Unable to find ECS service '%s' in cluster '%s'.\n" "$service" "$cluster" >&2
  jq -r '.failures[]? | "- \(.arn // .reason // "unknown failure")"' <<<"$service_json" >&2
  exit 1
fi

service_status=$(jq -r '.services[0].status' <<<"$service_json")
desired_count=$(jq -r '.services[0].desiredCount' <<<"$service_json")
running_count=$(jq -r '.services[0].runningCount' <<<"$service_json")
pending_count=$(jq -r '.services[0].pendingCount' <<<"$service_json")
current_task_definition=$(jq -r '.services[0].taskDefinition' <<<"$service_json")
launch_type=$(jq -r '.services[0].launchType // "UNKNOWN"' <<<"$service_json")

task_definition_json=$(aws ecs describe-task-definition \
  --region "$region" \
  --task-definition "$current_task_definition" \
  --output json \
  --no-cli-pager)

task_family=$(jq -r '.taskDefinition.family' <<<"$task_definition_json")
required_memory=$(jq -r '[.taskDefinition.containerDefinitions[] | (.memory // .memoryReservation // 0)] | max // 0' <<<"$task_definition_json")
deployment_max_percent=$(jq -r '.services[0].deploymentConfiguration.maximumPercent // 200' <<<"$service_json")
deployment_min_healthy_percent=$(jq -r '.services[0].deploymentConfiguration.minimumHealthyPercent // 100' <<<"$service_json")
max_total_tasks_during_rollout=$(awk -v desired="$desired_count" -v maxp="$deployment_max_percent" 'BEGIN { printf "%d", int((desired * maxp) / 100) }')
max_extra_tasks_during_rollout=$((max_total_tasks_during_rollout - desired_count))

if [ "$max_extra_tasks_during_rollout" -lt 0 ]; then
  max_extra_tasks_during_rollout=0
fi

if [[ "$target_task_def_rev" == *:* ]]; then
  target_task_def_rev="${target_task_def_rev##*:}"
fi

failure_events_json=$(jq --argjson limit "$limit" '
  [
    .services[0].events[]?
    | select(
        .message
        | test(
            "deployment failed|failed to start|unable to place|insufficient memory|insufficient cpu|rolling back to deployment|CannotPullContainerError|CannotStartContainerError|ResourceInitializationError|failed elb health checks|failed container health checks|health checks failed|is unhealthy in \\(target-group|unhealthy in \\(target-group|stopped [0-9]+ pending tasks";
            "i"
          )
      )
  ][0:$limit]
' <<<"$service_json")

recent_context_events_json=$(jq --argjson limit "$limit" '
  [
    .services[0].events[]?
    | select(
        .message
        | test(
            "deployment failed|failed to start|unable to place|insufficient memory|insufficient cpu|rolling back to deployment|CannotPullContainerError|CannotStartContainerError|ResourceInitializationError|failed elb health checks|failed container health checks|health checks failed|is unhealthy in \\(target-group|unhealthy in \\(target-group|stopped [0-9]+ pending tasks";
            "i"
          )
        | not
      )
  ][0:$limit]
' <<<"$service_json")

if [ -n "$target_deployment_id" ]; then
  failed_deployment_id="$target_deployment_id"
else
  failed_deployment_id=$(jq -r '[
    .[]?
    | .message
    | (try capture("deployment (?<id>ecs-svc/[0-9]+) deployment failed").id catch empty)
  ][0] // ""' <<<"$failure_events_json")
fi

container_instance_id=$(jq -r '[
  .[]?
  | .message
  | (try capture("container-instance (?<id>[A-Za-z0-9-]+)").id catch empty)
][0] // ""' <<<"$failure_events_json")

failure_event_messages=$(jq -r '[.[].message] | join("\n")' <<<"$failure_events_json")
has_failure_events="false"

if [ "$(jq 'length' <<<"$failure_events_json")" -gt 0 ]; then
  has_failure_events="true"
fi

rollback_reference_label=""
rollback_reference_time=""

if [ -n "$target_reference_time" ]; then
  rollback_reference_time="$target_reference_time"
  rollback_reference_label="user-supplied"
elif [ -n "$failed_deployment_id" ]; then
  rollback_reference_time=$(jq -r --arg needle "deployment ${failed_deployment_id} deployment failed" '[.[]? | select(.message | contains($needle)) | .createdAt][0] // ""' <<<"$failure_events_json")
  if [ -n "$rollback_reference_time" ]; then
    rollback_reference_label="deployment failed"
  fi
fi

if [ -z "$rollback_reference_time" ] && [ "$has_failure_events" = "true" ]; then
  rollback_reference_time=$(jq -r '[.[]? | select(.message | test("rolling back to deployment"; "i")) | .createdAt][0] // ""' <<<"$failure_events_json")
  if [ -n "$rollback_reference_time" ]; then
    rollback_reference_label="rolling back"
  fi
fi

if [ -z "$rollback_reference_time" ] && [ "$has_failure_events" = "true" ]; then
  rollback_reference_time=$(jq -r '[.[]? | select(.message | test("unable to place|insufficient memory|insufficient cpu"; "i")) | .createdAt][0] // ""' <<<"$failure_events_json")
  if [ -n "$rollback_reference_time" ]; then
    rollback_reference_label="placement failure"
  fi
fi

if [ -z "$rollback_reference_time" ] && [ "$has_failure_events" = "true" ]; then
  rollback_reference_time=$(jq -r '.[0].createdAt // ""' <<<"$failure_events_json")
  if [ -n "$rollback_reference_time" ]; then
    rollback_reference_label="first retained failure event"
  fi
fi

have_python3="false"
if have_cmd python3; then
  have_python3="true"
fi

rollback_start_utc=""
rollback_end_utc=""
rollback_target_utc=""
rollback_target_epoch=""

if [ -n "$rollback_reference_time" ] && [ "$have_python3" = "true" ]; then
  rollback_window_json=$(build_time_window_json "$rollback_reference_time")
  rollback_start_utc=$(jq -r '.startUtc' <<<"$rollback_window_json")
  rollback_end_utc=$(jq -r '.endUtc' <<<"$rollback_window_json")
  rollback_target_utc=$(jq -r '.targetUtc' <<<"$rollback_window_json")
  rollback_target_epoch=$(jq -r '.targetEpoch' <<<"$rollback_window_json")
fi

cluster_container_instances_json='{"containerInstances":[]}'
cluster_total=0
cluster_under_required=0
cluster_eligible_instances=0
cluster_theoretical_placements=0
cluster_avg_registered_memory=0
cluster_avg_registered_cpu=0
cluster_avg_remaining_memory=0

if [ "$launch_type" = "EC2" ]; then
  cluster_container_instances_list_json=$(aws ecs list-container-instances \
    --region "$region" \
    --cluster "$cluster" \
    --output json \
    --no-cli-pager)

  mapfile -t cluster_container_instances < <(jq -r '.containerInstanceArns[]?' <<<"$cluster_container_instances_list_json")

  if [ "${#cluster_container_instances[@]}" -gt 0 ]; then
    cluster_container_instances_json=$(describe_container_instances_all "${cluster_container_instances[@]}")
    cluster_total=$(jq '.containerInstances | length' <<<"$cluster_container_instances_json")
    cluster_avg_registered_memory=$(jq -r 'if (.containerInstances | length) == 0 then 0 else (([.containerInstances[] | ([.registeredResources[] | select(.name == "MEMORY") | .integerValue] | first // 0)] | add) / (.containerInstances | length) | floor) end' <<<"$cluster_container_instances_json")
    cluster_avg_registered_cpu=$(jq -r 'if (.containerInstances | length) == 0 then 0 else (([.containerInstances[] | ([.registeredResources[] | select(.name == "CPU") | .integerValue] | first // 0)] | add) / (.containerInstances | length) | floor) end' <<<"$cluster_container_instances_json")
    cluster_avg_remaining_memory=$(jq -r 'if (.containerInstances | length) == 0 then 0 else (([.containerInstances[] | ([.remainingResources[] | select(.name == "MEMORY") | .integerValue] | first // 0)] | add) / (.containerInstances | length) | floor) end' <<<"$cluster_container_instances_json")

    if [ "$required_memory" -gt 0 ]; then
      cluster_under_required=$(jq --argjson required "$required_memory" '[.containerInstances[] | ([.remainingResources[] | select(.name == "MEMORY") | .integerValue] | first // 0) | select(. < $required)] | length' <<<"$cluster_container_instances_json")
      cluster_eligible_instances=$(jq --argjson required "$required_memory" '[.containerInstances[] | ([.remainingResources[] | select(.name == "MEMORY") | .integerValue] | first // 0) | select(. >= $required)] | length' <<<"$cluster_container_instances_json")
      cluster_theoretical_placements=$(jq --argjson required "$required_memory" 'if $required <= 0 then 0 else ([.containerInstances[] | (([.remainingResources[] | select(.name == "MEMORY") | .integerValue] | first // 0) / $required | floor)] | add) end' <<<"$cluster_container_instances_json")
    fi
  fi
fi

print_section "Service"
printf "service: %s\n" "$service"
printf "cluster: %s\n" "$cluster"
printf "region: %s\n" "$region"
printf "status: %s\n" "$service_status"
printf "launch type: %s\n" "$launch_type"
printf "desired/running/pending: %s/%s/%s\n" "$desired_count" "$running_count" "$pending_count"
printf "deployment max/min healthy percent: %s/%s\n" "$deployment_max_percent" "$deployment_min_healthy_percent"
printf "max extra tasks during rollout: %s\n" "$max_extra_tasks_during_rollout"
printf "current task definition: %s\n" "$current_task_definition"
printf "task family: %s\n" "$task_family"
if [ "$required_memory" -gt 0 ]; then
  printf "container memory requirement: %s MiB\n" "$required_memory"
fi

stopped_task_arns_json=$(aws ecs list-tasks \
  --region "$region" \
  --cluster "$cluster" \
  --service-name "$service" \
  --desired-status STOPPED \
  --output json \
  --no-cli-pager)

mapfile -t stopped_task_arns < <(jq -r '.taskArns[]?' <<<"$stopped_task_arns_json")

all_stopped_tasks_json='[]'
recent_context_tasks_json='[]'
failure_tasks_json='[]'
has_failure_tasks="false"

if [ "${#stopped_task_arns[@]}" -gt 0 ]; then
  describe_tasks_json=$(aws ecs describe-tasks \
    --region "$region" \
    --cluster "$cluster" \
    --tasks "${stopped_task_arns[@]}" \
    --output json \
    --no-cli-pager)

  all_stopped_tasks_json=$(jq '
    [
      .tasks[]
      | {
          taskArn,
          taskId: (.taskArn | split("/")[-1]),
          taskDefinitionArn,
          taskDefinitionRevision: (.taskDefinitionArn | split(":")[-1]),
          startedBy: (.startedBy // ""),
          createdAt,
          pullStartedAt,
          startedAt,
          stoppedAt,
          stoppedReason: (.stoppedReason // ""),
          exitCode: (.containers[0].exitCode // null),
          containerReason: (.containers[0].reason // null)
        }
    ]
    | sort_by(.stoppedAt // .createdAt)
    | reverse
  ' <<<"$describe_tasks_json")

  recent_context_tasks_json=$(jq --argjson limit "$limit" '.[0:$limit]' <<<"$all_stopped_tasks_json")

  failure_tasks_json=$(jq --arg current_td "$current_task_definition" --arg failed_id "$failed_deployment_id" --arg target_rev "$target_task_def_rev" --argjson limit "$limit" '
    [
      .[]
      | . + {
          matchesFailedDeployment: ($failed_id != "" and .startedBy == $failed_id),
          matchesTargetRevision: ($target_rev != "" and .taskDefinitionRevision == $target_rev),
          nonCurrentTaskDefinition: (.taskDefinitionArn != $current_td)
        }
      | select(
          if $failed_id != "" or $target_rev != "" then
            .matchesFailedDeployment or .matchesTargetRevision
          else
            .nonCurrentTaskDefinition
          end
        )
    ]
    | .[0:$limit]
  ' <<<"$all_stopped_tasks_json")

  if [ "$(jq 'length' <<<"$failure_tasks_json")" -gt 0 ]; then
    has_failure_tasks="true"
  fi
fi

print_section "Failure Evidence"
if [ "$has_failure_events" = "true" ]; then
  print_success "events:"
  jq -r '.[] | "- \(.createdAt) | \(.message)"' <<<"$failure_events_json"
else
  print_warning "No retained failure events found in current ECS service history."
fi

if [ "$has_failure_tasks" = "true" ]; then
  print_success "stopped tasks:"
  jq -r '.[] |
    "- task=\(.taskId) | td=\(.taskDefinitionArn | split("/")[-1]) | startedBy=\(.startedBy // "None") | pullStartedAt=\(.pullStartedAt // "None") | startedAt=\(.startedAt // "None") | exit=\(.exitCode // "None") | containerReason=\(.containerReason // "None") | stoppedReason=\(.stoppedReason // "None")"' <<<"$failure_tasks_json"
else
  if [ -n "$failed_deployment_id" ] || [ -n "$target_task_def_rev" ]; then
    print_warning "No stopped tasks matched the targeted deployment or task definition revision. ECS may no longer retain that rollout's stopped tasks."
  else
    print_warning "No stopped tasks from a non-current task definition were found."
  fi
fi

print_section "Recent Service Activity (Context)"
if [ "$(jq 'length' <<<"$recent_context_events_json")" -gt 0 ]; then
  jq -r '.[] | "- \(.createdAt) | \(.message)"' <<<"$recent_context_events_json"
else
  printf "No recent non-failure service activity was retained.\n"
fi

print_section "Recent Stopped Tasks (Context)"
if [ "$(jq 'length' <<<"$recent_context_tasks_json")" -eq 0 ]; then
  printf "No stopped tasks found for this service.\n"
else
  jq -r '.[] |
    "- task=\(.taskId) | td=\(.taskDefinitionArn | split("/")[-1]) | startedBy=\(.startedBy // "None") | pullStartedAt=\(.pullStartedAt // "None") | startedAt=\(.startedAt // "None") | exit=\(.exitCode // "None") | containerReason=\(.containerReason // "None") | stoppedReason=\(.stoppedReason // "None")"' <<<"$recent_context_tasks_json"
fi

if [ "$launch_type" = "EC2" ]; then
  print_section "Current Cluster Headroom"
  if [ "$cluster_total" -eq 0 ]; then
    print_warning "No EC2 container instances found in cluster."
  else
    printf "container instances: %s\n" "$cluster_total"
    if [ "$cluster_avg_registered_memory" -gt 0 ]; then
      printf "avg registered memory per instance: %s MiB\n" "$cluster_avg_registered_memory"
    fi
    if [ "$cluster_avg_registered_cpu" -gt 0 ]; then
      printf "avg registered cpu per instance: %s units\n" "$cluster_avg_registered_cpu"
    fi
    if [ "$cluster_avg_remaining_memory" -gt 0 ]; then
      if [ "$required_memory" -gt 0 ] && [ "$cluster_avg_remaining_memory" -lt "$required_memory" ]; then
        print_warning "avg remaining memory per instance right now: ${cluster_avg_remaining_memory} MiB"
      else
        printf "avg remaining memory per instance right now: %s MiB\n" "$cluster_avg_remaining_memory"
      fi
    fi
    if [ "$required_memory" -gt 0 ]; then
      if [ "$max_extra_tasks_during_rollout" -gt 0 ] && [ "$cluster_eligible_instances" -lt "$max_extra_tasks_during_rollout" ]; then
        print_warning "eligible instances for a ${required_memory} MiB task right now: ${cluster_eligible_instances}/${cluster_total}"
      else
        print_success "eligible instances for a ${required_memory} MiB task right now: ${cluster_eligible_instances}/${cluster_total}"
      fi
      printf "instances below %s MiB free right now: %s/%s\n" "$required_memory" "$cluster_under_required" "$cluster_total"
      if [ "$max_extra_tasks_during_rollout" -gt 0 ] && [ "$cluster_theoretical_placements" -lt "$max_extra_tasks_during_rollout" ]; then
        print_warning "theoretical placements right now (memory only): ${cluster_theoretical_placements}"
      else
        print_success "theoretical placements right now (memory only): ${cluster_theoretical_placements}"
      fi
    fi
    if [ "$max_extra_tasks_during_rollout" -gt 0 ]; then
      printf "max extra tasks allowed during rollout: %s\n" "$max_extra_tasks_during_rollout"
    fi
  fi

  print_section "Rollback Window"
  if [ -n "$rollback_reference_time" ]; then
    printf "reference event: %s\n" "$rollback_reference_label"
    printf "reference time: %s\n" "$rollback_reference_time"
    if [ -n "$rollback_start_utc" ] && [ -n "$rollback_end_utc" ]; then
      printf "metric window (UTC): %s to %s\n" "$rollback_start_utc" "$rollback_end_utc"
    elif [ "$have_python3" != "true" ]; then
      print_warning "python3 not found, so historical metric windows cannot be calculated."
    fi
  else
    print_warning "No rollback reference event found in recent ECS service events."
  fi

  print_section "Rollback-Time Cluster Signals"
  if [ -n "$rollback_start_utc" ] && [ -n "$rollback_end_utc" ]; then
    asg_name=$(aws autoscaling describe-auto-scaling-groups \
      --region "$region" \
      --output json \
      --no-cli-pager | jq -r --arg cluster "$cluster" '[.AutoScalingGroups[] | select(any(.Tags[]?; .Key == "aws:cloudformation:stack-name" and (.Value | contains($cluster)))) | .AutoScalingGroupName][0] // ""')

    asg_inservice=""
    asg_desired=""
    asg_pending=""

    if [ -n "$asg_name" ]; then
      asg_inservice_point=$(get_metric_point "AWS/AutoScaling" "GroupInServiceInstances" "Average" "Name=AutoScalingGroupName,Value=$asg_name")
      asg_desired_point=$(get_metric_point "AWS/AutoScaling" "GroupDesiredCapacity" "Average" "Name=AutoScalingGroupName,Value=$asg_name")
      asg_pending_point=$(get_metric_point "AWS/AutoScaling" "GroupPendingInstances" "Average" "Name=AutoScalingGroupName,Value=$asg_name")

      [ -n "$asg_inservice_point" ] && asg_inservice=${asg_inservice_point%%|*}
      [ -n "$asg_desired_point" ] && asg_desired=${asg_desired_point%%|*}
      [ -n "$asg_pending_point" ] && asg_pending=${asg_pending_point%%|*}

      printf "asg: %s\n" "$asg_name"
      [ -n "$asg_inservice" ] && printf "asg in-service near rollback: %s\n" "$asg_inservice"
      [ -n "$asg_desired" ] && printf "asg desired near rollback: %s\n" "$asg_desired"
      [ -n "$asg_pending" ] && printf "asg pending near rollback: %s\n" "$asg_pending"
    else
      print_warning "No matching autoscaling group found for cluster tag lookup."
    fi

    ci_memory_reserved_point=$(get_metric_point "ECS/ContainerInsights" "MemoryReserved" "Average" "Name=ClusterName,Value=$cluster")
    ci_memory_utilized_point=$(get_metric_point "ECS/ContainerInsights" "MemoryUtilized" "Average" "Name=ClusterName,Value=$cluster")
    ci_cpu_reserved_point=$(get_metric_point "ECS/ContainerInsights" "CpuReserved" "Average" "Name=ClusterName,Value=$cluster")
    ci_cpu_utilized_point=$(get_metric_point "ECS/ContainerInsights" "CpuUtilized" "Average" "Name=ClusterName,Value=$cluster")
    ecs_memory_reservation_point=$(get_metric_point "AWS/ECS" "MemoryReservation" "Average" "Name=ClusterName,Value=$cluster")
    ecs_cpu_reservation_point=$(get_metric_point "AWS/ECS" "CPUReservation" "Average" "Name=ClusterName,Value=$cluster")

    rollback_estimated_memory_headroom=""
    rollback_estimate_source=""
    rollback_estimated_avg_free_memory_per_host=""

    if [ -n "$ci_memory_reserved_point" ] || [ -n "$ci_memory_utilized_point" ]; then
      printf "metric source: ECS/ContainerInsights\n"

      [ -n "$ci_memory_reserved_point" ] && printf "memory reserved near rollback: %s MiB\n" "${ci_memory_reserved_point%%|*}"
      [ -n "$ci_memory_utilized_point" ] && printf "memory utilized near rollback: %s MiB\n" "${ci_memory_utilized_point%%|*}"
      [ -n "$ci_cpu_reserved_point" ] && printf "cpu reserved near rollback: %s units\n" "${ci_cpu_reserved_point%%|*}"
      [ -n "$ci_cpu_utilized_point" ] && printf "cpu utilized near rollback: %s units\n" "${ci_cpu_utilized_point%%|*}"
      print_warning "note: Container Insights values are shown as raw signals only and are not used directly for slot estimates."
    fi

    if [ -n "$ecs_memory_reservation_point" ] || [ -n "$ecs_cpu_reservation_point" ]; then
      printf "metric source for headroom estimate: AWS/ECS\n"
      [ -n "$ecs_memory_reservation_point" ] && printf "memory reservation near rollback: %s%%\n" "${ecs_memory_reservation_point%%|*}"
      [ -n "$ecs_cpu_reservation_point" ] && printf "cpu reservation near rollback: %s%%\n" "${ecs_cpu_reservation_point%%|*}"

      if [ -n "$asg_inservice" ] && [ "$cluster_avg_registered_memory" -gt 0 ] && [ -n "$ecs_memory_reservation_point" ]; then
        rollback_estimated_memory_capacity=$(awk -v instances="$asg_inservice" -v per_instance="$cluster_avg_registered_memory" 'BEGIN { printf "%.0f", instances * per_instance }')
        rollback_estimated_memory_headroom=$(awk -v capacity="$rollback_estimated_memory_capacity" -v reservation="${ecs_memory_reservation_point%%|*}" 'BEGIN { value = capacity * (100 - reservation) / 100; if (value < 0) value = 0; printf "%.0f", value }')
        rollback_estimated_avg_free_memory_per_host=$(awk -v headroom="$rollback_estimated_memory_headroom" -v instances="$asg_inservice" 'BEGIN { if (instances <= 0) { print 0 } else { printf "%.0f", headroom / instances } }')
        rollback_estimate_source="AWS/ECS"
        printf "estimated memory capacity near rollback: %s MiB\n" "$rollback_estimated_memory_capacity"
        printf "estimated aggregate free memory near rollback: %s MiB\n" "$rollback_estimated_memory_headroom"
        if [ "$required_memory" -gt 0 ] && [ "$rollback_estimated_avg_free_memory_per_host" -lt "$required_memory" ]; then
          print_warning "estimated avg free memory per in-service host near rollback: ${rollback_estimated_avg_free_memory_per_host} MiB"
        else
          printf "estimated avg free memory per in-service host near rollback: %s MiB\n" "$rollback_estimated_avg_free_memory_per_host"
        fi
        if [ "$required_memory" -gt 0 ]; then
          printf "task requires per-host free memory of: %s MiB\n" "$required_memory"
          print_warning "note: aggregate free memory does not guarantee ECS can place the task on individual hosts."
        fi
      fi
    elif [ -z "$ci_memory_reserved_point" ] && [ -z "$ci_memory_utilized_point" ]; then
      print_warning "No historical cluster metrics were available for the rollback window."
    fi
  else
    print_warning "Historical rollback-time metrics unavailable without a rollback reference timestamp."
  fi
fi

likely_cause="unknown"
conclusion_lines=()
failure_started_count=0
failure_exit_count=0
failure_pull_count=0
failure_evidence_available="false"

if [ "$has_failure_events" = "true" ] || [ "$has_failure_tasks" = "true" ]; then
  failure_evidence_available="true"
fi

if [ "$has_failure_events" = "true" ] && printf "%s" "$failure_event_messages" | grep -Eqi 'unable to place|insufficient memory|insufficient cpu|no container instance met all of its requirements'; then
  likely_cause="capacity"
  conclusion_lines+=("Retained ECS failure events show the scheduler could not place tasks on the cluster.")
elif [ "$has_failure_events" = "true" ] && printf "%s" "$failure_event_messages" | grep -Eqi 'CannotPullContainerError|pull access denied|toomanyrequests'; then
  likely_cause="image-pull"
  conclusion_lines+=("Retained ECS failure events point to an image pull failure before the container started.")
elif [ "$has_failure_events" = "true" ] && printf "%s" "$failure_event_messages" | grep -Eqi 'failed container health checks|failed elb health checks|health checks failed|is unhealthy in \(target-group|unhealthy in \(target-group'; then
  likely_cause="health-check"
  conclusion_lines+=("Retained ECS failure events point to tasks starting but failing health checks.")
fi

if [ "$has_failure_tasks" = "true" ]; then
  failure_started_count=$(jq '[.[] | select(.startedAt != null)] | length' <<<"$failure_tasks_json")
  failure_exit_count=$(jq '[.[] | select(.exitCode != null)] | length' <<<"$failure_tasks_json")
  failure_pull_count=$(jq '[.[] | select(.pullStartedAt != null)] | length' <<<"$failure_tasks_json")
fi

if [ "$likely_cause" = "health-check" ] && [ "$failure_started_count" -eq 0 ] && [ "$has_failure_tasks" = "true" ]; then
  likely_cause="infrastructure-before-start"
  conclusion_lines=("Targeted failure tasks never reached RUNNING, so this does not look like a health-check failure.")
fi

if [ "$likely_cause" = "unknown" ] && [ "$has_failure_tasks" = "true" ]; then
  if [ "$failure_started_count" -gt 0 ] && [ "$failure_exit_count" -gt 0 ]; then
    likely_cause="application"
    conclusion_lines+=("Targeted failure tasks reached RUNNING and exited with container exit codes.")
  elif [ "$failure_started_count" -eq 0 ] && [ "$failure_pull_count" -eq 0 ]; then
    likely_cause="infrastructure-before-start"
    conclusion_lines+=("Targeted failure tasks never started and never began image pull, so the failure happened before application startup.")
  elif [ "$failure_started_count" -eq 0 ]; then
    likely_cause="infrastructure-before-start"
    conclusion_lines+=("Targeted failure tasks never reached RUNNING, so the failure happened before application startup.")
  fi
fi

if [ "$failure_evidence_available" = "false" ]; then
  conclusion_lines+=("No retained failure events or targeted failure tasks were found, so the result below is contextual rather than definitive.")
  if [ -n "$target_deployment_id" ] || [ -n "$target_task_def_rev" ]; then
    conclusion_lines+=("The targeted rollout is older than the ECS event/task history retained for this service.")
  fi
  if [ -n "$target_reference_time" ]; then
    conclusion_lines+=("Historical metrics can still support a capacity hypothesis, but the original ECS failure evidence has aged out.")
  elif [ -z "$target_deployment_id" ] && [ -z "$target_task_def_rev" ]; then
    conclusion_lines+=("Re-run with -d <deployment-id>, -t <task-def-rev>, or -a <iso8601 time> to target an older rollout.")
  fi
fi

if [ "$likely_cause" = "capacity" ] && [ -n "$container_instance_id" ]; then
  container_instance_json=$(aws ecs describe-container-instances \
    --region "$region" \
    --cluster "$cluster" \
    --container-instances "$container_instance_id" \
    --output json \
    --no-cli-pager)

  ec2_instance_id=$(jq -r '.containerInstances[0].ec2InstanceId // "unknown"' <<<"$container_instance_json")
  running_tasks_on_instance=$(jq -r '.containerInstances[0].runningTasksCount // 0' <<<"$container_instance_json")
  registered_memory=$(jq '.containerInstances[0].registeredResources' <<<"$container_instance_json" | extract_memory_value MEMORY)
  remaining_memory=$(jq '.containerInstances[0].remainingResources' <<<"$container_instance_json" | extract_memory_value MEMORY)

  print_section "Cited Container Instance"
  printf "container instance: %s\n" "$container_instance_id"
  printf "ec2 instance: %s\n" "$ec2_instance_id"
  printf "running tasks: %s\n" "$running_tasks_on_instance"
  printf "registered memory: %s MiB\n" "$registered_memory"
  printf "remaining memory: %s MiB\n" "$remaining_memory"

  if [ "$required_memory" -gt 0 ]; then
    if [ "$remaining_memory" -lt "$required_memory" ]; then
      conclusion_lines+=("The cited container instance had ${remaining_memory} MiB free, below the task's ${required_memory} MiB requirement.")
    else
      conclusion_lines+=("The cited container instance had ${remaining_memory} MiB free versus a ${required_memory} MiB task requirement.")
    fi
  fi
fi

if [ "$launch_type" = "EC2" ] && [ "$cluster_total" -gt 0 ] && [ "$required_memory" -gt 0 ] && [ "$likely_cause" != "application" ]; then
  conclusion_lines+=("Current cluster memory is tight: only ${cluster_eligible_instances}/${cluster_total} hosts can fit a ${required_memory} MiB task right now.")
  if [ "$max_extra_tasks_during_rollout" -gt 0 ] && [ "$cluster_theoretical_placements" -lt "$max_extra_tasks_during_rollout" ]; then
    conclusion_lines+=("Current theoretical placements (${cluster_theoretical_placements}) are below the rollout surge budget (${max_extra_tasks_during_rollout}) for this service.")
  fi
fi

if [ -n "${rollback_estimated_avg_free_memory_per_host:-}" ] && [ "$required_memory" -gt 0 ]; then
  if [ "$rollback_estimated_avg_free_memory_per_host" -lt "$required_memory" ]; then
    conclusion_lines+=("Estimated average free memory per in-service host near rollback from ${rollback_estimate_source:-historical metrics} was ${rollback_estimated_avg_free_memory_per_host} MiB, below the ${required_memory} MiB task requirement.")
  else
    conclusion_lines+=("Estimated average free memory per in-service host near rollback from ${rollback_estimate_source:-historical metrics} was ${rollback_estimated_avg_free_memory_per_host} MiB versus a ${required_memory} MiB task requirement.")
  fi
fi

if [ "$likely_cause" = "application" ]; then
  conclusion_lines+=("Look at container exit codes, container reasons, and CloudWatch logs next.")
elif [ "$likely_cause" = "capacity" ] || [ "$likely_cause" = "infrastructure-before-start" ]; then
  conclusion_lines+=("The failed tasks did not provide evidence of an application crash before rollback.")
fi

print_section "Conclusion"
case "$likely_cause" in
  application|image-pull|health-check)
    print_error "likely cause: $likely_cause"
    ;;
  capacity|infrastructure-before-start)
    print_warning "likely cause: $likely_cause"
    ;;
  *)
    print_warning "likely cause: $likely_cause"
    ;;
esac
if [ "${#conclusion_lines[@]}" -gt 0 ]; then
  for line in "${conclusion_lines[@]}"; do
    case "$line" in
      No\ retained*|The\ targeted\ rollout*|Historical\ metrics*|Re-run*)
        print_warning "- $line"
        ;;
      *below*|*tight*|*theoretical\ placements*)
        print_warning "- $line"
        ;;
      *)
        print_emphasis "- $line"
        ;;
    esac
  done
fi

if [ "$verbose" = "true" ]; then
  print_section "Verbose"
  printf "failed deployment id: %s\n" "${failed_deployment_id:-unknown}"
  printf "target task definition revision: %s\n" "${target_task_def_rev:-none}"
  printf "target reference time: %s\n" "${target_reference_time:-none}"
  printf "retained failure events: %s\n" "$(jq 'length' <<<"$failure_events_json")"
  printf "targeted failure tasks: %s\n" "$(jq 'length' <<<"$failure_tasks_json")"
  printf "raw failure events json:\n"
  jq '.' <<<"$failure_events_json"
fi
