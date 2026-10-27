# Implementation and Validation

## 1. Project Overview

The AWS Linux Server Operations & Incident Response project implements a single-instance cloud infrastructure environment designed to demonstrate Linux administration, operational automation, secure deployment, failure recovery and centralised monitoring.

The solution runs on Amazon EC2 using Amazon Linux 2023 in the `eu-west-2` AWS Region. AWS Systems Manager provides remote administration without inbound SSH connectivity, while a Bash-based health-check mechanism monitors selected operating-system and service conditions.

GitHub Actions provides automated code validation and controlled deployment through AWS identity federation. Amazon CloudWatch supports centralised collection of system metrics and health-check logs, with a metric filter and alarm configured to detect specified operational failures.

The project is an operational prototype intended to demonstrate practical cloud engineering skills rather than a production-grade, highly available platform.

## 2. Infrastructure Implementation

The environment was provisioned using an existing AWS account and the default VPC in the London Region.

The principal infrastructure components are:

| Component | Implementation |
|---|---|
| AWS Region | Europe (London), `eu-west-2` |
| Compute | Amazon EC2 `t3.micro` |
| Operating system | Amazon Linux 2023 |
| Storage | 8 GiB gp3 EBS volume |
| Networking | Default VPC and public subnet |
| Security group | No inbound rules |
| Remote administration | AWS Systems Manager Session Manager |
| EC2 IAM role | `project1-ec2-ssm-role` |
| Deployment IAM role | `project1-github-deployment-role` |

The absence of inbound SSH rules reduces the server's externally accessible management surface. Instead of maintaining SSH keys, administrative sessions are established through Systems Manager using IAM-based authorisation.

The EC2 role provides permissions for Systems Manager connectivity and CloudWatch Agent operation. A separate IAM role is used for GitHub Actions deployment, maintaining a distinction between instance operations and external deployment automation.

## 3. Automated Linux Health Checks

A Bash script, `scripts/server-health-check.sh`, was developed to inspect selected conditions affecting the Linux server.

The script reports system uptime and load, memory utilisation, root filesystem utilisation and the operational state of the Amazon SSM Agent.

The implementation applies an 80% root filesystem utilisation threshold. Reaching or exceeding this threshold results in a nonzero exit status. The script also reports failure when the SSM Agent service is not running.

Although CPU load and memory information are collected, these measurements are diagnostic and are not currently evaluated against failure thresholds.

The script is executed by `server-health-check.service`, configured as a systemd oneshot service. A corresponding `server-health-check.timer` initiates execution approximately every five minutes.

System journal evidence from 26 October 2026 confirmed successful executions at 20:06 and 20:11 UTC. During those executions, root filesystem utilisation was 25%, and the SSM Agent was running.

The service completed successfully and returned to its inactive state between executions, as expected for a systemd oneshot service.

## 4. Automated Testing and Continuous Integration

A Bash test suite was created under `tests/test-server-health-check.sh` to validate the health-check implementation.

The four automated test scenarios cover:

1. Healthy filesystem utilisation below the configured threshold.
2. Filesystem utilisation reaching the 80% threshold.
3. Critical filesystem utilisation above the threshold.
4. A simulated stopped SSM Agent.

The tests use mocked Linux command outputs to exercise the script's logic without requiring actual disk exhaustion or disruption of the SSM Agent.

GitHub Actions automatically validates Bash syntax and executes the tests when changes are pushed or pull requests are submitted.

The CI pipeline was successfully executed through GitHub Actions.

### Mutation Testing

A further test was performed to assess whether the automated tests could identify an implementation regression.

The disk utilisation threshold was changed from 80% to 90% in a temporary copy of the health-check script.

When the existing test suite was executed against the modified implementation, the 80% and 85% disk scenarios failed, while the healthy filesystem and stopped-agent scenarios passed.

This demonstrated that the tests could detect the specific threshold regression introduced during mutation testing.

The original version-controlled script remained unchanged.

## 5. Continuous Delivery Implementation

A separate GitHub Actions workflow was developed to deploy validated changes to the EC2 instance.

The delivery process performs the following operations:

1. Checks out the selected repository revision.
2. Validates the Bash scripts.
3. Executes the automated test suite.
4. Authenticates to AWS using GitHub OIDC.
5. Assumes a restricted deployment IAM role.
6. Invokes a custom AWS Systems Manager deployment document.
7. Downloads the selected script revision from GitHub.
8. Validates, installs and executes the updated health-check script.
9. Retrieves and reports the Systems Manager command result.

The workflow uses a full Git commit SHA to identify the source revision rather than downloading an unspecified latest version.

GitHub OIDC and AWS Security Token Service issue temporary AWS credentials without requiring long-lived AWS access keys to be stored in GitHub.

The deployment role's permissions were restricted to the designated EC2 instance and custom Systems Manager deployment document.

A live deployment was executed successfully on 26 October 2026, demonstrating that GitHub Actions could authenticate, invoke Systems Manager and install the selected script revision on the EC2 instance.

The workflow is manually triggered. Consequently, it implements controlled Continuous Delivery rather than automatic deployment on every code change.

## 6. Deployment Rollback Testing

The deployment procedure includes backup and rollback functionality intended to restore the previous script when deployment verification fails.

### 6.1 Initial Isolated Testing

An isolated rollback test was first conducted using temporary files on EC2.

The test replaced a working script with a version that intentionally returned a nonzero exit status.

During the initial execution, the expected rollback did not occur because Bash continued executing within a subshell evaluated as part of an `if` condition.

This exposed an important limitation of relying exclusively on `set -e` for error propagation.

