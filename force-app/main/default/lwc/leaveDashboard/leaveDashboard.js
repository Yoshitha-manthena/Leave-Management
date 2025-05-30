import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createLeaveRequest from '@salesforce/apex/LeaveController.createLeaveRequest';
import getLeaveStatus from '@salesforce/apex/LeaveController.getLeaveStatus';
import getLeaveHistory from '@salesforce/apex/LeaveController.getLeaveHistory';
import getLeaveBalance from '@salesforce/apex/LeaveController.getLeaveBalance';
import getCurrentUserId from '@salesforce/apex/LeaveController.getCurrentUserId';

export default class LeaveDashboard extends LightningElement {
    @track leaveType = '';
    @track startDate = '';
    @track endDate = '';
    @track reason = '';
    @track reasonRequired = false;
    @track leaveStatusData = [];
    @track leaveHistoryData = [];
    @track pendingLeaves = 0;
    @track totalLeaves = 0;
    @track today = new Date().toISOString().split('T')[0];

    leaveTypeOptions = [
        { label: 'Sick Leave', value: 'Sick Leave' },
        { label: 'Vacation', value: 'Vacation' },
        { label: 'Personal Leave', value: 'Personal Leave' }
    ];

    leaveStatusColumns = [
        { label: 'Leave ID', fieldName: 'Name' },
        { label: 'Status', fieldName: 'Status__c' }
    ];

    leaveHistoryColumns = [
        { label: 'Request ID', fieldName: 'Name' },
        { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
        { label: 'End Date', fieldName: 'End_Date__c', type: 'date' },
        { label: 'Reason', fieldName: 'Reason__c' },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Approved By', fieldName: 'Approved_By__r.Name' }
    ];

    connectedCallback() {
        this.loadLeaveData();
    }

    async loadLeaveData() {
        try {
            const balance = await getLeaveBalance();
            this.pendingLeaves = balance.Pending_Leaves__c || 0;
            this.totalLeaves = balance.Total_Allocated_Leaves__c || 0;
            this.leaveStatusData = await getLeaveStatus();
            this.leaveHistoryData = await getLeaveHistory();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        if (field === 'leaveType') this.leaveType = event.target.value;
        if (field === 'startDate') this.startDate = event.target.value;
        if (field === 'endDate') this.endDate = event.target.value;
        if (field === 'reason') this.reason = event.target.value;

        // Check if reason is required (no leaves remaining)
        if (this.pendingLeaves === 0) {
            this.reasonRequired = true;
        } else {
            this.reasonRequired = false;
        }
    }

    async handleSubmit() {
        if (!this.leaveType || !this.startDate || !this.endDate || (this.reasonRequired && !this.reason)) {
            this.showToast('Error', 'Please fill all required fields.', 'error');
            return;
        }

        try {
            const userId = await getCurrentUserId();
            await createLeaveRequest({
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason,
                employeeId: userId
            });
            this.showToast('Success', 'Leave request submitted successfully.', 'success');
            this.resetForm();
            this.loadLeaveData();
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    resetForm() {
        this.leaveType = '';
        this.startDate = '';
        this.endDate = '';
        this.reason = '';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}