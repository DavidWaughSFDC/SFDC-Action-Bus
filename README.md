<a href="https://githubsfdeploy.herokuapp.com/?owner=DavidWaughSFDC&repo=sfdc-action-orchestrator">
  <img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>
#sfdc-action-orchestrator
A Salesforce continuous job that regularly executes pre-defined custom 'actions' via APEX (Salesforce's customization language)

#Starting and Stopping the Orchestration Manager
To start or stop the continously running 3-minute job that orchestrates actions, run the associated command in the [Anonomous Execution Window](https://help.salesforce.com/apex/HTViewHelpDoc?id=code_dev_console_execute_anonymous.htm&language=en "Salesforcee's Anonomous Execution Window") of the Salesforce Developer Console:

###Start Orchestration Manager Job

```java
// note: param '1' means start in 1 minute or less
Orc_ScheduledOrchestrationManager.manuallyStartJobInMinutes(1);
```

###Stop Orchestration Manager Job

```java
Orc_ScheduledOrchestrationManager.manuallyAbortJob();
```

#View Orchestration Summary

A summary of Orchestration Manager Job progress, queued items, and batch execution of queued items can be viewed by clicking on the header tab 'Orchestration Summary', or by navigating to the Salesforce-instance-relative path `/apex/Orc_OrchestrationSummary`

