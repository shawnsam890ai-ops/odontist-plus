import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/doctor_provider.dart';
import '../../models/doctor.dart';

/// Responsive UI component for displaying the next upcoming appointment.
/// Shows doctor info (left column) and doctor avatar (right column).
class UpcomingAppointmentWidget extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const UpcomingAppointmentWidget({
    super.key,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final doctorProvider = context.watch<DoctorProvider>();
    final now = DateTime.now();

    // Find next upcoming appointment (after current time)
    final upcomingAppointments = appointmentProvider.appointments
        .where((appt) => appt.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // If no upcoming appointment, show placeholder
    if (upcomingAppointments.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        elevation: 2.0,
        child: Padding(
          padding: padding,
          child: const Center(
            child: Text(
              'No upcoming appointments',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ),
      );
    }

    final nextAppointment = upcomingAppointments.first;
    
    // Find doctor for this appointment if possible
    final doctors = doctorProvider.doctors.where((d) => d.id == nextAppointment.doctorId).toList();
    final doctor = doctors.isNotEmpty ? doctors.first : null;

    final doctorName = doctor?.name ?? nextAppointment.doctorName ?? 'Dr. Unknown';
  final specialty = doctor != null ? doctor.role.label() : 'General Dentist';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 2.0,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Column: Appointment details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    doctorName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '($specialty)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Time details with vertical line
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTime(nextAppointment.dateTime),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _formatDate(nextAppointment.dateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right Column: Doctor image (full display with rounded corners)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 100,
                height: 180,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Image.asset(
                  'assets/images/doctor_avatar.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // _formatRole removed; use DoctorRole.label() where a Doctor instance exists.

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }

  String _formatDate(DateTime dateTime) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}
