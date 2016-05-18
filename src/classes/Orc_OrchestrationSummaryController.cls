public without sharing class Orc_OrchestrationSummaryController 
{
	//serializable JSON object for return to Link_Systems.page
    public class Orc_Orchestration_Summary_Page_Json
    {
        public Integer orchestrationManagerMinutesBetweenBatches = null;
        public String orchestrationManagerNextFireTime = null;
        public String orchestrationManagerState = null;
        public Integer totalActionsInQueue = 0;
        public Integer totalCreateActionsInQueue = 0;
        public Integer totalUpdateActionsInQueue = 0;

        public Integer actionsPerBatch = 0;
        public String scheduledJobStatus = null;
        public Integer currentBatchCount = 0;
        public Integer totalBatches = 0;
    }
    
    @RemoteAction
    public static Orc_Orchestration_Summary_Page_Json getSummaryPageJSON()
    {
    	Orc_Orchestration_Summary_Page_Json jsonReturn = new Orc_Orchestration_Summary_Page_Json();

       	CronTrigger cronTrigger = Orc_ScheduledOrchestrationManager.getJobStateAndNextFireTime();

        if (cronTrigger != null)
        {
        	jsonReturn.orchestrationManagerMinutesBetweenBatches = Orc_ScheduledOrchestrationManager.MINUTES_TO_NEXT_SCHEDULED_EXECUTION;
        	jsonReturn.orchestrationManagerNextFireTime = String.valueOf(cronTrigger.NextFireTime);
        	jsonReturn.orchestrationManagerState = String.valueOf(cronTrigger.State);
        }

        //query for count of pending actions
        List<AggregateResult> groupedQueuedActions = new List<AggregateResult>();        
        groupedQueuedActions = [SELECT Action__c, 
                                	COUNT(ID) Action_Count
                                FROM Orchestrated_Action_Queue__c
                                WHERE Account__r.Id != NULL
                                AND Orchestrated_Action_Log__c = NULL /*no log associated with queued action means its pending */
                                GROUP BY Action__c];

        for (AggregateResult ar : groupedQueuedActions)
        {
            String aggregatedAction = (String) ar.get('Action__c');
            if (aggregatedAction == Orc_BatchableActionOrchestrator.ACTION_ERP_ACCOUNT_CREATE && ((Integer) ar.get('Action_Count')) > 0)
            {
                jsonReturn.totalCreateActionsInQueue = (Integer) ar.get('Action_Count');
            }
            else if (aggregatedAction == Orc_BatchableActionOrchestrator.ACTION_ERP_ACCOUNT_UPDATE && ((Integer) ar.get('Action_Count')) > 0)
            {
                jsonReturn.totalUpdateActionsInQueue = (Integer) ar.get('Action_Count');
            }
        }            
        
        jsonReturn.totalActionsInQueue = jsonReturn.totalCreateActionsInQueue 
                                        + jsonReturn.totalUpdateActionsInQueue;

        Id executingBatchJobId = Orc_ScheduledOrchestrationManager.getExecutingOrchestrationManagerJobId();

        //query for in-progress batch-execution details
        if (executingBatchJobId != null)
        {
            List<AsyncApexJob> executingBatchJobs = new List<AsyncApexJob>();
            executingBatchJobs = [SELECT Id, Status, JobItemsProcessed, TotalJobItems
                                            FROM AsyncApexJob
                                            WHERE ID = :executingBatchJobId
                                            AND (Status = 'Processing' OR Status = 'Preparing')
                                            LIMIT 1];

            if (!executingBatchJobs.isEmpty())
            {
                //json response field-assignment to report on attributes of executing batch job
                jsonReturn.actionsPerBatch = Orc_ScheduledOrchestrationManager.ACTIONS_PER_BATCH;
                jsonReturn.scheduledJobStatus = executingBatchJobs[0].Status;
                jsonReturn.currentBatchCount = executingBatchJobs[0].JobItemsProcessed;
                jsonReturn.totalBatches = executingBatchJobs[0].TotalJobItems;
            }
        }
        return jsonReturn;
    }
}