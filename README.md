
# AWS Linux Server Operations & Incident Response

A hands-on AWS cloud engineering project demonstrating secure Linux administration, automated health checks, CI/CD, deployment rollback, centralised monitoring and operational incident detection.

## Project Overview

This project implements a single-instance AWS Linux operations environment designed to demonstrate practical infrastructure management, automation, testing, secure deployment and failure monitoring.

The environment runs on Amazon EC2 with Amazon Linux 2023. AWS Systems Manager provides remote administration without requiring inbound SSH access.

GitHub Actions automates testing and supports controlled application-script deployment using AWS IAM OIDC federation.

Amazon CloudWatch provides centralised system metrics, health-check logs and failure detection.

## Architecture

```text
                    GitHub Repository
                           |
               +-----------+-----------+
               |                       |
          CI Workflow             CD Workflow
               |                       |
        Bash validation          Bash validation
        Automated tests          Automated tests
                                       |
                                  GitHub OIDC
                                       |
                                    AWS STS
                                       |
                                Deployment IAM Role
                                       |
                              Systems Manager
                                 Run Command
                                       |
                                       v
                              Amazon EC2 Instance
                                       |
                    +------------------+------------------+
                    |                                     |
              Bash Health Check                    CloudWatch Agent
                    |                                     |
              systemd Service                      Metrics and Logs
                    |                                     |
              systemd Timer                       CloudWatch Logs
                    |                                     |
              Every ~5 minutes                    Metric Filter
                                                          |
                                                    CloudWatch Alarm
```

## AWS Infrastructure

| Component | Implementation |
|-----------|----------------|
| AWS Region | eu-west-2 (London) |
| Compute | Amazon EC2 t3.micro |
| Operating system | Amazon Linux 2023 |
| Storage | 8 GiB gp3 EBS |
| Networking | Default VPC and public subnet |
| Security group | No inbound rules |
| Administration | AWS Systems Manager Session Manager |
| EC2 IAM role | Systems Manager and CloudWatch Agent permissions |
| Deployment IAM role | Restricted GitHub OIDC role |

The implementation is a single-instance operational prototype rather than a highly available production platform.

## Linux Health Monitoring

The Bash health-check script reports:

- System uptime and load
- Memory utilisation
- Root filesystem utilisation
- AWS Systems Manager Agent status

The script returns a nonzero exit status when root filesystem utilisation reaches 80% or the SSM Agent check fails.

A systemd oneshot service and timer execute the script approximately every five minutes.

## Continuous Integration

GitHub Actions automatically validates the Bash implementation and executes four automated test scenarios:

1. Healthy filesystem utilisation
2. Disk usage at the 80% threshold
3. Critical disk utilisation
4. Stopped SSM Agent

Mutation testing was also performed by changing the disk threshold from 80% to 90% in a temporary script copy.

The automated tests identified the regression, demonstrating their ability to detect an incorrect threshold implementation.

## Continuous Delivery

A separate GitHub Actions workflow supports manually initiated deployment to EC2.

The workflow:

1. Checks out the selected commit.
2. Validates Bash syntax.
3. Executes automated tests.
4. Authenticates to AWS through GitHub OIDC.
5. Assumes a restricted IAM deployment role.
6. Invokes an AWS Systems Manager deployment document.
7. Installs and validates the selected script revision.

A live deployment completed successfully.

The deployment is manually triggered rather than automatically executed on every push to the repository.

## Rollback Validation

The deployment procedure backs up the current health-check script before replacing it.

Rollback was validated through AWS Systems Manager using an isolated deployment target on the existing EC2 instance.

The test performed the following sequence:

1. Downloaded a pinned GitHub revision.
2. Installed the revision into a temporary target.
3. Injected a failure after replacement.
4. Triggered the deployment rollback handler.
5. Restored the original script.
6. Verified that the restored file matched the backup.

Systems Manager returned exit status 42 because the failure was intentionally injected.

The command output confirmed successful restoration:

```text
INJECTED FAILURE: after script replacement
Deployment failed. Restoring previous version.
ROLLBACK: previous version restored
PASS: restored file matches backup
```

This validates the specific post-installation failure and recovery path tested. It does not guarantee recovery from power loss, forced termination or backup corruption.

## CloudWatch Monitoring and Alarm Validation

The Amazon CloudWatch Agent collects EC2 system metrics and forwards health-check journal entries to:

`/project1/linux/health-check`

A CloudWatch Logs metric filter named `project1-health-check-failures` detects selected critical disk utilisation and SSM Agent failure messages.

Its associated alarm is:

`project1-health-check-failure-alarm`

### Filter Testing

The metric filter was tested using representative JSON log events for:

- Critical disk utilisation
- SSM Agent failure
- Successful health-check execution

The failure events matched the filter, while the successful execution was excluded.

### End-to-End Alarm Testing

The complete CloudWatch detection pipeline was tested using a temporary filter pattern matching successful health-check messages.

The observed alarm state transitions were:

```text
OK → ALARM → OK
```

This confirmed that:

1. The CloudWatch Agent forwarded health-check log events.
2. The metric filter generated matching metric datapoints.
3. CloudWatch evaluated the alarm threshold.
4. The alarm entered the ALARM state.
5. The alarm subsequently returned to OK.

The original failure-detection filter was restored after testing.

The test validated the monitoring pipeline without requiring a real infrastructure failure.

## Security Design

The implementation uses several security controls:

- No inbound SSH access
- EC2 management through AWS Systems Manager
- Separate IAM roles for EC2 operations and GitHub deployment
- Temporary AWS credentials through OIDC
- Restricted deployment permissions for the designated EC2 instance and SSM document
- No permanent AWS access keys stored in GitHub

Repository integrity, approved deployment revisions and access to the AWS configuration remain important security considerations.

## Repository Structure

```text
.github/workflows/     CI, OIDC and deployment workflows
scripts/               Linux health-check script
tests/                 Automated Bash test suite
systemd/               Health-check service and timer
ssm/                   Deployment and rollback documents
cloudwatch/            CloudWatch Agent configuration
docs/                  Infrastructure and test documentation
README.md              Project overview
```

## Documentation

- [Infrastructure baseline](docs/infrastructure-baseline.md)
- [Implementation and validation](docs/implementation-and-validation.md)

## Known Limitations

- Single EC2 instance without high availability
- No automatic EC2 instance replacement
- CPU and memory are reported but not evaluated against failure thresholds
- CloudWatch alarms monitor selected messages, not every possible failure
- Missing scheduled health-check executions are not independently detected
- Rollback has not been tested against every potential failure condition
- AWS IAM and SSM configuration is not fully managed through infrastructure as code
- Production deployments require stronger branch protection and release approvals

## Future Improvements

- Terraform infrastructure provisioning
- Stronger deployment approval controls
- Missing-heartbeat monitoring
- SNS incident notifications
- Dedicated staging environment
- Expanded automated deployment and resilience tests

## Skills Demonstrated

AWS EC2 | IAM | Systems Manager | CloudWatch | Linux | Bash | systemd | Git | GitHub Actions | OIDC | CI/CD | Monitoring | Incident Response

