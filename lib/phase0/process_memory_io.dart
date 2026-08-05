import 'dart:io';

int? currentResidentBytes() => ProcessInfo.currentRss;
