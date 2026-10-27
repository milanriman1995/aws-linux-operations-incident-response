Implementation and validation

Project overview

This project implements a Linux server operations environment on AWS, combining secure administration, automated health checks, continuous integration, controlled deployment, rollback testing and centralised monitoring.

The prototype uses a single Amazon EC2 instance running Amazon Linux 2023 in the London (eu-west-2) Region. AWS Systems Manager provides remote administration and command execution without requiring inbound SSH access.

The project demonstrates operational engineering practices on a single-instance system rather than a highly available production architecture.

Architecture

The implementation uses:

Amazon EC2: Hosts the Linux environment and health-check script.

AWS IAM: Separates EC2 management permissions from GitHub deployment permissions.

AWS Systems Manager: Provides Session Manager access and remote command execution.

systemd: Runs the health check through a scheduled timer.

GitHub Actions: Provides automated testing and manually triggered deployment.

GitHub OIDC and AWS STS: Exchange federated identity tokens for temporary deployment credentials.

Amazon CloudWatch: Collects system metrics and journal logs and evaluates health-check failure conditions.

Automated Linux health checks

The Bash health-check script reports system uptime, memory utilisation, root filesystem utilisation and SSM Agent status.

A disk utilisation threshold of 80% is used to identify unhealthy filesystem conditions. The script also returns a failure status when the SSM Agent is not running.

A systemd oneshot service executes the script, with a timer configured to run approximately every five minutes.

During validation, journal records showed successful executions at 20:06 and 20:11 UTC on 26 October 2026. The root filesystem was at 25% utilisation, and the SSM Agent was running.

Continuous integration

The GitHub Actions CI workflow validates Bash syntax and runs four automated test scenarios, covering healthy disk utilisation, threshold behaviour, critical disk utilisation and failure of the SSM Agent check.

Mutation testing was also performed by changing the disk threshold in a temporary copy of the script from 80% to 90%.

The automated tests correctly detected the regression: the 80% and 85% scenarios failed against the modified implementation.

This demonstrates that the tests are capable of detecting at least one meaningful implementation defect.

Continuous delivery

A separate GitHub Actions workflow provides manually triggered deployment to EC2.

The workflow validates the Bash scripts, executes automated tests, authenticates to AWS through OIDC and invokes a restricted Systems Manager deployment document.

The deployment document downloads a script from an identified Git commit, validates its syntax, backs up the existing version, installs the replacement and executes a health check.

A live deployment completed successfully on 26 October 2026.

Deployment remains manually triggered; changes pushed to GitHub do not automatically deploy to EC2.

Rollback validation

Rollback testing was performed in two stages.

First, an isolated Bash test demonstrated that a failure after script replacement could activate an EXIT trap and restore the previous version.

The initial test uncovered a Bash error-handling issue: using set -e inside a subshell evaluated by an if statement did not terminate execution as expected. Explicit failure propagation corrected this behaviour.

Second, a Systems Manager rollback-test mode executed the deployment procedure against temporary files on EC2.

The test downloaded and installed a pinned script, injected an exit status of 42 after replacement, restored the previous file and verified that the restored content matched its backup.

The command returned a nonzero status by design. The Systems Manager output confirmed successful restoration.

This validates rollback under the tested failure condition. It does not establish recovery from power loss, abrupt termination or unsuccessful backup restoration.

CloudWatch monitoring

The CloudWatch Agent collects EC2 resource metrics and forwards systemd journal messages from server-health-check.service to the log group:

/project1/linux/health-check

Successful log ingestion was verified using an event containing Health check completed successfully. and the associated systemd unit metadata.

A CloudWatch Logs metric filter was configured to detect critical disk utilisation messages and SSM Agent failure messages.

The filter was tested using representative JSON events for both failures and a successful execution.

A CloudWatch alarm named project1-health-check-failure-alarm was created for the resulting HealthCheckFailureCount metric.

Evidence limitation: The filter's sample-event matching has been verified. An actual transition into the ALARM state has not yet been confirmed from alarm history.

Security considerations

The EC2 instance is managed through Systems Manager without an inbound SSH security group rule.

The instance and GitHub deployment workflow use separate IAM roles. GitHub obtains temporary AWS credentials through OIDC rather than storing long-lived AWS access keys.

The deployment role is restricted to a designated EC2 instance and custom Systems Manager document.

The deployment procedure still executes repository-hosted Bash code, so repository access controls and review of the selected commit remain important security boundaries.

Known limitations

This implementation uses a single EC2 instance and does not provide automatic instance replacement or high availability.

The health-check script reports memory and system load but does not apply CPU or memory failure thresholds.

Monitoring detects specific failure messages but does not comprehensively detect missing executions or CloudWatch Agent failures.

The rollback mechanism has been validated under controlled conditions, not against every possible infrastructure failure.

The deployment document and its IAM policy were configured in AWS separately from the source code. A future improvement would manage these resources through infrastructure as code to prevent configuration drift.

Outcome

The project demonstrates secure Linux administration, scheduled operational checks, automated testing, controlled AWS deployment, fault-injection testing, basic recovery and centralised observability.

It provides a foundation for further AWS infrastructure automation, application deployment and operational reliability projects.
