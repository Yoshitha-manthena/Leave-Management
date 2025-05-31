public with sharing class LeaveController {
    @AuraEnabled(cacheable=true)
    public static myApp202224__Leave_Balance__c getLeaveBalance() {
        try {
            String userId = UserInfo.getUserId();
            String currentYear = String.valueOf(Date.today().year());
            List<myApp202224__Leave_Balance__c> leaveBalances = [SELECT Id, myApp202224__Pending_Leaves__c, myApp202224__Total_Allocated_Leaves__c
                                                    FROM myApp202224__Leave_Balance__c
                                                    WHERE myApp202224__Employee__c = :userId AND myApp202224__Year__c = :currentYear
                                                    LIMIT 1];
            return leaveBalances.isEmpty() ? null : leaveBalances[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leave balance: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static myApp202224__Leave_Balance__c createDefaultLeaveBalance() {
        try {
            String userId = UserInfo.getUserId();
            String currentYear = String.valueOf(Date.today().year());
            List<myApp202224__Leave_Balance__c> existingBalances = [SELECT Id, myApp202224__Pending_Leaves__c, myApp202224__Total_Allocated_Leaves__c
                                                      FROM myApp202224__Leave_Balance__c
                                                      WHERE myApp202224__Employee__c = :userId AND myApp202224__Year__c = :currentYear
                                                      LIMIT 1];
            if (!existingBalances.isEmpty()) {
                return existingBalances[0];
            }
            myApp202224__Leave_Balance__c newBalance = new myApp202224__Leave_Balance__c(
                myApp202224__Employee__c = userId,
                myApp202224__Year__c = currentYear,
                myApp202224__Pending_Leaves__c = 2,
                myApp202224__Total_Allocated_Leaves__c = 24
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

            // Validate Employee__c lookup
            List<User> users = [SELECT Id FROM User WHERE Id = :employeeId LIMIT 1];
            if (users.isEmpty()) {
                throw new AuraHandledException('Invalid Employee ID: ' + employeeId);
            }

            // Validate Leave Type against picklist values
            Schema.DescribeFieldResult fieldResult = Leave_Request__c.Leave_Type__c.getDescribe();
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            Set<String> validLeaveTypes = new Set<String>();
            List<String> allPicklistValues = new List<String>();
            for (Schema.PicklistEntry entry : picklistValues) {
                allPicklistValues.add(entry.getValue() + (entry.isActive() ? ' (Active)' : ' (Inactive)'));
                if (entry.isActive()) {
                    validLeaveTypes.add(entry.getValue());
                }
            }
            System.debug('All Leave_Type__c picklist values: ' + allPicklistValues);
            System.debug('Valid (active) Leave_Type__c picklist values: ' + validLeaveTypes);
            if (!validLeaveTypes.contains(leaveType)) {
                throw new AuraHandledException('Invalid Leave Type: ' + leaveType + '. Valid types are: ' + String.join(new List<String>(validLeaveTypes), ', '));
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
            Database.SaveResult sr = Database.insert(leave, false);
            if (!sr.isSuccess()) {
                String errors = 'DML Errors: ';
                for (Database.Error err : sr.getErrors()) {
                    errors += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                }
                System.debug(LoggingLevel.ERROR, errors);
                throw new AuraHandledException(errors);
            }
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
    public static List<myApp202224__Leave_Request__c> getLeaveStatus() {
        try {
            String userId = UserInfo.getUserId();
            return [SELECT Id, Name, myApp202224__Status__c, myApp202224__Leave_Type__c, myApp202224__Start_Date__c, myApp202224__End_Date__c, myApp202224__Reason__c
                    FROM myApp202224__Leave_Request__c
                    WHERE myApp202224__Employee__c = :userId AND myApp202224__Status__c IN ('Pending', 'Auto-Approved')
                    ORDER BY CreatedDate DESC];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching leave status: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<myApp202224__Leave_Request__c> getLeaveHistory() {
        try {
            String userId = UserInfo.getUserId();
            return [SELECT Id, Name, myApp202224__Start_Date__c, myApp202224__End_Date__c, myApp202224__Reason__c, myApp202224__Status__c, myApp202224__Approved_By__c, Leave_Type__c
                    FROM myApp202224__Leave_Request__c
                    WHERE myApp202224__Employee__c = :userId
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
   @AuraEnabled(cacheable=true)
    public static List<myApp202224__Leave_Request__c> getPendingLeaveRequests() {
        try {
            String managerId = UserInfo.getUserId();
            System.debug('Manager ID: ' + managerId + ', Name: ' + UserInfo.getName());
            List<User> subordinates = [SELECT Id, Name, Email FROM User WHERE ManagerId = :managerId];
            System.debug('Subordinates: ' + subordinates);
            Set<Id> subordinateIds = new Set<Id>();
            for (User u : subordinates) {
                subordinateIds.add(u.Id);
            }
            System.debug('Subordinate IDs: ' + subordinateIds);
            if (subordinateIds.isEmpty()) {
                System.debug('No subordinates found for manager ID: ' + managerId);
                return new List<Leave_Request__c>();
            }
            List<myApp202224__Leave_Request__c> pendingRequests = [SELECT Id, Name, myApp202224__Leave_Type__c, myApp202224__Start_Date__c, myApp202224__End_Date__c, 
                                                            myApp202224__Reason__c, myApp202224__Employee__r.Name, myApp202224__Employee__c, myApp202224__Status__c 
                                                     FROM myApp202224__Leave_Request__c 
                                                     WHERE myApp202224__Employee__c IN :subordinateIds AND myApp202224__Status__c = 'Pending'
                                                     ORDER BY Start_Date__c];
            System.debug('Pending Requests: ' + pendingRequests);
            if (pendingRequests.isEmpty()) {
                System.debug('No pending requests found for subordinates: ' + subordinateIds);
                List<myApp202224__Leave_Request__c> allRequests = [SELECT Id, Name, myApp202224__Leave_Type__c, myApp202224__Start_Date__c, myApp202224__End_Date__c, 
                                                            myApp202224__Status__c, Employee__c, myApp202224__Employee__r.Name 
                                                     FROM myApp202224__Leave_Request__c 
                                                     WHERE myApp202224__Employee__c IN :subordinateIds
                                                     ORDER BY CreatedDate DESC];
                System.debug('All requests for subordinates: ' + allRequests);
            }
            return pendingRequests;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error fetching pending leave requests: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            throw new AuraHandledException('Error fetching pending leave requests: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateLeaveRequest(String leaveRequestId, String newStatus) {
        try {
            if (String.isBlank(leaveRequestId)) {
                throw new AuraHandledException('Leave Request ID is required.');
            }
            if (!new Set<String>{'Approved', 'Rejected'}.contains(newStatus)) {
                throw new AuraHandledException('Invalid Status: ' + newStatus + '. Valid statuses are Approved or Rejected.');
            }

            Schema.DescribeFieldResult fieldResult = Leave_Request__c.Status__c.getDescribe();
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            Set<String> validStatuses = new Set<String>();
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.isActive()) {
                    validStatuses.add(entry.getValue());
                }
            }
            if (!validStatuses.contains(newStatus)) {
                throw new AuraHandledException('Invalid Status value for picklist: ' + newStatus);
            }

            List<Leave_Request__c> leaveRequests = [SELECT Id, Leave_Type__c, Start_Date__c, End_Date__c, 
                                                          Employee__c, Status__c 
                                                   FROM Leave_Request__c 
                                                   WHERE Id = :leaveRequestId LIMIT 1];
            if (leaveRequests.isEmpty()) {
                throw new AuraHandledException('Leave Request not found: ' + leaveRequestId);
            }
            Leave_Request__c leave = leaveRequests[0];

            leave.Status__c = newStatus;
            leave.Approved_By__c = UserInfo.getUserId();

            if (newStatus == 'Approved') {
                String currentYear = String.valueOf(Date.today().year());
                List<Leave_Balance__c> leaveBalances = [SELECT Id, Pending_Leaves__c 
                                                       FROM Leave_Balance__c 
                                                       WHERE Employee__c = :leave.Employee__c AND Year__c = :currentYear
                                                       LIMIT 1];
                if (leaveBalances.isEmpty()) {
                    throw new AuraHandledException('No leave balance found for employee');
                }
                Integer leaveDays = leave.Start_Date__c.daysBetween(leave.End_Date__c) + 1;
                if (leaveBalances[0].Pending_Leaves__c < leaveDays) {
                    throw new AuraHandledException('Insufficient leave balance: ' + leaveDays + ' days required');
                }
                leaveBalances[0].Pending_Leaves__c -= leaveDays;
                Database.SaveResult sr = Database.update(leaveBalances[0], false);
                if (!sr.isSuccess()) {
                    String errors = 'Leave Balance Update Errors: ';
                    for (Database.Error err : sr.getErrors()) {
                        errors += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    throw new AuraHandledException(errors);
                }
            }

            Database.SaveResult sr = Database.update(leave, false);
            if (!sr.isSuccess()) {
                String errors = 'DML Errors: ';
                for (Database.Error err : sr.getErrors()) {
                    errors += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                }
                throw new AuraHandledException(errors);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error updating leave request: ' + e.getMessage());
        }
    }
}