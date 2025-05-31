import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createLeaveRequest from '@salesforce/apex/LeaveController.createLeaveRequest';
import getLeaveStatus from '@salesforce/apex/LeaveController.getLeaveStatus';
import getLeaveHistory from '@salesforce/apex/LeaveController.getLeaveHistory';
import getLeaveBalance from '@salesforce/apex/LeaveController.getLeaveBalance';
import createDefaultLeaveBalance from '@salesforce/apex/LeaveController.createDefaultLeaveBalance';
import getCurrentUserId from '@salesforce/apex/LeaveController.getCurrentUserId';

export default class LeaveDashboard extends LightningElement {
    @track leaveType = '';
    @track startDate = '';
    @track endDate = '';
    @track reason = '';
    @track reasonRequired = false;
    @track leaveStatusData = [];
    @track leaveHistoryData = [];
    @track pendingLeaves = 2;
    @track totalLeaves = 24;
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
            console.log('Loading leave balance...');
            let balance = await getLeaveBalance();
            if (!balance) {
                console.log('No leave balance found, creating default...');
                balance = await createDefaultLeaveBalance();
            }
            console.log('Leave balance loaded:', JSON.stringify(balance));
            this.pendingLeaves = balance.Pending_Leaves__c || 0;
            this.totalLeaves = balance.Total_Allocated_Leaves__c || 0;

            console.log('Loading leave status...');
            this.leaveStatusData = await getLeaveStatus();
            console.log('Leave status loaded:', JSON.stringify(this.leaveStatusData));

            console.log('Loading leave history...');
            this.leaveHistoryData = await getLeaveHistory();
            console.log('Leave history loaded:', JSON.stringify(this.leaveHistoryData));
        } catch (error) {
            console.error('Load leave data error:', JSON.stringify(error, null, 2));
            this.showToast('Error', `Failed to load leave data: ${error.body?.message || error.message}`, 'error');
            this.pendingLeaves = 0;
            this.totalLeaves = 0;
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        if (field === 'leaveType') this.leaveType = event.target.value;
        if (field === 'startDate') this.startDate = event.target.value;
        if (field === 'endDate') this.endDate = event.target.value;
        if (field === 'reason') this.reason = event.target.value;

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
            console.log('Input data:', {
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason
            });
            const userId = await getCurrentUserId();
            console.log('User ID:', userId);
            await createLeaveRequest({
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason,
                employeeId: userId
            });
            console.log('Leave request submitted successfully');
            this.showToast('Success', 'Leave request submitted successfully.', 'success');
            this.resetForm();
            await this.loadLeaveData();
        } catch (error) {
            console.error('Submission error:', JSON.stringify(error, null, 2));
            const errorMessage = error.body?.message || error.message || 'Unknown error occurred';
            this.showToast('Error', `Failed to submit leave request: ${errorMessage}`, 'error');
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