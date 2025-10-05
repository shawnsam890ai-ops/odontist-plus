import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../models/patient.dart';
import '../models/treatment_session.dart';

/// Builds formatted session summary text and generates a PDF over prescription pad background.
class SessionExportService {
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  static String buildGeneralSessionText(Patient patient, TreatmentSession s) {
    final b = StringBuffer();
    b.writeln('Patient: ${patient.name}   Age: ${patient.age}   Sex: ${patient.sex.label}   Date: ${_dateFmt.format(s.date)}');
    b.writeln();
    if (s.chiefComplaint != null && (s.chiefComplaint!.complaints.isNotEmpty || s.chiefComplaint!.quadrants.isNotEmpty)) {
      final cc = s.chiefComplaint!;
      final complaint = cc.complaints.join(', ');
      final quadrant = cc.quadrants.isNotEmpty ? ' w.r.t ${cc.quadrants.join(', ')}' : '';
      b.writeln('1. Chief Complaint: Pt c/o of $complaint$quadrant.');
    }
    if (s.oralExamFindings.isNotEmpty) {
      b.writeln('2. Oral Findings:');
      for (var i = 0; i < s.oralExamFindings.length; i++) {
        final f = s.oralExamFindings[i];
        b.writeln('   ${String.fromCharCode(97 + i)}) ${f.toothNumber}, ${f.finding}');
      }
    }
    if (s.investigations.isNotEmpty) {
      b.writeln('3. Investigation Done: ${s.investigations.map((e) => e.label).join(', ')}');
    }
    if (s.investigationFindings.isNotEmpty) {
      b.writeln('4. Investigational Findings:');
      for (var i = 0; i < s.investigationFindings.length; i++) {
        final f = s.investigationFindings[i];
        b.writeln('   ${String.fromCharCode(97 + i)}) ${f.toothNumber}, ${f.finding}');
      }
    }
    if (s.toothPlans.isNotEmpty || s.planOptions.isNotEmpty) {
      b.writeln('5. Treatment Plan:');
      if (s.planOptions.isNotEmpty) {
        b.writeln('   Options: ${s.planOptions.join(', ')}');
      }
      for (var i = 0; i < s.toothPlans.length; i++) {
        final f = s.toothPlans[i];
        b.writeln('   ${String.fromCharCode(97 + i)}) ${f.toothNumber}, ${f.plan}');
      }
    }
    if (s.treatmentsDone.isNotEmpty || s.treatmentDoneOptions.isNotEmpty) {
      b.writeln('6. Treatment Done:');
      if (s.treatmentDoneOptions.isNotEmpty) {
        b.writeln('   Options: ${s.treatmentDoneOptions.join(', ')}');
      }
      for (var i = 0; i < s.treatmentsDone.length; i++) {
        final f = s.treatmentsDone[i];
        b.writeln('   ${String.fromCharCode(97 + i)}) ${f.toothNumber}, ${f.treatment}');
      }
    }
    if (s.nextAppointment != null) {
      b.writeln('Next Appointment: ${_dateFmt.format(s.nextAppointment!)}');
    }
    if (s.notes.isNotEmpty) {
      b.writeln('Notes: ${s.notes}');
    }
    return b.toString();
  }

  /// Generates a PDF bytes with prescription pad background (asset) and session text overlay.
  static Future<Uint8List> generateGeneralSessionPdf({
    required Patient patient,
    required TreatmentSession session,
    String padAssetPath = 'assets/prescription/pad.png',
  }) async {
    final doc = pw.Document();
    pw.ImageProvider? bgImage;
    try {
      final bytes = await rootBundle.load(padAssetPath);
      bgImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // silently ignore if asset missing; we'll render plain background
    }

    final text = buildGeneralSessionText(patient, session);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Stack(
            children: [
              if (bgImage != null)
                pw.Positioned.fill(
                  child: pw.Opacity(opacity: 0.95, child: pw.Image(bgImage, fit: pw.BoxFit.cover)),
                ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(40, 120, 40, 60),
                child: pw.Text(
                  text,
                  style: pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  /// Save bytes to a temporary file and return path.
  static Future<File> saveTempFile(Uint8List bytes, {String prefix = 'session_', String ext = '.pdf'}) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$prefix${DateTime.now().millisecondsSinceEpoch}$ext'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
