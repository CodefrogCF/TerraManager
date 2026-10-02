import 'package:file_picker_web/file_picker_web.dart';

// The plugin defaults to reading the complete selected file before returning
// it. Keep the browser File/Blob available and read only the header until the
// user enters a password and the size limit has been checked.
const FilePickerWebOptions backupPickerWebOptions = FilePickerWebOptions(
  withData: false,
  withReadStream: true,
);
