/// Represents one row from the Trimitha / Thrinath / Thripura sheets.
/// `row` is the actual spreadsheet row number — required for update/delete.
/// `sheet` is only populated when this came from the notifications feed
/// (which pulls from all three sheets at once); forms_data_screen sets it
/// separately since it already knows which sheet it's viewing.
class Contact {
  final int row;
  final String contactId;
  final String name;
  final String email;
  final String subject;
  final String message;
  final String source;
  final String status; // 'Unread' | 'Read' | 'Deleted'
  final bool starred;
  final String notes;
  final DateTime? timestamp;
  final String? sheet;

  Contact({
    required this.row,
    required this.contactId,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.source,
    required this.status,
    required this.starred,
    required this.notes,
    required this.timestamp,
    this.sheet,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    DateTime? ts;
    try {
      if (json['Timestamp'] != null)
        ts = DateTime.parse(json['Timestamp'].toString());
    } catch (_) {
      ts = null;
    }
    return Contact(
      row: (json['_row'] is int)
          ? json['_row'] as int
          : int.tryParse('${json['_row']}') ?? 0,
      contactId: json['ContactID']?.toString() ?? '',
      name: json['Name']?.toString() ?? 'Unknown',
      email: json['Email']?.toString() ?? '',
      subject: json['Subject']?.toString() ?? '',
      message: json['Message']?.toString() ?? '',
      source: json['Source']?.toString() ?? '',
      status: json['Status']?.toString() ?? 'Unread',
      starred: json['Starred'] == true || json['Starred']?.toString() == 'true',
      notes: json['Notes']?.toString() ?? '',
      timestamp: ts,
      sheet: json['sheet']?.toString(),
    );
  }

  bool get isUnread => status == 'Unread';

  Contact copyWith({String? status, bool? starred, String? notes}) {
    return Contact(
      row: row,
      contactId: contactId,
      name: name,
      email: email,
      subject: subject,
      message: message,
      source: source,
      status: status ?? this.status,
      starred: starred ?? this.starred,
      notes: notes ?? this.notes,
      timestamp: timestamp,
      sheet: sheet,
    );
  }
}
