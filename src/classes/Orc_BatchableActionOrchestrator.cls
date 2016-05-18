global class Orc_BatchableActionOrchestrator implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts 
{
    public static final String ACTION_ERP_ACCOUNT_CREATE = 'ERP Create Account';
    public static final String ACTION_ERP_ACCOUNT_UPDATE = 'ERP Update Account';
    
    public class Orc_BatchableActionOrchestratorException extends Exception { }
    
    global List<Orchestrated_Action_Queue__c> targetQueueItems;
    global String targetQueryString = null;
    global List<String> batchIdList = null;

    global Orc_BatchableActionOrchestrator()
    {
        targetQueueItems = new List<Orchestrated_Action_Queue__c>();
        batchIdList = new List<String>();
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) 
    {
        targetQueryString =  'SELECT ID FROM Orchestrated_Action_Queue__c ' +
            					'WHERE (Account__r.ID != NULL) AND Orchestrated_Action_Log__c = NULL';

        return Database.getQueryLocator(targetQueryString);
    }
 
    global void execute(Database.BatchableContext BC, List<Orchestrated_Action_Queue__c> scope)
    {
        
    }
    
    global void finish(Database.BatchableContext BC)
    {
        Orc_ScheduledOrchestrationManagerHelper.abortAndReschedule();
    }
}