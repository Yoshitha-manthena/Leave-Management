public with sharing class MonthlyLeaveAllocation implements Schedulable {
    public void execute(SchedulableContext ctx) {
        String currentYear = String.valueOf(Date.today().year());
        List<Leave_Balance__c> balances = [SELECT Id, Pending_Leaves__c, Total_Allocated_Leaves__c
                                           FROM Leave_Balance__c
                                           WHERE Year__c = :currentYear];
        for (Leave_Balance__c balance : balances) {
            balance.Pending_Leaves__c = (balance.Pending_Leaves__c == null ? 0 : balance.Pending_Leaves__c) + 2;
            balance.Total_Allocated_Leaves__c = (balance.Total_Allocated_Leaves__c == null ? 0 : balance.Total_Allocated_Leaves__c) + 2;
        }
        if (!balances.isEmpty()) {
            update balances;
        }

        // Create new balance records for users without one
        List<User> users = [SELECT Id FROM User WHERE IsActive = true];
        List<Leave_Balance__c> newBalances = new List<Leave_Balance__c>();
        for (User u : users) {
            if ([SELECT COUNT() FROM Leave_Balance__c WHERE Employee__c = :u.Id AND Year__c = :currentYear] == 0) {
                newBalances.add(new Leave_Balance__c(
                    Employee__c = u.Id,
                    Year__c = currentYear,
                    Pending_Leaves__c = 2,
                    Total_Allocated_Leaves__c = 24
                ));
            }
        }
        if (!newBalances.isEmpty()) {
            insert newBalances;
        }
    }
}