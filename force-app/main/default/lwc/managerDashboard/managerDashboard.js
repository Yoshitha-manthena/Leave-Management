import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingLeaveRequests from '@salesforce/apex/LeaveController.getPendingLeaveRequests';
import updateLeaveRequest from '@salesforce/apex/LeaveController.updateLeaveRequest';

export default class ManagerLeaveApproval extends LightningElement {
    @track pendingRequests = [];
    @track selectedRequestId = '';
    @track newStatus = '';
    @track isModalOpen = false;
    @track isLoading = true;

    columns = [
        { label: 'Request ID', fieldName: 'Name', type: 'text' },
        { label: 'Employee', fieldName: 'EmployeeName', type: 'text' },
        { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
        { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
        { label: 'End Date', fieldName: 'End_Date__c', type: 'date' },
        { label: 'Reason', fieldName: 'Reason__c', type: 'text' },
        { 
            label: 'Actions', 
            type: 'button', 
            typeAttributes: { 
                label: 'Review', 
                name: 'review', 
                variant: 'brand',
                title: 'Review Request',
                disabled: false
            }
        }
    ];

    statusOptions = [
        { label: 'Approve', value: 'Approved' },
        { label: 'Reject', value: 'Rejected' }
    ];

    connectedCallback() {
        this.loadPendingRequests();
    }

    async loadPendingRequests() {
        this.isLoading = true;
        try {
            const data = await getPendingLeaveRequests();
            console.log('Raw data from Apex:', JSON.stringify(data));
            this.pendingRequests = data.map(record => ({
                Id: record.Id,
                Name: record.Name,
                EmployeeName: record.Employee__r?.Name || 'Unknown',
                Leave_Type__c: record.Leave_Type__c,
                Start_Date__c: record.Start_Date__c,
                End_Date__c: record.End_Date__c,
                Reason__c: record.Reason__c || ''
            }));
            console.log('Mapped pending requests:', JSON.stringify(this.pendingRequests));
            if (this.pendingRequests.length === 0) {
                this.showToast('Info', 'No pending leave requests found.', 'info');
            }
        } catch (error) {
            console.error('Error loading requests:', error);
            this.showToast('Error', `Failed to load pending requests: ${error.body?.message || error.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        console.log('Row action:', actionName, 'Row:', JSON.stringify(row));
        if (actionName === 'review') {
            this.selectedRequestId = row.Id;
            this.isModalOpen = true;
        }
    }

    handleStatusChange(event) {
        this.newStatus = event.target.value;
        console.log('Selected status:', this.newStatus);
    }

    async handleSubmit() {
        if (!this.newStatus) {
            this.showToast('Error', 'Please select a status.', 'error');
            return;
        }
        try {
            console.log('Submitting update:', { leaveRequestId: this.selectedRequestId, newStatus: this.newStatus });
            await updateLeaveRequest({
                leaveRequestId: this.selectedRequestId,
                newStatus: this.newStatus
            });
            this.showToast('Success', 'Leave request updated successfully.', 'success');
            this.closeModal();
            await this.loadPendingRequests();
        } catch (error) {
            console.error('Update error:', error);
            this.showToast('Error', `Failed to update leave request: ${error.body?.message || error.message}`, 'error');
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedRequestId = '';
        this.newStatus = '';
        console.log('Modal closed');
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}