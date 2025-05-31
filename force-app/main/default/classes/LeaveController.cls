public with sharing class LeaveController {
    @AuraEnabled(cacheable=true)
    public static myApp202224__Leave_Balance__c getLeaveBalance() {
        String userId = UserInfo.getUserId();
        String currentYear = String.valueOf(Date.today().year());
        
        List<myApp202224__Leave_Balance__c> leaveBalances = [SELECT Id, myApp202224__Pending_Leaves__c, myApp202224__Total_Allocated_Leaves__c
                                                FROM myApp202224__Leave_Balance__c
                                                WHERE myApp202224__Employee__c = :userId AND myApp202224__Year__c = :currentYear
                                                LIMIT 1];
        
        return leaveBalances.isEmpty() ? null : leaveBalances[0];
    }

    @AuraEnabled
    public static myApp202224__Leave_Balance__c createDefaultLeaveBalance() {
        String userId = UserInfo.getUserId();
        String currentYear = String.valueOf(Date.today().year());
        
        List<myApp202224__Leave_Balance__c> existingBalances = [SELECT Id, myApp202224__Pending_Leaves__c, myApp202224__Total_Allocated_Leaves__c
                                                  FROM myApp202224__Leave_Balance__c
                                                  WHERE myApp202224__Employee__c = :userId AND myApp202224__Year__c = :currentYear
                                                  LIMIT 1];
        if (!existingBalances.isEmpty()) {
            return existingBalances[0];
        }

        Leave_Balance__c newBalance = new Leave_Balance__c(
            myApp202224__Employee__c = userId,
            myApp202224__Year__c = currentYear,
            myApp202224__Pending_Leaves__c = 24,
            myApp202224__Total_Allocated_Leaves__c = 24
        );
        insert newBalance;
        return newBalance;
    }

    @AuraEnabled
    public static String createLeaveRequest(String leaveType, Date startDate, Date endDate, String reason, String employeeId) {
        try {
            // Input validations
            if (String.isBlank(leaveType)) {
                throw new AuraHandledException('Leave Type is required.');
            }
            if (startDate == null || endDate == null) {
                throw new AuraHandledException('Start and End Dates are required.');
            }
            if (startDate < Date.today()) {
                throw new AuraHandledException('Start Date must be today or in the future.');
            }
            if (endDate < startDate) {
                throw new AuraHandledException('End Date must be on or after Start Date.');
            }
            if (String.isBlank(employeeId)) {
                throw new AuraHandledException('Employee ID is required.');
            }
            // Validate Leave Type against picklist values
            Schema.DescribeFieldResult fieldResult = Leave_Request__c.Leave_Type__c.getDescribe();
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            Set<String> validLeaveTypes = new Set<String>();
            for (Schema.PicklistEntry entry : picklistValues) {
                validLeaveTypes.add(entry.getValue());
            }
            if (!validLeaveTypes.contains(leaveType)) {
                throw new AuraHandledException('Invalid Leave Type: ' + leaveType + '. Valid types are: ' + String.join(new List<String>(validLeaveTypes), ', '));
            }
            // Create leave request
            myApp202224__Leave_Request__c leave = new myApp202224__Leave_Request__c(
                myApp202224__Leave_Type__c = leaveType,
                myApp202224__Start_Date__c = startDate,
                myApp202224__End_Date__c = endDate,
                myApp202224__Reason__c = String.isBlank(reason) ? null : reason,
                myApp202224__Employee__c = employeeId,
                myApp202224__Status__c = 'Pending'
            );
            insert leave;
            System.debug('Leave request created with ID: ' + leave.Id);
            return leave.Id;
        } catch (DmlException e) {
            String message = 'DML Error: ' + e.getDmlMessage(0);
            for (Integer i = 1; i < e.getNumDml(); i++) {
                message += '; ' + e.getDmlMessage(i);
            }
            System.debug(LoggingLevel.ERROR, 'DML Exception: ' + message);
            throw new AuraHandledException(message);
        } catch (Exception e) {
            String errorDetails = 'Error creating leave request: ' + e.getMessage() + ' at line ' + e.getLineNumber();
            System.debug(LoggingLevel.ERROR, errorDetails);
            throw new AuraHandledException(errorDetails);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<myApp202224__Leave_Request__c> getLeaveStatus() {
        String userId = UserInfo.getUserId();
        return [SELECT Id, Name, myApp202224__Status__c, myApp202224__Leave_Type__c, myApp202224__Start_Date__c, myApp202224__End_Date__c, myApp202224__Reason__c
                FROM myApp202224__Leave_Request__c
                WHERE myApp202224__Employee__c = :userId AND myApp202224__Status__c IN ('Pending', 'Auto-Approved')
                ORDER BY CreatedDate DESC];
    }

    @AuraEnabled(cacheable=true)
    public static List<myApp202224__Leave_Request__c> getLeaveHistory() {
        String userId = UserInfo.getUserId();
        return [SELECT Id, Name, myApp202224__Start_Date__c, myApp202224__End_Date__c, myApp202224__Reason__c, myApp202224__Status__c, myApp202224__Approved_By__c, myApp202224__Leave_Type__c
                FROM myApp202224__Leave_Request__c
                WHERE myApp202224__Employee__c = :userId
                ORDER BY CreatedDate DESC];
    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentUserId() {
        return UserInfo.getUserId();
    }
    @AuraEnabled(cacheable=true)
    public static List<myApp202224__Leave_Request__c> getPendingLeaveRequests() {
        try {
            String userId = UserInfo.getUserId();
            // Fetch users in the same role hierarchy or subordinates
            Set<Id> accessibleUserIds = new Set<Id>();
            for (User u : [SELECT Id FROM User WHERE ManagerId = :userId OR Id = :userId]) {
                accessibleUserIds.add(u.Id);
            }
            return [SELECT Id, Name, myApp202224__Leave_Type__c, myApp202224__Start_Date__c, myApp202224__End_Date__c, myApp202224__Reason__c, myApp202224__Status__c, myApp202224__Employee__r.Name
                    FROM myApp202224__Leave_Request__c
                    WHERE myApp202224__Employee__c IN :accessibleUserIds AND myApp202224__Status__c = 'Pending'
                    ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching pending leave requests: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateLeaveRequest(String leaveRequestId, String status, String comments) {
        try {
            if (String.isBlank(leaveRequestId)) {
                throw new AuraHandledException('Leave Request ID is required.');
            }
            if (String.isBlank(status) || !new Set<String>{'Approved', 'Rejected'}.contains(status)) {
                throw new AuraHandledException('Invalid status. Must be Approved or Rejected.');
            }
            List<myApp202224__Leave_Request__c> leaveRequests = [SELECT Id, myApp202224__Status__c, myApp202224__Leave_Type__c, myApp202224__Start_Date__c, myApp202224__End_Date__c, myApp202224__Employee__c
                                                    FROM myApp202224__Leave_Request__c
                                                    WHERE Id = :leaveRequestId AND myApp202224__Status__c = 'Pending'
                                                    LIMIT 1];
            if (leaveRequests.isEmpty()) {
                throw new AuraHandledException('Pending leave request not found.');
            }
            Leave_Request__c leave = leaveRequests[0];
            leave.myApp202224__Status__c = status;
            leave.myApp202224__Approved_By__c = UserInfo.getUserId();
            //leave.Comments__c = String.isBlank(comments) ? null : comments;
            if (status == 'Approved') {
                Integer leaveDays = leave.Start_Date__c.daysBetween(leave.End_Date__c) + 1;
                List<Leave_Balance__c> balances = [SELECT Id, myApp202224__Pending_Leaves__c
                                                  FROM myApp202224__Leave_Balance__c
                                                  WHERE myApp202224__Employee__c = :leave.myApp202224__Employee__c AND myApp202224__Year__c = :String.valueOf(Date.today().year())
                                                  LIMIT 1];
                if (balances.isEmpty()) {
                    throw new AuraHandledException('No leave balance found for employee.');
                }
                if (balances[0].myApp202224__Pending_Leaves__c < leaveDays) {
                    throw new AuraHandledException('Insufficient leave balance.');
                }
                balances[0].myApp202224__Pending_Leaves__c -= leaveDays;
                update balances;
            }
            update leave;
            System.debug('Leave request updated: ID=' + leaveRequestId + ', Status=' + status);
        } catch (DmlException e) {
            String message = 'DML Error: ' + e.getDmlMessage(0);
            for (Integer i = 1; i < e.getNumDml(); i++) {
                message += '; ' + e.getDmlMessage(i);
            }
            System.debug(LoggingLevel.ERROR, 'DML Exception in updateLeaveRequest: ' + message);
            throw new AuraHandledException(message);
        } catch (Exception e) {
            String errorDetails = 'Error updating leave request: ' + e.getMessage() + ' at line ' + e.getLineNumber();
            System.debug(LoggingLevel.ERROR, errorDetails);
            throw new AuraHandledException(errorDetails);
        }
    }
}