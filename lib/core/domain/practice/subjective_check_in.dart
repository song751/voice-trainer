final class SubjectiveCheckIn {
  const SubjectiveCheckIn({
    this.comfort = SubjectiveComfort.unspecified,
    this.notes,
  });

  final SubjectiveComfort comfort;
  final String? notes;
}

enum SubjectiveComfort { unspecified, comfortable, discomfort }
