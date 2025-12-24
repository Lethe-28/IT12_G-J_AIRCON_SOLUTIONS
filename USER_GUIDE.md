# 📘 G&J Aircon Solutions - User Guide

**Version:** 1.0  
**Last Updated:** December 20, 2025

---

## 📑 Table of Contents

1. [Getting Started](#1-getting-started)
2. [Dashboard Overview](#2-dashboard-overview)
3. [Managing Customers](#3-managing-customers)
4. [Managing Technicians](#4-managing-technicians)
5. [Aircon Unit Management](#5-aircon-unit-management)
6. [Job Scheduling & Orders](#6-job-scheduling--orders)
7. [Financial Management](#7-financial-management)
8. [Reports & Analytics](#8-reports--analytics)
9. [Document Management](#9-document-management)
10. [Administration](#10-administration)

---

## 1. Getting Started

### 1.1 Logging In

1. Launch the G&J Aircon Solutions application
2. Enter your **Email** address in the email field
3. Enter your **Password** in the password field
4. Click the **Login** button
5. If you forgot your password, click "Forgot Password?" to reset it via email

### 1.2 Navigation

The application uses a **sidebar navigation** system:

- **Desktop View**: A permanent sidebar appears on the left side of the screen
- **Mobile View**: Access the navigation menu via the hamburger icon (☰) in the top-left corner

**Main Navigation Sections:**
| Icon | Section | Description |
|------|---------|-------------|
| 📊 | Dashboard | Overview of business metrics and pending actions |
| 📅 | Scheduling | Manage job orders and calendar |
| 👥 | Customers | Customer database management |
| 🔧 | Technicians | Technician roster management |
| ❄️ | Aircons | Aircon unit registry |
| 💰 | Expenses | Financial transaction tracking |
| 💳 | Payments | Payment records |
| 📈 | Reports | Business analytics and charts |
| 📄 | Documents | Document management and generation |
| ⚙️ | Admin | User management, services, and master data |

### 1.3 Logging Out

1. Locate your user profile at the bottom of the sidebar
2. Click on your profile or the settings icon
3. Select **Logout** to securely exit the application

---

## 2. Dashboard Overview

The Dashboard is your **command center** for monitoring business operations at a glance.

### 2.1 Overview Cards

The top section displays key performance indicators (KPIs):

- **Total Revenue**: Sum of all completed payments
- **Pending Jobs**: Number of jobs awaiting action
- **Active Customers**: Count of current customers
- **Today's Schedule**: Number of jobs scheduled for today

### 2.2 Attention Section

This section highlights items requiring immediate attention:

- ⚠️ **Overdue Jobs**: Jobs past their scheduled date
- 📋 **Pending Approvals**: Jobs awaiting confirmation
- 💰 **Unpaid Invoices**: Outstanding payment balances
- 🔔 **Notifications**: Click the bell icon to view all notifications

### 2.3 Today's Job Orders

A quick view of all jobs scheduled for the current day, showing:

- Customer name and contact
- Service type
- Assigned technician
- Job status

**Actions:**
- Click on any job to view full details
- Use quick actions to update job status

---

## 3. Managing Customers

### 3.1 Viewing Customers

1. Navigate to **Customers** from the sidebar
2. Browse the customer list in table view (desktop) or card view (mobile)
3. Use the **Search bar** to find specific customers by name, phone, or email

### 3.2 Adding a New Customer

1. Click the **+ Add Customer** button
2. Fill in the required fields:
   - **Name** (required)
   - **Contact Number** (required)
   - **Email** (optional)
   - **Address** (required)
   - **Customer Type**: Individual or Business
3. Click **Save** to create the customer record

### 3.3 Editing a Customer

1. Locate the customer in the list
2. Click the **Edit** (✏️) button on the customer row
3. Modify the necessary information
4. Click **Save** to update

### 3.4 Archiving a Customer

1. Click the **Archive** button on the customer row
2. Confirm the action in the dialog
3. Archived customers can be restored from the archive section

---

## 4. Managing Technicians

### 4.1 Viewing Technicians

1. Navigate to **Technicians** from the sidebar
2. View technician profiles with their contact information and specializations

### 4.2 Adding a New Technician

1. Click **+ Add Technician**
2. Fill in the details:
   - **Full Name** (required)
   - **Contact Number** (required)
   - **Email** (optional)
   - **Specialization** (e.g., Installation, Repair, Maintenance)
   - **Status**: Active or Inactive
3. Click **Save**

### 4.3 Editing/Archiving Technicians

- Use the **Edit** button to modify technician details
- Use the **Archive** button to deactivate a technician

---

## 5. Aircon Unit Management

### 5.1 Viewing Aircon Units

1. Navigate to **Aircons** from the sidebar
2. Browse all registered aircon units
3. Filter by customer or status

### 5.2 Registering a New Aircon Unit

1. Click **+ Add Aircon**
2. Complete the form:
   - **Customer** (required): Select from existing customers
   - **Brand** (required): Select or add a new brand
   - **Type** (required): Window, Split, Cassette, etc.
   - **Model Number** (optional)
   - **Serial Number** (optional)
   - **Installation Date** (optional)
   - **Location** (where the unit is installed)
   - **Status**: Active, For Repair, Decommissioned
3. Click **Save**

### 5.3 Managing Aircon Records

- **Edit**: Update unit details or status
- **Archive**: Remove from active list (data is preserved)
- **View History**: See all service jobs related to this unit

---

## 6. Job Scheduling & Orders

### 6.1 Calendar View

1. Navigate to **Scheduling** from the sidebar
2. The calendar displays jobs for the current month
3. **Navigate months**: Use the arrow buttons (< >) to move between months
4. **Color coding**:
   - 🟢 Green: Completed jobs
   - 🟡 Yellow: Pending jobs
   - 🔴 Red: Overdue jobs
   - 🔵 Blue: In-progress jobs

### 6.2 Creating a New Job Order

1. Click **+ New Job Order** or click on a date
2. Fill in the job details:

   **Customer Information:**
   - **Customer** (required): Select from dropdown
   - **Aircon Unit** (required): Select customer's registered units

   **Job Details:**
   - **Service Type** (required): Installation, Repair, Cleaning, Maintenance
   - **Description** (optional): Additional notes
   - **Scheduled Date** (required): When the job should be performed
   - **Scheduled Time** (optional): Preferred time slot

   **Assignment:**
   - **Technician** (required): Assign a technician
   - **Priority**: Normal, High, Urgent

3. Click **Create Job Order**

### 6.3 Managing Job Orders

**Viewing Job Details:**
1. Click on any job in the calendar or list
2. View comprehensive details including customer info, service items, and billing

**Updating Job Status:**
1. Open the job details
2. Change status using the status dropdown:
   - **Pending** → **Confirmed** → **In Progress** → **Completed**
3. Status updates are saved automatically

**Adding Service Items & Billing:**
1. Open the job and go to the **Billing** tab
2. Add service items (labor, parts, materials)
3. Adjust quantities and prices
4. The total is calculated automatically

**Completing a Job:**
1. Ensure all service items are added
2. Change status to **Completed**
3. Generate invoice if required

### 6.4 Action Banner (Pending Actions)

At the top of the scheduling screen, you'll see a banner showing jobs requiring action:
- Click on the banner to expand the list
- Take quick actions directly from the list

### 6.5 Creating Follow-Up Jobs

After completing a maintenance job, you can schedule follow-up services:
1. Open a completed job
2. Click **Schedule Follow-Up**
3. Select the interval (e.g., 3 months, 6 months, 1 year)
4. Confirm to create a new scheduled job

---

## 7. Financial Management

### 7.1 Expenses Screen

Navigate to **Expenses** to track all financial transactions.

**Summary Cards:**
- 💵 **Total Income**: All revenue for the selected period
- 💸 **Total Expenses**: All outgoing payments
- 💰 **Net Balance**: Income minus expenses

**Viewing Transactions:**
- Filter by date range using the date selector
- Filter by type: All, Income, Expense
- View transactions in chronological order

### 7.2 Recording an Expense/Income

1. Click **+ Add Transaction**
2. Select transaction type:
   - **Income**: Payments received from customers
   - **Expense**: Business costs (supplies, utilities, etc.)
3. Fill in details:
   - **Amount** (required)
   - **Category** (required): Select from predefined categories
   - **Description** (optional)
   - **Date** (required)
   - **Linked Job** (optional): Associate with a job order
4. Click **Save**

### 7.3 Payments Screen

Navigate to **Payments** for detailed payment tracking.

**Recording a Payment:**
1. Click **+ Add Payment**
2. Select the associated job order
3. Enter payment details:
   - Amount received
   - Payment method (Cash, Card, Bank Transfer, etc.)
   - Reference number (for tracking)
4. Click **Save**

---

## 8. Reports & Analytics

### 8.1 Accessing Reports

1. Navigate to **Reports** from the sidebar
2. Select the report period using the filter chips:
   - Today
   - Weekly
   - Monthly
   - Last 6 Months
   - Yearly

### 8.2 Available Reports

**Key Performance Indicators (KPIs):**
- Total Jobs
- Completed Jobs
- Revenue Generated
- Pending Collections

**Business Insights:**
- Average Job Value
- Completion Rate
- Top Service Type
- Busiest Day

**Financial Overview:**
- Income trends over time
- Expense breakdown by category
- Net profit/loss analysis

**Service Distribution:**
- Pie/bar chart showing service type popularity
- Top performing services

**Customer Analytics:**
- Top customers by revenue
- Customer acquisition trends

### 8.3 Interactive Charts

- **Hover** over chart elements to see detailed values
- **Click** on insight cards to drill down into period-specific data
- Charts update automatically when you change the date range

---

## 9. Document Management

### 9.1 Viewing Documents

1. Navigate to **Documents** from the sidebar
2. Use **Categories** to filter:
   - 📄 All Documents
   - 🧾 Invoices
   - 📋 Contracts
   - 📊 Reports
   - 🗄️ Archived
3. Toggle between **Grid** and **List** view

### 9.2 Generating Documents

1. Click the **+ Generate** button
2. Select document type:

   **Statement of Account (SOA):**
   - Select a customer
   - Choose date range
   - Click **Generate**

   **Weekly Report:**
   - Select the week
   - Click **Generate**

   **Deferment Form:**
   - Select customer and job
   - Fill in deferment details
   - Click **Generate**

### 9.3 Managing Documents

**Viewing/Printing:**
- Click on a document to preview
- Use the **Print** button to print or save as PDF

**Archiving:**
- Click the **Archive** button to move to archive
- Archived documents can be restored or permanently deleted

---

## 10. Administration

### 10.1 User Management

*(Admin Access Required)*

1. Navigate to **Admin** > **User Management**
2. View all system users and their roles

**Adding a New User:**
1. Click **+ Add User**
2. Fill in:
   - Email address
   - Full name
   - Role: Admin, Manager, Employee
3. A password reset link will be sent to the user's email

**Managing Users:**
- **Edit**: Modify user details or change role
- **Delete**: Remove user access (use with caution)

### 10.2 Service Items

1. Navigate to **Admin** > **Service Items**
2. Manage the catalog of services offered

**Adding a Service Item:**
1. Click **+ Add Service**
2. Enter details:
   - Service Name
   - Description
   - Default Price
   - Category
3. Click **Save**

### 10.3 Master Data

1. Navigate to **Admin** > **Master Data**
2. Manage reference data used throughout the system:

**Editable Categories:**
- **AC Brands**: Samsung, LG, Daikin, etc.
- **AC Types**: Window, Split, Cassette, etc.

**System References (Read-Only):**
- Job Statuses
- Payment Methods
- Service Categories

---

## 📱 Mobile App Tips

- **Swipe gestures**: Swipe left on list items for quick actions
- **Pull to refresh**: Pull down on any list to refresh data
- **Floating Action Button (FAB)**: Use the + button for quick creation
- **Responsive layout**: The app adapts to your screen size automatically

---

## ⌨️ Keyboard Shortcuts (Desktop)

| Shortcut | Action |
|----------|--------|
| `Ctrl + N` | New item (context-dependent) |
| `Ctrl + S` | Save current form |
| `Esc` | Close dialog/cancel |
| `Enter` | Submit form |

---

## 🆘 Troubleshooting

### Common Issues

**Cannot log in:**
- Verify email and password are correct
- Check your internet connection
- Try the "Forgot Password" feature

**Data not loading:**
- Check your internet connection
- Pull to refresh the screen
- Try logging out and back in

**App running slowly:**
- Close other running applications
- Clear app cache if available
- Ensure stable internet connection

### Getting Help

For additional support:
- Contact your system administrator
- Check the application documentation
- Report bugs through the feedback system

---

## 📝 Best Practices

1. **Regular Backups**: Ensure data is synced to the cloud regularly
2. **Complete Job Records**: Fill in all relevant fields for accurate reporting
3. **Timely Updates**: Update job statuses as work progresses
4. **Customer Data**: Keep customer information current
5. **Document Generation**: Generate invoices promptly after job completion
6. **Regular Reviews**: Check the dashboard daily for pending actions

---

*© 2025 G&J Aircon Solutions. All rights reserved.*
