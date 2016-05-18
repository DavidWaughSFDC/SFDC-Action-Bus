// needed to prevent circular dependencies
global class Orc_ScheduledOrchestrationManagerHelper
{
	global static void abortAndReschedule()
	{
		Orc_ScheduledOrchestrationManager.abortAndReschedule();
	}
    
    global static Id startBatchableActionOrchestrator(Integer actionsPerBatch)
    {
        Orc_BatchableActionOrchestrator actionOrchestrator = new Orc_BatchableActionOrchestrator();
        Id batchId = database.executebatch(actionOrchestrator, actionsPerBatch);
        
        return batchId;
    }
}