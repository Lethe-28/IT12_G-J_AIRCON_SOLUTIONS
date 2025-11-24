import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'scheduling.dart';

class CalendarViewScreen extends StatefulWidget {
  final List<JobOrder> jobOrders;
  
  const CalendarViewScreen({super.key, required this.jobOrders});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();

  List<JobOrder> get _selectedDateJobs {
    return widget.jobOrders.where((job) {
      final jobDate = DateTime(
        job.dateTime.year,
        job.dateTime.month,
        job.dateTime.day,
      );
      final selected = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      return jobDate.isAtSameMomentAs(selected);
    }).toList();
  }

  List<JobOrder> get _monthJobs {
    return widget.jobOrders.where((job) {
      return job.dateTime.year == _currentMonth.year &&
          job.dateTime.month == _currentMonth.month;
    }).toList();
  }

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  int _getJobsCountForDay(int day) {
    return _monthJobs.where((job) => job.dateTime.day == day).length;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isServiceManager = AppState.currentRole == UserRole.serviceManager;
    final fontSize = isServiceManager ? 16.0 : 14.0;
    
    return Dialog(
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Calendar View',
                  style: TextStyle(fontSize: isServiceManager ? 24.0 : 20.0, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _monthHeader(fontSize),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _calendarGrid(fontSize),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: _selectedDateJobsList(fontSize),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader(double fontSize) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
          iconSize: fontSize + 4,
        ),
        Text(
          '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
          style: TextStyle(fontSize: fontSize + 4, fontWeight: FontWeight.w700),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
          iconSize: fontSize + 4,
        ),
      ],
    );
  }

  Widget _calendarGrid(double fontSize) {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstDay = _getFirstDayOfMonth(_currentMonth);
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Week day headers
          Row(
            children: weekDays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          // Calendar days
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: daysInMonth + firstDay - 1,
              itemBuilder: (context, index) {
                if (index < firstDay - 1) {
                  return const SizedBox.shrink();
                }
                
                final day = index - firstDay + 2;
                final dayDate = DateTime(_currentMonth.year, _currentMonth.month, day);
                final isSelected = dayDate.year == _selectedDate.year &&
                    dayDate.month == _selectedDate.month &&
                    dayDate.day == _selectedDate.day;
                final isToday = dayDate.year == DateTime.now().year &&
                    dayDate.month == DateTime.now().month &&
                    dayDate.day == DateTime.now().day;
                final jobsCount = _getJobsCountForDay(day);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = dayDate;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : isToday
                              ? const Color(0xFFEAF2FF)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isSelected
                          ? Border.all(color: const Color(0xFF2563EB), width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.toString(),
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (jobsCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.3)
                                  : const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              jobsCount.toString(),
                              style: TextStyle(
                                fontSize: fontSize - 4,
                                color: isSelected ? Colors.white : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedDateJobsList(double fontSize) {
    final dateStr = '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jobs on $dateStr',
            style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedDateJobs.isEmpty
                ? Center(
                    child: Text(
                      'No jobs scheduled',
                      style: TextStyle(fontSize: fontSize, color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _selectedDateJobs.length,
                    itemBuilder: (context, index) {
                      final job = _selectedDateJobs[index];
                      return _jobCard(job, fontSize);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _jobCard(JobOrder job, double fontSize) {
    final statusColor = _getStatusColor(job.status);
    final timeStr = '${job.dateTime.hour.toString().padLeft(2, '0')}:${job.dateTime.minute.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.id,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  job.status,
                  style: TextStyle(
                    fontSize: fontSize - 4,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.clientName,
            style: TextStyle(
              fontSize: fontSize - 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: fontSize - 2, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                '$timeStr • ${job.jobType}',
                style: TextStyle(fontSize: fontSize - 2, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

