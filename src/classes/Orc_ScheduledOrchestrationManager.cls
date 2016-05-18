global class Orc_ScheduledOrchestrationManager implements Schedulable
{
	public class ScheduledOrchestrationManagerException extends Exception { }

	private static final String CLASS_NAME = 'Orc_ScheduledOrchestrationManager';

	private static final String EXECUTE_JOB_EVENT_NAME = 'Execute Orc_ScheduledOrchestrationManager Job';
    private static final String RESCHEDULE_JOB_EVENT_NAME = 'Schedule Orc_ScheduledOrchestrationManager Job';
    private static final String MANUALLY_SCHEDULE_JOB_EVENT_NAME = 'Manually Schedule Orc_ScheduledOrchestrationManager Job';
    private static final String MANUALLY_ABORT_JOB_EVENT_NAME = 'Manually Abort Orc_ScheduledOrchestrationManager Job';

    public static final Integer MINUTES_TO_NEXT_SCHEDULED_EXECUTION = 3;
    public static final Integer ACTIONS_PER_BATCH = 25;

	global void execute(SchedulableContext sc) 
	{
		Scheduled_Orchestration_Manager_Log__c orcManagerLog = new Scheduled_Orchestration_Manager_Log__c();
		orcManagerLog.Event_Name__c = EXECUTE_JOB_EVENT_NAME;
		orcManagerLog.Timestamp__c = Datetime.now();

		try
		{
			// if batch is not already executing
			if (!isBatchableActionOrchestratorAlreadyRunning())
			{
				Id batchId = Orc_ScheduledOrchestrationManagerHelper.startBatchableActionOrchestrator(ACTIONS_PER_BATCH);
				
				orcManagerLog.Was_Successful__c = true;
				orcManagerLog.Batch_Id__c = batchId;
				orcManagerLog.Message__c = 'Success';
			}
		}
		catch (Exception e)
		{
			orcManagerLog.Was_Successful__c = false;
			orcManagerLog.Message__c = e.getMessage();
		}

		insert orcManagerLog;
	}

	global static boolean isBatchableActionOrchestratorAlreadyRunning()
	{
		Boolean isRunning = false;

		List<AsyncApexJob> existingBatchableActionOrchestratorsJobs = new List<AsyncApexJob>();
		existingBatchableActionOrchestratorsJobs = [Select Id
                                                     From AsyncApexJob
                                                     Where ApexClass.Name = 'Orc_BatchableActionOrchestrator'
                                                     AND Status != 'Aborted' 
                                                     AND Status != 'Completed' 
                                                     AND Status != 'Failed'];

		if (existingBatchableActionOrchestratorsJobs.size() > 0)
		{
			isRunning = true;
		}

		return isRunning;
	}

	global static void abortAndReschedule()
	{
		//reschedule in 3 mins;
		abortJob();

		String sch = generateNextScheduleString(MINUTES_TO_NEXT_SCHEDULED_EXECUTION);
		startJob(sch, RESCHEDULE_JOB_EVENT_NAME);

		//TODO:
		//must check that duplicate jobs that snuck in (manual start) get canceled, too.
		//also check in startJob
	}

	global static ID manuallyStartJob(String sch)
	{
		return startJob(sch, MANUALLY_SCHEDULE_JOB_EVENT_NAME);
	}

	global static ID manuallyStartJobInMinutes(Integer mins)
	{
		return startJob(generateNextScheduleString(mins), MANUALLY_SCHEDULE_JOB_EVENT_NAME);
	}

	global static CronTrigger getJobStateAndNextFireTime()
	{
		CronTrigger cTrigger = null;
		ID recentJobId = getMostRecentJobId();

		if (recentJobId != null)
		{
			//Note: single-record version of this query may throw 'List has no rows for assignment to Sobject' 
			//exception, so we use list version and check for empty list case
			List<CronTrigger> ctList = [SELECT State, TimesTriggered, NextFireTime
								FROM CronTrigger WHERE Id = :recentJobId];

			if (!ctList.isEmpty())
			{
				cTrigger = ctList[0];
			}
		}

		return cTrigger;
	}

	global static void manuallyAbortJob()
	{
		if (abortJob())
		{													
			Scheduled_Orchestration_Manager_Log__c orcManagerLog = new Scheduled_Orchestration_Manager_Log__c();
			orcManagerLog.Event_Name__c = MANUALLY_ABORT_JOB_EVENT_NAME;
			orcManagerLog.Was_Successful__c = true;
			orcManagerLog.Timestamp__c = Datetime.now();

			insert orcManagerLog;
		}
	}

	/******************* PRIVATE HELPER REGION *******************/

	private static ID startJob(String sch, String eventName)
	{
		//guard condition
		if (isBatchableActionOrchestratorAlreadyRunning())
		{
			throw new ScheduledOrchestrationManagerException('Orc_ScheduledOrchestrationManager.startJob cannot run if a Orc_ScheduledOrchestrationManager job is still scheduled');
		}

		//example sch: '0 09 * * * ?'
		Orc_ScheduledOrchestrationManager orcManager = new Orc_ScheduledOrchestrationManager();
		
		ID jobId = System.schedule(CLASS_NAME, sch, orcManager);

		Scheduled_Orchestration_Manager_Log__c orcManagerLog = new Scheduled_Orchestration_Manager_Log__c();
		orcManagerLog.Event_Name__c = eventName;
		orcManagerLog.Job_ID__c = jobId;
		orcManagerLog.Was_Successful__c = true;
		orcManagerLog.Timestamp__c = Datetime.now();

		insert orcManagerLog;

		return jobId;
	}

	private static boolean abortJob()
	{
		boolean isAborted = false;
		//use list
		ID mostRecentJobId = getMostRecentJobId();

		if (mostRecentJobId != null)
		{													
			System.abortJob(mostRecentJobId);
			isAborted = true;
		}

		return isAborted;
	}

	public static ID getMostRecentJobId()
	{
		List<Scheduled_Orchestration_Manager_Log__c> mostRecentOrchestrationManagerJobs = new List<Scheduled_Orchestration_Manager_Log__c>();
		mostRecentOrchestrationManagerJobs = [SELECT Job_ID__c 
                                              	FROM Scheduled_Orchestration_Manager_Log__c 
													WHERE Event_Name__c = :MANUALLY_SCHEDULE_JOB_EVENT_NAME
													OR Event_Name__c = :RESCHEDULE_JOB_EVENT_NAME
													ORDER BY Timestamp__c DESC 
													LIMIT 1];

		ID recentJobId = null;
		if (!mostRecentOrchestrationManagerJobs.isEmpty() 
            && mostRecentOrchestrationManagerJobs[0].Job_ID__c != null)
		{
			recentJobId = Id.valueOf(mostRecentOrchestrationManagerJobs[0].Job_ID__c);
		}					

		return recentJobId;
	}

	public static ID getExecutingOrchestrationManagerJobId()
	{
		List<Scheduled_Orchestration_Manager_Log__c> lastExecutedOrchestrationManagerJobs = new List<Scheduled_Orchestration_Manager_Log__c>();
		lastExecutedOrchestrationManagerJobs = [SELECT Batch_Id__c 
                                                	FROM Scheduled_Orchestration_Manager_Log__c 
                                                	WHERE Event_Name__c = :EXECUTE_JOB_EVENT_NAME
                                                	ORDER BY Timestamp__c DESC 
                                                	LIMIT 1];

		Id returnJobId = null;
		if (!lastExecutedOrchestrationManagerJobs.isEmpty()
            && lastExecutedOrchestrationManagerJobs[0].Batch_Id__c != null)
		{
			Id executingJobId = Id.valueOf(lastExecutedOrchestrationManagerJobs[0].Batch_Id__c);

			List<AsyncApexJob> executingJobs = new List<AsyncApexJob>();
			executingJobs = [SELECT Id 
								  	FROM AsyncApexJob
								  	WHERE ID = :executingJobId
								  	AND (Status = 'Processing' OR Status = 'Preparing')
								  	LIMIT 1];

			if (!executingJobs.isEmpty()) 
			{
				returnJobId = executingJobId;
			}	
		}					

		return returnJobId;
	}

	private static String generateNextScheduleString(Integer mins)
	{
		//guard condition
		if (mins < 1)
		{
			throw new ScheduledOrchestrationManagerException('manuallyStartJobInMinutes() parameter \'mins\' must be greater than 0');
		}

		Datetime now = Datetime.now();
		
		Integer minuteToSchedule = now.minuteGmt() + mins;
		if (minuteToSchedule >= 60)
		{
		    minuteToSchedule = Math.mod(minuteToSchedule, 60);
		}
		
		//guard condition
		if (minuteToSchedule < 0 || minuteToSchedule >= 60)
		{
			throw new ScheduledOrchestrationManagerException('Scheduling string with minute value of ' + minuteToSchedule + ' is not allowed');
		}

		return '0 ' + minuteToSchedule + ' * * * ?';
	}
    
}