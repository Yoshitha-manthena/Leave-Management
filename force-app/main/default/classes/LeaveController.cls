public with sharing class LeaveController {
    @AuraEnabled(cacheable=true)
    public static Leave_Balance__c getLeaveBalance() {
        String userId = UserInfo.getUserId();
        return [SELECT Pending_Leaves__c, Total_Allocated_Leaves__c
                FROM Leave_Balance__c
                WHERE Employee__c = :userId AND Year__c = :String.valueOf(Date.today().year())
                LIMIT 1];
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveStatus() {
        String userId = UserInfo.getUserId();
        return [SELECT Name, Status__c
                FROM Leave_Request__c
                WHERE Employee__c = :userId AND Status__c = 'Pending'];
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveHistory() {
        String userId = UserInfo.getUserId();
        return [SELECT Name, Start_Date__c, End_Date__c, Reason__c, Status__c, Approved_By__r.Name
                FROM Leave_Request__c
                WHERE Employee__c = :userId];
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getPendingLeaveRequests() {
        return [SELECT Id, Name, Employee__r.Name, Leave_Type__c, Start_Date__c, End_Date__c, Reason__c
                FROM Leave_Request__c
                WHERE Status__c = 'Pending'];
    }

    @AuraEnabled
    public static void createLeaveRequest(String leaveType, Date startDate, Date endDate, String reason, String employeeId) {
        if (startDate < Date.today() || endDate < Date.today()) {
            throw new AuraHandledException('Start and End Dates cannot be in the past.');
        }
        Leave_Request__c leave = new Leave_Request__c(
            Leave_Type__c = leaveType,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Reason__c = reason,
            Employee__c = employeeId,
            Status__c = 'Pending'
        );
        insert leave;
    }

    @AuraEnabled
    public static void updateLeaveRequest(String leaveId, String status) {
        Leave_Request__c leave = [SELECT Id, Status__c, Approved_By__c
                                 FROM Leave_Request__c
                                 WHERE Id = :leaveId LIMIT 1];
        leave.Status__c = status;
        leave.Approved_By__c = UserInfo.getUserId();
        update leave;
    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentUserId() {
        return UserInfo.getUserId();
    }
}