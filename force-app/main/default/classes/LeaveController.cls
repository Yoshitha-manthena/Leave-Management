public with sharing class LeaveController {
    @AuraEnabled(cacheable=true)
    public static Leave_Balance__c getLeaveBalance() {
        try {
            String userId = UserInfo.getUserId();
            String currentYear = String.valueOf(Date.today().year());
            List<Leave_Balance__c> leaveBalances = [SELECT Id, Pending_Leaves__c, Total_Allocated_Leaves__c
                                                    FROM Leave_Balance__c
                                                    WHERE Employee__c = :userId AND Year__c = :currentYear
                                                    LIMIT 1];
            return leaveBalances.isEmpty() ? null : leaveBalances[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leave balance: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Leave_Balance__c createDefaultLeaveBalance() {
        try {
            String userId = UserInfo.getUserId();
            String currentYear = String.valueOf(Date.today().year());
            List<Leave_Balance__c> existingBalances = [SELECT Id, Pending_Leaves__c, Total_Allocated_Leaves__c
                                                      FROM Leave_Balance__c
                                                      WHERE Employee__c = :userId AND Year__c = :currentYear
                                                      LIMIT 1];
            if (!existingBalances.isEmpty()) {
                return existingBalances[0];
            }
            Leave_Balance__c newBalance = new Leave_Balance__c(
                Employee__c = userId,
                Year__c = currentYear,
                Pending_Leaves__c = 24,
                Total_Allocated_Leaves__c = 24
            );
            insert newBalance;
            return newBalance;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating default leave balance: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createLeaveRequest(String leaveType, Date startDate, Date endDate, String reason, String employeeId) {
        try {
            // Log inputs for debugging
            System.debug('createLeaveRequest inputs: leaveType=' + leaveType + ', startDate=' + startDate + 
                         ', endDate=' + endDate + ', reason=' + reason + ', employeeId=' + employeeId);

            // Input validations
            if (String.isBlank(leaveType)) {
                throw new AuraHandledException('Leave Type is required.');
            }
            if (startDate == null) {
                throw new AuraHandledException('Start Date is required.');
            }
            if (endDate == null) {
                throw new AuraHandledException('End Date is required.');
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
            Set<String> validLeaveTypes = new Set<String>{'Sick Leave', 'Personal Leave', 'Vacation'};
            if (!validLeaveTypes.contains(leaveType)) {
                // Log available picklist values for debugging
                Schema.DescribeFieldResult fieldResult = Leave_Request__c.Leave_Type__c.getDescribe();
                List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
                List<String> picklistLabels = new List<String>();
                for (Schema.PicklistEntry entry : picklistValues) {
                    picklistLabels.add(entry.getValue());
                }
                System.debug('Valid Leave_Type__c picklist values: ' + picklistLabels);
                throw new AuraHandledException('Invalid Leave Type: ' + leaveType + '. Valid types are: ' + String.join(picklistLabels, ', '));
            }

            // Create leave request
            Leave_Request__c leave = new Leave_Request__c(
                Leave_Type__c = leaveType,
                Start_Date__c = startDate,
                End_Date__c = endDate,
                Reason__c = String.isBlank(reason) ? null : reason,
                Employee__c = employeeId,
                Status__c = 'Pending'
            );
            System.debug('Attempting to insert leave request: ' + leave);
            insert leave;
            System.debug('Leave request created with ID: ' + leave.Id + ', Type: ' + leaveType);
            return leave.Id;
        } catch (DmlException e) {
            String message = 'DML Error creating leave request: ' + e.getDmlMessage(0);
            for (Integer i = 1; i < e.getNumDml(); i++) {
                message += '; ' + e.getDmlMessage(i);
            }
            System.debug(LoggingLevel.ERROR, 'DML Exception: ' + message + ' at line ' + e.getLineNumber());
            throw new AuraHandledException(message);
        } catch (Exception e) {
            String errorDetails = 'Error creating leave request: ' + e.getMessage() + ' at line ' + e.getLineNumber();
            System.debug(LoggingLevel.ERROR, errorDetails);
            throw new AuraHandledException(errorDetails);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveStatus() {
        try {
            String userId = UserInfo.getUserId();
            return [SELECT Id, Name, Status__c, Leave_Type__c, Start_Date__c, End_Date__c, Reason__c
                    FROM Leave_Request__c
                    WHERE Employee__c = :userId AND Status__c IN ('Pending', 'Auto-Approved')
                    ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leave status: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveHistory() {
        try {
            String userId = UserInfo.getUserId();
            return [SELECT Id, Name, Start_Date__c, End_Date__c, Reason__c, Status__c, Approved_By__r.Name, Leave_Type__c
                    FROM Leave_Request__c
                    WHERE Employee__c = :userId
                    ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leave history: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentUserId() {
        try {
            return UserInfo.getUserId();
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching current user ID: ' + e.getMessage());
        }
    }
}