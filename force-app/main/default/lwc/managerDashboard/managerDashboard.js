import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingLeaveRequests from '@salesforce/apex/LeaveController.getPendingLeaveRequests';
import updateLeaveRequest from '@salesforce/apex/LeaveController.updateLeaveRequest';

export default class ManagerDashboard extends LightningElement {
    @track leaveRequests = [];
    @track columns = [
        { label: 'Request ID', fieldName: 'Name' },
        { label: 'Employee', fieldName: 'myApp202224__Employee__r.Name' },
        { label: 'Leave Type', fieldName: 'myApp202224__Leave_Type__c' },
        { label: 'Start Date', fieldName: 'myApp202224__Start_Date__c', type: 'date' },
        { label: 'End Date', fieldName: 'myApp202224__End_Date__c', type: 'date' },
        { label: 'Reason', fieldName: 'myApp202224__Reason__c' },
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

    connectedCallback() {
        this.loadPendingRequests();
    }

    async loadPendingRequests() {
        try {
            this.leaveRequests = await getPendingLeaveRequests();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        try {
            await updateLeaveRequest({
                leaveId: row.Id,
                status: actionName === 'approve' ? 'Approved' : 'Rejected'
            });
            this.showToast('Success', `Leave request ${actionName}d successfully.`, 'success');
            this.loadPendingRequests();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}