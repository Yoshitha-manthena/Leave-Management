import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingLeaveRequests from '@salesforce/apex/LeaveController.getPendingLeaveRequests';
import updateLeaveRequest from '@salesforce/apex/LeaveController.updateLeaveRequest';
import { refreshApex } from '@salesforce/apex';

export default class ManagerLeaveApproval extends LightningElement {
    @track leaveRequests = [];
    @track isLoading = true;
    wiredResult;

    columns = [
        { label: 'Request ID', fieldName: 'Name', type: 'text' },
        { label: 'Employee', fieldName: 'EmployeeName', type: 'text' },
        { label: 'Leave Type', fieldName: 'myApp202224__Leave_Type__c', type: 'text' },
        { label: 'Start Date', fieldName: 'myApp202224__Start_Date__c', type: 'date' },
        { label: 'End Date', fieldName: 'myApp202224__End_Date__c', type: 'date' },
        { label: 'Reason', fieldName: 'myApp202224__Reason__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Approve', name: 'approve' },
                    { label: 'Reject', name: 'reject' }
                ]
            }
        }
    ];

    @wire(getPendingLeaveRequests)
    wiredLeaveRequests(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            console.log('Raw data from Apex:', JSON.stringify(result.data));
            this.leaveRequests = result.data.map(record => ({
                Id: record.Id,
                Name: record.Name,
                EmployeeName: record.myApp202224__Employee__r?.Name || 'Unknown',
                myApp202224__Leave_Type__c: record.myApp202224__Leave_Type__c,
                myApp202224__Start_Date__c: record.myApp202224__Start_Date__c,
                myApp202224__End_Date__c: record.myApp202224__End_Date__c,
                myApp202224__Reason__c: record.myApp202224__Reason__c || 'None'
            }));
            console.log('Mapped leave requests:', JSON.stringify(this.leaveRequests));
            console.log('Number of requests:', this.leaveRequests.length);
        } else if (result.error) {
            console.error('Error fetching requests:', JSON.stringify(result.error));
            this.showToast('Error', 'Failed to load leave requests: ' + (result.error.body?.message || result.error.message), 'error');
            this.leaveRequests = [];
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        console.log('Row action:', actionName, 'for request ID:', row.Id);
        this.handleLeaveAction(row.Id, actionName === 'approve' ? 'Approved' : 'Rejected');
    }

    async handleLeaveAction(leaveRequestId, newStatus) {
        this.isLoading = true;
        try {
            console.log('Updating leave request:', leaveRequestId, 'to status:', newStatus);
            await updateLeaveRequest({ leaveRequestId, newStatus });
            this.showToast('Success', `Leave request ${newStatus.toLowerCase()} successfully.`, 'success');
            await refreshApex(this.wiredResult);
        } catch (error) {
            console.error('Update error:', JSON.stringify(error));
            this.showToast('Error', `Failed to update leave request: ${error.body?.message || error.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}