The test was corrected to explicitly propagate the failing command's exit status. Subsequent execution confirmed that the rollback trap restored the previous script and that the restored content matched the backup.

### 6.2 Systems Manager Rollback Validation

A further rollback test was performed using AWS Systems Manager and a deployment document supporting an isolated rollback-test mode.

The procedure downloaded a pinned script revision, installed it into a temporary target and intentionally injected a failure after replacement.

The failure triggered the deployment document's rollback handler, which restored the previous script and compared the restored file against its backup.

The Systems Manager output confirmed:

```text
INJECTED FAILURE: after script replacement
Deployment failed. Restoring previous version.
ROLLBACK: previous version restored
PASS: restored file matches backup
```

The command returned exit status `42` by design, causing Systems Manager to record the execution as failed even though restoration succeeded.

This is appropriate behaviour for a failed deployment: successful rollback does not mean the attempted deployment itself succeeded.

The test confirmed the rollback mechanism for the controlled post-installation failure scenario. It did not test recovery from power loss, abrupt termination, backup corruption or every possible deployment failure.

The existing live health-check installation remained unaffected by the isolated test.

## 7. CloudWatch Monitoring

The Amazon CloudWatch Agent was installed and configured to collect EC2 resource metrics and health-check service journal entries.

The health-check log group is:

`/project1/linux/health-check`

Successful ingestion was verified by inspecting a CloudWatch log event containing:

```json
{
  "body": {
    "MESSAGE": "Health check completed successfully.",
    "_SYSTEMD_UNIT": "server-health-check.service"
  }
}
```

This confirmed that the CloudWatch Agent was forwarding output from the intended systemd unit to CloudWatch Logs.

### 7.1 Failure Metric Filter

A CloudWatch Logs metric filter named `project1-health-check-failures` was configured to detect selected health-check failure messages.

The associated metric is:

| Setting | Value |
|---|---|
| Namespace | `Project1/LinuxOperations` |
| Metric | `HealthCheckFailureCount` |
| Metric value on match | `1` |
| Statistic for alarm | Sum |
| Evaluation period | 5 minutes |

The filter was tested against representative JSON log events containing critical disk utilisation and SSM Agent failure messages.

A normal successful health-check message was also tested to confirm that it was not treated as a failure.

These tests verified the filter's ability to distinguish the specified failure conditions from normal execution.

### 7.2 End-to-End Alarm Validation

A CloudWatch alarm named `project1-health-check-failure-alarm` was configured to enter the ALARM state when the failure metric reached or exceeded one event within a five-minute evaluation period.

To validate the complete monitoring pipeline without interrupting the working server, the metric filter was temporarily modified to match successful health-check messages.

Because the systemd timer continued producing these messages, the test generated genuine log ingestion and metric activity.

The CloudWatch alarm was observed transitioning through the following states:

**OK → ALARM → OK**

This demonstrated that the log-ingestion, metric-filtering and alarm-evaluation components operated together.

After the test, the failure-detection filter was restored so that ordinary successful executions would no longer trigger the alarm.

The test verified the alarm pipeline using a controlled matching event. It did not represent an actual disk exhaustion or SSM Agent outage.

The alarm was initially configured without notification actions, meaning state changes were visible in CloudWatch but did not automatically generate an email notification.

## 8. Security Considerations

The implementation incorporates several controls intended to reduce unnecessary access and separate operational responsibilities.

The EC2 security group has no inbound access rules, and administration is performed through Systems Manager instead of SSH.

The EC2 instance and GitHub deployment workflow use separate IAM roles.

GitHub Actions authenticates through OIDC and assumes its IAM role using temporary AWS credentials. This avoids storing permanent AWS access keys in repository settings.

Systems Manager deployment permissions are restricted to the intended EC2 instance and deployment document rather than granting broad infrastructure administration permissions.

However, the deployment process ultimately executes Bash code retrieved from the GitHub repository. Repository permissions, branch protection, review of deployment revisions and control of the SSM document therefore remain important security considerations.

The project does not claim to implement a complete production deployment-governance framework.

## 9. Limitations and Future Improvements

The environment uses a single EC2 instance and therefore does not provide automatic instance replacement, fault-tolerant capacity or high availability.

The health-check script applies specific disk and SSM Agent checks but does not enforce thresholds for all reported resource metrics.

CloudWatch monitoring detects selected failure messages but does not independently detect every missed timer execution or interruption in log delivery.

The alarm was validated using a controlled log-matching test rather than a genuine infrastructure outage.

Rollback was successfully demonstrated for a controlled failure after replacement, but not for all possible recovery scenarios.

The prototype also relies partly on manually configured AWS resources. Managing IAM policies, Systems Manager documents and monitoring components through Terraform would improve repeatability and reduce configuration drift.

Further improvements could include stronger deployment approvals, missing-heartbeat alarms, SNS notifications, dedicated staging environments and additional resilience testing.

## 10. Project Outcome

The project successfully demonstrated the integration of Linux administration, automated health checks, continuous integration, manually controlled delivery, federated AWS authentication, remote deployment, controlled rollback and centralised monitoring.

Automated tests detected a threshold regression during mutation testing. GitHub Actions successfully deployed a selected revision to EC2. Systems Manager rollback testing demonstrated restoration following an injected post-installation failure. CloudWatch collected application logs and its alarm successfully transitioned from OK to ALARM and back to OK during controlled validation.

Together, these results provide practical evidence of cloud operations and DevOps engineering capabilities, while retaining clear boundaries around the prototype's reliability and production-readiness limitations.
