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
    @track leaveStatusData = [];
    @track leaveHistoryData = [];
    @track pendingLeaves = 2;
    @track totalLeaves = 24;
    @track today = new Date().toISOString().split('T')[0];

    leaveTypeOptions = [
        { label: 'Sick', value: 'Sick' }, // Replace 'Sick' with actual Leave_Type__c picklist value
        { label: 'Personal', value: 'Personal' }, // Replace 'Personal' with actual value
        { label: 'Vacation', value: 'Vacation' } // Matches, as Vacation works
    ];

    leaveStatusColumns = [
        { label: 'Leave ID', fieldName: 'Name', type: 'text' },
        { label: 'Status', fieldName: 'myApp202224__Status__c', type: 'text' },
        { label: 'Leave Type', fieldName: 'myApp202224__Leave_Type__c', type: 'text' }
    ];

    leaveHistoryColumns = [
        { label: 'Request ID', fieldName: 'Name', type: 'text' },
        { label: 'Start Date', fieldName: 'myApp202224__Start_Date__c', type: 'date' },
        { label: 'End Date', fieldName: 'myApp202224__End_Date__c', type: 'date' },
        { label: 'Reason', fieldName: 'myApp202224__Reason__c', type: 'text' },
        { label: 'Status', fieldName: 'myApp202224__Status__c', type: 'text' },
        { label: 'Approved By', fieldName: 'myApp202224__Approved_By__c', type: 'text' }
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
            this.pendingLeaves = balance.Pending_Leaves__c || 2;
            this.totalLeaves = balance.Total_Allocated_Leaves__c || 24;

            const statusData = await getLeaveStatus();
            this.leaveStatusData = statusData.map(record => ({
                Id: record.Id,
                Name: record.Name,
                myApp202224__Status__c: record.myApp202224__Status__c,
                myApp202224__Leave_Type__c: record.myApp202224__Leave_Type__c,
                myApp202224__Start_Date__c: record.myApp202224__Start_Date__c,
                myApp202224__End_Date__c: record.myApp202224__End_Date__c,
                myApp202224__Reason__c: record.myApp202224__Reason__c
            }));
            console.log('Leave status data:', JSON.stringify(this.leaveStatusData));

            const historyData = await getLeaveHistory();
            this.leaveHistoryData = historyData.map(record => ({
                Id: record.Id,
                Name: record.Name,
                myApp202224__Start_Date__c: record.myApp202224__Start_Date__c,
                myApp202224__End_Date__c: record.myApp202224__End_Date__c,
                myApp202224__Reason__c: record.myApp202224__Reason__c,
                myApp202224__Status__c: record.myApp202224__Status__c,
                myApp202224__Approved_By__c: record.myApp202224__Approved_By__c || '',
                myApp202224__Leave_Type__c: record.myApp202224__Leave_Type__c
            }));
            console.log('Leave history data:', JSON.stringify(this.leaveHistoryData));
        } catch (error) {
            console.error('Load leave data error:', JSON.stringify(error, null, 2));
            this.showToast('Error', `Failed to load leave data: ${error.body?.message || error.message}`, 'error');
            this.pendingLeaves = 2;
            this.totalLeaves = 24;
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        console.log(`Input change: field=${field}, value=${value}`);
        if (field === 'leaveType') {
            this.leaveType = value;
        } else if (field === 'startDate') {
            this.startDate = value;
        } else if (field === 'endDate') {
            this.endDate = value;
        } else if (field === 'reason') {
            this.reason = value;
        }
        console.log('Current state:', {
            leaveType: this.leaveType,
            startDate: this.startDate,
            endDate: this.endDate,
            reason: this.reason
        });
    }

    async handleSubmit() {
        console.log('handleSubmit called with:', {
            leaveType: this.leaveType,
            startDate: this.startDate,
            endDate: this.endDate,
            reason: this.reason,
            
        });
        if (!this.leaveType || !this.startDate || !this.endDate) {
            console.error('Validation failed:', {
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate
            });
            this.showToast('Error', 'Please fill all required fields (Leave Type, Start Date, End Date).', 'error');
            return;
        }
        try {
            console.log('Submitting leave request:', {
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason || 'None'
            });
            const userId = await getCurrentUserId();
            console.log('User ID:', userId);
            const leaveId = await createLeaveRequest({
                leaveType: this.leaveType,
                startDate: this.startDate,
                endDate: this.endDate,
                reason: this.reason || '',
                employeeId: userId
            });
            console.log('Leave request created with ID:', leaveId);
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
        console.log('Form reset');
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}